#!/bin/zsh
set -euo pipefail

LAB_DIR="${0:A:h}"
REPOS_DIR="${LAB_DIR:h:h:h}"
GITIFY_DIR="${KEYLUME_GITIFY_WORKTREE:-${REPOS_DIR}/clone-keylume-ios-app-issue-4}"
HEYCLICKY_DIR="${KEYLUME_HEYCLICKY_WORKTREE:-${REPOS_DIR}/clone-keylume-ios-app-issue-5}"

build_if_missing() {
  local variant_dir="$1"
  local executable="${variant_dir}/.build/release/KeylumeClone.app/Contents/MacOS/KeylumeClone"
  if [[ ! -x "$executable" ]]; then
    print "Building pinned experiment in ${variant_dir}..."
    (cd "$variant_dir" && zsh scripts/package_app.sh release -)
  fi
}

build_if_missing "$GITIFY_DIR"
build_if_missing "$HEYCLICKY_DIR"

export KEYLUME_GITIFY_WORKTREE="$GITIFY_DIR"
export KEYLUME_HEYCLICKY_WORKTREE="$HEYCLICKY_DIR"
exec python3 "${LAB_DIR}/server.py" --open "$@"
