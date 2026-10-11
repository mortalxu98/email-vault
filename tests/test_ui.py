from __future__ import annotations

from pathlib import Path

from email_vault import ui

BRAND_ICONS = Path(ui.__file__).parent / "templates" / "_brand_icons.html"


def test_known_provider_logos_exist() -> None:
    icons = BRAND_ICONS.read_text()
    for address in ("a@gmail.com", "a@outlook.com", "a@proton.me", "a@icloud.com", "a@qq.com"):
        pv = ui.provider(address)
        assert pv.logo, address
        assert f'id="brand-{pv.logo}"' in icons


def test_provider_fallbacks() -> None:
    assert ui.provider("a@163.com").logo is None  # no free logo; letter avatar
    unknown = ui.provider("a@Example.ORG")
    assert unknown.logo is None and unknown.initial == "E" and unknown.css.startswith("av-")
