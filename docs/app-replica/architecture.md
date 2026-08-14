# Keylume Clone architecture

The candidate is a menu-bar-only macOS 14+ SwiftUI application with AppKit windows where exact panel behavior matters. It uses only public macOS APIs and keeps the reference app as a behavioral oracle, never as a runtime dependency.

## Runtime flow

1. `KeylumeCloneApp` creates the status item and starts the shared `AppModel`.
2. `AccessibilityManager` gates protected behavior. `GlobalEventMonitor` installs a listen-only `CGEventTap` only after permission is granted.
3. `MenuReader` walks the frontmost application's Accessibility menu tree into `AppShortcut` values. Those values are the single model used by the overlay, keyboard matching, mouse-menu matching, execution, coaching, and analytics.
4. `WindowPresenter` owns the onboarding, settings, analytics, floating overlay, and status-level coaching toast windows.
5. `UsageStore` persists local JSON usage records. `AppPreferences` persists user choices and operates `SMAppService.mainApp`; `LicenseManager` implements a deliberately independent local candidate entitlement boundary.

## Boundaries

- Reference identity, proprietary artwork, Keychain items, licensing service, and Sparkle signing material are not copied.
- The candidate bundle ID is `co.serp.KeylumeClone`; its URL scheme is `keylumeclone:`.
- Update checking has an explicit candidate feed boundary through `KEYLUME_CLONE_UPDATE_FEED`. With no feed configured it reports the installed version as current.
- All captured usage and preference data stays local.

## Verification seams

- Pure value behavior is covered by Swift Testing: modifier decoding, analytics, JSON persistence, trial and candidate licensing, update-feed fallback, quiet hours, dismissed shortcuts, rate limiting, and preference/exclusion persistence.
- Installed-app checks exercise Accessibility trees, live Finder menu discovery, overlay search/execution, raw mouse menu selection, coaching toast presentation, URL routes, analytics persistence, launch-item registration/removal, signing, and universal packaging.
