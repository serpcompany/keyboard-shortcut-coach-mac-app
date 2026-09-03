# Mac App Store Lite lane

Shortcut Coach Lite is the sandbox-compatible Store product, not a disabled build of the full app.

## User value

- Search and filter a built-in shortcut library.
- Follow the most recently active supported app without inspecting its controls.
- Use the menu-bar utility and presentation-channel previews.
- Learn about the full real-time coaching product from a disclosed website link.

## Review boundary

Lite does not compile the `Detection` module, request Accessibility, inspect controls in other apps, download software, install a helper, or update outside the Mac App Store. The website CTA must not dominate the product. If the landing page sells the full app, storefront-specific external-purchase rules require a fresh review before submission.

Relevant App Review Guidelines: 2.4.5 (Mac App Store packaging/sandbox/update rules), 3.1.1 (digital features and external purchase links), and 4.2 (minimum functionality and apps that primarily advertise or require another app).

## Build

~~~sh
xcodegen generate
xcodebuild \
  -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach-Lite \
  -configuration AppStoreLite \
  -destination 'generic/platform=macOS' \
  build
~~~

Archive and export the upload package with the committed `ExportOptions.plist`; it maps `com.serp.shortcutcoach.lite` to the Mac App Store profile explicitly.

Before submission, verify the GitHub Pages landing, privacy, and support URLs are live and accurate. The Lite CTA opens the landing page and does not auto-download software.

## Apple resources

- Bundle ID resource: `SKAFR2UAA3`
- Mac App Store profile: `BL7TK2JCNN` (`Shortcut Coach Lite Mac App Store`)
- Profile expiration: 2026-10-24

The canonical Lite metadata validates under `metadata-lite/`. The product and privacy landing pages are not yet verified live, so App Store record creation and submission remain blocked.
