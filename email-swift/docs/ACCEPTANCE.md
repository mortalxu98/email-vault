# Acceptance checklist (on your Mac)

Do **not** unlock or write the live vault until steps 1–2 pass. Always use a **copy** of `vault.db` for step 3.

## 1. Build & unit tests

```bash
cd /path/to/email-swift
swift test
# Expect: CryptoTests, StoreTests, PlatformTests all green
# (Argon2 test vectors, unlock, encrypt roundtrip, blank password,
#  cascade delete, LIKE escape, platform logo matching)
```

```bash
./scripts/build.sh
# Produces: dist/Email Vault.app
open "dist/Email Vault.app"
```

Optional dry-run (no compile):

```bash
./scripts/build.sh --dry-run
```

## 2. Temporary vault smoke test

```bash
export EMAIL_VAULT_DB="/tmp/email-vault-smoke.db"
rm -f "$EMAIL_VAULT_DB"
open "dist/Email Vault.app"
# Set master password (≥8 chars), add an email + service, lock, unlock again.
# Confirm passwords show/copy; blank edit keeps old password.
```

## 3. Real data — COPY only

```bash
# Copy — never point the app at the live file for first verification
mkdir -p /tmp/email-vault-accept
cp ~/.local/share/email-vault/vault.db /tmp/email-vault-accept/vault.db
chmod 600 /tmp/email-vault-accept/vault.db
export EMAIL_VAULT_DB="/tmp/email-vault-accept/vault.db"
open "dist/Email Vault.app"
```

1. Unlock with your **existing** master password.
2. Compare email count and service count with what you expect from the original DB.
3. Spot-check a few passwords (reveal/copy).
4. Confirm provider grouping and platform icons look right.

Only after that matches, you may launch without `EMAIL_VAULT_DB` so the app opens `~/.local/share/email-vault/vault.db` directly (no sandbox).

## 4. Regression reminders

- Wrong master password: ~1s delay, no unlock.
- Idle ~10 minutes → auto lock (⌘L forces lock).
- Export Backup → SQLite file, passwords still encrypted, mode 600.
- Edit service / email with empty password field → does not overwrite.
- Delete email → accounts cascade away.
