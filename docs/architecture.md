# Architecture

## Data flow

~~~text
ManualActionDetector
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

Synthetic previews and real detector events share NotificationDeliveryService. A preview can prove a presentation adapter, but only a physical action can prove the detector boundary.

## Module ownership

| Module | Owns | Does not own |
| --- | --- | --- |
| Domain | Coaching event, channels, shortcut formatting, delivery report | UI, storage, macOS APIs |
| Detection | Accessibility trust and manual menu-item observation | Presentation or history |
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

