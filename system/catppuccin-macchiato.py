#!/usr/bin/env python3
"""Re-skin calibre-web's caliBlur (dark) theme to Catppuccin Macchiato.

calibre-web has no theme plugin system, so we re-skin from the inside:

  * `css <file...>`      rewrite CaliBlur's colour palette (hex tokens) in place
  * `images <dir>`       replace CaliBlur's backdrop textures with flat colours

`images` matters because CaliBlur paints the page with three PNGs
(blur-noise/light/dark.png) — a palette swap alone leaves those untouched, and
they are what makes the page read as "a gradient/image" rather than a colour.
Replacing them with flat Macchiato pixels re-colours every rule that references
them, at once, with no selector guessing.

Accent: Pink #f5bde6.
"""
import os
import re
import struct
import sys
import zlib

# --- palette -----------------------------------------------------------------
BASE, MANTLE, CRUST = "#24273a", "#1e2030", "#181926"
ACCENT = "#f5bde6"

# CaliBlur (dark)  ->  Catppuccin Macchiato
MAP = {
    # backgrounds: the grey stack -> base/mantle/crust
    "#323232": BASE,
    "#282828": MANTLE,
    "#222222": MANTLE,
    "#222":    MANTLE,
    "#202020": CRUST,
    "#1f1f1f": CRUST,     # also --color-background-mobile
    "#191a1c": CRUST,
    "#000":    CRUST,
    # surfaces & borders
    "#3f4245": "#363a4f",   # surface0
    "#3c444a": "#363a4f",
    "#4f4f4f": "#494d64",   # surface1
    "#474747": BASE,        # <- the --color-background variable: page backdrop
    # text ramp (light -> dark)
    "#fff":    "#cad3f5",   # text
    "#eee":    "#b8c0e0",   # subtext1
    "#ccc":    "#a5adcb",   # subtext0
    "#999":    "#8087a2",   # overlay1
    "#555":    "#6e738d",   # overlay0
    # accents -> pink
    "#ce3d2a": ACCENT,
    "#ac3323": ACCENT,
    "#f9be03": ACCENT,      # <- the --color-primary variable
    "#641e14": "#494d64",   # near-black red -> surface1
    "#cc7b19": "#f5a97f",   # peach (badges) = --color-secondary
    "#e59029": "#f5a97f",   # --color-secondary-hover
}

# Non-hex tokens that also sit on the grey stack.
LITERALS = {
    "rgba(50, 50, 50, .5)": "rgba(36, 39, 58, .5)",   # 50% #323232 -> 50% base
}

# A colour token: 3 or 6 hex digits, NOT followed by another identifier char.
# The trailing guard is vital — it stops us mangling id selectors like
# `#add-to-shelf`, which otherwise looks exactly like the hex colour #add.
COLOR = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z_-])")

# Backdrop textures -> flat Macchiato. blur-noise is layered ON TOP of
# blur-light, so make it transparent (drops the grain, reveals the colour).
BACKDROPS = {
    "blur-noise.png": (0x00, 0x00, 0x00, 0x00),   # transparent
    "blur-light.png": (0x24, 0x27, 0x3A, 0xFF),   # base
    "blur-dark.png":  (0x1E, 0x20, 0x30, 0xFF),   # mantle
}


def _png(rgba: tuple[int, int, int, int], size: int = 4) -> bytes:
    """A tiny solid-colour RGBA PNG, built from stdlib only."""
    raw = b"".join(b"\x00" + bytes(rgba) * size for _ in range(size))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


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


def do_css(paths: list[str]) -> int:
    for path in paths:
        with open(path) as f:
            src = f.read()
        out, n = rewrite(src)
        with open(path, "w") as f:
            f.write(out)
        print(f"catppuccin-macchiato: rewrote {n} colour token(s) in {path}")
    return 0


def do_images(directory: str) -> int:
    for name, rgba in BACKDROPS.items():
        path = os.path.join(directory, name)
        if not os.path.exists(path):
            print(f"catppuccin-macchiato: WARNING no such backdrop {path}")
            continue
        with open(path, "wb") as f:
            f.write(_png(rgba))
        print(f"catppuccin-macchiato: flattened backdrop {path} -> #{''.join(f'{c:02x}' for c in rgba)}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "images":
        return do_images(argv[1])
    if len(argv) >= 2 and argv[0] == "css":
        return do_css(argv[1:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
