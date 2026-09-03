# Shortcut Coach

Shortcut Coach is a native macOS app that notices supported commands performed with the mouse and teaches the corresponding keyboard shortcut.

This repository is the canonical Shortcut Coach codebase and starting point for product iteration.

## Current MVP

- Detects macOS menu-item clicks, a conservative set of Chrome controls, standard window controls, and verified Finder-to-Trash drags after Accessibility permission is granted.
- Records every coaching event in durable local history.
- Shows an always-available menu-bar coaching inbox with unread state.
- Provides ten selectable notification channels and per-channel previews.
- Includes a full settings window for history, notification styles, app presence, permissions, and diagnostics.
- Appears in the Dock and Cmd-Tab by default; one setting hides both while retaining the menu-bar item.
- Uses one delivery path for both detected and synthetic test events.

The proven end-to-end paths are Finder → File → New Finder Window → ⌘N and Chrome's New Tab button → ⌘T. Chrome Close/Settings, window controls, and Finder-to-Trash rules are implemented and deterministic-test verified, but still require fresh human physical-pointer acceptance from the signed integration build. Broad application coverage and visual acceptance of every channel combination remain future work.

See:

- [Feature inventory](docs/product/feature-inventory.md)
- [Architecture](docs/architecture.md)
- [Verification status](docs/verification.md)
- [Privacy](docs/privacy.md)
- [Development guide](docs/development.md)
- [Roadmap](docs/roadmap.md)

## Develop

Requirements:

- macOS 14 or newer
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

~~~sh
xcodegen generate
open ShortcutCoach.xcodeproj
~~~

Choose the **ShortcutCoach** scheme and press Run. Use the stable generated Debug bundle; do not mutate or ad-hoc re-sign it after macOS grants Accessibility permission.

## Verify

~~~sh
xcodegen generate
xcodebuild \
  -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach \
  -configuration Debug \
  -derivedDataPath .derived \
  test
~~~

The working product name is **Shortcut Coach** and the bundle identifier is **co.serp.shortcutcoach**.
