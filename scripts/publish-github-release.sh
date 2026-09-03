#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --lane full|lite --version X.Y.Z [--artifact PATH] [--notes-file PATH] [--prerelease] [--dry-run]" >&2
}

lane=""
version=""
artifact=""
notes_file=""
dry_run=false
prerelease=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane) lane="${2:-}"; shift 2 ;;
    --version) version="${2:-}"; shift 2 ;;
    --artifact) artifact="${2:-}"; shift 2 ;;
    --notes-file) notes_file="${2:-}"; shift 2 ;;
    --prerelease) prerelease=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    *) usage; exit 2 ;;
  esac
done

if [[ "$lane" != "full" && "$lane" != "lite" ]]; then
  usage
  exit 2
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  usage
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Release worktree must be clean." >&2
  exit 1
fi
if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Release publication must run from main." >&2
  exit 1
fi

git fetch origin main --quiet
release_commit="$(git rev-parse HEAD)"
remote_commit="$(git rev-parse origin/main)"
if [[ "$release_commit" != "$remote_commit" ]]; then
  echo "HEAD and origin/main do not match." >&2
  exit 1
fi

tag="${lane}-v${version}"
if [[ "$lane" == "full" ]]; then
  title="Shortcut Coach ${version}"
  if [[ -z "$artifact" || ! -f "$artifact" ]]; then
    echo "The full lane requires a notarized release artifact." >&2
    exit 1
  fi
else
  title="Shortcut Coach Lite ${version}"
fi

if [[ -n "$artifact" ]]; then
  artifact="$(cd "$(dirname "$artifact")" && pwd)/$(basename "$artifact")"
fi
if [[ -n "$notes_file" ]]; then
  if [[ ! -f "$notes_file" ]]; then
    echo "Notes file does not exist: $notes_file" >&2
    exit 1
  fi
  notes_file="$(cd "$(dirname "$notes_file")" && pwd)/$(basename "$notes_file")"
fi

if git show-ref --tags --verify --quiet "refs/tags/$tag" || \
   [[ -n "$(git ls-remote --tags origin "refs/tags/$tag")" ]]; then
  echo "Tag already exists: $tag" >&2
  exit 1
fi
if gh release view "$tag" >/dev/null 2>&1; then
  echo "GitHub Release already exists: $tag" >&2
  exit 1
fi

echo "Lane: $lane"
echo "Version: $version"
echo "Tag: $tag"
echo "Commit: $release_commit"
echo "Title: $title"
echo "Prerelease: $prerelease"
[[ -n "$artifact" ]] && echo "Artifact: $artifact"
[[ -n "$notes_file" ]] && echo "Notes: $notes_file"

if [[ "$dry_run" == true ]]; then
  echo "Dry run complete; no tag or GitHub Release was created."
  exit 0
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  if [[ -d "$tmp_dir" ]]; then
    find "$tmp_dir" -depth -delete
  fi
}
trap cleanup EXIT

assets=()
if [[ -n "$artifact" ]]; then
  checksum_file="$tmp_dir/SHA256SUMS"
  (cd "$(dirname "$artifact")" && shasum -a 256 "$(basename "$artifact")") > "$checksum_file"
  assets+=("$artifact" "$checksum_file")
fi

git tag -a "$tag" "$release_commit" -m "$title"
git push origin "$tag"

release_args=("$tag" --verify-tag --target "$release_commit" --title "$title")
if [[ "$prerelease" == true ]]; then
  release_args+=(--prerelease)
fi
if [[ -n "$notes_file" ]]; then
  release_args+=(--notes-file "$notes_file")
else
  release_args+=(--generate-notes)
fi
if [[ ${#assets[@]} -gt 0 ]]; then
  release_args+=("${assets[@]}")
fi

gh release create "${release_args[@]}"
gh release view "$tag"
