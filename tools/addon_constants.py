"""Constants shared with the addon, read from its Lua files."""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "FeelsLike", "Model.lua")
DIAL_VECTOR = os.path.join(ROOT, "FeelsLike", "DialVector.lua")

# Neutral color for the SVG scale and icon.
SCALE_NEUTRAL = "2E3F4F"


def _read_lua(path):
    """The Lua file without comments."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.DOTALL)
    return re.sub(r"--[^\n]*", "", text)


def _whole_number(text, name, where):
    """Reads a whole number constant."""
    match = re.search(rf"^{re.escape(name)} = (\S+)[ \t]*$", text, re.MULTILINE)
    if not match or not match.group(1).isdigit():
        raise SystemExit(f"{where}: no `{name} = <whole number>` line")
    return int(match.group(1))


def segment_colors():
    """Segment colors from cold to hot."""
    text = _read_lua(MODEL)
    block = re.search(r"Model\.SEGMENT_COLORS = \{(.*?)\n\}", text, re.DOTALL)
    if not block:
        raise SystemExit(f"{MODEL}: Model.SEGMENT_COLORS not found")
    entries = [entry.strip() for entry in block.group(1).split(",") if entry.strip()]
    colors = []
    for entry in entries:
        color = re.fullmatch(r"""rgb\s*\(?\s*["']([0-9A-Fa-f]{6})["']\s*\)?""", entry)
        if color:
            colors.append(color.group(1).upper())
        elif entry == "NEUTRAL":
            colors.append(SCALE_NEUTRAL)
        else:
            raise SystemExit(f"{MODEL}: cannot read the segment color {entry!r}")
    count = _whole_number(text, "Model.SEGMENT_COUNT", MODEL)
    if len(colors) != count:
        raise SystemExit(f"{MODEL}: {len(colors)} segment colors, but Model.SEGMENT_COUNT is {count}")
    return colors


def sweep():
    """Arc of the scale in degrees."""
    return _whole_number(_read_lua(MODEL), "Model.SWEEP", MODEL)


def needle_steps():
    """Number of needle steps."""
    return _whole_number(_read_lua(DIAL_VECTOR), "local NEEDLE_STEPS", DIAL_VECTOR)
