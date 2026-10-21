"""Constants the asset scripts share with the addon, read from its Lua files so they cannot drift apart.

Model.lua sets the scale colors and the sweep; DialVector.lua sets how many needle positions it loads.
"""

import os
import re

# The project root, so the scripts work from any folder.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "FeelsLike", "Model.lua")
DIAL_VECTOR = os.path.join(ROOT, "FeelsLike", "DialVector.lua")

# Neutral segments for the SVG scale and the icon: a touch lighter than in the line renderer
# (Model.lua NEUTRAL), so the dim top of the scale still shows at small sizes.
SCALE_NEUTRAL = "2E3F4F"


def _read_lua(path):
    """The file without its comments (--[[ ]] blocks and -- lines), so commented-out code never counts."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.DOTALL)
    return re.sub(r"--[^\n]*", "", text)


def _whole_number(text, name, where):
    """The value of `name = <whole number>` on a line of its own; anything else is an error."""
    match = re.search(rf"^{re.escape(name)} = (\S+)[ \t]*$", text, re.MULTILINE)
    if not match or not match.group(1).isdigit():
        raise SystemExit(f"{where}: no `{name} = <whole number>` line")
    return int(match.group(1))


def segment_colors():
    """Model.SEGMENT_COLORS from cold to hot as hex strings, with SCALE_NEUTRAL for the neutral ones."""
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
    """Model.SWEEP: degrees of the arc, centered on 12 o'clock."""
    return _whole_number(_read_lua(MODEL), "Model.SWEEP", MODEL)


def needle_steps():
    """NEEDLE_STEPS from DialVector.lua: the needle files are 00.svg to <steps>.svg."""
    return _whole_number(_read_lua(DIAL_VECTOR), "local NEEDLE_STEPS", DIAL_VECTOR)
