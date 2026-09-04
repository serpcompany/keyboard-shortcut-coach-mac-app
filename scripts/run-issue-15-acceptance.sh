#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="$(mktemp -d "${TMPDIR:-/tmp}/shortcut-coach-issue-15.XXXXXX")"
cleanup() {
  if [[ "$derived_data" == *"shortcut-coach-issue-15."* ]]; then
    rm -rf -- "$derived_data"
  fi
}
trap cleanup EXIT

cd "$repo_root"
full_suite="${1:-}"
set --
if [[ "$full_suite" != "--full" ]]; then
  set -- -only-testing:ShortcutCoachTests/FinderTrashDetectionTests
fi
xcodebuild test \
  -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach \
  -destination 'platform=macOS' \
  "$@" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO

printf '%s\n' 'Issue #15 deterministic acceptance passed.'
printf '%s\n' 'This runner does not claim a physical Finder/Dock Accessibility acceptance result.'
