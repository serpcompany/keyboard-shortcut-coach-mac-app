# Shortcut Coach

A fresh macOS foundation for teaching keyboard shortcuts after users perform actions manually.

The earlier clone and UI experiments are preserved as pre-project evidence on branch `archive/pre-project-evidence-2026-08-16` and tag `milestone/pre-project-evidence-2026-08-16`. They are not implementation dependencies.

## Develop

```sh
xcodegen generate
open ShortcutCoach.xcodeproj
```

Choose the **ShortcutCoach** scheme and press Run. Running through Xcode keeps one stable Debug bundle and signing identity so macOS Accessibility permission is not invalidated by post-build mutation or ad-hoc re-signing.

## Verify

```sh
xcodebuild -project ShortcutCoach.xcodeproj -scheme ShortcutCoach -configuration Debug -derivedDataPath .derived test
```

