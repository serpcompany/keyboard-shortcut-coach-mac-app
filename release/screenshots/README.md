# App Store screenshot evidence

Only screenshots captured from the real Shortcut Coach build belong here. Do not add mockups that imply unsupported behavior.

Required review set:

| ID | Surface | Required state |
| --- | --- | --- |
| `01-coaching-inbox` | Menu-bar popover | SERP mark, durable history, unread state |
| `02-notification-styles` | Main Settings window | Real selectable channel list and previews |
| `03-permissions` | Main Settings window | Real Accessibility permission state |
| `04-diagnostics` | Main Settings window | Real detector and delivery diagnostics |
| `05-about` | Main Settings window | SERP mark, Shortcut Coach name, version |
| `06-live-coaching` | Desktop presentation | A coaching event emitted from a proven physical action |

Static UI captures may be reviewed before the sandbox gate. The live-coaching screenshot must be captured only after the sandboxed physical-pointer gate passes. Store-upload files must match one of App Store Connect's current accepted macOS screenshot dimensions and are finalized by the primary release agent.

Current truthful sandboxed Release-build captures:

- `review/02-notification-styles.png`
- `review/03-permissions.png` — intentionally shows the clean-install `Required` state
- `review/04-diagnostics.png` — intentionally records the unpassed Accessibility gate
- `review/05-about.png`

Run `scripts/generate-app-store-screenshots.sh` to place these real captures without distortion on an opaque 1280×800 canvas under `app-store/`. `asc screenshots validate --device-type APP_DESKTOP` validates that output. Inbox and live-coaching captures remain blocked on the physical Accessibility test and must not be manufactured from synthetic state.
