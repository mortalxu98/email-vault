# email-vault

Local-only password vault: email ↔ platform accounts. Native macOS SwiftUI app in `email-swift/` (SwiftPM, no Xcode project).

- `email-swift/Sources/EmailVaultCore/` – crypto (Argon2id KDF, AES-GCM), vault auth, SQLite store, platform catalog
- `email-swift/Sources/EmailVaultApp/` – SwiftUI views and app model
- `email-swift/Sources/CArgon2/` – vendored reference Argon2
- `email-swift/scripts/build.sh` – builds `email-swift/dist/Email Vault.app`; uses `assets/EmailVault.icns`
- `docs/swift-rewrite-prompt.md` – DB schema and crypto test vectors; the on-disk format must stay compatible

Rules:
- Never log or persist plaintext passwords.
- Never touch the real DB (`~/.local/share/email-vault/vault.db`); use a temp `EMAIL_VAULT_DB` for manual tests.
- Before committing: `cd email-swift && swift build` (`swift test` needs full Xcode/XCTest, not available here).
