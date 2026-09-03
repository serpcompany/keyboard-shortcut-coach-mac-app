# Changelog

## Unreleased

- Moved to the fresh `com.serpcompany.shortcutcoach` identity to clear corrupted macOS status-item state.
- Migrated existing notification-channel and Dock preferences from the previous bundle identity.
- Replaced the hidden SwiftUI menu extra with a compact native Coaching Inbox status item.
- Serialized Accessibility hit-testing on the main thread to prevent in-process AppKit crashes.

## 0.1.0 — MVP baseline

- Established the Shortcut Coach product foundation.
- Added one durable coaching-event delivery path.
- Added ten selectable notification channels.
- Added menu-bar inbox, unread history, settings, permissions, and diagnostics.
- Added supported Dock and Cmd-Tab presence control.
- Added stable Xcode project generation and Developer ID local signing.
- Proved a real Finder menu-item action through notification and relaunch persistence.
