"""Draws the addon list icon: a small gauge with its own gold ring (no Blizzard pixels).

Writes FeelsLike/Media/Icon.tga (64x64, RGBA) and docs/icon.png (512x512 logo).
Run from the project root: python3 tools/make_icon.py  (needs Pillow)
"""
import math
from PIL import Image, ImageDraw

OUT = 64
SS = 8  # supersampling
W = OUT * SS
C = W / 2

RING_OUTER = 0.97
RING_INNER = 0.76
SEG_IN, SEG_OUT, SEG_W = 0.40, 0.66, 0.17
NEEDLE_LEN, NEEDLE_W, PIVOT = 0.50, 0.075, 0.11
NEEDLE_ANGLE = 40  # degrees clockwise from 12 o'clock, toward the warm side

# Same order as Model.SEGMENT_COLORS; neutral a little lighter so it shows at icon size.
SEGMENTS = ["2747C9", "3A78E8", "66B3F0", "A8E2F7"] + ["2E3E4C"] * 4 + ["F2D24B", "F5A445", "EE7135", "E0403C"]
FACE = (14, 22, 32, 255)
NEEDLE = (232, 245, 255, 255)

def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(len(a)))

def point(angle, radius):
    rad = math.radians(angle)
    return (C + radius * C * math.sin(rad), C - radius * C * math.cos(rad))

def bar(draw, angle, r1, r2, width, color):
    rad = math.radians(angle)
    dx, dy = math.sin(rad), -math.cos(rad)
    nx, ny = -dy, dx
    half = width * C / 2
    pts = []
    for r, s in ((r1, 1), (r2, 1), (r2, -1), (r1, -1)):
        pts.append((C + dx * r * C + nx * half * s, C + dy * r * C + ny * half * s))
    draw.polygon(pts, fill=color)

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
    angle = 270 * ((i + 0.5) / 12 - 0.5)
    bar(draw, angle, SEG_IN, SEG_OUT, SEG_W, hexrgb(color))
bar(draw, NEEDLE_ANGLE, 0, NEEDLE_LEN, NEEDLE_W, NEEDLE)
p = PIVOT * C
draw.ellipse((C - p, C - p, C + p, C + p), fill=NEEDLE)

icon = img.resize((OUT, OUT), Image.LANCZOS)
icon.save("FeelsLike/Media/Icon.tga")
img.save("docs/icon.png")  # 512x512, smooth; logo for CurseForge
print("FeelsLike/Media/Icon.tga", icon.size, icon.mode)
