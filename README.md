# Shortcut Coach

Shortcut Coach is a native macOS app that notices supported commands performed with the mouse and teaches the corresponding keyboard shortcut.

This repository is the canonical Shortcut Coach codebase and starting point for product iteration.

## Current MVP

- Detects macOS menu-item clicks, a conservative set of Chrome controls, standard window controls, and verified Finder-to-Trash drags after Accessibility and Input Monitoring permissions are granted.
- Records every coaching event in durable local history.
- Shows an always-available menu-bar coaching inbox with unread state.
- Provides ten selectable presentation channels and per-channel previews.
- Includes a full settings window for history, presentation channels, app presence, permissions, and diagnostics.
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
- [Release lanes](release/release-lanes.md)

## Develop

Requirements:

- macOS 14 or newer
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

~~~sh
xcodegen generate
open ShortcutCoach.xcodeproj
~~~

Choose the **ShortcutCoach** scheme and press Run. Use the stable generated Debug bundle; do not mutate or ad-hoc re-sign it after macOS grants Accessibility and Input Monitoring permissions.

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

The product name is **Shortcut Coach** and the production bundle identifier is **com.serp.shortcutcoach**.

## Release lanes

The full app ships through Developer ID signing and Apple notarization because its Accessibility-powered detector does not pass the current App Sandbox gate. `ShortcutCoach-DeveloperID` builds that product as `com.serp.shortcutcoach`.

`ShortcutCoach-Lite` builds a separate sandboxed Mac App Store product as `com.serp.shortcutcoach.lite`. Lite provides a standalone shortcut library and previews, never requests Accessibility, and can open the SERP product website from its clearly labeled Full Version settings destination. See [the release-lane decision](docs/adr/0002-full-and-app-store-lite-release-lanes.md).
