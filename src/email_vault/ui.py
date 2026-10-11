"""Jinja helpers for avatars and provider badges."""

from __future__ import annotations

import zlib
from typing import NamedTuple, Protocol, TypeVar
from urllib.parse import urlsplit

AVATAR_PALETTE_SIZE = 8


class _HasAddress(Protocol):
    @property
    def address(self) -> str: ...


_E = TypeVar("_E", bound=_HasAddress)


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


def group_by_provider(emails: list[_E]) -> list[tuple[Provider, list[_E]]]:
    """Group emails by provider, biggest group first; unknown domains each form their own."""
    groups: dict[str, tuple[Provider, list[_E]]] = {}
    for email in emails:
        pv = provider(email.address)
        groups.setdefault(pv.name, (pv, []))[1].append(email)
    return sorted(groups.values(), key=lambda g: (-len(g[1]), g[0].name.lower()))


def split_address(address: str) -> tuple[str, str]:
    local, _, domain = address.rpartition("@")
    return local, f"@{domain}"


class Platform(NamedTuple):
    name: str  # display name, also used as the canonical alias
    category: str
    domains: tuple[str, ...]  # first one is used as the default URL
    aliases: tuple[str, ...] = ()
    logo: str | None = None  # symbol id suffix in _brand_icons.html


def _norm(text: str) -> str:
    """Lowercase and drop whitespace, so "B 站" == "b站"."""
    return "".join(text.lower().split())


# fmt: off
PLATFORMS: tuple[Platform, ...] = (
    # AI
    Platform("ChatGPT", "ai", ("chatgpt.com", "openai.com", "sora.com"), ("openai", "sora", "dall-e", "dalle"), "openai"),
    Platform("Claude", "ai", ("claude.ai", "claude.com"), ("claudecode", "claude.ai"), "claude"),
    Platform("Anthropic Console", "ai", ("console.anthropic.com", "anthropic.com"), ("anthropic", "anthropicapi"), "anthropic"),
    Platform("Gemini", "ai", ("gemini.google.com", "aistudio.google.com"), ("googlegemini", "bard", "aistudio", "googleaistudio"), "gemini"),
    Platform("GitHub Copilot", "ai", (), (), "githubcopilot"),
    Platform("Copilot", "ai", ("copilot.microsoft.com",), ("microsoftcopilot", "bingcopilot"), "microsoft"),
    Platform("Cursor", "ai", ("cursor.com", "cursor.sh"), (), "cursor"),
    Platform("Perplexity", "ai", ("perplexity.ai",), (), "perplexity"),
    Platform("Midjourney", "ai", ("midjourney.com",), ("mj",), "midjourney"),
    Platform("Notion", "ai", ("notion.so", "notion.com"), ("notionai",), "notion"),
    Platform("Hugging Face", "ai", ("huggingface.co",), ("hf",), "huggingface"),
    Platform("Poe", "ai", ("poe.com",), (), "poe"),
    Platform("ElevenLabs", "ai", ("elevenlabs.io",), (), "elevenlabs"),
    Platform("Kimi", "ai", ("kimi.com", "kimi.moonshot.cn", "moonshot.cn"), ("moonshot", "月之暗面"), "kimi"),
    Platform("通义千问", "ai", ("tongyi.aliyun.com", "qwen.ai", "qianwen.com"), ("qwen", "通义", "tongyi"), "qwen"),
    Platform("DeepSeek", "ai", ("deepseek.com",), (), "deepseek"),
    Platform("Mistral", "ai", ("mistral.ai",), ("mistralai", "lechat"), "mistral"),
    Platform("Suno", "ai", ("suno.com", "suno.ai"), (), "suno"),
    Platform("Replicate", "ai", ("replicate.com",), (), "replicate"),
    Platform("Ollama", "ai", ("ollama.com",), (), "ollama"),
    Platform("Grok", "ai", ("grok.com",), ("xai",)),
    Platform("Runway", "ai", ("runwayml.com",), ("runwayml",)),
    Platform("Character.AI", "ai", ("character.ai",), ("characterai", "c.ai")),
    Platform("豆包", "ai", ("doubao.com",), ("doubao",)),
    Platform("文心一言", "ai", ("yiyan.baidu.com",), ("wenxin", "ernie", "文心")),
    # social
    Platform("X", "social", ("x.com", "twitter.com"), ("twitter", "推特"), "x"),
    Platform("Instagram", "social", ("instagram.com",), ("ins", "ig"), "instagram"),
    Platform("Facebook", "social", ("facebook.com",), ("fb",), "facebook"),
    Platform("Threads", "social", ("threads.net", "threads.com"), (), "threads"),
    Platform("Reddit", "social", ("reddit.com",), (), "reddit"),
    Platform("YouTube", "social", ("youtube.com",), ("油管",), "youtube"),
    Platform("TikTok", "social", ("tiktok.com",), (), "tiktok"),
    Platform("抖音", "social", ("douyin.com",), ("douyin",), "tiktok"),
    Platform("Discord", "social", ("discord.com", "discord.gg"), (), "discord"),
    Platform("Telegram", "social", ("telegram.org", "t.me"), ("tg", "电报"), "telegram"),
    Platform("WhatsApp", "social", ("whatsapp.com",), (), "whatsapp"),
    Platform("LinkedIn", "social", ("linkedin.com",), ("领英",), "linkedin"),
    Platform("Mastodon", "social", ("mastodon.social",), (), "mastodon"),
    Platform("Bluesky", "social", ("bsky.app",), ("bsky",), "bluesky"),
    Platform("Pinterest", "social", ("pinterest.com",), (), "pinterest"),
    Platform("Snapchat", "social", ("snapchat.com",), (), "snapchat"),
    Platform("小红书", "social", ("xiaohongshu.com",), ("xiaohongshu", "rednote"), "xiaohongshu"),
    Platform("微博", "social", ("weibo.com",), ("新浪微博", "weibo"), "weibo"),
    Platform("B 站", "social", ("bilibili.com",), ("bilibili", "哔哩哔哩"), "bilibili"),
    Platform("知乎", "social", ("zhihu.com",), ("zhihu",), "zhihu"),
    Platform("豆瓣", "social", ("douban.com",), ("douban",), "douban"),
    Platform("微信", "social", ("weixin.qq.com", "wechat.com"), ("wechat", "weixin"), "wechat"),
    Platform("Twitch", "social", ("twitch.tv",), (), "twitch"),
    Platform("Medium", "social", ("medium.com",), (), "medium"),
    Platform("Quora", "social", ("quora.com",), (), "quora"),
    # crypto
    Platform("OKX", "crypto", ("okx.com", "okex.com"), ("okex", "欧易"), "okx"),
    Platform("Binance", "crypto", ("binance.com",), ("币安",), "binance"),
    Platform("Bybit", "crypto", ("bybit.com",), ()),
    Platform("Bitget", "crypto", ("bitget.com",), ()),
    Platform("Gate", "crypto", ("gate.io", "gate.com"), ("gate.io", "芝麻开门")),
    Platform("HTX", "crypto", ("htx.com", "huobi.com"), ("huobi", "火币")),
    Platform("MEXC", "crypto", ("mexc.com",), ("抹茶",)),
    Platform("KuCoin", "crypto", ("kucoin.com",), ("库币",), "kucoin"),
    Platform("Kraken", "crypto", ("kraken.com",), (), "kraken"),
    Platform("Coinbase", "crypto", ("coinbase.com",), ()),
    Platform("Bitfinex", "crypto", ("bitfinex.com",), ()),
    Platform("MetaMask", "crypto", ("metamask.io",), ("小狐狸",), "metamask"),
    Platform("Trust Wallet", "crypto", ("trustwallet.com",), ("trust",)),
    Platform("Phantom", "crypto", ("phantom.app", "phantom.com"), ()),
    Platform("OKX Wallet", "crypto", ("web3.okx.com",), ("okxweb3", "欧易钱包"), "okx"),
    Platform("Ledger", "crypto", ("ledger.com",), ()),
    Platform("Trezor", "crypto", ("trezor.io",), (), "trezor"),
    # other
    Platform("Slack", "other", ("slack.com",), (), "slack"),
    Platform("GitHub", "other", ("github.com",), (), "github"),
    Platform("Spotify", "other", ("spotify.com",), (), "spotify"),
)
# fmt: on

