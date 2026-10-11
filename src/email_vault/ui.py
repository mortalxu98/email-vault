"""Jinja helpers for avatars and provider badges."""

from __future__ import annotations

import zlib
from typing import NamedTuple
from urllib.parse import urlsplit

AVATAR_PALETTE_SIZE = 8


class Provider(NamedTuple):
    name: str
    initial: str
    css: str
    logo: str | None = None  # symbol id suffix in _brand_icons.html


_PROVIDERS: dict[str, Provider] = {}
for _domains, _provider in (
    (("gmail.com", "googlemail.com"), Provider("Gmail", "G", "pv-gmail", "gmail")),
    (
        ("outlook.com", "hotmail.com", "live.com", "msn.com"),
        Provider("Outlook", "O", "pv-outlook", "microsoft"),
    ),
    (("proton.me", "protonmail.com", "pm.me"), Provider("Proton", "P", "pv-proton", "proton")),
    (("icloud.com", "me.com", "mac.com"), Provider("iCloud", "i", "pv-icloud", "icloud")),
    (("qq.com", "foxmail.com"), Provider("QQ", "Q", "pv-qq", "qq")),
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


# logo key -> (platform name aliases, site domains). Names are matched after
# lowercasing and removing whitespace, so "B 站" == "b站".
_PLATFORMS: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = {
    "openai": (
        ("chatgpt", "openai", "sora", "dall-e", "dalle"),
        ("chatgpt.com", "openai.com", "sora.com"),
    ),
    "claude": (("claude", "claudecode", "claude.ai"), ("claude.ai", "claude.com")),
    "anthropic": (("anthropic", "anthropicconsole", "anthropicapi"), ("anthropic.com",)),
    "gemini": (
        ("gemini", "googlegemini", "bard", "aistudio", "googleaistudio"),
        ("gemini.google.com", "aistudio.google.com"),
    ),
    "githubcopilot": (("githubcopilot",), ()),
    "microsoft": (("copilot", "microsoftcopilot", "bingcopilot"), ("copilot.microsoft.com",)),
    "cursor": (("cursor",), ("cursor.com", "cursor.sh")),
    "perplexity": (("perplexity",), ("perplexity.ai",)),
    "midjourney": (("midjourney", "mj"), ("midjourney.com",)),
    "notion": (("notion", "notionai"), ("notion.so", "notion.com")),
    "huggingface": (("huggingface", "hf"), ("huggingface.co",)),
    "poe": (("poe",), ("poe.com",)),
    "elevenlabs": (("elevenlabs",), ("elevenlabs.io",)),
    "kimi": (("kimi", "moonshot", "月之暗面"), ("kimi.moonshot.cn", "moonshot.cn", "kimi.com")),
    "qwen": (
        ("qwen", "通义千问", "通义", "tongyi"),
        ("tongyi.aliyun.com", "qwen.ai", "qianwen.com"),
    ),
    "deepseek": (("deepseek",), ("deepseek.com",)),
    "mistral": (("mistral", "mistralai", "lechat"), ("mistral.ai",)),
    "suno": (("suno",), ("suno.com", "suno.ai")),
    "replicate": (("replicate",), ("replicate.com",)),
    "ollama": (("ollama",), ("ollama.com",)),
    "x": (("x", "twitter", "推特"), ("x.com", "twitter.com")),
    "instagram": (("instagram", "ins", "ig"), ("instagram.com",)),
    "facebook": (("facebook", "fb"), ("facebook.com",)),
    "threads": (("threads",), ("threads.net", "threads.com")),
    "reddit": (("reddit",), ("reddit.com",)),
    "youtube": (("youtube", "油管"), ("youtube.com",)),
    "tiktok": (("tiktok", "抖音", "douyin"), ("tiktok.com", "douyin.com")),
    "discord": (("discord",), ("discord.com", "discord.gg")),
    "telegram": (("telegram", "tg", "电报"), ("telegram.org", "t.me")),
    "whatsapp": (("whatsapp",), ("whatsapp.com",)),
    "linkedin": (("linkedin", "领英"), ("linkedin.com",)),
    "mastodon": (("mastodon",), ("mastodon.social",)),
    "bluesky": (("bluesky", "bsky"), ("bsky.app",)),
    "pinterest": (("pinterest",), ("pinterest.com",)),
    "snapchat": (("snapchat",), ("snapchat.com",)),
    "xiaohongshu": (("小红书", "xiaohongshu", "rednote"), ("xiaohongshu.com",)),
    "weibo": (("微博", "新浪微博", "weibo"), ("weibo.com",)),
    "bilibili": (("b站", "bilibili", "哔哩哔哩"), ("bilibili.com",)),
    "zhihu": (("知乎", "zhihu"), ("zhihu.com",)),
    "douban": (("豆瓣", "douban"), ("douban.com",)),
    "wechat": (("微信", "wechat", "weixin"), ("weixin.qq.com", "wechat.com")),
    "slack": (("slack",), ("slack.com",)),
    "github": (("github",), ("github.com",)),
    "twitch": (("twitch",), ("twitch.tv",)),
    "spotify": (("spotify",), ("spotify.com",)),
    "medium": (("medium",), ("medium.com",)),
    "quora": (("quora",), ("quora.com",)),
}
_PLATFORM_BY_NAME = {name: key for key, (names, _) in _PLATFORMS.items() for name in names}
_PLATFORM_BY_DOMAIN = {d: key for key, (_, domains) in _PLATFORMS.items() for d in domains}


def platform_logo(platform: str, url: str = "") -> str | None:
    """Logo key for a platform: exact name alias first, then the URL's domain."""
    key = _PLATFORM_BY_NAME.get("".join(platform.lower().split()))
    if key:
        return key
    host = (urlsplit(url).hostname or "").removeprefix("www.")
    # Try the full host, then each parent domain: a.b.example.com -> b.example.com -> ...
    parts = host.split(".")
    for i in range(len(parts) - 1):
        key = _PLATFORM_BY_DOMAIN.get(".".join(parts[i:]))
        if key:
            return key
    return None
