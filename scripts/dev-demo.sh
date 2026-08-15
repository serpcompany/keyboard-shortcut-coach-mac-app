#!/bin/zsh
set -euo pipefail

lab_repo=${0:A:h:h}
repos_dir=${lab_repo:h}
demo_root="$lab_repo/prototypes/preproject-ui-lab/.demo-apps"

baseline_repo=${KEYLUME_BASELINE_WORKTREE:-"$repos_dir/clone-keylume-ios-app"}
gitify_repo=${KEYLUME_GITIFY_WORKTREE:-"$repos_dir/clone-keylume-ios-app-issue-4"}
heyclicky_repo=${KEYLUME_HEYCLICKY_WORKTREE:-"$repos_dir/clone-keylume-ios-app-issue-5"}

variant_names=(baseline gitify heyclicky)
demo_names=("Keylume Baseline Demo" "Keylume Gitify Demo" "Keylume HeyClicky Demo")
source_repos=("$baseline_repo" "$gitify_repo" "$heyclicky_repo")

usage() {
  print 'Keylume pre-project demo runner'
  print ''
  print 'Usage:'
  print '  ./scripts/dev-demo.sh baseline'
  print '  ./scripts/dev-demo.sh gitify'
  print '  ./scripts/dev-demo.sh heyclicky'
  print '  ./scripts/dev-demo.sh xcode <baseline|gitify|heyclicky>'
  print '  ./scripts/dev-demo.sh status'
  print '  ./scripts/dev-demo.sh stop'
  print '  ./scripts/dev-demo.sh clean'
  print ''
  print 'The three generated apps stay inside this throwaway worktree, never /Applications.'
}

variant_index() {
  local requested_variant=$1
  local index
  for index in {1..3}; do
    if [[ "${variant_names[$index]}" == "$requested_variant" ]]; then
      print "$index"
      return 0
    fi
  done
  print -u2 "Unknown variant: $requested_variant"
  usage >&2
  return 2
}

allowed_executables() {
  local index configuration generated_app
  for index in {1..3}; do
    print "$demo_root/${demo_names[$index]}.app/Contents/MacOS/KeylumeClone"
    for configuration in debug release; do
      print "${source_repos[$index]}/.build/$configuration/KeylumeClone.app/Contents/MacOS/KeylumeClone"
    done
    generated_app="${source_repos[$index]}/.build/arm64-apple-macosx/release/KeylumeClone.app/Contents/MacOS/KeylumeClone"
    print "$generated_app"
  done
}

running_demo_processes() {
  local candidate_pid candidate_command allowed_executable
  local candidate_pids
  candidate_pids=$(/usr/bin/pgrep -x KeylumeClone 2>/dev/null || true)
  [[ -n "$candidate_pids" ]] || return 0

  for candidate_pid in ${(f)candidate_pids}; do
    candidate_command=$(/bin/ps -p "$candidate_pid" -o command= 2>/dev/null || true)
    [[ -n "$candidate_command" ]] || continue
    while IFS= read -r allowed_executable; do
      if [[ "$candidate_command" == "$allowed_executable" || "$candidate_command" == "$allowed_executable "* ]]; then
        print "$candidate_pid|$candidate_command"
        break
      fi
    done < <(allowed_executables)
  done
}

stop_demos() {
  local running_line candidate_pid
  local running_lines
  running_lines=$(running_demo_processes)
  if [[ -z "$running_lines" ]]; then
    print 'No Keylume demo is running.'
    return 0
  fi

  while IFS= read -r running_line; do
    candidate_pid=${running_line%%|*}
    /bin/kill -TERM "$candidate_pid" 2>/dev/null || true
    print "Stopped demo PID $candidate_pid"
  done <<< "$running_lines"

  local deadline=$((SECONDS + 5))
  while [[ -n "$(running_demo_processes)" && $SECONDS -lt $deadline ]]; do
    sleep 0.1
  done
  if [[ -n "$(running_demo_processes)" ]]; then
    print -u2 'A demo did not stop cleanly. Quit it from its menu and try again.'
    return 1
  fi
}

show_status() {
  local running_lines
  running_lines=$(running_demo_processes)
  if [[ -z "$running_lines" ]]; then
    print 'Active demo: none'
    return 0
  fi
  print 'Active demo process(es):'
  while IFS= read -r running_line; do
    print "  ${running_line#*|} (PID ${running_line%%|*})"
  done <<< "$running_lines"
}

open_in_xcode() {
  local requested_variant=$1
  local index
  index=$(variant_index "$requested_variant")
  local source_repo=${source_repos[$index]}
  [[ -f "$source_repo/Package.swift" ]] || {
    print -u2 "Missing Swift package: $source_repo/Package.swift"
    return 1
  }
  print "Opening ${demo_names[$index]} source in Xcode"
  /usr/bin/open -a Xcode "$source_repo/Package.swift"
}

run_variant() {
  local requested_variant=$1
  local index
  index=$(variant_index "$requested_variant")
  local source_repo=${source_repos[$index]}
  local demo_name=${demo_names[$index]}
  local source_app="$source_repo/.build/debug/KeylumeClone.app"
  local demo_app="$demo_root/$demo_name.app"

  [[ -f "$source_repo/scripts/package_app.sh" ]] || {
    print -u2 "Missing packaging script: $source_repo/scripts/package_app.sh"
    return 1
  }

  stop_demos
  print "Building $demo_name from $(git -C "$source_repo" branch --show-current)@$(git -C "$source_repo" rev-parse --short HEAD)..."
  zsh "$source_repo/scripts/package_app.sh" debug -

  /bin/mkdir -p "$demo_root"
  if [[ -e "$demo_app" ]]; then
    /bin/rm -rf "$demo_app"
  fi
  /usr/bin/ditto "$source_app" "$demo_app"
  /usr/bin/plutil -replace CFBundleDisplayName -string "$demo_name" "$demo_app/Contents/Info.plist"
  /usr/bin/plutil -replace CFBundleName -string "$demo_name" "$demo_app/Contents/Info.plist"
  /usr/bin/plutil -replace KeylumeDemoVariant -string "$requested_variant" "$demo_app/Contents/Info.plist"
  /usr/bin/codesign --force --deep --options runtime --timestamp=none --sign - "$demo_app"
  /usr/bin/codesign --verify --deep --strict "$demo_app"

  print "Launching: $demo_name"
  print "Bundle: $demo_app"
  /usr/bin/open -n "$demo_app"
  sleep 1
  show_status
}

clean_demo_apps() {
  stop_demos
  [[ "$demo_root" == "$lab_repo/prototypes/preproject-ui-lab/.demo-apps" ]] || {
    print -u2 'Refusing to clean an unexpected directory.'
    return 1
  }
  if [[ -d "$demo_root" ]]; then
    /bin/rm -rf "$demo_root"
    print "Removed generated demo apps from: $demo_root"
  else
    print 'No generated demo apps to remove.'
  fi
  print 'Swift build caches were preserved for faster rebuilds.'
}

command_name=${1:-help}
case "$command_name" in
  baseline|gitify|heyclicky)
    run_variant "$command_name"
    ;;
  xcode)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    open_in_xcode "$2"
    ;;
  status)
    show_status
    ;;
  stop)
    stop_demos
    ;;
  clean)
    clean_demo_apps
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    print -u2 "Unknown command: $command_name"
    usage >&2
    exit 2
    ;;
esac
