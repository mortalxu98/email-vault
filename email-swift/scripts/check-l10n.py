#!/usr/bin/env python3
"""Fail if a tr()/trf() key in the app sources has no English translation, or a translation is unused."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources" / "EmailVaultApp"
STRINGS = ROOT / "Localization" / "en.lproj" / "Localizable.strings"

# Keys are compared in their escaped source form; Swift literals and .strings share \n and \" escapes.
CALL = re.compile(r'\btrf?\("((?:[^"\\]|\\.)*)"')
ENTRY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"(?:[^"\\]|\\.)*";\s*$', re.M)


def main() -> int:
    used = {
        key
        for path in SOURCES.rglob("*.swift")
        for key in CALL.findall(path.read_text(encoding="utf-8"))
    }
    translated = set(ENTRY.findall(STRINGS.read_text(encoding="utf-8")))

    missing = sorted(used - translated)
    unused = sorted(translated - used)
    for key in missing:
        print(f"missing English translation: {key}", file=sys.stderr)
    for key in unused:
        print(f"unused translation: {key}", file=sys.stderr)
    print(f"{len(used)} keys, {len(missing)} missing, {len(unused)} unused")
    return 1 if missing or unused else 0


if __name__ == "__main__":
    raise SystemExit(main())
