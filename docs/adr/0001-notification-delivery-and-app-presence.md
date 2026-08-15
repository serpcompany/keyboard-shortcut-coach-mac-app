# ADR 0001: One notification delivery module and supported app presence

## Status

Accepted on 2026-08-16.

## Decision

All synthetic and detected coaching events enter the same `NotificationDeliveryService`. It first records durable inbox history, then fans out to selected presentation-channel adapters and returns a per-channel report.

The menu-bar item is always available. The app uses regular activation policy by default, so it appears in both the Dock and Cmd-Tab. A single setting switches to accessory activation policy and hides it from both surfaces.

## Rationale

A single delivery seam keeps previews and detected events on the same presentation path while still requiring separate proof that the detector emits a real event.

Supported macOS activation policies couple normal Dock presence with app-switcher presence. The product does not depend on unsupported UI tricks to separate them.

## Release gate

A build is not considered working until a normally signed app, with valid Accessibility permission, observes a manual action in another app and produces a durable event plus the selected user-visible presentations.
