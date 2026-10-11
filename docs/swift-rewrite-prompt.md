# 任务：把 Email Vault 重构成原生 macOS Swift 应用

## 背景

我有一个本地密码管理小工具 Email Vault，现在是 Python（FastAPI + SQLite + 网页 UI，外面用 pywebview 包成 .app）。
它记录「哪个邮箱注册了哪些平台」，并加密保存邮箱密码和平台密码。
请用 **Swift + SwiftUI** 重写成原生 macOS 应用，**功能和数据格式与现版本完全兼容**。

源码在这个目录（请先通读）：`/Users/fantasy/Desktop/claude/email`
重点文件：
- `src/email_vault/crypto.py`：密钥派生与加密（**必须逐字节兼容**）
- `src/email_vault/auth.py`：主密码校验、会话与闲置自动锁定
- `src/email_vault/store.py`：SQLite 表结构与查询
- `src/email_vault/ui.py`：邮箱厂商识别、平台目录 `PLATFORMS`、平台图标匹配规则
- `src/email_vault/templates/`、`static/`：现有界面与交互（作为 UI 参考）
- `src/email_vault/templates/_brand_icons.html`：品牌 SVG 图标（CC0，可直接转成 Asset）
- `tests/`：现有行为的测试，可作为验收参考

## 🚨 最高优先级：真实数据不能丢

- 真实数据库：`~/.local/share/email-vault/vault.db`，里面是真实账号密码。
- **开发和测试期间禁止读写这个文件**，一律用 `EMAIL_VAULT_DB` 环境变量指向临时库，或者复制一份来测。
- 应用最终要能**直接打开这个现有的 vault.db**，用原来的主密码解锁，看到全部数据。不要做迁移、不要改表结构、不要换加密格式。
- 任何会写入真实库的操作（包括 schema 变更）前，必须先用 SQLite 备份 API 备份到 `~/.local/share/email-vault/backups/`。
- 应用**不要开 App Sandbox**（否则访问不到 `~/.local/share`），或者首次启动用 NSOpenPanel 让我选择文件并保存 security-scoped bookmark。二选一，告诉我你选哪个。

## 数据格式（必须兼容）

### SQLite 表结构（原样使用，不得修改）

```sql
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE emails (
    id INTEGER PRIMARY KEY,
    address TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_enc BLOB,
    note TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE accounts (
    id INTEGER PRIMARY KEY,
    email_id INTEGER NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'other',   -- ai | social | crypto | other
    username TEXT NOT NULL DEFAULT '',
    password_enc BLOB,
    url TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_accounts_email_id ON accounts(email_id);
```
每个连接都要执行 `PRAGMA foreign_keys = ON`（删除邮箱时级联删除服务）。

### 加密

- `meta` 表中：
  - `kdf_params`：JSON，例如 `{"salt": "<32位hex>", "time_cost": 3, "memory_cost": 65536, "parallelism": 4}`
  - `key_verifier`：hex 字符串，是用主密钥加密 `"email-vault-verifier-v1"` 得到的密文
- 密钥派生：**Argon2id**（版本 0x13），输入为主密码的 UTF-8 字节，salt = `kdf_params.salt` 的 hex 解码，`time_cost` / `memory_cost`(KiB) / `parallelism` 取自 JSON，输出 32 字节。等价于 Python `argon2.low_level.hash_secret_raw(..., type=Type.ID)`。
  - CryptoKit 没有 Argon2，需要引入可靠的实现（比如封装官方 C 参考实现 libargon2 的 Swift Package）。参数要从 JSON 里读，不能写死。
- 字段加密：**AES-256-GCM**，无 AAD。存储格式 = `nonce(12字节) || 密文 || tag(16字节)`，正好是 CryptoKit `AES.GCM.SealedBox.combined` 的格式。明文为 UTF-8 字符串。
- 解锁：派生密钥后解密 `key_verifier`，结果等于 `email-vault-verifier-v1` 才算主密码正确；失败时延迟 1 秒再返回。
- `password_enc` 为 NULL 表示「未设置密码」（比如 Google 登录）。
- 编辑时密码框留空表示**不修改**原密码。

### 测试向量（必须写进单元测试并通过）

```
主密码:      test-master-123
kdf_params: {"salt": "00112233445566778899aabbccddeeff", "time_cost": 3, "memory_cost": 65536, "parallelism": 4}
派生密钥:    4cf81a5f663c93d65bbd014cd37f286547b700ee06382a23ffdd425d698f22b3
密文 blob:   0102030405060708090a0b0c84795e1334ccf22ad386a44db5211e03d3020877c74a13e8b2a06dc8ae824bcc
解密结果:    hello-密码-123
verifier:   0102030405060708090a0b0c8971531637cc61e4200d70e1ee755e59aaffb193fd025682de2292f0a15416805052e0352f149a
            （解密应得到 email-vault-verifier-v1）
```

