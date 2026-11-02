# 数据格式规范

Email Vault 的全部数据保存在一个 SQLite 文件中。本文档是磁盘格式的权威说明：任何实现都必须能读写符合本规范的数据库，所有改动必须向后兼容。

默认路径 `~/.local/share/email-vault/vault.db`，可用环境变量 `EMAIL_VAULT_DB` 覆盖。文件权限 0600。

## 表结构

```sql
CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE emails (
    id           INTEGER PRIMARY KEY,
    address      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_enc BLOB,                     -- 密文；NULL 表示未设置
    note         TEXT NOT NULL DEFAULT '', -- 明文
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now')),
    secret_enc   BLOB                      -- 安全备注密文（v1.0.0 新增）
);

CREATE TABLE accounts (
    id              INTEGER PRIMARY KEY,
    email_id        INTEGER NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
    platform        TEXT NOT NULL,
    category        TEXT NOT NULL DEFAULT 'other', -- ai | social | crypto | other
    username        TEXT NOT NULL DEFAULT '',
    password_enc    BLOB,
    url             TEXT NOT NULL DEFAULT '',
    note            TEXT NOT NULL DEFAULT '',
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    -- 以下为 v1.0.0 新增
    renew_at        TEXT,                          -- 到期日 yyyy-MM-dd（本地日期）；NULL 表示无续费提醒
    renew_cycle     TEXT NOT NULL DEFAULT '',      -- once | monthly | yearly
    renew_amount    TEXT NOT NULL DEFAULT '',      -- 自由文本，如 ¥99
    renew_lead_days INTEGER NOT NULL DEFAULT 7,    -- 提前提醒天数
    secret_enc      BLOB                           -- 安全备注密文
);

CREATE INDEX idx_accounts_email_id ON accounts(email_id);
```

每个连接必须执行 `PRAGMA foreign_keys = ON`，删除邮箱时级联删除其服务。

### 迁移规则

- 只允许 `ALTER TABLE ... ADD COLUMN`，新列必须可为 NULL 或带默认值，保证旧版本仍能打开新库。
- 打开数据库时检测缺失的列并补齐；库中已有数据时，先用 SQLite 备份 API 备份到 `<库目录>/backups/<库名>-pre-migration-<日期>-<时间戳>.db`（0600）。
- 修改主密码前同样备份，标签为 `pre-password-change`。

## 加密

### 密钥派生

`meta` 表中两条记录：

| key | value |
|---|---|
| `kdf_params` | JSON：`{"salt": "<32 位 hex>", "time_cost": 3, "memory_cost": 65536, "parallelism": 4}` |
| `key_verifier` | hex 字符串：用主密钥加密 `email-vault-verifier-v1` 得到的密文 |

主密钥 = **Argon2id**（版本 0x13），输入为主密码的 UTF-8 字节，salt 为 `kdf_params.salt` 的 hex 解码，`time_cost` / `memory_cost`（KiB）/ `parallelism` 取自 JSON，输出 32 字节。参数从 JSON 读取，不得写死。

### 字段加密

AES-256-GCM，无 AAD，每次加密使用随机 12 字节 nonce。存储格式：

```
nonce (12 字节) || 密文 || tag (16 字节)
```

即 CryptoKit `AES.GCM.SealedBox.combined`。明文为 UTF-8 字符串。加密字段：`emails.password_enc`、`emails.secret_enc`、`accounts.password_enc`、`accounts.secret_enc`。

### 解锁

派生密钥后解密 `key_verifier`，结果等于 `email-vault-verifier-v1` 才算主密码正确。失败时应延迟约 1 秒再返回。

### 修改主密码

校验当前密码 → 生成新 salt 并派生新密钥 → 备份 → 在**单个事务**内用新密钥重新加密所有加密字段，并写入新的 `kdf_params` 与 `key_verifier`。任一密文解密失败则整个事务回滚。

### 测试向量

实现必须通过以下向量（见 `email-swift/Tests/EmailVaultCoreTests/CryptoTests.swift`）：

```
主密码:      test-master-123
kdf_params: {"salt": "00112233445566778899aabbccddeeff", "time_cost": 3, "memory_cost": 65536, "parallelism": 4}
派生密钥:    4cf81a5f663c93d65bbd014cd37f286547b700ee06382a23ffdd425d698f22b3
密文 blob:   0102030405060708090a0b0c84795e1334ccf22ad386a44db5211e03d3020877c74a13e8b2a06dc8ae824bcc
解密结果:    hello-密码-123
verifier:   0102030405060708090a0b0c8971531637cc61e4200d70e1ee755e59aaffb193fd025682de2292f0a15416805052e0352f149a
            （解密应得到 email-vault-verifier-v1）
```

## Touch ID 封装文件

开启 Touch ID 后，在数据库旁写入 `<库名>.touchid.json`（0600）。该文件不属于数据库，也不包含在备份中。

```json
{
  "version": 1,
  "seKey": "<base64>",
  "ephemeralPublicKey": "<base64>",
  "sealedKey": "<base64>",
  "vaultID": "<hex>",
  "passwordAt": 1793630000
}
```

| 字段 | 含义 |
|---|---|
| `seKey` | Secure Enclave P-256 密钥的不透明表示（`SecureEnclave.P256.KeyAgreement.PrivateKey.dataRepresentation`），访问控制为 `privateKeyUsage` + `biometryCurrentSet`，只能在本机使用 |
| `ephemeralPublicKey` | 临时 P-256 公钥，X9.63 格式 |
| `sealedKey` | 用封装密钥加密的主密钥，格式同字段加密 |
| `vaultID` | `SHA-256(key_verifier 的 hex 字符串)`；与当前库不符时文件作废 |
| `passwordAt` | 最近一次输入主密码的时间（Unix 秒）；超过 14 天必须重新输入 |

封装密钥 = HKDF-SHA256(ECDH(临时私钥, SE 公钥), salt = `email-vault-touchid-v1`, info = 临时公钥 X9.63 ‖ SE 公钥 X9.63, 32 字节)。

## 备份文件

导出的备份与自动备份都是完整的 SQLite 快照（SQLite 备份 API），加密字段保持密文，可直接作为 `vault.db` 使用，需要备份当时的主密码解锁。
