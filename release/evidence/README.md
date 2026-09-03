# Release UI evidence index

All images are privacy-cropped from the exact sandboxed Release build `com.serp.shortcutcoach` version `1.0.0 (1)`. Presentation preview images were opened through the real Settings preview buttons; they are synthetic coaching events by product design and are not claimed as manual-action detector evidence.

| Evidence | Result |
| --- | --- |
| [`menu-bar-dark.png`](menu-bar-dark.png) | Real SERP template symbol visible in the dark macOS menu bar |
| [`dock-app-icon.png`](dock-app-icon.png) | Real generated app icon visible in the auto-hidden Dock |
| [`finder-app-icon.png`](finder-app-icon.png) | Real built Release app icon visible in Finder |
| [`preview-top-center-shelf.png`](preview-top-center-shelf.png) | Real Top-center Shelf preview |
| [`preview-decision-banner.png`](preview-decision-banner.png) | Real Decision Banner preview |
| [`../screenshots/review/01-coaching-inbox.png`](../screenshots/review/01-coaching-inbox.png) | Real status-item press opens the branded Coaching Inbox |
| [`../screenshots/review/02-presentation-channels.png`](../screenshots/review/02-presentation-channels.png) | Complete Presentation Channels window |
| [`../screenshots/review/03-permissions.png`](../screenshots/review/03-permissions.png) | Complete clean-install permission state |
| [`../screenshots/review/04-diagnostics.png`](../screenshots/review/04-diagnostics.png) | Complete detector diagnostics state |
| [`../screenshots/review/05-about.png`](../screenshots/review/05-about.png) | Complete SERP About view |

Not captured:

- Light-appearance menu-bar rendering requires changing the maintainer's global macOS Appearance setting. The actual `NSStatusBarButton` contract is covered by a test that verifies its loaded SERP image is a template; light visual acceptance remains manual.
- No live-coaching image is included because the sandboxed Accessibility gate fails before physical detector testing. It must not be substituted with a Settings preview.
