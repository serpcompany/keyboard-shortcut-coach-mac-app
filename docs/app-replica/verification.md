# Verification report — 2026-08-15

## Proven installed workflow

The signed app at `/Applications/Keylume Clone.app` was tested as a fresh installed process, not from `.build`:

- Universal `arm64` and `x86_64` executable; strict deep code-sign verification passes.
- `LSUIElement` launch produces a menu-bar utility with no Dock app window.
- Four-page onboarding completes and observes the existing Accessibility grant; the packaged onboarding window is 520×452 points.
- Holding right Command for 1.7 seconds while Finder is active presents the persistent 660×532 overlay. The final fixture exposed 119 live shortcuts.
- Searching `New Tab` reduced the tree to `File, New Tab, ⌘, T`; first Escape cleared the query and second Escape closed the overlay.
- Selecting the overlay row executed Finder's command, closed the overlay, and recorded keyboard usage.
- Clicking Finder File → New Tab with the mouse recorded mouse usage and displayed the 380×62 status-level coaching toast.
- Analytics showed the controlled New Tab keyboard/mouse totals and retained them across a full quit/relaunch.
- Candidate license activation and deactivation, update fallback, automatic-update persistence, launch-at-login registration/removal, settings and analytics deep links, and clean quit were exercised.
- Ten deterministic Swift tests pass.

## Reference comparison

Paired reference/candidate screenshots and Accessibility captures live under `evidence/1.1.2`. The same live Finder fixture was previously compared in a single state with the same 117-row count and ordering; the count is expected to change when system menus and Services change.

## Completion boundary

The observable Goal 1 workflow is complete within the clean-room boundaries in `scope.md`. A separately identified signed probe exercised the denied-Accessibility path without stripping the installed app's grant; the final installed identity was then reconfirmed as granted. Both event-tap disable notification routes are covered by the production recovery callback and deterministic test. `SMAppService` registration/removal succeeded, and the reference and candidate both report version 1.1.2 current.

The candidate intentionally substitutes its own local entitlement and update-feed identities for the reference's private credentials, services, and signing material. That is a declared identity boundary, not an unimplemented product workflow.
