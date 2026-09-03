#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

scripts/generate-brand-assets.sh
plutil -lint ShortcutCoach/Resources/ShortcutCoach-AppStore.entitlements >/dev/null
asc metadata validate --dir metadata --output table
scripts/generate-app-store-screenshots.sh
asc screenshots validate --path release/screenshots/app-store --device-type APP_DESKTOP --output table

store_icon="brand/generated/app-store/ShortcutCoach-AppStore-1024.png"
[[ "$(sips -g pixelWidth "$store_icon" | awk '/pixelWidth/ {print $2}')" == "1024" ]]
[[ "$(sips -g pixelHeight "$store_icon" | awk '/pixelHeight/ {print $2}')" == "1024" ]]
[[ "$(sips -g hasAlpha "$store_icon" | awk '/hasAlpha/ {print $2}')" == "no" ]]

for size in 16 32 64 128 256 512 1024; do
  file="ShortcutCoach/Resources/Assets.xcassets/AppIcon.appiconset/app-icon-${size}.png"
  [[ "$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')" == "$size" ]]
  [[ "$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')" == "$size" ]]
done

if rg -n -i 'keylume|gitify|heyclicky|openclicky' ShortcutCoach project.yml metadata release/app-store; then
  echo "Third-party prototype identity found in shipped/release material" >&2
  exit 1
fi

echo "Release assets and canonical metadata validated."
