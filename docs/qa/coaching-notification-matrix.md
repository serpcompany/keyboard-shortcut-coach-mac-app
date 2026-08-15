# Coaching-notification QA matrix

Issue: [#2](https://github.com/serpcompany/keylume-mac-hotkey-app-clone/issues/2)  
Purpose: living inventory for reliable automated testing of pointer-driven shortcut coaching.  
Last updated: 2026-08-15

## Definition and evidence boundary

Here, **notification** means the in-product coaching toast, not a macOS Notification Center notification.

The user supplied a Notion `Hotkeys` export. Its normalized shortcut rows seed this backlog; the raw archive and private Notion metadata remain untracked. Live application menus are authoritative because exported mappings can be stale or app-specific.

The first delegated pass safely opened Chrome's live File menu and confirmed `New Tab`, `New Window`, and `Reopen Closed Tab` are exposed. It could not attribute a toast while the reference and candidate were simultaneously active, so no controlled Chrome action is reported as executed. This is an automation-harness gap, not evidence that either app passed or failed.

## Required test reset

Before every controlled trial:

1. record reference/candidate bundle, version, hash, and which one process is active;
2. run exactly one coaching app and restore the original process state afterward;
3. use a fresh blank Chrome window and avoid unrelated user tabs;
4. verify Accessibility is already granted without changing TCC settings;
5. verify coaching is enabled, Chrome is not excluded, and quiet hours are inactive;
6. isolate or record dismissed shortcuts, minimum interval, hourly cap, analytics, and persisted usage;
7. wait for the prior toast/cooldown to clear or use a deterministic test clock/store;
8. capture the pointer event, resolved menu/action, shortcut match, policy decision, and toast lifecycle.

Run each P0 action ten times per app after reset. A single observation is supporting evidence, not a reliability result.

## Current findings

| ID | Priority | Case | Current evidence | Classification | Required next proof |
| --- | --- | --- | --- | --- | --- |
| `chrome-menu-new-tab` | P0 | Pointer-click File → New Tab (`⌘T`) | User reports no toast; live menu entry confirmed | `blocked` | Isolated reference and candidate 10-trial runs |
| `chrome-menu-new-window` | P0 | Pointer-click File → New Window (`⌘N`) | User reports toast appears; live menu entry confirmed | `blocked` | Matching control under identical reset state |
| `chrome-tab-strip-next` | P0 | Pointer-click immediately adjacent tab | User expects `⌃Tab`; menu equivalence not yet proven | `product-enhancement` | Reference comparison and deterministic tab-transition mapping |
| `finder-menu-new-tab-baseline` | P0 | Finder File → New Tab | Existing Goal 1 evidence records candidate mouse usage and toast | `pass` | Convert the installed workflow into a repeatable harness |
| `policy-cooldown-same-action` | P0 | Repeat same eligible click | Existing unit policy coverage; no installed reliability loop | `blocked` | Test clock plus installed event/toast assertion |
| `policy-cooldown-different-action` | P0 | New Tab then New Window | Plausible cause of “sometimes”; not isolated | `blocked` | Determine whether cooldown is global or per shortcut |
| `toast-attribution-single-process` | P0 | Identify which coaching app emitted toast | First pass found simultaneous processes ambiguous | `blocked` | Harness that runs exactly one reference/candidate process |

## P0 automation backlog

1. **Single-process installed E2E harness.** Record initial process state, run one coaching app, execute one Chrome pointer action, assert one attributable toast, and restore state.
2. **Chrome New Tab differential loop.** Ten reference and ten candidate trials; assert shortcut resolution, policy verdict, and toast content `⌘T`.
3. **Chrome New Window control loop.** Same reset and timing as New Tab; compare event/matching/policy/presentation stages.
4. **Policy suppression trace.** At the real call site, return a structured reason such as `eligible`, `cooldown`, `hourly-cap`, `quiet-hours`, `disabled`, `excluded`, `dismissed`, or `permission-unavailable` to a test adapter.
5. **Adjacent-tab capability probe.** Detect a tab-strip selection change without reading page content, resolve direction, and compare with the live Window/Tab menu. Until that seam exists, classify this as a requested enhancement rather than proven parity failure.

## P1 policy and persistence backlog

- Same action inside and outside cooldown.
- Different action during cooldown.
- Permanently dismissed shortcut and reset.
- Coaching disabled.
- Quiet hours, including overnight boundaries.
- Hourly cap and rate-limit reset.
- Excluded application.
- Relaunch persistence of every suppression state.
- Accessibility unavailable/revoked using a separately identified probe; never alter the accepted app's TCC grant during an unattended run.

## P2 compatibility and presentation backlog

- Chrome reopen closed tab, close tab/window, address bar, next/previous tab, numbered tab, Find/Next/Previous, and Back.
- Context-menu actions with and without menu-bar equivalents.
- Finder and Safari smoke matrices.
- Correct action title, glyph order, application identity, timing, placement, auto-dismiss, close, permanent-dismiss, no duplicates, and no stale toast.
- Negative controls: keyboard invocation, shortcutless menu action, candidate overlay execution, excluded app, and coaching disabled.

## Test-seam map

| Layer | What it may prove | Red-capable assertion |
| --- | --- | --- |
| Unit | Shortcut normalization and policy decisions | Exact input returns expected shortcut or suppression reason |
| Integration | Mouse/menu event → resolved menu item → policy request | Fixture event produces one typed coaching request |
| Installed E2E | Real Chrome menu click, OS event capture, and visible toast | One isolated process emits exactly one toast with expected title/shortcut |
| Human-only | Cases blocked by nondeterministic/private UI | Explicit blocker and proposed smallest missing adapter |

A unit test does not close an installed pointer-flow case. Each case remains open until its declared layer produces the required evidence.

## Adding cases

Add the case to `coaching-notification-cases.json` first, using a stable lowercase ID. Mirror its concise status here. Preserve historical results, append a new dated result when behavior changes, and never promote user-reported or backlog-only evidence to an executed pass.

## Current blocker and next action

The required Chrome differential run needs an installed E2E harness that isolates the reference and candidate processes and exposes a deterministic toast assertion. Issue #2 should remain open for that run and subsequent owner review; implementation fixes require separate tickets after a reproducible red signal exists.
