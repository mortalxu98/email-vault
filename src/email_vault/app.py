"""FastAPI web UI."""

from __future__ import annotations

import time
from datetime import datetime
from pathlib import Path
from typing import Annotated
from urllib.parse import urlencode, urlsplit

from fastapi import FastAPI, Form, Request
from fastapi.responses import JSONResponse, PlainTextResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.trustedhost import TrustedHostMiddleware

from . import crypto, ui
from .auth import AlreadyInitialized, InvalidMasterPassword, SessionManager, Vault
from .store import DuplicateEmailError, NotFoundError, Store

PACKAGE_DIR = Path(__file__).parent
SESSION_COOKIE = "ev_session"
MIN_MASTER_PASSWORD_LEN = 8
UNLOCK_FAILURE_DELAY = 1.0
CATEGORIES: dict[str, str] = {"ai": "AI 工具", "social": "社交", "other": "其他"}

FormStr = Annotated[str, Form()]


class NotUnlocked(Exception):
    pass


def _redirect(path: str, **params: str | int | None) -> RedirectResponse:
    query = urlencode({k: v for k, v in params.items() if v not in (None, "")})
    return RedirectResponse(f"{path}?{query}" if query else path, status_code=303)


def _category(value: str) -> str:
    return value if value in CATEGORIES else "other"


def _normalize_url(value: str) -> str:
    """Default to https:// and drop non-web schemes (e.g. javascript:)."""
    value = value.strip()
    if not value:
        return ""
    if "://" not in value:
        value = f"https://{value}"
    return value if urlsplit(value).scheme in ("http", "https") else ""


