# /// script
# requires-python = ">=3.9"
# ///
"""Draws the gauge SVG layers. Run with uv run tools/make_svg.py, add --check to only compare.

The game draws only circle, rect and polygon with solid colors.
"""

import glob
import math
import os
import re
import sys

# Import the shared module from this folder.
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

# Ring drawn as full circles under the face.
RING_OUTER = 63.5  # outer edge of the outline
BAND_OUTER = 58.2  # outer edge of the band
FACE_RADIUS = 50.5
FACE_RIM = 1.4  # inner edge of the ring, drawn as part of the face
FACE_RIM_COLOR = "1D2B42"  # dark edge of the face

# Ring shading around the band.
LIGHT_ANGLE, LIGHT_POWER = 300.0, 3.0
SHADE_ANGLE, SHADE_POWER = 150.0, 2.0
BAND_STEP = 10.0

# Ring colors.
RINGS = {
    "ring_gold": ("2B1F08", "986F22", "C99A2E", "F6D77E"),
    "ring_bronze": ("201A0D", "5E4527", "77542C", "AB8D5B"),
    "ring_classic": ("16140F", "665216", "7C6D24", "E4CA43"),
    "ring_icy": ("14232C", "62879E", "8FBAD3", "E8F7FF"),
    "ring_hot": ("2A0A03", "9F3D1B", "D9602A", "FFB27A"),
}
FACES = {"face": "0E1620", "face_cold": "163A55", "face_hot": "4A1A0E"}

NEEDLE_COLOR = "E8F6FF"
NEEDLE_EDGE = "070B10"  # dark edge around the needle
PIVOT_CENTER = "8EA3B5"
NEEDLE_STEPS = needle_steps()  # 91 files, 3 degrees apart
GLYPH_COLOR = "F2C94C"
GLYPH_SHADOW = "05070A"

ALLOWED = {"svg", "circle", "rect", "polygon"}


def mix(a, b, k):
    """Mixes color a toward b by k."""
    ca = [int(a[i : i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i : i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * k):02X}" for x, y in zip(ca, cb))


def svg(body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n' + body + "</svg>\n"
    )


def point(angle, radius, cx=C, cy=C):
    """Point at an angle from 12 o'clock."""
    rad = math.radians(angle)
    return cx + radius * math.sin(rad), cy - radius * math.cos(rad)


def arc(start, end, radius, cx=C, cy=C):
    """Points along an arc."""
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
    """Band between two radii as one polygon."""
    return polygon(arc(start, end, outer, cx, cy) + arc(end, start, inner, cx, cy), color)


def ring_of(outer, inner, color, cx=C, cy=C):
    """Full ring as one polygon."""
    return polygon(arc(0, 360, outer, cx, cy) + arc(360, 0, inner, cx, cy), color)


def band_color(angle, shade, band, light):
    """Band color at an angle."""

    def weight(center, power):
        return max(0.0, math.cos(math.radians(angle - center))) ** power

    return mix(mix(band, light, weight(LIGHT_ANGLE, LIGHT_POWER)), shade, weight(SHADE_ANGLE, SHADE_POWER))


def ring_layer(outline, shade, band, light):
    body = circle(C, C, RING_OUTER, outline)
    body += circle(C, C, BAND_OUTER, band)
    # Color steps around the band.
    half = BAND_STEP / 2 + 0.5
    for i in range(round(360 / BAND_STEP)):
        angle = i * BAND_STEP
        color = band_color(angle, shade, band, light)
        if color != band:
            body += sector(angle - half, angle + half, BAND_OUTER, FACE_RADIUS - 1, color)
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


# Unit letters.
GLYPH_Y = 91.0  # center of the letter
GLYPH_H = 24.0  # cap height of C and F
STROKE = 5.2


def degree(x, y, color):
    return ring_of(4.4, 2.0, color, x, y)


def letter_c(x, y, color):
    r_out, r_in = GLYPH_H / 2, GLYPH_H / 2 - STROKE
    # Opening on the right.
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
    """Needle with a dark edge and a pivot."""

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
    """Fails if a file uses shapes the game does not draw."""
    tags = set(re.findall(r"<([a-zA-Z]+)", text))
    extra = tags - ALLOWED
    if extra or "opacity" in text or "fill-rule" in text or "stroke" in text:
        raise SystemExit(f"{path}: uses {sorted(extra) or 'opacity, fill-rule or stroke'}, which the game may not draw")


def layers():
    """Every SVG file by path."""
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
    """File text, or None if missing."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read()


def on_disk():
    return sorted(glob.glob(os.path.join(MEDIA, "*.svg")) + glob.glob(os.path.join(NEEDLE_DIR, "*.svg")))


def old_needles(files, svgs):
    """Old needle files no longer used."""
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
    # Hand made SVGs must follow the same rules.
    for path in svgs:
        if path not in files and path not in leftovers:
            check(path, read(path))

    if "--check" in sys.argv[1:]:
        # The release must ship the committed art.
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
