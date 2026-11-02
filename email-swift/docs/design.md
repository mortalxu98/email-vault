# Email Vault（Swift 版）— 设计说明

## 目标

macOS 14+ 原生 SwiftUI 应用。项目最初由 Python 网页版重写而来，磁盘格式保持兼容并只做加列扩展，规范见 [`docs/data-format.md`](../../docs/data-format.md)。

## 已确认的决策

1. **不启用 App Sandbox** — 默认数据库路径 `~/.local/share/email-vault/vault.db`（可用 `EMAIL_VAULT_DB` 覆盖）。
2. **Argon2id** 使用内置的官方 C 参考实现（`Sources/CArgon2`，PHC 冠军算法），封装成 SPM 的 C target。
3. **SQLite** 通过 GRDB.swift 访问；每个连接都执行 `PRAGMA foreign_keys = ON`。

## 目录结构

```
email-swift/
  Package.swift
  Sources/
    CArgon2/           # libargon2 参考实现（ARGON2_NO_THREADS）
    EmailVaultCore/    # 加密、认证、存储、平台目录（可在 Linux 上测试）
    EmailVaultApp/     # SwiftUI macOS 应用（#if os(macOS)）
  Tests/EmailVaultCoreTests/
  scripts/build.sh
  docs/
  BrandIcons/          # 品牌 SVG 图标源（_brand_icons.html）
```

## 加密

