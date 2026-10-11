# email-vault

Local web UI for tracking which email registered which platform (AI tools, social, ...),
including encrypted email/platform passwords.

## Run

```bash
uv run email-vault
# open http://127.0.0.1:8000
```

First launch asks for a master password. **It cannot be recovered if lost.**

| Env var | Default | Meaning |
|---|---|---|
| `EMAIL_VAULT_DB` | `~/.local/share/email-vault/vault.db` | SQLite file |
| `EMAIL_VAULT_PORT` | `8000` | Port (always bound to 127.0.0.1) |
| `EMAIL_VAULT_IDLE_MINUTES` | `10` | Auto-lock after idle |

## Security model

- Key = Argon2id(master password, random salt); passwords encrypted with AES-256-GCM.
  Only password fields are encrypted — addresses, platforms and notes are plaintext
  so they stay searchable. Don't put secrets in notes.
- Key lives only in server memory per session; idle timeout or "锁定" drops it.
- Bound to loopback; Host allowlist, cross-site POST rejection, strict CSP, SameSite=Strict cookie.

## Backup / restore

"导出备份" downloads a snapshot of the SQLite file (passwords stay encrypted).
Restore: stop the app, replace the file at `EMAIL_VAULT_DB`, start again.
The same master password is required.

## Dev

```bash
uv run pytest
uv run ruff check src tests && uv run ruff format --check src tests
uv run mypy src
```

## Credits

Brand marks in `templates/_brand_icons.html` (CC0): Gmail and Microsoft from
[gilbarbara/logos](https://github.com/gilbarbara/logos); Proton Mail, iCloud and QQ from
[Simple Icons](https://simpleicons.org). Trademarks belong to their owners.