## 功能清单（与现版本对齐）

1. **首次设置 / 解锁**：没有 `kdf_params` 时进入设置主密码页（至少 8 位、两次确认、提示忘记无法找回）；否则进入解锁页。
2. **安全**
   - 密钥只放在内存里。闲置 10 分钟自动锁定，菜单里提供「立即锁定」（⌘L）。锁定时清空密钥和界面上显示过的明文。
   - 密码默认显示为 `••••••••`，可以点「显示」或「复制」。
   - 复制到剪贴板时标记为 concealed（`org.nspasteboard.ConcealedType`），并在 30 秒后自动清除（前提是剪贴板内容还是我们复制的那条）。
   - 备注、地址、平台名是明文存储，界面提示「备注别写密码」。
3. **主界面布局**（参考现有网页版）
   - 左侧全高侧栏：搜索框、「新增邮箱」按钮、邮箱列表**按厂商分组**（Gmail / iCloud / Outlook / Proton / QQ / 网易 / 其他域名），每项显示头像、用户名、域名和服务数量；底部放「导出备份」「锁定」。
   - 右侧顶部一排统计卡片：邮箱数、关联服务数、未设密码数、各分类数量（带分类色点和文字）。
   - 邮箱详情头部：大头像、地址（可复制）、厂商标签、服务数量、邮箱密码（显示 / 复制）、备注、编辑 / 删除（删除需二次确认，提示会连带删除 N 个服务）。
   - 服务区：分类筛选（全部 / AI 工具 / 社交 / 加密货币 / 其他，只显示数量大于 0 的分类）、**卡片 / 列表视图切换**（记住选择）、「新增服务」按钮。
   - 服务卡片：平台图标、名称、分类标签、顶部分类色条、用户名（点击复制）、密码（显示 / 复制）、网址（用默认浏览器打开）、备注、编辑 / 删除。
   - 搜索：同时匹配邮箱地址、备注、平台名、用户名，结果里要显示所属邮箱。
4. **新增 / 编辑服务时自动补全平台**：输入关键字后弹出候选（比如输入 `b` 出现 Bybit、Bitget、Binance、B 站……），匹配规则照搬 `ui.py` 里的 `platform_catalog` 和 `app.js` 里的 `score`（名称前缀 > 别名前缀 > 包含；只输入一个字符时只匹配名称前缀；最多 8 条）。选中后自动填入名称、分类，网址为空时自动填入。候选里还要包含我自己录入过、但不在内置目录里的平台。
5. **图标**
   - 邮箱厂商识别、平台目录、别名和域名匹配全部照搬 `ui.py`（包括 Apple、Meta 各合并成一个条目，iCloud 邮箱用黑色苹果图标，OKX 等横向 logo 放大显示）。
   - 平台匹配：先按名称 / 别名精确匹配（小写、去空格），再按网址域名从最具体的子域开始逐级匹配。
   - 没有图标的显示彩色首字母头像（颜色由名称 crc32 % 8 决定）。
   - 品牌 SVG 来自 `_brand_icons.html`，转成 Asset Catalog 里的矢量图。
6. **导出备份**：用 `NSSavePanel` 选位置，写出整个 SQLite 的一致性快照（用 `sqlite3_backup` 或 `VACUUM INTO`），文件权限 600。
7. **深色模式**跟随系统；窗口最小尺寸约 760×560；支持 ⌘F 聚焦搜索、⌘N 新增服务、⌘⇧N 新增邮箱。

## 技术要求

- Swift 5.9+ / SwiftUI，目标 macOS 14+，Xcode 工程或 Swift Package（能用 `xcodebuild` 在命令行构建）。
- SQLite 用系统 `libsqlite3` 或 GRDB.swift 都可以。所有 SQL 一律用参数绑定，LIKE 搜索要转义 `%`、`_`、`\`。
- 不联网、不打日志输出明文密码、不把密码写进 UserDefaults 或任何缓存。
- 提供命令行构建脚本（bash，`set -euo pipefail`，支持 `--dry-run`），输出 `dist/Email Vault.app`，未签名也能在本机运行。
- 单元测试至少覆盖：上面的测试向量、主密码校验对错、加密往返、留空密码不覆盖、级联删除、LIKE 转义、平台图标匹配（参考 `tests/test_ui.py`）。

## 交付与工作方式

1. 先给我方案（工程结构、Argon2 用哪个库、App Sandbox 怎么处理），我确认后再写代码。
2. 新代码放在 `/Users/fantasy/Desktop/claude/email-swift/`，不要改动 Python 项目。
3. 验收步骤：
   ① 测试全部通过；
   ② 用测试向量和临时库跑通；
   ③ **复制一份** vault.db 到临时目录，用我的主密码解锁这份副本，核对邮箱数和服务数与 Python 版一致。到这一步我会自己操作，你给我操作步骤就行。
4. 代码、注释、commit message 用英文；和我沟通用中文。
