# Shortcut Coach release lanes

| Lane | Bundle ID | Distribution | Core experience |
| --- | --- | --- | --- |
| Full | `com.serp.shortcutcoach` | Developer ID, Apple notarization, SERP website | Real-time supported click detection, history, and presentation channels |
| App Store Lite | `com.serp.shortcutcoach.lite` | Mac App Store | Searchable shortcut library, active-app guidance, presentation previews, and menu-bar access |

## Full lane

Build and archive with `ShortcutCoach-DeveloperID`. It is unsandboxed, hardened, signed with Developer ID, notarized, and stapled before public distribution. Accessibility is requested only because real-time cross-app coaching is the product's core function.

## App Store Lite lane

Build and archive the separate `ShortcutCoachLite` target with `ShortcutCoach-Lite` using the `AppStoreLite` configuration. It excludes the Detection source directory, is sandboxed, and is compiled with `APP_STORE_LITE`. Lite does not contain or start the detector, show Accessibility controls, or claim to observe clicks. Its **Full Version** settings destination opens `https://serp.co/shortcut-coach/` in the browser and does not initiate a download.

Lite must stay independently useful and its CTA must remain secondary to the shortcut library and previews. Apple review risks and current rules are tracked in [`app-store-lite/README.md`](app-store-lite/README.md).

## Shared release rules

- Keep the bundle identities and update channels separate.
- Use the same approved SERP visual system.
- Never present Lite screenshots as evidence of full detector functionality.
- Validate and smoke-test the exact archive for each lane.
