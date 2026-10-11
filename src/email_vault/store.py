"""SQLite persistence. Password fields are stored as encrypted blobs only."""

from __future__ import annotations

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS emails (
    id           INTEGER PRIMARY KEY,
    address      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_enc BLOB,
    note         TEXT NOT NULL DEFAULT '',
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS accounts (
    id           INTEGER PRIMARY KEY,
    email_id     INTEGER NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
    platform     TEXT NOT NULL,
    category     TEXT NOT NULL DEFAULT 'other',
    username     TEXT NOT NULL DEFAULT '',
    password_enc BLOB,
    url          TEXT NOT NULL DEFAULT '',
    note         TEXT NOT NULL DEFAULT '',
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_accounts_email_id ON accounts(email_id);
"""

_EMAIL_COLUMNS = """
    e.id, e.address, e.note, e.password_enc IS NOT NULL AS has_password,
    (SELECT COUNT(*) FROM accounts a WHERE a.email_id = e.id) AS account_count
"""

_ACCOUNT_COLUMNS = """
    a.id, a.email_id, e.address AS email_address, a.platform, a.category,
    a.username, a.password_enc IS NOT NULL AS has_password, a.url, a.note
"""


class DuplicateEmailError(Exception):
    pass


class NotFoundError(Exception):
    pass


@dataclass(frozen=True)
class Email:
    id: int
    address: str
    note: str
    has_password: bool
    account_count: int


@dataclass(frozen=True)
class Account:
    id: int
    email_id: int
    email_address: str
    platform: str
    category: str
    username: str
    has_password: bool
    url: str
    note: str


def _like(query: str) -> str:
    escaped = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def _email(row: sqlite3.Row) -> Email:
    return Email(
        id=row["id"],
        address=row["address"],
        note=row["note"],
        has_password=bool(row["has_password"]),
        account_count=row["account_count"],
    )


def _account(row: sqlite3.Row) -> Account:
    return Account(
        id=row["id"],
        email_id=row["email_id"],
        email_address=row["email_address"],
        platform=row["platform"],
        category=row["category"],
        username=row["username"],
        has_password=bool(row["has_password"]),
        url=row["url"],
        note=row["note"],
    )


class Store:
    def __init__(self, path: Path) -> None:
        self.path = path
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.executescript(SCHEMA)
        path.chmod(0o600)

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        try:
            with conn:
                yield conn
        finally:
            conn.close()

    # --- meta -------------------------------------------------------------

    def get_meta(self, key: str) -> str | None:
        with self._connect() as conn:
            row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
        return None if row is None else row["value"]

    def set_meta_many(self, values: dict[str, str]) -> None:
        with self._connect() as conn:
            conn.executemany(
                "INSERT INTO meta (key, value) VALUES (?, ?) "
                "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                values.items(),
            )

    # --- emails -----------------------------------------------------------

    def list_emails(self, query: str = "") -> list[Email]:
        sql = f"SELECT {_EMAIL_COLUMNS} FROM emails e"
        params: dict[str, str] = {}
        if query:
            sql += """
                WHERE e.address LIKE :p ESCAPE '\\'
                   OR e.note LIKE :p ESCAPE '\\'
                   OR EXISTS (SELECT 1 FROM accounts a
                              WHERE a.email_id = e.id AND a.platform LIKE :p ESCAPE '\\')
            """
            params = {"p": _like(query)}
        sql += " ORDER BY e.address"
        with self._connect() as conn:
            rows = conn.execute(sql, params).fetchall()
        return [_email(r) for r in rows]

    def get_email(self, email_id: int) -> Email | None:
        with self._connect() as conn:
            row = conn.execute(
                f"SELECT {_EMAIL_COLUMNS} FROM emails e WHERE e.id = ?", (email_id,)
            ).fetchone()
        return None if row is None else _email(row)

    def create_email(self, address: str, note: str, password_enc: bytes | None) -> int:
        try:
            with self._connect() as conn:
                cur = conn.execute(
                    "INSERT INTO emails (address, note, password_enc) VALUES (?, ?, ?)",
                    (address, note, password_enc),
                )
        except sqlite3.IntegrityError as exc:
            raise DuplicateEmailError(address) from exc
        assert cur.lastrowid is not None
        return cur.lastrowid

    def update_email(
        self, email_id: int, address: str, note: str, password_enc: bytes | None
    ) -> None:
        """password_enc=None keeps the stored password."""
        try:
            with self._connect() as conn:
                cur = conn.execute(
                    """UPDATE emails
                       SET address = ?, note = ?,
                           password_enc = COALESCE(?, password_enc),
                           updated_at = datetime('now')
                       WHERE id = ?""",
                    (address, note, password_enc, email_id),
                )
        except sqlite3.IntegrityError as exc:
            raise DuplicateEmailError(address) from exc
        if cur.rowcount == 0:
            raise NotFoundError(email_id)

    def delete_email(self, email_id: int) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM emails WHERE id = ?", (email_id,))

    def get_email_password(self, email_id: int) -> bytes | None:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT password_enc FROM emails WHERE id = ?", (email_id,)
            ).fetchone()
        if row is None:
            raise NotFoundError(email_id)
        blob: bytes | None = row["password_enc"]
        return blob

    # --- accounts ---------------------------------------------------------

    def list_accounts(self, email_id: int) -> list[Account]:
        with self._connect() as conn:
            rows = conn.execute(
                f"""SELECT {_ACCOUNT_COLUMNS}
                    FROM accounts a JOIN emails e ON e.id = a.email_id
                    WHERE a.email_id = ?
                    ORDER BY a.category, a.platform COLLATE NOCASE""",
                (email_id,),
            ).fetchall()
        return [_account(r) for r in rows]

    def search_accounts(self, query: str) -> list[Account]:
        with self._connect() as conn:
            rows = conn.execute(
                f"""SELECT {_ACCOUNT_COLUMNS}
                    FROM accounts a JOIN emails e ON e.id = a.email_id
                    WHERE a.platform LIKE :p ESCAPE '\\'
                       OR a.username LIKE :p ESCAPE '\\'
                       OR a.note LIKE :p ESCAPE '\\'
                       OR e.address LIKE :p ESCAPE '\\'
                    ORDER BY a.platform COLLATE NOCASE, e.address""",
                {"p": _like(query)},
            ).fetchall()
        return [_account(r) for r in rows]

    def get_account(self, account_id: int) -> Account | None:
        with self._connect() as conn:
            row = conn.execute(
                f"""SELECT {_ACCOUNT_COLUMNS}
                    FROM accounts a JOIN emails e ON e.id = a.email_id
                    WHERE a.id = ?""",
                (account_id,),
            ).fetchone()
        return None if row is None else _account(row)

    def create_account(
        self,
        email_id: int,
        platform: str,
        category: str,
        username: str,
        url: str,
        note: str,
        password_enc: bytes | None,
    ) -> int:
        try:
            with self._connect() as conn:
                cur = conn.execute(
                    """INSERT INTO accounts
                       (email_id, platform, category, username, url, note, password_enc)
                       VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (email_id, platform, category, username, url, note, password_enc),
                )
        except sqlite3.IntegrityError as exc:
            raise NotFoundError(email_id) from exc
        assert cur.lastrowid is not None
        return cur.lastrowid

    def update_account(
        self,
        account_id: int,
        platform: str,
        category: str,
        username: str,
        url: str,
        note: str,
        password_enc: bytes | None,
    ) -> None:
        """password_enc=None keeps the stored password."""
        with self._connect() as conn:
            cur = conn.execute(
                """UPDATE accounts
                   SET platform = ?, category = ?, username = ?, url = ?, note = ?,
                       password_enc = COALESCE(?, password_enc),
                       updated_at = datetime('now')
                   WHERE id = ?""",
                (platform, category, username, url, note, password_enc, account_id),
            )
        if cur.rowcount == 0:
            raise NotFoundError(account_id)

    def delete_account(self, account_id: int) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM accounts WHERE id = ?", (account_id,))

    def get_account_password(self, account_id: int) -> bytes | None:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT password_enc FROM accounts WHERE id = ?", (account_id,)
            ).fetchone()
        if row is None:
            raise NotFoundError(account_id)
        blob: bytes | None = row["password_enc"]
        return blob

    # --- backup -----------------------------------------------------------

    def export_bytes(self) -> bytes:
        """Consistent snapshot of the whole database (passwords stay encrypted)."""
        with self._connect() as conn:
            return conn.serialize()