# Horizontal marks that need more of the avatar to stay legible.
WIDE_LOGOS = frozenset({"okx"})

_BY_NAME = {_norm(a): p for p in PLATFORMS for a in (p.name, *p.aliases)}
_BY_DOMAIN = {d: p for p in PLATFORMS for d in p.domains}


def platform_logo(platform: str, url: str = "") -> str | None:
    """Logo key for a platform: exact name/alias first, then the URL's domain."""
    known = _BY_NAME.get(_norm(platform))
    if known:
        return known.logo
    host = (urlsplit(url).hostname or "").removeprefix("www.")
    # Try the full host, then each parent domain: a.b.example.com -> b.example.com -> ...
    parts = host.split(".")
    for i in range(len(parts) - 1):
        known = _BY_DOMAIN.get(".".join(parts[i:]))
        if known:
            return known.logo
    return None


def platform_catalog(user_platforms: list[tuple[str, str, str]]) -> list[dict[str, object]]:
    """Autocomplete entries: built-in platforms plus the user's own (name, category, url)."""
    entries: list[dict[str, object]] = [
        {
            "name": p.name,
            "category": p.category,
            "url": f"https://{p.domains[0]}" if p.domains else "",
            "keys": sorted({_norm(a) for a in (p.name, *p.aliases)}),
            "logo": p.logo,
        }
        for p in PLATFORMS
    ]
    for name, category, url in user_platforms:
        if _norm(name) in _BY_NAME:
            continue
        entries.append(
            {
                "name": name,
                "category": category,
                "url": url,
                "keys": [_norm(name)],
                "logo": platform_logo(name, url),
                "mine": True,
            }
        )
    return entries
