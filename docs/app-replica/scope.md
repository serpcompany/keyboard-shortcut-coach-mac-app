# Keylume clean-room replica scope

## Authorization and finish line

The user asked on 2026-08-15 for a "100% clone" and a "working copy exactly, fully functional" of the locally installed Keylume.app. This is `complete-reference` scope: every reachable surface, meaningful state, interaction, side effect, permission path, and persistence boundary of the frozen reference is in scope.

Goal 1 is functional and visual parity with the reference. Goal 2 is a plan for a new settings or management UI, and must not begin until Goal 1 is proven. No Goal 2 UI may be implemented under the current gate.

## Clean-room boundary

- Behavioral oracle: `/Applications/Keylume.app`
- Reference identity: `app.keylume.Keylume`, version `1.1.2`, build `7`
- Candidate working name: `KeylumeClone`
- Candidate bundle identifier: `co.serp.KeylumeClone`
- Intended use: an independently maintained local macOS application reproducing observable behavior through public macOS APIs.
- The reference executable and resources remain in place and are not copied into, linked by, or shipped with the candidate.
- Extracted strings, symbols, metadata, screenshots, accessibility trees, and runtime observations are evidence only.
- The candidate will not bypass, modify, or impersonate the reference app's trial or license state and will not call its private license service.
- Branding and proprietary assets are not assumed licensed. The candidate uses a distinct identity and independently created or system assets unless the user later supplies proof of rights.
- No behavior is excluded. Blocked or unknown states remain `unresolved` until exercised or explicitly removed by the user.

## Frozen oracle

| Property | Value |
|---|---|
| Reference path | `/Applications/Keylume.app` |
| Bundle ID | `app.keylume.Keylume` |
| Version/build | `1.1.2 (7)` |
| Executable SHA-256 | `9a6275d1353e4e2d2b54da99a0e32b4b7acd832a1e2b59a5ef734d678e94f0af` |
| Code-directory hash | `55314f79ff1b14e6315274c332ea2512d815a834` |
| Architecture | Universal Mach-O: `arm64`, `x86_64` |
| Signature | Notarized Developer ID, team `STH3G36J82` |
| Minimum macOS | 14.0 |
| Frozen host | Mac15,9; Apple M3 Max; macOS 26.5.2 (25F84) |
| Display | Built-in 3456×2234 Retina; dark appearance |
| Locale/languages | `en_US`; `en-US`, `ja-US` |
| Distribution behavior | Sparkle 2.9.0 appcast at `https://keylume.app/appcast.xml` |
| Reference UI model | `LSUIElement=true`; SwiftUI `MenuBarExtra`, floating panels and toast windows; no ordinary Dock window |
| Declared URL scheme | `keylume://` |

## Private and dynamic data

Reference trial/license secrets and machine identifiers are stored in Keychain-backed items. They will not be read, copied, logged, or used as candidate fixtures. Usage analytics records may contain local app-usage history; evidence will use controlled test actions and mask unrelated private activity.

## Known reference hazards

Two 2026-08-15 crash reports correspond to a reference copy launched from `/Volumes/Keylume` and then losing its mounted executable. Those crashes are not candidate requirements. All oracle work uses the stable `/Applications/Keylume.app` artifact whose hash is recorded above.

## Primary acceptance unit

With Accessibility permission granted and a shortcut-bearing app active:

1. Launch the packaged candidate as a menu-bar-only app.
2. Hold the right Command key for the reference hold duration and display the active app's live menu shortcuts.
3. Search, inspect, and execute a shortcut through the overlay, including empty and cancellation states.
4. Click a shortcut-bearing menu item with the mouse and receive a matching coaching nudge.
5. Use the equivalent keyboard shortcut and record the keyboard-vs-mouse outcome.
6. Quit and relaunch; settings, dismissed shortcuts, launch-at-login choice, and analytics persist.
7. Exercise missing Accessibility permission, event-tap failure, and no-shortcut states.

Passing this unit permits broader reconstruction but does not complete the literal `complete-reference` request.
