#!/bin/sh
# Builds dist/FeelsLike-<version>.zip for CurseForge and Wago. Run from anywhere.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(sed -n 's/^## Version: *//p' "$root/FeelsLike/FeelsLike.toc" | tr -d '\r')
if [ -z "$version" ]; then
	echo "No ## Version in FeelsLike.toc" >&2
	exit 1
fi

# Fails if the committed SVG layers or icon differ from what the tools draw (or an SVG uses a shape
# the game does not draw). Writes nothing, so the zip holds exactly the committed art.
(cd "$root" && uv run tools/make_svg.py --check)
(cd "$root" && uv run tools/make_icon.py --check)
(cd "$root" && luajit tests/model_test.lua)
(cd "$root" && luajit tests/smoke_test.lua)

mkdir -p "$root/dist"
zip_path="$root/dist/FeelsLike-$version.zip"
rm -f "$zip_path"

# The zip must contain the FeelsLike folder itself, so it unpacks straight into Interface/AddOns.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R "$root/FeelsLike" "$stage/FeelsLike"
cp "$root/LICENSE" "$stage/FeelsLike/LICENSE.txt"
(cd "$stage" && zip -r -X -q "$zip_path" FeelsLike -x '*.DS_Store')
echo "$zip_path"
