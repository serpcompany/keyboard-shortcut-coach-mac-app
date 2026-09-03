# Mac App Store sandbox feasibility gate

Mac App Store submission is blocked until the exact sandboxed Release artifact passes the physical-pointer detector checklist below. Unit tests and synthetic notifications are not substitutes for this gate.

## Build requirements

- Bundle ID is exactly `com.serp.shortcutcoach`.
- Version/build are `1.0.0 (1)` or a higher remote-safe build number selected before upload.
- Release signature uses an Apple Distribution certificate and a Mac App Store provisioning profile.
- `com.apple.security.app-sandbox` is `true`.
- Hardened runtime is enabled.
- The app contains no external updater, privileged helper, private framework, or non-system runtime dependency.

## Clean-install test

1. Remove prior test copies of the `com.serp.shortcutcoach` build from LaunchServices.
2. Reset Accessibility permission only for `com.serp.shortcutcoach`.
3. Install and launch the exact sandboxed Release artifact.
4. Complete the feasible visual/UI checks before permission:
   - SERP app icon renders in Finder and in the Dock.
   - SERP template status item is visible and clickable in both light and dark appearance.
   - Clicking the status item opens the branded Coaching Inbox.
   - Main-window navigation reaches History, Presentation Channels, App Presence, Permissions, Diagnostics, and About without clipping.
   - Preview Top-center Shelf and Decision Banner through their real Presentation Channels buttons.
5. Grant Accessibility permission through the system prompt and confirm Diagnostics reports monitoring.
6. Physically exercise these proven release gates:
   - Finder → File → New Finder Window → exactly one durable `⌘N` event.
   - Chrome New Tab `+` → exactly one durable `⌘T` event.
   - One standard red/yellow/green window control → event only after its verified outcome.
   - A disposable regular Finder item dragged to Dock Trash → `⌘Delete` only after verified disappearance.
7. Relaunch and confirm history, unread count, settings, and detector state persist.
8. Verify native banner authorization/appearance and each selected presentation channel.

## Stop condition and fallback

If the sandboxed artifact cannot become Accessibility-trusted, cannot create the listen-only system-wide event tap, or cannot read the required cross-process Accessibility state, do not upload it. Preserve the same product identity and prepare a Developer ID distribution with hardened runtime, notarization, and stapling instead. The Developer ID build must still pass the same physical-action checklist.

## Current evidence and verdict — blocked

On 2026-09-04, the exact universal Release artifact was built with hardened runtime, strict-valid Developer ID signing for local feasibility testing, and only `com.apple.security.app-sandbox = true`. Its identity is `com.serp.shortcutcoach`, version `1.0.0 (1)`.

After `tccutil reset Accessibility com.serp.shortcutcoach`, the app launched normally and its brand/settings UI was operable. Choosing **Request Permission** left the UI at **Required**, opened no macOS prompt or System Settings pane, and logged:

~~~text
activating connection: mach=true ... name=com.apple.universalaccessAuthWarn
failed to do a bootstrap look-up: xpc_error=[159: Unknown error: 159]
~~~

The same clean request from the unsandboxed Developer ID control build connected to `com.apple.universalaccessAuthWarn` without the bootstrap failure. This isolates the failed permission flow to App Sandbox on this machine. Apple documents that `AXIsProcessTrustedWithOptions` should asynchronously inform an untrusted user when `kAXTrustedCheckOptionPrompt` is true; the sandboxed artifact did not reach that behavior.

Because the clean Accessibility permission flow fails, the required Chrome/Finder/window-control physical checks cannot begin. The Mac App Store gate therefore fails before upload. Do not create or upload a Mac App Store build from this branch. Use the documented Developer ID + notarization configuration unless Apple grants an App-Store-acceptable capability or the sandbox behavior is proven fixed in a future macOS/toolchain build.

Feasible UI evidence passed for the complete Settings window/navigation, Finder and Dock icons, dark-appearance menu-bar symbol, clickable Coaching Inbox, and real Top-center Shelf/Decision Banner previews. A real light-appearance menu-bar capture was not taken because that requires changing the maintainer's global macOS appearance setting; the AppKit regression test instead verifies that the actual status-button image is configured as a template. Light-appearance visual acceptance remains an explicit human check.

Primary references:

- <https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions>
- <https://developer.apple.com/documentation/security/app-sandbox>
