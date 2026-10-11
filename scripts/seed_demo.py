"""Create a demo vault filled with fake data.

Usage: uv run python scripts/seed_demo.py <db_path> [--master PASSWORD] [--force]
"""

from __future__ import annotations

import argparse
import secrets
import string
import sys
from pathlib import Path

from email_vault import crypto
from email_vault.auth import Vault
from email_vault.store import Store

DEFAULT_REAL_DB = Path.home() / ".local" / "share" / "email-vault" / "vault.db"

# address, note, [(platform, category, username, url, note, has_password)]
DEMO: list[tuple[str, str, list[tuple[str, str, str, str, str, bool]]]] = [
    (
        "alex.chen.work@gmail.com",
        "主力工作邮箱\n恢复邮箱：alex.backup@outlook.com",
        [
            ("ChatGPT", "ai", "", "chatgpt.com", "Plus 订阅，每月 3 号扣费", True),
            ("Claude", "ai", "", "claude.ai", "Pro", False),
            ("GitHub Copilot", "ai", "alexchen-dev", "github.com/features/copilot", "", True),
            ("Cursor", "ai", "", "cursor.com", "Google 登录", False),
            ("Notion AI", "ai", "", "notion.so", "", True),
            ("LinkedIn", "social", "", "linkedin.com", "", True),
            ("Slack", "other", "", "slack.com", "公司 workspace", True),
        ],
    ),
    (
        "alex.backup@outlook.com",
        "备用邮箱，绑定手机 138****2468",
        [
            ("Gemini", "ai", "", "gemini.google.com", "", True),
            ("Copilot", "ai", "", "copilot.microsoft.com", "微软账号登录", False),
            ("Discord", "social", "alexc#2048", "discord.com", "", True),
        ],
    ),
    (
        "alexc.ai@proton.me",
        "专门注册 AI 工具试用",
        [
            ("Perplexity", "ai", "", "perplexity.ai", "", True),
            ("Midjourney", "ai", "", "midjourney.com", "Discord 登录", False),
            ("Runway", "ai", "", "runwayml.com", "免费额度已用完", True),
            ("ElevenLabs", "ai", "", "elevenlabs.io", "", True),
            ("Poe", "ai", "", "poe.com", "", True),
            ("Hugging Face", "ai", "alexc-hf", "huggingface.co", "", True),
        ],
    ),
    (
        "chen.alex.social@gmail.com",
        "社交媒体专用",
        [
            ("X", "social", "@alexchen_dev", "x.com", "Google 登录", False),
            ("Instagram", "social", "alex.shoots", "instagram.com", "", True),
            ("Reddit", "social", "u/quiet_alex", "reddit.com", "", True),
            ("YouTube", "social", "", "youtube.com", "Google 账号", False),
            ("Threads", "social", "alex.shoots", "threads.net", "跟 Instagram 绑定", False),
            ("Telegram", "social", "@alexc", "telegram.org", "手机号注册", False),
        ],
    ),
    (
        "alexchen88@qq.com",
        "国内平台",
        [
            ("Kimi", "ai", "", "kimi.moonshot.cn", "手机号登录", False),
            ("通义千问", "ai", "", "tongyi.aliyun.com", "", True),
            ("小红书", "social", "阿历克斯", "xiaohongshu.com", "", True),
            ("微博", "social", "Alex_陈", "weibo.com", "", True),
            ("B 站", "social", "alexchen88", "bilibili.com", "", True),
        ],
    ),
    (
        "alexchen_2019@163.com",
        "老邮箱，基本不用了",
        [
            ("豆瓣", "social", "", "douban.com", "", True),
            ("知乎", "social", "陈亚历", "zhihu.com", "", True),
        ],
    ),
    (
        "a.chen@icloud.com",
        "Apple ID",
        [
            ("Mastodon", "social", "@alexc@mastodon.social", "mastodon.social", "", True),
            ("OKX", "crypto", "", "okx.com", "已 KYC，资金密码另存", True),
            ("Binance", "crypto", "", "binance.com", "", True),
            ("Coinbase", "crypto", "", "coinbase.com", "", True),
            ("MetaMask", "crypto", "", "metamask.io", "助记词离线保存", True),
            ("Bybit", "crypto", "", "bybit.com", "", True),
        ],
    ),
    ("test.alex.2024@gmail.com", "临时测试用，还没注册东西", []),
]

ALPHABET = string.ascii_letters + string.digits + "!@#$%^&*"


def fake_password() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(16))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("db_path", type=Path)
    parser.add_argument("--master", default="demo1234", help="master password (default: demo1234)")
    parser.add_argument("--force", action="store_true", help="overwrite an existing demo db")
    args = parser.parse_args()

    db_path: Path = args.db_path.expanduser().resolve()
    if db_path == DEFAULT_REAL_DB.resolve():
        print(f"refusing to seed the real vault: {db_path}", file=sys.stderr)
        return 1
    if db_path.exists():
        if not args.force:
            print(f"{db_path} exists; use --force to recreate", file=sys.stderr)
            return 1
        db_path.unlink()

    store = Store(db_path)
    key = Vault(store).initialize(args.master)
    accounts = 0
    for address, note, items in DEMO:
        email_id = store.create_email(address, note, crypto.encrypt(key, fake_password()))
        for platform, category, username, url, acc_note, has_pw in items:
            store.create_account(
                email_id,
                platform,
                category,
                username,
                f"https://{url}",
                acc_note,
                crypto.encrypt(key, fake_password()) if has_pw else None,
            )
            accounts += 1
    print(f"seeded {db_path}: {len(DEMO)} emails, {accounts} accounts, master={args.master}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
