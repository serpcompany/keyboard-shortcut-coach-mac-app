# Decision: retire the clone experiments as pre-project evidence

- **Date:** 2026-08-16
- **Status:** accepted by owner
- **Scope:** baseline clone, Gitify-style experiment, HeyClicky-style experiment,
  OpenClicky research track, QA matrix, and comparison lab

## Decision

Stop treating the prototype branches as candidate production foundations.
Preserve their issues, commits, galleries, and findings, then implement a fresh
macOS product centered on a configurable notification-delivery module.

Use supported macOS behavior: the default regular activation policy exposes the
app in both the Dock and Command-Tab. A single setting may switch to accessory
mode, which hides both while leaving the menu-bar surface available.

## Why

The experiments answered presentation questions but did not close the installed
manual-action detection gate. Combining them directly would preserve accidental
coupling and would make synthetic demonstrations look like end-to-end proof.

## Consequences

- Existing experiment branches stay available for evidence and visual reference.
- New production code must not import prototype presentation coordinators or
  stores wholesale.
- Notification selection, persistence, presentation, and system adapters receive
  explicit seams and independent verification.
- The first release gate requires a real, permission-valid manual action to flow
  through detection, policy, delivery, inbox history, and visible presentation.
