from __future__ import annotations

import re
import sqlite3
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from email_vault import app as app_module
from email_vault.app import create_app
from email_vault.auth import SessionManager

MASTER = "correct horse battery"
BASE_URL = "http://127.0.0.1"


@pytest.fixture
def db_path(tmp_path: Path) -> Path:
    return tmp_path / "vault.db"


@pytest.fixture
def client(db_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    monkeypatch.setattr(app_module, "UNLOCK_FAILURE_DELAY", 0)
    with TestClient(create_app(db_path, idle_timeout=600), base_url=BASE_URL) as c:
        yield c


@pytest.fixture
def unlocked(client: TestClient) -> TestClient:
    r = client.post("/setup", data={"password": MASTER, "confirm": MASTER})
    assert r.status_code == 200 and "ev_session" in client.cookies
    return client


def add_email(c: TestClient, address: str, password: str = "") -> int:
    r = c.post("/emails", data={"address": address, "password": password}, follow_redirects=False)
    m = re.search(r"email_id=(\d+)", r.headers["location"])
    assert m, r.headers["location"]
    return int(m.group(1))


def add_account(c: TestClient, email_id: int, platform: str, **fields: str) -> None:
    data = {"email_id": str(email_id), "platform": platform, **fields}
    r = c.post("/accounts", data=data, follow_redirects=False)
    assert "err=" not in r.headers["location"]


def account_ids(db_path: Path) -> list[int]:
    with sqlite3.connect(db_path) as conn:
        return [row[0] for row in conn.execute("SELECT id FROM accounts ORDER BY id")]


def test_redirects_to_setup_when_uninitialized(client: TestClient) -> None:
    r = client.get("/", follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == "/setup"


def test_setup_rejects_short_or_mismatched(client: TestClient) -> None:
    r = client.post(
        "/setup", data={"password": "short", "confirm": "short"}, follow_redirects=False
    )
    assert "err=" in r.headers["location"]
    r = client.post(
        "/setup", data={"password": MASTER, "confirm": "x" * 10}, follow_redirects=False
    )
    assert "err=" in r.headers["location"]


def test_passwords_are_encrypted_at_rest(unlocked: TestClient, db_path: Path) -> None:
    eid = add_email(unlocked, "a@gmail.com", "mail-secret-123")
    add_account(unlocked, eid, "ChatGPT", category="ai", password="gpt-secret-456")
    raw = db_path.read_bytes()
    assert b"mail-secret-123" not in raw and b"gpt-secret-456" not in raw
    assert b"a@gmail.com" in raw  # metadata stays searchable


def test_reveal_passwords(unlocked: TestClient, db_path: Path) -> None:
    eid = add_email(unlocked, "a@gmail.com", "mail-secret-123")
    add_account(unlocked, eid, "Claude", password="claude-pw")
    add_account(unlocked, eid, "X")  # OAuth, no password
    claude_id, x_id = account_ids(db_path)
    assert unlocked.post(f"/api/emails/{eid}/password").json() == {"password": "mail-secret-123"}
    assert unlocked.post(f"/api/accounts/{claude_id}/password").json() == {"password": "claude-pw"}
    assert unlocked.post(f"/api/accounts/{x_id}/password").json() == {"password": None}


def test_email_page_lists_its_services(unlocked: TestClient) -> None:
    a = add_email(unlocked, "a@gmail.com")
    b = add_email(unlocked, "b@outlook.com")
    add_account(unlocked, a, "ChatGPT", category="ai")
    add_account(unlocked, a, "Instagram", category="social")
    add_account(unlocked, b, "Gemini", category="ai")
    page = unlocked.get(f"/?email_id={a}").text
    cards = page.split('id="platform-catalog"')[0]  # the autocomplete catalog lists every platform
    assert "ChatGPT" in cards and "Instagram" in cards and "Gemini" not in cards


def test_search_by_platform_finds_emails(unlocked: TestClient) -> None:
    a = add_email(unlocked, "a@gmail.com")
    b = add_email(unlocked, "b@outlook.com")
    add_email(unlocked, "c@proton.me")
    add_account(unlocked, a, "ChatGPT")
    add_account(unlocked, b, "ChatGPT")
    page = unlocked.get("/?q=chatgpt").text
    assert "a@gmail.com" in page and "b@outlook.com" in page and "c@proton.me" not in page
    assert "2 个服务" in page


def test_search_escapes_like_wildcards(unlocked: TestClient) -> None:
    add_email(unlocked, "a@gmail.com")
    assert "没有匹配的邮箱" in unlocked.get("/?q=%25").text


def test_blank_password_on_edit_keeps_existing(unlocked: TestClient, db_path: Path) -> None:
    eid = add_email(unlocked, "a@gmail.com", "keep-me")
    add_account(unlocked, eid, "Claude", password="old")
    (aid,) = account_ids(db_path)
    unlocked.post(f"/emails/{eid}", data={"address": "a@gmail.com", "note": "n", "password": ""})
    unlocked.post(f"/accounts/{aid}", data={"platform": "Claude", "password": ""})
    assert unlocked.post(f"/api/emails/{eid}/password").json()["password"] == "keep-me"
    assert unlocked.post(f"/api/accounts/{aid}/password").json()["password"] == "old"
    unlocked.post(f"/accounts/{aid}", data={"platform": "Claude", "password": "new"})
    assert unlocked.post(f"/api/accounts/{aid}/password").json()["password"] == "new"


def test_duplicate_email_rejected(unlocked: TestClient) -> None:
    add_email(unlocked, "a@gmail.com")
    r = unlocked.post("/emails", data={"address": "A@Gmail.com"}, follow_redirects=False)
    assert "err=" in r.headers["location"]


def test_delete_email_cascades(unlocked: TestClient, db_path: Path) -> None:
    eid = add_email(unlocked, "a@gmail.com")
    add_account(unlocked, eid, "ChatGPT")
    unlocked.post(f"/emails/{eid}/delete")
    assert account_ids(db_path) == []


def test_unsafe_url_scheme_dropped(unlocked: TestClient) -> None:
    eid = add_email(unlocked, "a@gmail.com")
    add_account(unlocked, eid, "Evil", url="javascript://alert(1)")
    add_account(unlocked, eid, "Good", url="chatgpt.com")
    page = unlocked.get(f"/?email_id={eid}").text
    assert "javascript:" not in page
    assert 'href="https://chatgpt.com"' in page


def test_lock_and_unlock(unlocked: TestClient) -> None:
    eid = add_email(unlocked, "a@gmail.com", "pw")
    unlocked.post("/lock")
    assert unlocked.post(f"/api/emails/{eid}/password").status_code == 401
    assert unlocked.get("/", follow_redirects=False).headers["location"] == "/unlock"

    r = unlocked.post("/unlock", data={"password": "wrong-password"}, follow_redirects=False)
    assert "err=" in r.headers["location"]
    unlocked.post("/unlock", data={"password": MASTER})
    assert unlocked.post(f"/api/emails/{eid}/password").json()["password"] == "pw"


def test_unlock_survives_restart(db_path: Path, unlocked: TestClient) -> None:
    eid = add_email(unlocked, "a@gmail.com", "pw")
    with TestClient(create_app(db_path, idle_timeout=600), base_url=BASE_URL) as fresh:
        assert fresh.get("/", follow_redirects=False).headers["location"] == "/unlock"
        fresh.post("/unlock", data={"password": MASTER})
        assert fresh.post(f"/api/emails/{eid}/password").json()["password"] == "pw"


def test_cross_site_post_blocked(unlocked: TestClient) -> None:
    r = unlocked.post(
        "/emails", data={"address": "x@evil.com"}, headers={"Origin": "https://evil.com"}
    )
    assert r.status_code == 403
    r = unlocked.post(
        "/emails", data={"address": "x@evil.com"}, headers={"Sec-Fetch-Site": "cross-site"}
    )
    assert r.status_code == 403


def test_untrusted_host_rejected(db_path: Path) -> None:
    with TestClient(create_app(db_path, idle_timeout=600), base_url="http://evil.com") as c:
        assert c.get("/setup").status_code == 400


def test_export_contains_no_plaintext(unlocked: TestClient) -> None:
    add_email(unlocked, "a@gmail.com", "mail-secret-123")
    r = unlocked.get("/export")
    assert r.status_code == 200 and r.content.startswith(b"SQLite format 3")
    assert b"mail-secret-123" not in r.content


def test_session_idle_expiry(monkeypatch: pytest.MonkeyPatch) -> None:
    now = [1000.0]
    monkeypatch.setattr("email_vault.auth.time.monotonic", lambda: now[0])
    sessions = SessionManager(idle_timeout=60)
    token = sessions.create(b"k" * 32)
    now[0] += 59
    assert sessions.get_key(token) == b"k" * 32  # also refreshes last_seen
    now[0] += 59
    assert sessions.get_key(token) is not None
    now[0] += 61
    assert sessions.get_key(token) is None


def test_same_origin_post_allowed(unlocked: TestClient) -> None:
    r = unlocked.post(
        "/emails",
        data={"address": "ok@gmail.com"},
        headers={"Origin": "http://127.0.0.1:8000", "Sec-Fetch-Site": "same-origin"},
        follow_redirects=False,
    )
    assert r.status_code == 303 and "err=" not in r.headers["location"]


def test_referrer_policy_keeps_origin_header(client: TestClient) -> None:
    # "no-referrer" makes browsers send `Origin: null`, which the origin guard rejects.
    assert client.get("/setup").headers["referrer-policy"] == "same-origin"


def test_catalog_includes_users_own_platforms(unlocked: TestClient) -> None:
    eid = add_email(unlocked, "a@gmail.com")
    add_account(unlocked, eid, "My Private Forum", category="other", url="forum.example.org")
    add_account(unlocked, eid, "chatgpt", category="ai")  # known platform: not duplicated
    page = unlocked.get(f"/?email_id={eid}").text
    catalog = page.split('id="platform-catalog">')[1].split("</script>")[0]
    assert '"name": "My Private Forum"' in catalog and '"mine": true' in catalog
    assert catalog.count('"name": "ChatGPT"') == 1 and '"name": "chatgpt"' not in catalog
    assert '"name": "Bybit"' in catalog


class FakeShell:
    def __init__(self) -> None:
        self.copied: list[str] = []
        self.saved: list[tuple[str, bytes]] = []

    def copy(self, text: str) -> bool:
        self.copied.append(text)
        return True

    def save_backup(self, filename: str, data: bytes) -> str | None:
        self.saved.append((filename, data))
        return f"/saved/{filename}"


def test_native_routes_absent_in_browser_mode(unlocked: TestClient) -> None:
    assert unlocked.post("/native/copy", data={"text": "x"}).status_code == 404
    assert "data-native" not in unlocked.get("/").text


def test_native_routes_in_app_mode(db_path: Path) -> None:
    shell = FakeShell()
    with TestClient(create_app(db_path, idle_timeout=600, native=shell), base_url=BASE_URL) as c:
        # locked: refused, nothing reaches the OS
        assert c.post("/native/copy", data={"text": "x"}, follow_redirects=False).status_code == 303
        assert c.post("/native/export", follow_redirects=False).status_code == 303
        c.post("/setup", data={"password": MASTER, "confirm": MASTER})
        assert "data-native" in c.get("/").text
        add_email(c, "a@gmail.com", "mail-secret-123")
        assert c.post("/native/copy", data={"text": "hello"}).json() == {"ok": True}
        r = c.post("/native/export").json()
        assert shell.copied == ["hello"]
        ((filename, data),) = shell.saved
        assert r == {"saved": f"/saved/{filename}"} and filename.endswith(".db")
        assert data.startswith(b"SQLite format 3") and b"mail-secret-123" not in data
        # cross-site requests are still blocked
        bad = c.post("/native/copy", data={"text": "x"}, headers={"Origin": "https://evil.com"})
        assert bad.status_code == 403 and shell.copied == ["hello"]
