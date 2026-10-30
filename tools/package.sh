#!/bin/sh
# Builds the release zip. Run from anywhere.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(sed -n 's/^## Version: *//p' "$root/FeelsLike/FeelsLike.toc" | tr -d '\r')
if [ -z "$version" ]; then
	echo "No ## Version in FeelsLike.toc" >&2
	exit 1
fi

# Check that the art matches the tools.
(cd "$root" && uv run tools/make_svg.py --check)
(cd "$root" && uv run tools/make_icon.py --check)
(cd "$root" && luajit tests/model_test.lua)
(cd "$root" && luajit tests/smoke_test.lua)

mkdir -p "$root/dist"
zip_path="$root/dist/FeelsLike-$version.zip"
rm -f "$zip_path"

# The zip holds the FeelsLike folder.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R "$root/FeelsLike" "$stage/FeelsLike"
cp "$root/LICENSE" "$stage/FeelsLike/LICENSE.txt"
(cd "$stage" && zip -r -X -q "$zip_path" FeelsLike -x '*.DS_Store')
echo "$zip_path"
