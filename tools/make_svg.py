# /// script
# requires-python = ">=3.9"
# ///
"""Draws the gauge as SVG layers for the VectorGraphics renderer (WoW 12.1.0+, Forever 1.60.1).

Every layer shares one 128x128 view box, so the addon stacks them at the same size and place.

The in-game SVG renderer is not a browser. Seen in game on 2026-10-04 (Retail 12.1.0): <circle>,
<rect> and <polygon> draw; <path> with arcs draws nothing. So this file uses only those three
elements, with opaque hex fills: arcs become polygons with a vertex every 2 degrees, the ring is a
stack of circles under the face, and see-through effects are pre-mixed colors. check() enforces it.

Writes FeelsLike/Media/*.svg and FeelsLike/Media/Needle/00.svg … 90.svg. The scale colors, the sweep
and the needle count come from the addon's Lua files (see addon_constants.py).
Run from the project root: uv run tools/make_svg.py
With --check it writes nothing and fails if the files on disk differ from what it would write.
"""

import glob
import math
import os
import re
import sys

# The shared module sits next to this script; PYTHONSAFEPATH would leave this folder off the path.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_constants import ROOT, needle_steps, segment_colors, sweep

MEDIA = "FeelsLike/Media"
NEEDLE_DIR = os.path.join(MEDIA, "Needle")
C = 64.0  # view box center
ARC_STEP = 2.0  # degrees between polygon vertices on an arc

SEGMENTS = segment_colors()  # cold to hot
SWEEP = float(sweep())
SEGMENT_GAP = 4.0  # degrees between segments
SCALE_INNER, SCALE_OUTER = 31.0, 46.0

# The ring is drawn as full circles under the face; the face covers everything inside FACE_RADIUS.
RING_OUTER = 63.5
RING_RIM = 1.8  # dark outer edge
FACE_RADIUS = 50.5
FACE_RIM = 1.4  # dark inner edge of the ring, drawn as part of the face
FACE_RIM_COLOR = "120E08"

# Ring palettes: outer rim, band, light. Light and shade are mixed into the band ahead of time.
# Gold matches the minimap buttons on Retail; bronze matches the minimap ring of Forever (sampled from
# Forever screenshots, 2026-10-21).
RINGS = {
    "ring_gold": ("5C400D", "C99A2E", "F6D77E"),
    "ring_bronze": ("38240F", "7E5933", "D2AA74"),
    "ring_icy": ("2A4A5E", "8FBAD3", "E8F7FF"),
    "ring_hot": ("5A1606", "D9602A", "FFB27A"),
}
FACES = {"face": "0E1620", "face_cold": "163A55", "face_hot": "4A1A0E"}

NEEDLE_COLOR = "E8F6FF"
NEEDLE_EDGE = "070B10"  # dark edge around the needle, for contrast on any face color
PIVOT_CENTER = "8EA3B5"
NEEDLE_STEPS = needle_steps()  # 90: 91 files, 3 degrees apart
GLYPH_COLOR = "F2C94C"
GLYPH_SHADOW = "05070A"

ALLOWED = {"svg", "circle", "rect", "polygon"}


