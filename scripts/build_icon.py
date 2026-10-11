"""Render assets/icon.svg to assets/EmailVault.icns (macOS only).

Usage: uv run --with playwright python scripts/build_icon.py
Needs Google Chrome installed (used headless to rasterise the SVG).
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
SVG = ROOT / "assets" / "icon.svg"
ICNS = ROOT / "assets" / "EmailVault.icns"
SIZES = (16, 32, 128, 256, 512)


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        master = Path(tmp) / "icon-1024.png"
        with sync_playwright() as p:
            browser = p.chromium.launch(channel="chrome")
            page = browser.new_page(viewport={"width": 1024, "height": 1024})
            page.set_content(
                f"<body style='margin:0;background:transparent'>{SVG.read_text()}</body>"
            )
            page.locator("svg").screenshot(path=str(master), omit_background=True)
            browser.close()

        iconset = Path(tmp) / "EmailVault.iconset"
        iconset.mkdir()
        for size in SIZES:
            for scale in (1, 2):
                px = size * scale
                out = iconset / f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
                if px == 1024:
                    shutil.copy(master, out)
                else:
                    subprocess.run(
                        ["/usr/bin/sips", "-z", str(px), str(px), str(master), "--out", str(out)],
                        check=True,
                        capture_output=True,
                    )
        subprocess.run(
            ["/usr/bin/iconutil", "-c", "icns", str(iconset), "-o", str(ICNS)], check=True
        )
    print(f"wrote {ICNS}")


if __name__ == "__main__":
    main()
