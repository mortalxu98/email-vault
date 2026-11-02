# Email Vault

一个纯本地、离线运行的 macOS 密码库，按「邮箱 → 注册过的平台」组织账号，跟踪订阅续费。

<p align="center">
  <img src="docs/screenshots/overview.png" width="49%" alt="总览">
  <img src="docs/screenshots/detail.png" width="49%" alt="邮箱详情">
</p>

<sub>截图使用演示数据。</sub>

## 特性

**账号管理**
- 邮箱按服务商（Gmail、Outlook、Proton、iCloud、QQ……）分组；每个邮箱下记录它注册过的平台。
- 内置 70+ 个常用平台目录（AI、社交、加密货币等），输入时自动补全名称、分类和网址，并匹配品牌图标。
- 卡片 / 列表两种视图，按分类筛选；全局搜索邮箱、平台、用户名和备注。

**安全**
- Argon2id 派生主密钥，AES-256-GCM 加密密码和安全备注；密钥只在内存中。
- 可选 Touch ID 解锁（Secure Enclave，每 14 天仍需输入一次主密码）。
- 闲置 10 分钟、睡眠、锁屏、屏保、切换用户时自动锁定。
- 复制的密码标记为 concealed，30 秒后或锁定时自动清空剪贴板。
- 支持修改主密码：单事务重新加密全部数据，失败整体回滚。

**续费提醒**
- 为服务设置到期日、周期（一次性 / 每月 / 每年）、金额和提前提醒天数。
- 即将到期或已过期的项目在顶部横幅提示；「已续费」自动顺延一个周期。

**数据**
- 单个 SQLite 文件，结构变更只做加列，迁移前自动备份。
- 一键导出一致性快照，备份中的敏感字段始终是密文。

## 安装

要求：macOS 14+，Swift 5.9+ 工具链（Command Line Tools 即可，无需完整 Xcode）。

```bash
git clone https://github.com/mortalxu98/email-vault.git
cd email-vault/email-swift
./scripts/build.sh                 # 输出 dist/Email Vault.app
cp -R "dist/Email Vault.app" /Applications/
```

构建产物未签名。首次打开如被 Gatekeeper 拦截，在 Finder 中右键 → 打开。

首次启动设置主密码（至少 8 个字符）。**主密码无法找回**，遗忘即无法解密数据。

## 使用

| 操作 | 方式 |
|---|---|
| 新增邮箱 | ⇧⌘N |
| 新增服务 | ⌘N（需先选中邮箱） |
| 搜索 | ⌘F |
| 立即锁定 | ⌘L，或工具栏锁形按钮 |
| 回到总览 | 工具栏房子按钮 |
| 导出备份 / 修改主密码 / Touch ID | 工具栏「…」菜单 |

## 安全模型

| 数据 | 存储方式 |
|---|---|
| 邮箱密码、服务密码 | AES-256-GCM 密文 |
| 安全备注（助记词、恢复码、2FA 密钥等） | AES-256-GCM 密文 |
| 邮箱地址、平台名、用户名、网址、普通备注、续费信息 | 明文（用于搜索和提醒） |

- **密钥派生**：Argon2id v1.3，`t=3, m=64 MiB, p=4`，16 字节随机 salt；参数存于数据库，可平滑调整。
- **主密码校验**：用派生密钥解密固定校验串，不存储任何密码哈希。
- **Touch ID**：保险箱密钥经 ECDH + HKDF + AES-GCM 封装到绑定当前指纹的 Secure Enclave 密钥，封装文件只能在本机解开；增删指纹后自动失效。
- **不防护的场景**：已解锁状态下的本机恶意软件、能通过你指纹验证的人、主密码泄露。明文字段不要写敏感信息。

应用不联网，不记录日志，不把明文写入磁盘、UserDefaults 或任何缓存。

## 数据与备份

| 路径 | 内容 |
|---|---|
| `~/.local/share/email-vault/vault.db` | 数据库（权限 0600） |
| `~/.local/share/email-vault/backups/` | 迁移、修改主密码前的自动备份 |
| `~/.local/share/email-vault/vault.touchid.json` | Touch ID 封装（仅开启时存在） |

设置环境变量 `EMAIL_VAULT_DB` 可指定其他数据库路径，例如用副本做测试：

```bash
open -n --env EMAIL_VAULT_DB=/tmp/vault-copy.db "/Applications/Email Vault.app"
```

**备份**：工具栏「…」→ 导出备份，或 `sqlite3 ~/.local/share/email-vault/vault.db ".backup <目标路径>"`。

**恢复**：退出应用，用备份文件替换 `vault.db` 后重新打开，使用备份时的主密码解锁。若主密码与当前不同，Touch ID 会自动关闭，重新开启即可。

## 开发

```
email-swift/
├── Sources/EmailVaultCore/   加密、认证、SQLite 存储、平台目录（平台无关，可在 Linux 测试）
├── Sources/EmailVaultApp/    SwiftUI 界面与应用状态
├── Sources/CArgon2/          Argon2 官方 C 参考实现（vendored）
├── Tests/                    Core 单元测试
└── scripts/build.sh          构建 .app，支持 --dry-run / --debug
```

```bash
cd email-swift
swift build
swift test            # 需要完整 Xcode（XCTest）
```

- 设计说明：[`email-swift/docs/design.md`](email-swift/docs/design.md)
- 数据格式与加密测试向量：[`docs/swift-rewrite-prompt.md`](docs/swift-rewrite-prompt.md)
- 验收清单：[`email-swift/docs/ACCEPTANCE.md`](email-swift/docs/ACCEPTANCE.md)

开发调试一律使用临时数据库（`EMAIL_VAULT_DB`），不要直接操作真实数据。

## 致谢

- [Argon2](https://github.com/P-H-C/phc-winner-argon2) 参考实现
- [GRDB.swift](https://github.com/groue/GRDB.swift)、[swift-crypto](https://github.com/apple/swift-crypto)
- 品牌图标来自 CC0 图标集 [gilbarbara/logos](https://github.com/gilbarbara/logos) 与 [Simple Icons](https://simpleicons.org)，商标归各自所有者，详见 [`Resources/README.md`](email-swift/Sources/EmailVaultApp/Resources/README.md)。
