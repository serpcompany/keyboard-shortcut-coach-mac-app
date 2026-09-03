# Shortcut Coach 1.0.0 — App Store Connect draft

## Record

- Platform: `MAC_OS`
- Bundle ID: `com.serp.shortcutcoach`
- SKU suggestion: `shortcut-coach-macos-1`
- Primary locale: English (U.S.)
- Primary category: Productivity
- Secondary category: Education
- Copyright: `2026 SERP`
- Price: Free

The exact legal seller/copyright name must be confirmed in App Store Connect before submission. Keep **Shortcut Coach** unless App Store Connect rejects it. An existing iOS listing named **Keyboard Shortcut Coach** creates a review/search-confusion risk but is not authorization to rename this app silently.

## URLs

- Marketing: <https://serp.co/>
- Support: <https://serp.co/contact/>
- Privacy policy candidate: <https://serp.co/shortcut-coach/privacy/>

The product-specific privacy-policy candidate is not yet proven live. Publishing that page with the reviewed contents of `docs/privacy.md` is a release blocker.

## Age rating draft

All Apple age-rating content descriptors: **None**. There is no user-generated content, unrestricted web access, messaging, advertising, gambling, violence, sexual content, medical content, alcohol/tobacco/drug content, or loot-box mechanism.

## App Privacy draft

Select **Data Not Collected**. The MVP has no account, analytics, advertising, telemetry, cloud sync, network client, or third-party SDK. Accessibility snapshots and coaching history are processed and stored locally. Re-evaluate these answers if the shipped code changes.

## Review contact

Required maintainer input before submission:

- First and last name
- App Review email
- App Review phone

No demo account is required because the app has no authentication.

## Review notes draft

Shortcut Coach is a native macOS utility. It requires Accessibility permission to identify supported controls beneath physical pointer input and suggest a behaviorally equivalent keyboard shortcut. The pointer event tap is listen-only; the app does not modify clicks or collect typed text, webpage content, URLs, tab titles, filenames, or file paths.

To review:

1. Launch Shortcut Coach. It appears in the Dock and menu bar by default.
2. Open Settings → Permissions, choose Request Permission, and enable Shortcut Coach in System Settings → Privacy & Security → Accessibility.
3. Return to Shortcut Coach and choose Retry Detection. Diagnostics should report “Monitoring supported manual pointer actions.”
4. In Finder, click File → New Finder Window. Shortcut Coach should save and present “Try ⌘N next time.”
5. In Chrome, physically click the New Tab `+` button. Shortcut Coach should save and present “Try ⌘T next time.”
6. Click the SERP arrow in the menu bar to review the Coaching Inbox.
7. Settings → Presentation Channels can preview each presentation channel without requiring a manual action.

No external hardware, purchase, account, or network connection is required.

## Export compliance

The app does not implement or embed non-exempt encryption. `ITSAppUsesNonExemptEncryption` is `false`.
