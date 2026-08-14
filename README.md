# Keylume Clone

An independent clean-room macOS implementation of the observable Keylume 1.1.2 workflows. It is a menu-bar utility that reads shortcuts exposed through the macOS Accessibility API, shows a searchable shortcut overlay, detects mouse use of menu commands, offers coaching nudges, and records local usage analytics.

The candidate intentionally uses its own bundle identifier (`co.serp.KeylumeClone`), URL scheme (`keylumeclone:`), local license format, and update-feed boundary. It does not contain Keylume code, signing identity, private services, or secrets.

## Build and package

```sh
swift test
zsh scripts/package_app.sh
open .build/release/KeylumeClone.app
```

For a stable macOS Accessibility grant across rebuilds, pass a local signing identity as the second argument, for example `zsh scripts/package_app.sh release "Apple Development: Your Name (TEAMID)"`. Ad-hoc signing is the portable fallback.

On first launch, grant Accessibility permission when prompted. macOS keys that permission to the signed candidate artifact, so rebuilding may require removing and re-adding the app in System Settings.

## Local data

- Preferences and trial state: `co.serp.KeylumeClone` user defaults
- Usage analytics: `~/Library/Application Support/KeylumeClone/usage.json`
- Network: none by default; update checks use only `KEYLUME_CLONE_UPDATE_FEED` when explicitly configured

The parity evidence and current completion gate live in `docs/app-replica/`.

The packaging script produces a universal `arm64`/`x86_64` executable, matching the reference's supported Mac architectures.

## Contextual presentation V1 showcase

This comparison branch adds six original local coaching presentations. Build the exact app artifact, then launch any mode directly without relying on browser/menu detection:

```sh
zsh scripts/package_app.sh
open -n .build/release/KeylumeClone.app --args --showcase=all
```

Individual mode values are `topCenterPresence`, `compactExpandedShelf`, `cursorHalo`, `statusFeedback`, `pointerCard`, and `decisionBanner`. The same previews are available from the menu-bar **Presentation Showcase** submenu and from Settings → Coaching. Preview events traverse the production presentation coordinator but are labeled local previews and do not add usage analytics.
