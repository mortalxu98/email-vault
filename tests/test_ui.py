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


def test_platform_logo_matching() -> None:
    assert ui.platform_logo("ChatGPT") == "openai"
    assert ui.platform_logo("B 站") == "bilibili"
    assert (
        ui.platform_logo("GitHub Copilot", "https://github.com/features/copilot") == "githubcopilot"
    )
    assert ui.platform_logo("Copilot") == "microsoft"
    assert ui.platform_logo("My Gemini", "https://gemini.google.com/app") == "gemini"
    assert ui.platform_logo("工作号", "https://www.x.com/home") == "x"
    assert ui.platform_logo("Something", "https://evilx.com") is None
    assert ui.platform_logo("Grok") is None


def test_every_platform_logo_has_a_symbol() -> None:
    icons = BRAND_ICONS.read_text()
    for p in ui.PLATFORMS:
        if p.logo:
            assert f'id="brand-{p.logo}"' in icons, p.name


def test_crypto_platforms() -> None:
    assert ui.platform_logo("OKEx") == "okx"
    assert ui.platform_logo("欧易") == "okx"
    assert ui.platform_logo("交易所", "https://www.binance.com/zh-CN") == "binance"


def test_catalog_entries_have_url_and_keys() -> None:
    entries = {e["name"]: e for e in ui.platform_catalog([])}
    assert entries["Bybit"]["url"] == "https://bybit.com" and entries["Bybit"]["logo"] is None
    assert "okex" in entries["OKX"]["keys"]  # type: ignore[operator]


def test_apple_platforms_share_one_logo() -> None:
    for name in ("Apple", "apple id", "苹果", "App Store", "iCloud"):
        assert ui.platform_logo(name) == "apple", name
    assert ui.platform_logo("账号", "https://appleid.apple.com/") == "apple"
    assert ui.platform_logo("某账号", "https://apps.apple.com/") == "apple"


def test_google_account_vs_google_products() -> None:
    assert ui.platform_logo("Google") == "google"
    assert ui.platform_logo("谷歌账号") == "google"
    assert ui.platform_logo("账号", "https://accounts.google.com/") == "google"
    assert (
        ui.platform_logo("某账号", "https://gemini.google.com/") == "gemini"
    )  # most specific host wins


def test_icloud_mail_uses_apple_logo() -> None:
    for address in ("a@icloud.com", "a@me.com", "a@mac.com"):
        assert ui.provider(address).logo == "apple"
