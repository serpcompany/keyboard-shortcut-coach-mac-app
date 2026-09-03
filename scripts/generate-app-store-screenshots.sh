#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
review_dir="$repo_root/release/screenshots/review"
output_dir="$repo_root/release/screenshots/app-store"

mkdir -p "$output_dir"
for source in "$review_dir"/*.png; do
  [[ -e "$source" ]] || continue
  filename="$(basename "$source")"
  magick "$source" \
    -resize '1120x700' \
    -background '#121212' \
    -gravity center \
    -extent 1280x800 \
    -alpha off \
    -colorspace sRGB \
    -strip +set date:create +set date:modify \
    -define png:exclude-chunk=date,time \
    PNG24:"$output_dir/$filename"
done

echo "Generated 1280×800 App Store review images in $output_dir"
