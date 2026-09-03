# Developer ID fallback

The sandboxed Mac App Store Release cannot complete the system Accessibility permission flow on the current test machine. This separate release-quality configuration preserves the product's core detector without App Sandbox while retaining hardened runtime and the final `com.serp.shortcutcoach` identity.

~~~sh
xcodegen generate
xcodebuild archive \
  -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach-DeveloperID \
  -configuration DeveloperID \
  -destination 'generic/platform=macOS' \
  -archivePath .artifacts/ShortcutCoach-DeveloperID.xcarchive

xcodebuild -exportArchive \
  -archivePath .artifacts/ShortcutCoach-DeveloperID.xcarchive \
  -exportPath .artifacts/ShortcutCoach-DeveloperID \
  -exportOptionsPlist release/developer-id/ExportOptions.plist
~~~

Verify the exported app has a Developer ID Application authority, a secure timestamp, hardened runtime, and no `com.apple.security.app-sandbox` entitlement. Then ZIP or package the app, submit it to Apple notarization with `asc notarization submit --wait`, and staple the accepted ticket. Upload/notarization is owned by the primary release agent and is intentionally not performed by the implementation branch.
