#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
review_dir="$repo_root/release/screenshots/lite-review"
output_dir="$repo_root/release/screenshots/lite-app-store/en-US"

mkdir -p "$output_dir"
for source in "$review_dir"/*.png; do
  [[ -e "$source" ]] || continue
  filename="$(basename "$source")"
  magick "$source" \
    -resize '1180x720>' \
    -background '#121212' \
    -gravity center \
    -extent 1280x800 \
    -alpha off \
    -colorspace sRGB \
    -strip +set date:create +set date:modify \
    -define png:exclude-chunk=date,time \
    PNG24:"$output_dir/$filename"
done

echo "Generated Shortcut Coach Lite 1280×800 screenshots in $output_dir"