def mix(a, b, k):
    """Hex color a moved toward b by k (0..1)."""
    ca = [int(a[i : i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i : i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * k):02X}" for x, y in zip(ca, cb))


def svg(body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n' + body + "</svg>\n"
    )


def point(angle, radius, cx=C, cy=C):
    """Angle in degrees clockwise from 12 o'clock; SVG y grows downward."""
    rad = math.radians(angle)
    return cx + radius * math.sin(rad), cy - radius * math.cos(rad)


def arc(start, end, radius, cx=C, cy=C):
    """Points along an arc from start to end degrees, both ends included."""
    count = max(2, math.ceil(abs(end - start) / ARC_STEP) + 1)
    return [point(start + (end - start) * i / (count - 1), radius, cx, cy) for i in range(count)]


def circle(x, y, r, color):
    return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="#{color}"/>\n'


def rect(x, y, w, h, color):
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="#{color}"/>\n'


def polygon(points, color):
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    return f'<polygon points="{pts}" fill="#{color}"/>\n'


def sector(start, end, outer, inner, color, cx=C, cy=C):
    """Band between two radii from start to end degrees, as one polygon."""
    return polygon(arc(start, end, outer, cx, cy) + arc(end, start, inner, cx, cy), color)


def ring_of(outer, inner, color, cx=C, cy=C):
    """Full ring as one polygon: around the outer edge, then back around the inner edge.
    The two edges meet along one zero-width seam, which leaves the hole open under any fill rule."""
    return polygon(arc(0, 360, outer, cx, cy) + arc(360, 0, inner, cx, cy), color)


def ring_layer(rim, band, light):
    body = circle(C, C, RING_OUTER, rim)
    body += circle(C, C, RING_OUTER - RING_RIM, band)
    # Light from the top left, shade at the bottom right: reads as metal even at 40 px.
    body += sector(250, 380, RING_OUTER - RING_RIM, FACE_RADIUS - 1, mix(band, light, 0.55))
    body += sector(70, 200, RING_OUTER - RING_RIM, FACE_RADIUS - 1, mix(band, rim, 0.45))
    body += sector(255, 375, RING_OUTER - 3.5, RING_OUTER - 6.0, light)
    return svg(body)


def face_layer(color):
    return svg(circle(C, C, FACE_RADIUS, FACE_RIM_COLOR) + circle(C, C, FACE_RADIUS - FACE_RIM, color))


def scale_layer():
    body = ""
    step = SWEEP / len(SEGMENTS)
    for i, color in enumerate(SEGMENTS):
        start = -SWEEP / 2 + i * step + SEGMENT_GAP / 2
        body += sector(start, start + step - SEGMENT_GAP, SCALE_OUTER, SCALE_INNER, color)
    return svg(body)


# Unit glyphs: geometric shapes, bold enough for 10 px.
GLYPH_Y = 91.0  # center of the letter
GLYPH_H = 24.0  # cap height of C and F
STROKE = 5.2


def degree(x, y, color):
    return ring_of(4.4, 2.0, color, x, y)


def letter_c(x, y, color):
    r_out, r_in = GLYPH_H / 2, GLYPH_H / 2 - STROKE
    # Opening on the right: from the lower right, clockwise through the bottom, left and top.
    body = sector(135, 405, r_out, r_in, color, x, y)
    mid = (r_out + r_in) / 2
    for angle in (135, 405):  # round ends
        px, py = point(angle, mid, x, y)
        body += circle(px, py, STROKE / 2, color)
    return body


def letter_f(x, y, color):
    top = y - GLYPH_H / 2
    width = 15.0
    left = x - width / 2
    return (
        rect(left, top, STROKE, GLYPH_H, color)
        + rect(left, top, width, STROKE, color)
        + rect(left, top + GLYPH_H * 0.42, width * 0.85, STROKE, color)
    )


def unit_layer(unit):
    letter = letter_c if unit == "C" else letter_f

    def glyphs(dx, dy, color):
        return degree(50.0 + dx, GLYPH_Y - GLYPH_H / 2 + 4.6 + dy, color) + letter(70.0 + dx, GLYPH_Y + dy, color)

    return svg(glyphs(1.2, 1.2, GLYPH_SHADOW) + glyphs(0, 0, GLYPH_COLOR))


def needle_layer(angle):
    """Tapered needle from the center toward angle, a dark edge for contrast, and the pivot."""

    def shape(base_half, tip_half, length, tail):
        tip = point(angle, length)
        return [
            point(angle + 180, tail),
            point(angle - 90, base_half),
            point(angle - 90, tip_half, *tip),
            point(angle + 90, tip_half, *tip),
            point(angle + 90, base_half),
        ]

    body = polygon(shape(5.2, 2.2, 40.5, 6.0), NEEDLE_EDGE)
    body += polygon(shape(3.6, 1.1, 39.0, 4.5), NEEDLE_COLOR)
    body += circle(C, C, 8.6, NEEDLE_EDGE)
    body += circle(C, C, 7.0, NEEDLE_COLOR)
    body += circle(C, C, 2.6, PIVOT_CENTER)
    return svg(body)


def check(path, text):
    """Fails if a file uses anything beyond what the game was seen to draw."""
    tags = set(re.findall(r"<([a-zA-Z]+)", text))
    extra = tags - ALLOWED
    if extra or "opacity" in text or "fill-rule" in text or "stroke" in text:
        raise SystemExit(f"{path}: uses {sorted(extra) or 'opacity, fill-rule or stroke'}, which the game may not draw")


def layers():
    """Every SVG file as {path: text}."""
    out = {}
    for name, palette in RINGS.items():
        out[os.path.join(MEDIA, name + ".svg")] = ring_layer(*palette)
    for name, color in FACES.items():
        out[os.path.join(MEDIA, name + ".svg")] = face_layer(color)
    out[os.path.join(MEDIA, "scale.svg")] = scale_layer()
    out[os.path.join(MEDIA, "unit_c.svg")] = unit_layer("C")
    out[os.path.join(MEDIA, "unit_f.svg")] = unit_layer("F")
    for step in range(NEEDLE_STEPS + 1):
        angle = -SWEEP / 2 + SWEEP * step / NEEDLE_STEPS
        out[os.path.join(NEEDLE_DIR, f"{step:02d}.svg")] = needle_layer(angle)
    return out


def read(path):
    """The file's text, or None when it does not exist."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read()


def on_disk():
    return sorted(glob.glob(os.path.join(MEDIA, "*.svg")) + glob.glob(os.path.join(NEEDLE_DIR, "*.svg")))


def old_needles(files, svgs):
    """Numbered needle files on disk that the current NEEDLE_STEPS no longer draws. Only these are
    the script's own leftovers; any other SVG in Media is not touched."""
    return [
        path
        for path in svgs
        if path not in files
        and os.path.dirname(path) == NEEDLE_DIR
        and re.fullmatch(r"\d+\.svg", os.path.basename(path))
    ]


def main():
    os.chdir(ROOT)
    files = layers()
    for path, text in files.items():
        check(path, text)
    changed = sorted(path for path, text in files.items() if read(path) != text)
    svgs = on_disk()
    leftovers = old_needles(files, svgs)
    # Hand-made SVGs ship in the zip too, so they must keep to what the game draws.
    for path in svgs:
        if path not in files and path not in leftovers:
            check(path, read(path))

    if "--check" in sys.argv[1:]:
        # Packaging: the release must ship exactly the committed art.
        if changed or leftovers:
            raise SystemExit(
                "SVG files differ from tools/make_svg.py; run it and commit the result:\n  "
                + "\n  ".join(changed + [path + " (no longer drawn)" for path in leftovers])
            )
        print("checked", len(files), "SVG files in", MEDIA)
        return

    os.makedirs(NEEDLE_DIR, exist_ok=True)
    for path in changed:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(files[path])
    for path in leftovers:
        os.remove(path)
        print("removed", path)
    print(f"checked {len(files)} SVG files in {MEDIA}, wrote {len(changed)}")


if __name__ == "__main__":
    main()
