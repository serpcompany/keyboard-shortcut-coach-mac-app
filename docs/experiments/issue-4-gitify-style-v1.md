# Issue #4 experiment — recoverable coaching inbox

This branch is a self-contained product experiment for comparing a persistent, Gitify-inspired information hierarchy with the parity baseline. It uses original native macOS UI and system symbols; it does not copy Gitify assets, wording, exact layout, or trade dress.

## Owner choices made for the demo

- The app becomes a regular macOS application while running. Its Dock icon and menu-bar extra are both always present.
- Opening Coaching History does not implicitly clear unread state. An item changes only through **Mark Seen**, **Mark Unseen**, **Mark All Seen**, dismissal, or clearing.
- Every detected eligible coaching opportunity is unread when persisted, including opportunities whose toast is suppressed.
- Native notifications and sound default off. The custom toast, history, menu state, Dock badge, and bounded informational bounce default on.
- Dock attention occurs only while inactive, at most once per five minutes, and is cancelled after one second.
- Local retention is the newest 500 events within 30 days.
- **Send Test Coaching Event** exercises presentation without adding usage analytics.
- A native notification outcome of `submitted-to-system` means Notification Center accepted the request. It does not claim a visible banner was observed through Focus or scheduled delivery.

## Deliberate baseline difference

The frozen Keylume reference and the parity baseline are `LSUIElement=true` menu-bar utilities. This experiment intentionally sets `LSUIElement=false` and uses regular activation so the Dock can provide badge and attention surfaces. Therefore the existing complete-reference manifest remains historical baseline evidence and must not be read as differential proof for this branch.

## Demo

```sh
swift test
zsh scripts/package_app.sh release -
open .build/release/KeylumeClone.app
```

Then open **Settings → Notifications**, choose **Send Test Coaching Event**, and compare:

1. contextual toast;
2. green menu-bar icon and exact unread count;
3. recent-event menu-bar inbox;
4. persistent Coaching History;
5. system Dock badge and bounded informational bounce;
6. optional native macOS notification after explicit authorization.

Quit and relaunch the packaged app to confirm the event and unread count return.

## Known verification boundary

Issue #2 still owns Chrome New Tab/New Window and tab-strip event-detection coverage. This branch does not claim those gaps are fixed. Deterministic tests cover persistence, migration, retention, idempotency, suppression reasons, preferences, and Dock attention policy. Human/installed E2E proof is still needed for Notification Center visibility under Focus, login-item launch, multiple Spaces, full-screen apps, VoiceOver navigation, and the #2 detection matrix.
