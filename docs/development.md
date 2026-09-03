# Development guide

## Canonical project

- Project generator: project.yml
- Generated Xcode project: ShortcutCoach.xcodeproj
- Shared scheme: ShortcutCoach
- Minimum platform: macOS 14
- Bundle identifier: com.serpcompany.shortcutcoach

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

## Accessibility identity

macOS associates Accessibility approval with the app's signed code requirement. To keep local approval stable:

- Run the Xcode-built bundle directly.
- Keep the bundle identifier and signing team stable.
- Do not edit the built bundle.
- Do not ad-hoc re-sign it.
- Rebuild before granting permission, not afterward.

If System Settings says the app is enabled but Diagnostics still says permission is required, reset only this bundle's stale row:

~~~sh
tccutil reset Accessibility com.serpcompany.shortcutcoach
~~~

Then relaunch the exact app, request permission, and enable the newly registered row.

## Runtime acceptance

A valid detector test requires a physical mouse click. Accessibility automation that invokes a menu item's Press action proves the command works, but intentionally does not produce a mouse event for the detector.
