"""Jinja helpers for avatars and provider badges."""

from __future__ import annotations

import zlib
from typing import NamedTuple

AVATAR_PALETTE_SIZE = 8


class Provider(NamedTuple):
    name: str
    initial: str
    css: str


_PROVIDERS: dict[str, Provider] = {}
for _domains, _provider in (
    (("gmail.com", "googlemail.com"), Provider("Gmail", "G", "pv-gmail")),
    (("outlook.com", "hotmail.com", "live.com", "msn.com"), Provider("Outlook", "O", "pv-outlook")),
    (("proton.me", "protonmail.com", "pm.me"), Provider("Proton", "P", "pv-proton")),
    (("icloud.com", "me.com", "mac.com"), Provider("iCloud", "i", "pv-icloud")),
    (("qq.com", "foxmail.com"), Provider("QQ", "Q", "pv-qq")),
    (("163.com", "126.com", "yeah.net"), Provider("网易", "网", "pv-netease")),
    (("yahoo.com",), Provider("Yahoo", "Y", "pv-yahoo")),
):
    for _domain in _domains:
        _PROVIDERS[_domain] = _provider


def color_index(text: str) -> int:
    return zlib.crc32(text.lower().encode()) % AVATAR_PALETTE_SIZE


def provider(address: str) -> Provider:
    domain = address.rpartition("@")[2].lower()
    known = _PROVIDERS.get(domain)
    if known:
        return known
    return Provider(domain, (domain[:1] or "?").upper(), f"av-{color_index(domain)}")


def split_address(address: str) -> tuple[str, str]:
    local, _, domain = address.rpartition("@")
    return local, f"@{domain}"
