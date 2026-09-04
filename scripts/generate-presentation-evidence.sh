#!/bin/bash

set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
derived_data="$repository_root/.derived-presentation-evidence"
artifact_directory="${TMPDIR:-/tmp}/ShortcutCoachPresentationEvidence"
evidence_directory="$repository_root/docs/evidence/presentation-channels"

cd "$repository_root"
xcodegen generate
xcodebuild \
  -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach \
  -configuration Debug \
  -derivedDataPath "$derived_data" \
  test \
  -only-testing:ShortcutCoachTests/PresentationEvidenceTests/testEveryCustomPresentationRendersToReviewablePNG \
  CODE_SIGNING_ALLOWED=NO

mkdir -p "$evidence_directory"
cp "$artifact_directory"/*.png "$evidence_directory"/
shasum -a 256 "$evidence_directory"/*.png
