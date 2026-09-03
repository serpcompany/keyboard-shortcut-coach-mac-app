# Apple DTS request draft

## Subject

Supported Mac App Store architecture for a sandboxed Accessibility client that provides shortcut coaching

## Problem

We are developing a native macOS utility that passively observes physical pointer events and uses public `AXUIElement` APIs to identify a bounded set of controls in other apps. It then suggests the equivalent keyboard shortcut. The app does not modify input or collect typed text, URLs, tab titles, filenames, or file paths.

The hardened, unsandboxed Developer ID build can call `AXIsProcessTrustedWithOptions`, receive Accessibility authorization, create a listen-only `CGEventTap`, and query the supported cross-process Accessibility elements. The otherwise equivalent sandboxed build cannot complete the Accessibility prompt flow.

## Reproduction

1. Build the macOS app with `com.apple.security.app-sandbox = true`.
2. Run `tccutil reset Accessibility com.serp.shortcutcoach`.
3. Launch the signed app and call `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt = true`.
4. No prompt or System Settings entry appears and the call remains false.
5. Unified logging reports a failed bootstrap lookup for `com.apple.universalaccessAuthWarn`.
6. Repeat with the same code, team, and bundle identity without App Sandbox; the authorization service connection succeeds.

Observed log excerpt:

~~~text
activating connection: mach=true ... name=com.apple.universalaccessAuthWarn
failed to do a bootstrap look-up: xpc_error=[159: Unknown error: 159]
~~~

## Environment

- macOS 26
- Xcode 26 / macOS 26 SDK
- SwiftUI/AppKit application targeting macOS 14+
- Public APIs: `AXIsProcessTrustedWithOptions`, `AXUIElementCopyElementAtPosition`, `AXUIElementCopyAttributeValue`, and listen-only `CGEventTapCreate`
- Sandboxed test entitlement: only `com.apple.security.app-sandbox = true`

## Questions

1. Is a Mac App Store sandboxed application allowed to become a trusted Accessibility client and query bounded cross-process `AXUIElement` state for this user-facing coaching purpose?
2. If yes, what supported entitlement, permission sequence, signing profile, or architecture is required on current macOS releases?
3. Should the listen-only event tap request Input Monitoring separately with `CGRequestListenEventAccess`, while cross-process AX access continues to use Accessibility authorization?
4. If this product cannot be implemented within App Sandbox, is Developer ID distribution the approved route?

## Expected outcome

We need a specific supported architecture for a Mac App Store build, or confirmation that the full product must use Developer ID distribution. A focused sample project and full logs can be supplied in reply to the acknowledgement email.
