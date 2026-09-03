#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_svg="$repo_root/brand/source/serp-arrow.svg"
appicon_dir="$repo_root/ShortcutCoach/Resources/Assets.xcassets/AppIcon.appiconset"
store_dir="$repo_root/brand/generated/app-store"

expected_sha="b9263f3fd95d25346c8e2689e5a3d2cab54f4e07cea48edcf09cfea0133e537d"
actual_sha="$(shasum -a 256 "$source_svg" | awk '{print $1}')"
if [[ "$actual_sha" != "$expected_sha" ]]; then
  echo "Unexpected SERP source checksum: $actual_sha" >&2
  exit 1
fi

mkdir -p "$appicon_dir" "$store_dir"
tmp_dir="$(mktemp -d)"
cleanup() {
  if [[ -d "$tmp_dir" ]]; then
    find "$tmp_dir" -depth -delete
  fi
}
trap cleanup EXIT

rsvg-convert --width 700 --height 700 "$source_svg" --output "$tmp_dir/arrow.png"
magick -size 1024x1024 xc:'#FFFFFF' "$tmp_dir/arrow.png" -gravity center -composite -alpha off PNG24:"$tmp_dir/app-icon-1024.png"

for size in 16 32 64 128 256 512 1024; do
  magick "$tmp_dir/app-icon-1024.png" -filter Lanczos -resize "${size}x${size}" \
    -strip +set date:create +set date:modify \
    -define png:exclude-chunk=date,time \
    PNG24:"$appicon_dir/app-icon-${size}.png"
done

magick "$tmp_dir/app-icon-1024.png" \
  -strip +set date:create +set date:modify \
  -define png:exclude-chunk=date,time \
  PNG24:"$store_dir/ShortcutCoach-AppStore-1024.png"
echo "Generated SERP app assets from $source_svg"
