# Email Vault（Swift 版）

Email Vault 的 macOS 原生 SwiftUI 重写版，兼容原 Python 版的数据库。

详见 `docs/design.md` 和 `docs/ACCEPTANCE.md`。

```bash
swift test          # 需要完整 Xcode（XCTest）
./scripts/build.sh
```

环境变量：

- `EMAIL_VAULT_DB` — 覆盖数据库路径（跑测试或验收用副本时必须设置）。
