"""Native macOS window (WebKit via pywebview) around the same FastAPI app.

The server binds to a random loopback port for the lifetime of the window;
closing the window stops it. Data lives in the same vault.db as `email-vault`.
"""

from __future__ import annotations

import logging
import os
import socket
import threading
import time
from pathlib import Path

import uvicorn
import webview
from AppKit import NSPasteboard, NSPasteboardTypeString

from . import DEFAULT_DB_PATH, HOST
from .app import create_app

APP_NAME = "Email Vault"
SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "EmailVault"
LOG_FILE = Path.home() / "Library" / "Logs" / "EmailVault" / "app.log"
SERVER_START_TIMEOUT = 10.0

log = logging.getLogger("email_vault.desktop")


class MacShell:
    """NativeHooks for the app: clipboard and "Save as" via AppKit / pywebview.

    Called from the server's request threads; pywebview marshals dialogs onto
    the main thread itself.
    """

    def __init__(self) -> None:
        self.window: webview.Window | None = None

    def copy(self, text: str) -> bool:
        board = NSPasteboard.generalPasteboard()
        board.clearContents()
        return bool(board.setString_forType_(text, NSPasteboardTypeString))

    def save_backup(self, filename: str, data: bytes) -> str | None:
        if self.window is None:
            return None
        chosen = self.window.create_file_dialog(
            webview.FileDialog.SAVE,
            directory=str(Path.home() / "Downloads"),
            save_filename=filename,
        )
        if not chosen:
            return None
        target = Path(chosen if isinstance(chosen, str) else chosen[0])
        target.write_bytes(data)
        target.chmod(0o600)
        log.info("backup saved to %s", target)
        return str(target)


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, 0))
        port: int = s.getsockname()[1]
        return port


def _setup_logging() -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=LOG_FILE,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def _start_server(
    db_path: Path, idle_timeout: float, shell: MacShell
) -> tuple[uvicorn.Server, int]:
    port = _free_port()
    config = uvicorn.Config(
        create_app(db_path, idle_timeout=idle_timeout, native=shell),
        host=HOST,
        port=port,
        # Explicit choices keep PyInstaller from needing uvicorn's dynamic imports.
        loop="asyncio",
        http="h11",
        ws="none",
        lifespan="off",
        log_level="warning",
        log_config=None,
    )
    server = uvicorn.Server(config)
    threading.Thread(target=server.run, name="uvicorn", daemon=True).start()
    deadline = time.monotonic() + SERVER_START_TIMEOUT
    while not server.started:
        if time.monotonic() > deadline:
            raise RuntimeError("embedded server did not start")
        time.sleep(0.05)
    return server, port


def main() -> None:
    _setup_logging()
    db_path = Path(os.environ.get("EMAIL_VAULT_DB", DEFAULT_DB_PATH)).expanduser()
    idle_minutes = float(os.environ.get("EMAIL_VAULT_IDLE_MINUTES", "10"))
    log.info("starting, db=%s", db_path)

    shell = MacShell()
    server, port = _start_server(db_path, idle_timeout=idle_minutes * 60, shell=shell)
    log.info("serving on http://%s:%d", HOST, port)
    window = webview.create_window(
        APP_NAME,
        f"http://{HOST}:{port}/",
        width=1320,
        height=860,
        min_size=(760, 560),
        text_select=True,
        background_color="#f6f7f9",
    )
    if window is None:
        raise RuntimeError("could not create window")
    shell.window = window
    window.events.closed += lambda: setattr(server, "should_exit", True)

    SUPPORT_DIR.mkdir(parents=True, exist_ok=True)
    # Persistent storage only keeps UI prefs (e.g. card/list view); secrets never reach it.
    webview.start(private_mode=False, storage_path=str(SUPPORT_DIR / "webview"))
    server.should_exit = True
    log.info("stopped")


if __name__ == "__main__":
    main()
