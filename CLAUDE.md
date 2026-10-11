# email-vault

Local-only password vault: email ↔ platform accounts, FastAPI + Jinja2 + SQLite, no frontend build.

- `src/email_vault/crypto.py` – Argon2id KDF, AES-GCM field encryption
- `src/email_vault/auth.py` – master password verifier, in-memory sessions with idle expiry
- `src/email_vault/store.py` – SQLite access; password columns hold ciphertext only
- `src/email_vault/app.py` – routes, security middleware
- `templates/`, `static/` – server-rendered UI, vanilla JS (CSP forbids inline script/style)

Rules:
- Never log or persist plaintext passwords; decrypt only in `/api/*/password` responses.
- Keep binding to 127.0.0.1.
- Never touch the real DB (`~/.local/share/email-vault/vault.db`); use a temp `EMAIL_VAULT_DB` for manual tests.
- Before committing: `uv run pytest && uv run ruff check src tests && uv run mypy src`.
