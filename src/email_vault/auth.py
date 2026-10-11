"""Master password handling and in-memory unlocked sessions."""

from __future__ import annotations

import secrets
import threading
import time
from dataclasses import dataclass

from . import crypto
from .store import Store

_VERIFIER_PLAINTEXT = "email-vault-verifier-v1"
_META_KDF = "kdf_params"
_META_VERIFIER = "key_verifier"


class InvalidMasterPassword(Exception):
    pass


class AlreadyInitialized(Exception):
    pass


class Vault:
    """Derives and verifies the encryption key from the master password."""

    def __init__(self, store: Store) -> None:
        self._store = store
        self._init_lock = threading.Lock()

    def is_initialized(self) -> bool:
        return self._store.get_meta(_META_KDF) is not None

    def initialize(self, password: str) -> bytes:
        with self._init_lock:
            if self.is_initialized():
                raise AlreadyInitialized
            params = crypto.KdfParams.generate()
            key = crypto.derive_key(password, params)
            verifier = crypto.encrypt(key, _VERIFIER_PLAINTEXT)
            self._store.set_meta_many({_META_KDF: params.to_json(), _META_VERIFIER: verifier.hex()})
        return key

    def unlock(self, password: str) -> bytes:
        raw_params = self._store.get_meta(_META_KDF)
        raw_verifier = self._store.get_meta(_META_VERIFIER)
        if raw_params is None or raw_verifier is None:
            raise InvalidMasterPassword
        key = crypto.derive_key(password, crypto.KdfParams.from_json(raw_params))
        try:
            plaintext = crypto.decrypt(key, bytes.fromhex(raw_verifier))
        except crypto.DecryptionError as exc:
            raise InvalidMasterPassword from exc
        if plaintext != _VERIFIER_PLAINTEXT:
            raise InvalidMasterPassword
        return key


@dataclass
class _Session:
    key: bytes
    last_seen: float


class SessionManager:
    """Maps opaque cookie tokens to the derived key; expires on idle."""

    def __init__(self, idle_timeout: float) -> None:
        self.idle_timeout = idle_timeout
        self._sessions: dict[str, _Session] = {}
        self._lock = threading.Lock()

    def create(self, key: bytes) -> str:
        token = secrets.token_urlsafe(32)
        with self._lock:
            self._sessions[token] = _Session(key=key, last_seen=time.monotonic())
        return token

    def get_key(self, token: str | None) -> bytes | None:
        if not token:
            return None
        now = time.monotonic()
        with self._lock:
            self._purge(now)
            session = self._sessions.get(token)
            if session is None:
                return None
            session.last_seen = now
            return session.key

    def destroy(self, token: str | None) -> None:
        if token:
            with self._lock:
                self._sessions.pop(token, None)

    def _purge(self, now: float) -> None:
        expired = [t for t, s in self._sessions.items() if now - s.last_seen > self.idle_timeout]
        for t in expired:
            del self._sessions[t]