| 组件 | 实现 |
|-------|----------------|
| 密钥派生 | `argon2id_hash_raw` v0x13，参数取自 JSON |
| AEAD | `AES.GCM`，用 [swift-crypto](https://github.com/apple/swift-crypto)（`Crypto` 模块）— `SealedBox.combined` 格式与 CryptoKit 相同：nonce(12)\|\|密文\|\|tag(16) |
| 校验值 | 加密 `"email-vault-verifier-v1"`，hex 存到 `meta.key_verifier` |

在 Apple 平台上 swift-crypto 底层就是 CryptoKit；在 Linux 上提供可移植实现，因此 Core 的单元测试不需要 Xcode。

## 存储

表结构在 Python 版基础上只做**加列**：`accounts` 新增 `renew_at`（`yyyy-MM-dd`，NULL 表示无提醒）、`renew_cycle`（`once`/`monthly`/`yearly`）、`renew_amount`、`renew_lead_days`（默认 7），`emails`/`accounts` 新增 `secret_enc`（安全备注，AES-GCM 加密，格式同密码）。`Store` 打开时检查缺失列并 `ALTER TABLE ADD COLUMN`；库里已有数据时，先用 SQLite 备份 API 备份到 `<库目录>/backups/vault-pre-migration-<日期>-<时间戳>.db`（0600）。旧版程序仍能打开迁移后的库。

修改主密码：校验当前密码 → 新 salt 派生新密钥 → 备份 → 单事务内重加密 `Store.encryptedColumns` 中的所有密文并写入新 `kdf_params`/`key_verifier`，任一条解密失败整体回滚。

Touch ID 解锁（可选，工具栏「…」里开关）：用 CryptoKit 在 Secure Enclave 生成 P-256 密钥（`.privateKeyUsage` + `.biometryCurrentSet`），ECDH + HKDF-SHA256 + AES-GCM 封装保险箱密钥，存到库旁的 `<库名>.touchid.json`（0600，不进 `vault.db`/备份）。不走钥匙串，因为未签名 App 用带生物识别 ACL 的 data-protection keychain 会报 `-34018`。解锁时先 `evaluatePolicy` 再用已认证的 `LAContext` 做 ECDH，解出的密钥用 `key_verifier` 校验。每 14 天必须输一次主密码；改主密码后用 SE 公钥重新封装（无需验证）；指纹变动导致 SE 密钥失效时自动关闭。

系统事件锁定：睡眠、屏幕休眠、锁屏、屏保启动、切换用户时立即锁定。

续费提醒：到期日减去今天 ≤ 提前天数（含已过期）时，详情区顶部显示提醒横幅；「已续费」按周期顺延（月末自动对齐，如 1/31 → 2/28），一次性的直接移除提醒。

编辑时密码留空 → SQL `COALESCE(?, password_enc)`（Swift 传 `nil`），不覆盖旧密码。LIKE 查询会转义 `\`、`%`、`_`。删除靠外键级联。

## 界面（SwiftUI）

- 侧边栏：搜索、新建邮箱、按邮箱服务商分组的列表。
- 工具栏：总览、更多（导出备份 / 修改主密码）、锁定。
- 总览（未选中邮箱时）：全库统计、所有续费项、最近修改。
- 编辑窗口：原生分组表单（`Form` + `.formStyle(.grouped)`）。
- 详情页：邮箱信息头、分类标签、账号网格/列表视图、平台名自动补全（打分规则沿用 `app.js`）。
- 安全：闲置 10 分钟自动锁定，⌘L 立即锁定，剪贴板内容标记为隐藏并在 30 秒后清空。
- 品牌图标：从 `Bundle.module` 加载 `brand-<id>.pdf`（位于 `Sources/EmailVaultApp/Resources/BrandIcons`，由 `_brand_icons.html` 提取）；没有图标时显示首字母头像（颜色取 `crc32 % 8`）。宽图标：okx/meta。Apple 图标在 iCloud 上用黑色模板图。
- 闲置锁定：10 分钟；通过本地 NSEvent 监听鼠标/键盘调用 `touch()`，配合 Timer 计时。
- 复制提示：「已复制到剪贴板」。
- 列表视图：紧凑的表格行（平台 / 用户名 / 密码 / 网址），不是堆叠卡片。
- 界面文字：中文分类（AI 工具/社交/加密货币/其他）和常用按钮。
- 解锁/初始化：Argon2 通过 `Task.detached` 在主 actor 之外运行。

## Linux 与 Mac 对比

| | Linux（最初开发机） | Mac |
|--|------------------|-----|
| `swift test`（Core） | 可以（Argon2 + swift-crypto 的 AES + GRDB） | 可以 |
| SwiftUI 应用 | `@main` 是占位，只打印错误 | 完整界面 |
| `scripts/build.sh` | 只有 `--dry-run` 有意义 | 生成 `dist/Email Vault.app` |

## 安全

- 测试中绝不碰真实的 `~/.local/share/email-vault/vault.db`，一律设置 `EMAIL_VAULT_DB`。
- 验收：用户把 vault.db 复制到临时路径，解锁这份副本。

## Linux 测试环境说明

- **swift-crypto** 在 Linux 上提供 `Crypto` 模块（AES-GCM）；在 Apple 平台底层用 CryptoKit，`SealedBox.combined` 布局相同。
- **GRDB** 链接系统的 `libsqlite3`。Debian 的版本没开 `SQLITE_ENABLE_SNAPSHOT`，所以仅在 Linux 上编译 `Sources/SQLiteSnapshotStubs`（不会被调用的桩函数）让链接通过。macOS 不包含这个 target。
- SwiftUI 应用代码都包在 `#if os(macOS)` 里；Linux 上 `@main` 是命令行占位程序，打印提示后退出。
- 品牌 SVG 图标放在 `BrandIcons/_brand_icons.html`（来自 Python 版）。PDF 由 `scripts/extract_brand_icons.py` 生成到 `Sources/EmailVaultApp/Resources/BrandIcons/`，通过 `BrandIcon.image(named:)` 从 `Bundle.module` 加载。

## 维护

- 品牌 PDF 已打包；修改 `BrandIcons/_brand_icons.html` 后运行 `python3 scripts/extract_brand_icons.py`。
- 应用图标源为 `assets/icon.svg`，修改后运行 `scripts/make-icon.sh` 重新生成 icns。
- 打包与发布见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。