def create_app(
    db_path: Path,
    idle_timeout: float,
    allowed_hosts: tuple[str, ...] = ("127.0.0.1", "localhost"),
) -> FastAPI:
    store = Store(db_path)
    vault = Vault(store)
    sessions = SessionManager(idle_timeout)
    templates = Jinja2Templates(directory=PACKAGE_DIR / "templates")
    templates.env.globals["categories"] = CATEGORIES
    templates.env.globals["idle_timeout_ms"] = int(idle_timeout * 1000)
    templates.env.filters["provider"] = ui.provider
    templates.env.filters["color_index"] = ui.color_index
    templates.env.filters["split_address"] = ui.split_address

    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=list(allowed_hosts))
    app.mount("/static", StaticFiles(directory=PACKAGE_DIR / "static"), name="static")

    @app.middleware("http")
    async def security_guard(request: Request, call_next):  # type: ignore[no-untyped-def]
        # Block cross-site writes (CSRF from other sites hitting localhost).
        if request.method not in ("GET", "HEAD"):
            if request.headers.get("sec-fetch-site") == "cross-site":
                return PlainTextResponse("cross-site request blocked", status_code=403)
            origin = request.headers.get("origin")
            if origin is not None and urlsplit(origin).hostname not in allowed_hosts:
                return PlainTextResponse("origin not allowed", status_code=403)
        response: Response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-Content-Type-Options"] = "nosniff"
        # Not "no-referrer": that makes browsers send `Origin: null` on same-site form POSTs.
        response.headers["Referrer-Policy"] = "same-origin"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; frame-ancestors 'none'; form-action 'self'"
        )
        return response

    @app.exception_handler(NotUnlocked)
    async def not_unlocked(request: Request, _exc: NotUnlocked) -> Response:
        if request.url.path.startswith("/api/"):
            return JSONResponse({"error": "locked"}, status_code=401)
        return _redirect("/unlock" if vault.is_initialized() else "/setup")

    def require_key(request: Request) -> bytes:
        key = sessions.get_key(request.cookies.get(SESSION_COOKIE))
        if key is None:
            raise NotUnlocked
        return key

    def start_session(key: bytes) -> RedirectResponse:
        response = _redirect("/")
        response.set_cookie(
            SESSION_COOKIE,
            sessions.create(key),
            httponly=True,
            samesite="strict",
            path="/",
        )
        return response

    def encrypt_optional(key: bytes, password: str) -> bytes | None:
        return crypto.encrypt(key, password) if password else None

    # --- setup / unlock ---------------------------------------------------

    @app.get("/setup")
    def setup_page(request: Request, err: str = "") -> Response:
        if vault.is_initialized():
            return _redirect("/unlock")
        return templates.TemplateResponse(
            request, "setup.html", {"err": err, "min_len": MIN_MASTER_PASSWORD_LEN}
        )

    @app.post("/setup")
    def setup(password: FormStr, confirm: FormStr) -> Response:
        if len(password) < MIN_MASTER_PASSWORD_LEN:
            return _redirect("/setup", err=f"主密码至少 {MIN_MASTER_PASSWORD_LEN} 位")
        if password != confirm:
            return _redirect("/setup", err="两次输入不一致")
        try:
            key = vault.initialize(password)
        except AlreadyInitialized:
            return _redirect("/unlock")
        return start_session(key)

    @app.get("/unlock")
    def unlock_page(request: Request, err: str = "") -> Response:
        if not vault.is_initialized():
            return _redirect("/setup")
        return templates.TemplateResponse(request, "unlock.html", {"err": err})

    @app.post("/unlock")
    def unlock(password: FormStr) -> Response:
        try:
            key = vault.unlock(password)
        except InvalidMasterPassword:
            time.sleep(UNLOCK_FAILURE_DELAY)
            return _redirect("/unlock", err="主密码错误")
        return start_session(key)

    @app.post("/lock")
    def lock(request: Request) -> Response:
        sessions.destroy(request.cookies.get(SESSION_COOKIE))
        response = _redirect("/unlock")
        response.delete_cookie(SESSION_COOKIE, path="/")
        return response

    # --- main page --------------------------------------------------------

    @app.get("/")
    def index(
        request: Request,
        email_id: int | None = None,
        q: str = "",
        err: str = "",
        msg: str = "",
    ) -> Response:
        require_key(request)
        q = q.strip()
        emails = store.list_emails(q)
        selected = store.get_email(email_id) if email_id is not None else None
        if selected is None and not q and emails:
            selected = emails[0]
        accounts = store.list_accounts(selected.id) if selected else []
        results = store.search_accounts(q) if q and selected is None else []
        return templates.TemplateResponse(
            request,
            "index.html",
            {
                "emails": emails,
                "selected": selected,
                "accounts": accounts,
                "results": results,
                "q": q,
                "err": err,
                "msg": msg,
            },
        )

    # --- emails -----------------------------------------------------------

    @app.post("/emails")
    def create_email(
        request: Request,
        address: FormStr,
        password: FormStr = "",
        note: FormStr = "",
    ) -> Response:
        key = require_key(request)
        address = address.strip()
        if "@" not in address:
            return _redirect("/", err="邮箱地址格式不对")
        try:
            email_id = store.create_email(address, note.strip(), encrypt_optional(key, password))
        except DuplicateEmailError:
            return _redirect("/", err=f"{address} 已存在")
        return _redirect("/", email_id=email_id, msg="已添加邮箱")

    @app.post("/emails/{email_id}")
    def update_email(
        request: Request,
        email_id: int,
        address: FormStr,
        password: FormStr = "",
        note: FormStr = "",
    ) -> Response:
        key = require_key(request)
        address = address.strip()
        if "@" not in address:
            return _redirect("/", email_id=email_id, err="邮箱地址格式不对")
        try:
            store.update_email(email_id, address, note.strip(), encrypt_optional(key, password))
        except DuplicateEmailError:
            return _redirect("/", email_id=email_id, err=f"{address} 已存在")
        except NotFoundError:
            return _redirect("/", err="邮箱不存在")
        return _redirect("/", email_id=email_id, msg="已保存")

    @app.post("/emails/{email_id}/delete")
    def delete_email(request: Request, email_id: int) -> Response:
        require_key(request)
        store.delete_email(email_id)
        return _redirect("/", msg="已删除邮箱及其关联服务")

    @app.post("/api/emails/{email_id}/password")
    def email_password(request: Request, email_id: int) -> Response:
        key = require_key(request)
        try:
            blob = store.get_email_password(email_id)
        except NotFoundError:
            return JSONResponse({"error": "not found"}, status_code=404)
        return JSONResponse({"password": crypto.decrypt(key, blob) if blob else None})

    # --- accounts ---------------------------------------------------------

    @app.post("/accounts")
    def create_account(
        request: Request,
        email_id: Annotated[int, Form()],
        platform: FormStr,
        category: FormStr = "other",
        username: FormStr = "",
        password: FormStr = "",
        url: FormStr = "",
        note: FormStr = "",
    ) -> Response:
        key = require_key(request)
        platform = platform.strip()
        if not platform:
            return _redirect("/", email_id=email_id, err="平台名称不能为空")
        try:
            store.create_account(
                email_id,
                platform,
                _category(category),
                username.strip(),
                _normalize_url(url),
                note.strip(),
                encrypt_optional(key, password),
            )
        except NotFoundError:
            return _redirect("/", err="邮箱不存在")
        return _redirect("/", email_id=email_id, msg=f"已添加 {platform}")

    @app.post("/accounts/{account_id}")
    def update_account(
        request: Request,
        account_id: int,
        platform: FormStr,
        category: FormStr = "other",
        username: FormStr = "",
        password: FormStr = "",
        url: FormStr = "",
        note: FormStr = "",
    ) -> Response:
        key = require_key(request)
        account = store.get_account(account_id)
        if account is None:
            return _redirect("/", err="服务记录不存在")
        platform = platform.strip()
        if not platform:
            return _redirect("/", email_id=account.email_id, err="平台名称不能为空")
        store.update_account(
            account_id,
            platform,
            _category(category),
            username.strip(),
            _normalize_url(url),
            note.strip(),
            encrypt_optional(key, password),
        )
        return _redirect("/", email_id=account.email_id, msg="已保存")

    @app.post("/accounts/{account_id}/delete")
    def delete_account(request: Request, account_id: int) -> Response:
        require_key(request)
        account = store.get_account(account_id)
        if account is None:
            return _redirect("/")
        store.delete_account(account_id)
        return _redirect("/", email_id=account.email_id, msg=f"已删除 {account.platform}")

    @app.post("/api/accounts/{account_id}/password")
    def account_password(request: Request, account_id: int) -> Response:
        key = require_key(request)
        try:
            blob = store.get_account_password(account_id)
        except NotFoundError:
            return JSONResponse({"error": "not found"}, status_code=404)
        return JSONResponse({"password": crypto.decrypt(key, blob) if blob else None})

    # --- backup -----------------------------------------------------------

    @app.get("/export")
    def export(request: Request) -> Response:
        require_key(request)
        filename = f"email-vault-{datetime.now():%Y%m%d-%H%M%S}.db"
        return Response(
            store.export_bytes(),
            media_type="application/octet-stream",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )

    return app
