# Architecture

## Data flow

~~~text
PointerEventMonitor (listen-only down/up/drag)
        |
        v
AccessibilitySnapshotter (bounded AX context)
        |
        v
ChromeActionAdapter + SystemChromeRuntimeStateReader + ActionCorrelator
        |
        +--> StandardWindowControlMonitor (retained-window postconditions)
        |
        +--> FinderTrashMonitor (Finder-to-Dock drag postcondition)
        |
        v
  CoachingEvent
        |
        v
NotificationDeliveryService
        |
        +--> InboxStore --> JSON persistence --> menu inbox/history/unread
        |
        +--> selected ChannelDelivering adapters
             native banner / panels / Dock / sound
~~~

Synthetic previews and real detector events share NotificationDeliveryService. A preview can prove a presentation adapter, but only human-observed pointer input can prove the detector boundary. Software can post Core Graphics events, so the app does not claim cryptographic hardware provenance.

`AccessibilitySnapshotter` is app-agnostic: it records only the bounded hit element and ancestor chain. Chrome application-tree reads live behind `ChromeRuntimeStateReading`; the system adapter resolves tab state, native menu-command metadata, and an immediately sanitized destination class. `ChromeActionAdapter` and `ActionCorrelator` own all Chrome semantic matching and postconditions.

## Module ownership

| Module | Owns | Does not own |
| --- | --- | --- |
| Domain | Coaching event, channels, shortcut formatting, delivery report | UI, storage, macOS APIs |
| Detection | Accessibility trust, passive pointer observation, AX snapshots, app rules, and verified postconditions | Presentation or history |
| Delivery | Durable-first fan-out and per-channel outcomes | Event detection |
| Infrastructure | Preferences, JSON history, activation policy | Presentation design |
| Views | Menu inbox and settings surfaces | Detector or persistence implementation |
| App | Composition and lifecycle | Domain rules |

## State and persistence

- AppModel, preferences, and inbox are main-actor observable state.
- Preferences use UserDefaults.
- Coaching history is stored atomically at:
  ~/Library/Application Support/ShortcutCoach/coaching-events.json
- There is no account, sync service, analytics SDK, or external runtime dependency.

## App presence

macOS supported activation policies couple ordinary Dock presence with Cmd-Tab presence:

- Regular: Dock and Cmd-Tab visible.
- Accessory: both hidden.

The menu-bar item remains present in both modes. See [ADR 0001](adr/0001-notification-delivery-and-app-presence.md).

## Distribution boundary

The full and App Store Lite products share domain, presentation, and SERP-brand modules. Only the full target compiles the Detection module. Lite adds a local shortcut catalog and a no-op detector boundary solely to satisfy shared composition, while excluding permission/detector surfaces through its compile-time release-lane setting. See [ADR 0002](adr/0002-full-and-app-store-lite-release-lanes.md).
