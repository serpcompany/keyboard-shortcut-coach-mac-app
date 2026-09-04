# Development guide

## Canonical project

- Project generator: project.yml
- Generated Xcode project: ShortcutCoach.xcodeproj
- Schemes: ShortcutCoach (tests), ShortcutCoach-DeveloperID (full), ShortcutCoach-Lite (App Store Lite)
- Minimum platform: macOS 14
- Bundle identifier: com.serp.shortcutcoach
- Lite bundle identifier: com.serp.shortcutcoach.lite

## Generate and open

~~~sh
xcodegen generate
open ShortcutCoach.xcodeproj
~~~

The generated project is committed. After changing project.yml, regenerate it and commit both the specification and generated project.

## Test

~~~sh
xcodebuild \
  -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach \
  -configuration Debug \
  -derivedDataPath .derived \
  test
~~~

CI disables signing. Local runtime verification uses the configured Developer ID identity.

## Detector permission identity

macOS associates Accessibility and Input Monitoring approvals with the app's signed code requirement. To keep local approval stable:

- Run the Xcode-built bundle directly.
- Keep the bundle identifier and signing team stable.
- Do not edit the built bundle.
- Do not ad-hoc re-sign it.
- Rebuild before granting permission, not afterward.

If System Settings says the app is enabled but Diagnostics still says permission is required, reset only this bundle's stale rows:

~~~sh
tccutil reset Accessibility com.serp.shortcutcoach
tccutil reset ListenEvent com.serp.shortcutcoach
~~~

Then relaunch the exact app, request both permissions, and enable the newly registered rows. Diagnostics reports Monitoring only when both public permission checks succeed and the listen-only event tap starts.

## Runtime acceptance

A valid detector test requires a physical mouse click. Accessibility automation that invokes a menu item's Press action proves the command works, but intentionally does not produce a mouse event for the detector.
