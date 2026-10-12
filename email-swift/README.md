# Email Vault (Swift)

Native macOS SwiftUI rewrite of Email Vault. Compatible with the existing Python vault database.

See `docs/design.md` and `docs/ACCEPTANCE.md`.

```bash
swift test
./scripts/build.sh
```

Environment:

- `EMAIL_VAULT_DB` — override database path (required for tests / acceptance copies).
