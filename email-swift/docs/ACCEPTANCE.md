# 验收清单（在你的 Mac 上）

第 1–2 步通过之前，**不要**解锁或写入正在使用的数据库。第 3 步一律用 `vault.db` 的**副本**。

注意：`open` 启动的应用**不会继承**当前 shell 的环境变量，必须用 `open --env` 显式传入 `EMAIL_VAULT_DB`，否则应用会打开真实数据库。

## 1. 构建与单元测试

```bash
cd /path/to/email-swift
swift test
# 预期：CryptoTests、StoreTests、PlatformTests 全部通过
# （Argon2 测试向量、解锁、加解密往返、空密码、
#   级联删除、LIKE 转义、平台图标匹配）
```

```bash
./scripts/build.sh
# 生成：dist/Email Vault.app
```

只看命令、不编译：

```bash
./scripts/build.sh --dry-run
```

## 2. 临时数据库冒烟测试

```bash
export EMAIL_VAULT_DB="/tmp/email-vault-smoke.db"
rm -f "$EMAIL_VAULT_DB"
open --env "EMAIL_VAULT_DB=$EMAIL_VAULT_DB" "dist/Email Vault.app"
# 设置主密码（≥8 位），添加一个邮箱和一个服务，锁定，再解锁。
# 确认密码能显示/复制；编辑时密码留空会保留旧密码。
```

## 3. 真实数据 — 只用副本

```bash
# 复制一份 — 首次验证绝不让应用直接打开真实文件
mkdir -p /tmp/email-vault-accept
cp ~/.local/share/email-vault/vault.db /tmp/email-vault-accept/vault.db
chmod 600 /tmp/email-vault-accept/vault.db
export EMAIL_VAULT_DB="/tmp/email-vault-accept/vault.db"
open --env "EMAIL_VAULT_DB=$EMAIL_VAULT_DB" "dist/Email Vault.app"
```

1. 用**现有**主密码解锁。
2. 核对邮箱数和服务数是否与原数据库一致。
3. 抽查几个密码（显示/复制）。
4. 确认邮箱服务商分组和平台图标显示正常。

以上都对得上之后，才可以不带 `EMAIL_VAULT_DB` 启动，让应用直接打开 `~/.local/share/email-vault/vault.db`（未启用沙盒）。

## 4. 回归检查要点

- 主密码错误：约 1 秒延迟，不解锁。
- 闲置约 10 分钟 → 自动锁定（⌘L 立即锁定）。
- 导出备份 → 得到 SQLite 文件，密码仍是密文，权限 600。
- 编辑服务/邮箱时密码栏留空 → 不覆盖旧密码。
- 删除邮箱 → 其下账号级联删除。
