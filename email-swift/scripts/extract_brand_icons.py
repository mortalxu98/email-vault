#!/usr/bin/env python3
"""Extract BrandIcons/_brand_icons.html symbols → PDF assets for the app bundle.

Requires librsvg2-bin (rsvg-convert). Writes to Sources/EmailVaultApp/Resources/BrandIcons/.
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "BrandIcons" / "_brand_icons.html"
OUT = ROOT / "Sources" / "EmailVaultApp" / "Resources" / "BrandIcons"

# Monochrome marks: force black fill so they render on light avatar backgrounds.
MONO = {
    "apple", "x", "github", "threads", "medium", "notion", "ollama",
    "elevenlabs", "cursor", "poe", "suno", "replicate", "okx", "githubcopilot",
}


def main() -> int:
    if not SRC.is_file():
        print(f"missing {SRC}", file=sys.stderr)
        return 1
    if not shutil_which("rsvg-convert"):
        print("rsvg-convert not found (install librsvg2-bin)", file=sys.stderr)
        return 1

    html = SRC.read_text()
    symbols = re.findall(
        r'<symbol\s+id="(brand-[a-z0-9]+)"([^>]*)>(.*?)</symbol>', html, re.S
    )
    OUT.mkdir(parents=True, exist_ok=True)
    # Clear old PDFs
    for old in OUT.glob("brand-*.pdf"):
        old.unlink()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for sid, attrs, body in symbols:
            key = sid.removeprefix("brand-")
            m = re.search(r'viewBox="([^"]+)"', attrs)
            vb = m.group(1) if m else "0 0 256 256"
            filled = body
            if key in MONO:
                if "fill=" not in body:
                    filled = re.sub(r"<path\b", '<path fill="#000000"', body, count=1)
                filled = filled.replace('fill="currentColor"', 'fill="#000000"')
            svg = (
                f'<?xml version="1.0" encoding="UTF-8"?>\n'
                f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" '
                f'width="256" height="256">\n{filled}\n</svg>\n'
            )
            svg_path = tmp_path / f"{sid}.svg"
            pdf_path = OUT / f"{sid}.pdf"
            svg_path.write_text(svg)
            subprocess.check_call(
                ["rsvg-convert", "-f", "pdf", "-o", str(pdf_path), str(svg_path)]
            )
    print(f"wrote {len(symbols)} PDFs → {OUT}")
    return 0


def shutil_which(cmd: str) -> str | None:
    from shutil import which
    return which(cmd)


if __name__ == "__main__":
    raise SystemExit(main())
