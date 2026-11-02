# EmailVault（Swift Package）

Email Vault 的 macOS 应用源码。功能、安装和安全模型见仓库根目录 [README](../README.md)。

```bash
swift build                    # 编译
swift test                     # Core 单元测试，需要完整 Xcode（XCTest）
./scripts/build.sh             # 打包 dist/Email Vault.app（--debug / --dry-run）
./scripts/package-dmg.sh       # 打包 dist/EmailVault-<VERSION>.dmg（--skip-build / --dry-run）
```

| Target | 说明 |
|---|---|
| `EmailVaultCore` | 加密（Argon2id、AES-GCM、Touch ID 封装）、认证、SQLite 存储与迁移、平台目录 |
| `EmailVaultApp` | SwiftUI 界面与 `AppModel` |
| `CArgon2` | Argon2 官方 C 参考实现 |

调试时务必通过 `EMAIL_VAULT_DB` 指向临时数据库。设计细节见 [`docs/design.md`](docs/design.md)。
