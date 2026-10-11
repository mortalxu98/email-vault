"""Local password vault that tracks which email registered which platform."""

from __future__ import annotations

import os
from pathlib import Path

import uvicorn

DEFAULT_DB_PATH = Path.home() / ".local" / "share" / "email-vault" / "vault.db"
HOST = "127.0.0.1"  # never expose beyond loopback


def main() -> None:
    from .app import create_app

    db_path = Path(os.environ.get("EMAIL_VAULT_DB", DEFAULT_DB_PATH)).expanduser()
    port = int(os.environ.get("EMAIL_VAULT_PORT", "8000"))
    idle_minutes = float(os.environ.get("EMAIL_VAULT_IDLE_MINUTES", "10"))

    app = create_app(db_path, idle_timeout=idle_minutes * 60)
    print(f"email-vault: db={db_path}  url=http://{HOST}:{port}")
    uvicorn.run(app, host=HOST, port=port, log_level="warning")
