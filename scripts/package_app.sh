#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
configuration=${1:-release}
signing_identity=${2:--}
app_dir="$repo_dir/.build/$configuration/KeylumeClone.app"
architecture_args=(--arch arm64 --arch x86_64)

swift build --package-path "$repo_dir" -c "$configuration" --product KeylumeClone "${architecture_args[@]}"
binary_dir=$(swift build --package-path "$repo_dir" -c "$configuration" "${architecture_args[@]}" --show-bin-path)

if [[ -e "$app_dir" ]]; then
    rm -rf "$app_dir"
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$repo_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$binary_dir/KeylumeClone" "$app_dir/Contents/MacOS/KeylumeClone"
cp "$repo_dir/README.md" "$app_dir/Contents/Resources/README.md"
cp "$repo_dir/docs/privacy.md" "$app_dir/Contents/Resources/privacy.md"
chmod 755 "$app_dir/Contents/MacOS/KeylumeClone"
codesign --force --deep --options runtime --timestamp=none --sign "$signing_identity" "$app_dir"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$app_dir"
file "$app_dir/Contents/MacOS/KeylumeClone"
echo "$app_dir"
