# Keylume parity ledger

`completion-manifest.json` is the machine-checkable gate. “Passed” means exercised against an installed candidate with appropriate reference evidence; “unresolved” is never counted as completion.

| Area | Passed | Unresolved |
|---|---|---|
| Lifecycle/onboarding | background launch, welcome, granted and denied-access onboarding, protected-monitor gating, clean quit | none |
| Menu bar | status item and complete panel actions | none |
| Overlay | timed right-Command trigger, release persistence, live menu reading, result/empty/no-shortcut states, two-stage Escape, AX execution | none |
| Coaching | raw mouse-menu detection, toast, quiet-hours logic, local rate-limit state machine, permanent-dismiss persistence and reset | none |
| Analytics | keyboard/mouse recording, dashboard, JSON persistence across relaunch | none |
| Settings | paired General/Coaching/About layouts, preference persistence, independent candidate trial/activation/deactivation, paired current-version updater outcome, packaged About documents | none |
| System integration | candidate URL routes, login-item register/unregister, both event-tap disable recovery routes | none |

## Current gate

- Reference inventory: complete for all reachable UI and ordinary runtime states.
- Primary acceptance workflow: passed.
- Installed artifact: verified and smoke-tested after the final rebuild.
- Literal observable-reference claim: **passed** within the clean-room boundaries in `scope.md`.
