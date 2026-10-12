# email-vault

Local-only password vault for tracking which email registered which platform,
with encrypted email/platform passwords. Native macOS SwiftUI app in `email-swift/`.

The original Python web version was removed; the Swift app reads the same database format
(schema and test vectors: `docs/swift-rewrite-prompt.md`).

## Build

```bash
cd email-swift
./scripts/build.sh            # -> email-swift/dist/Email Vault.app
./scripts/build.sh --dry-run
```

Install: copy `dist/Email Vault.app` to `/Applications`. The build is unsigned.

| Env var | Default | Meaning |
|---|---|---|
| `EMAIL_VAULT_DB` | `~/.local/share/email-vault/vault.db` | SQLite file |

First launch asks for a master password. **It cannot be recovered if lost.**

## Security model

- Key = Argon2id(master password, random salt); passwords encrypted with AES-256-GCM.
  Only password fields are encrypted — addresses, platforms and notes are plaintext.
  Don't put secrets in notes.
- Key lives only in memory; idle timeout or lock drops it.

## Backup / restore

Passwords stay encrypted in the SQLite file. Back up with
`sqlite3 ~/.local/share/email-vault/vault.db ".backup <dest>"`.
Restore: quit the app, replace the file, relaunch. The same master password is required.

## Credits

Brand marks come from two CC0 sets: [gilbarbara/logos](https://github.com/gilbarbara/logos)
and [Simple Icons](https://simpleicons.org). Trademarks belong to their owners.
See `email-swift/Sources/EmailVaultApp/Resources/README.md`.
