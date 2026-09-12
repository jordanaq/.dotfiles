#!/usr/bin/env python3
"""Re-skin calibre-web's caliBlur (dark) theme to Catppuccin Macchiato.

calibre-web has no theme plugin system, so rather than fight 8,000 lines of
selectors we rewrite caliBlur's *palette* in place: every CaliBlur grey/red
token is mapped onto its Macchiato equivalent. That re-skins the whole theme
consistently; the handful of things a blind swap cannot reason about (accent
used as a background, etc.) live in catppuccin-macchiato-override.css.

Run as: catppuccin-macchiato.py FILE [FILE...]   (edits in place)

Accent: Pink #f5bde6.
"""
import re
import sys

# CaliBlur (dark)  ->  Catppuccin Macchiato
MAP = {
    # --- backgrounds: the grey stack -> base/mantle/crust -------------------
    "#323232": "#24273a",   # base
    "#282828": "#1e2030",   # mantle
    "#222222": "#1e2030",
    "#222":    "#1e2030",
    "#202020": "#181926",   # crust
    "#1f1f1f": "#181926",
    "#191a1c": "#181926",
    "#000":    "#181926",
    # --- surfaces & borders -------------------------------------------------
    "#3f4245": "#363a4f",   # surface0
    "#3c444a": "#363a4f",
    "#4f4f4f": "#494d64",   # surface1
    "#474747": "#494d64",
    # --- text ramp (light -> dark) -----------------------------------------
    "#fff":    "#cad3f5",   # text
    "#eee":    "#b8c0e0",   # subtext1
    "#ccc":    "#a5adcb",   # subtext0
    "#999":    "#8087a2",   # overlay1
    "#555":    "#6e738d",   # overlay0
    # --- accents -> pink (the red/amber CaliBlur accents) -------------------
    "#ce3d2a": "#f5bde6",   # pink
    "#ac3323": "#f5bde6",
    "#641e14": "#494d64",   # near-black red -> surface1
    "#cc7b19": "#f5a97f",   # peach (badges)
    "#e59029": "#f5a97f",
    "#f9be03": "#eed49f",   # yellow
}

# Non-hex tokens that also sit on the grey stack.
LITERALS = {
    "rgba(50, 50, 50, .5)": "rgba(36, 39, 58, .5)",   # 50% #323232 -> 50% base
}

# A colour token: 3 or 6 hex digits, NOT followed by another identifier char.
# The trailing guard is vital — it stops us mangling id selectors like
# `#add-to-shelf` (which otherwise looks like the hex colour #add).
COLOR = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z_-])")


def rewrite(src: str) -> tuple[str, int]:
    n = 0

    def hex_sub(m: re.Match) -> str:
        nonlocal n
        new = MAP.get(m.group(0).lower())
        if new is None:
            return m.group(0)
        n += 1
        return new

    out = COLOR.sub(hex_sub, src)
    for old, new in LITERALS.items():
        n += out.count(old)
        out = out.replace(old, new)
    return out, n


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    for path in argv:
        with open(path) as f:
            src = f.read()
        out, n = rewrite(src)
        with open(path, "w") as f:
            f.write(out)
        print(f"catppuccin-macchiato: rewrote {n} colour token(s) in {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
