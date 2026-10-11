"""Key derivation (Argon2id) and field encryption (AES-256-GCM)."""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass

from argon2.low_level import Type, hash_secret_raw
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

KEY_LEN = 32
SALT_LEN = 16
NONCE_LEN = 12


class DecryptionError(Exception):
    """Ciphertext could not be decrypted with the given key."""


@dataclass(frozen=True)
class KdfParams:
    salt: str  # hex
    time_cost: int = 3
    memory_cost: int = 64 * 1024  # KiB
    parallelism: int = 4

    @classmethod
    def generate(cls) -> KdfParams:
        return cls(salt=os.urandom(SALT_LEN).hex())

    def to_json(self) -> str:
        return json.dumps(asdict(self))

    @classmethod
    def from_json(cls, raw: str) -> KdfParams:
        return cls(**json.loads(raw))


def derive_key(password: str, params: KdfParams) -> bytes:
    return hash_secret_raw(
        secret=password.encode(),
        salt=bytes.fromhex(params.salt),
        time_cost=params.time_cost,
        memory_cost=params.memory_cost,
        parallelism=params.parallelism,
        hash_len=KEY_LEN,
        type=Type.ID,
    )


def encrypt(key: bytes, plaintext: str) -> bytes:
    """Return nonce || ciphertext+tag."""
    nonce = os.urandom(NONCE_LEN)
    return nonce + AESGCM(key).encrypt(nonce, plaintext.encode(), None)


def decrypt(key: bytes, blob: bytes) -> str:
    nonce, ciphertext = blob[:NONCE_LEN], blob[NONCE_LEN:]
    try:
        return AESGCM(key).decrypt(nonce, ciphertext, None).decode()
    except InvalidTag as exc:
        raise DecryptionError("invalid key or corrupted data") from exc
