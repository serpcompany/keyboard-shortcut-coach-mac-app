# ADR 0002: Separate full and App Store Lite release lanes

## Status

Accepted on 2026-09-04.

## Decision

Shortcut Coach ships from one codebase through two distinct macOS products. The full lane uses Developer ID signing and Apple notarization under `com.serp.shortcutcoach` so Accessibility-powered manual-action coaching can work. The App Store Lite lane is sandboxed under `com.serp.shortcutcoach.lite`; it provides a shortcut library, active-app guidance, presentation previews, and a disclosed website-only link to learn about the full product, but it never starts or requests the manual-action detector.

## Rationale

The exact sandboxed full build cannot complete Accessibility authorization on the current release environment, while Apple requires Mac App Store apps to be sandboxed. A deliberately useful Lite product is more honest and reviewable than uploading a broken full build or making the Store app primarily an installer.

## Consequences

The two products have separate bundle identities, signing/update channels, metadata, and release verification. Lite must remain useful on its own, must not download or install the full app, and must not imply that a website purchase unlocks functionality inside the Store app. Apple DTS may later identify an approved sandbox architecture; that evidence can supersede this decision.
