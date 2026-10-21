# /// script
# requires-python = ">=3.11"  # Pillow 13 needs 3.11
# dependencies = ["pillow==13.0.0"]  # pinned: the --check compares pixels
# ///
"""Draws the addon list icon: a small gauge with its own gold ring (no Blizzard pixels).

Writes FeelsLike/Media/Icon.tga (64x64, RGBA) and docs/icon.png (512x512 logo).
Run from the project root: uv run tools/make_icon.py
With --check it writes nothing and fails if Icon.tga differs from what it would draw.
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw

# The shared module sits next to this script; PYTHONSAFEPATH would leave this folder off the path.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_constants import ROOT, segment_colors, sweep

ICON = "FeelsLike/Media/Icon.tga"
LOGO = "docs/icon.png"
# Resampling may differ by a step between Pillow versions; a real color change is far larger.
CHECK_TOLERANCE = 2

OUT = 64
SS = 8  # supersampling
W = OUT * SS
C = W / 2

RING_OUTER = 0.97
RING_INNER = 0.76
SEG_IN, SEG_OUT, SEG_W = 0.40, 0.66, 0.17
NEEDLE_LEN, NEEDLE_W, PIVOT = 0.50, 0.075, 0.11
NEEDLE_ANGLE = 40  # degrees clockwise from 12 o'clock, toward the warm side

SEGMENTS = segment_colors()  # cold to hot, the same as the SVG scale
SWEEP = sweep()
FACE = (14, 22, 32, 255)
NEEDLE = (232, 245, 255, 255)


def hexrgb(h):
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)) + (255,)


def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(len(a)))


def bar(draw, angle, r1, r2, width, color):
    rad = math.radians(angle)
    dx, dy = math.sin(rad), -math.cos(rad)
    nx, ny = -dy, dx
    half = width * C / 2
    pts = []
    for r, s in ((r1, 1), (r2, 1), (r2, -1), (r1, -1)):
        pts.append((C + dx * r * C + nx * half * s, C + dy * r * C + ny * half * s))
    draw.polygon(pts, fill=color)


def draw_logo():
    """The gauge at W x W, smooth; the icon is this scaled down."""
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    px = img.load()

    # Gold ring: bright in the middle of the band, darker at both edges, lit from the top left.
    dark, mid, light = (96, 70, 16, 255), (214, 168, 52, 255), (255, 232, 140, 255)
    for y in range(W):
        for x in range(W):
            dx, dy = (x + 0.5 - C) / C, (y + 0.5 - C) / C
            r = math.hypot(dx, dy)
            if RING_INNER <= r <= RING_OUTER:
                t = (r - RING_INNER) / (RING_OUTER - RING_INNER)
                bevel = 1 - abs(t - 0.45) / 0.55
                base = lerp(dark, mid, max(0.0, min(1.0, bevel)))
                lightness = (-dx - dy) / math.sqrt(2) / r  # 1 at top left, -1 at bottom right
                if lightness > 0:
                    px[x, y] = lerp(base, light, lightness * 0.6 * bevel)
                else:
                    px[x, y] = lerp(base, dark, -lightness * 0.5)
            elif r < RING_INNER:
                px[x, y] = FACE

    draw = ImageDraw.Draw(img)
    for i, color in enumerate(SEGMENTS):
        angle = SWEEP * ((i + 0.5) / len(SEGMENTS) - 0.5)
        bar(draw, angle, SEG_IN, SEG_OUT, SEG_W, hexrgb(color))
    bar(draw, NEEDLE_ANGLE, 0, NEEDLE_LEN, NEEDLE_W, NEEDLE)
    p = PIVOT * C
    draw.ellipse((C - p, C - p, C + p, C + p), fill=NEEDLE)
    return img


def main():
    os.chdir(ROOT)
    logo = draw_logo()
    icon = logo.resize((OUT, OUT), Image.LANCZOS)

    if "--check" in sys.argv[1:]:
        # Packaging: the release must ship the icon for the current colors.
        if not os.path.exists(ICON):
            raise SystemExit(f"{ICON} is missing; run tools/make_icon.py and commit the result")
        with Image.open(ICON) as committed:
            committed = committed.convert("RGBA")
        if committed.size != icon.size:
            raise SystemExit(f"{ICON} is {committed.size}, expected {icon.size}; run tools/make_icon.py")
        diff = max(high for _, high in ImageChops.difference(committed, icon).getextrema())
        if diff > CHECK_TOLERANCE:
            raise SystemExit(
                f"{ICON} differs from tools/make_icon.py by up to {diff}/255 per channel; run it and commit the result"
            )
        print("checked", ICON)
        return

    icon.save(ICON)
    os.makedirs(os.path.dirname(LOGO), exist_ok=True)  # docs/ is not in git, so a fresh clone has none
    logo.save(LOGO)  # 512x512, smooth; logo for CurseForge
    print(ICON, icon.size, icon.mode)


if __name__ == "__main__":
    main()
