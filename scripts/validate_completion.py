#!/usr/bin/env python3
import json
import sys
from pathlib import Path

manifest_path = Path(__file__).resolve().parents[1] / "docs/app-replica/completion-manifest.json"
manifest = json.loads(manifest_path.read_text())
failures = []

for key in ("inventory_complete", "primary_workflow_passed", "installed_artifact_verified"):
    if manifest.get(key) is not True:
        failures.append(key)

verification = manifest.get("independent_verification", {})
if verification.get("required") and not verification.get("passed"):
    failures.append("independent_verification")

for row in manifest.get("rows", []):
    if row.get("in_scope") and (row.get("status") != "passed" or not row.get("exercised")):
        failures.append(row.get("id", "unnamed-row"))

if failures:
    print("INCOMPLETE: " + ", ".join(failures))
    sys.exit(1)

print("COMPLETE")
