# Pre-project evidence archive — 2026-08-16

This branch is an immutable record of the clean-room clone and notification UI
experiments completed before the product foundation was restarted. It is
evidence, not an implementation base or a merge target.

## Preserved history

The archive branch contains explicit merge parents for every experiment, so the
full Git histories remain reachable from this single ref:

| Track | Preserved ref | Final commit | Outcome |
| --- | --- | --- | --- |
| Baseline clone | `main` | `6cfe4ecc549675493e086825572b79badba13757` | Broad UI and behavior replica; end-to-end reliability not proven |
| Gitify-style inbox | `feat/4-gitify-coaching-inbox` | `60e3ca3e9eb369d1e2c00c098590156c284e73f3` | Synthetic notification, inbox, settings, history, and attention-channel evidence |
| HeyClicky-style presentation | `feat/5-heyclicky-presentation-modes` | `ec844dc83d543e91fcf858acab1ae860a832cdb5` | Six synthetic presentation modes and screenshot/video evidence |
| Comparison lab | `codex/prototype-8-preproject-ui-comparison-lab` | `292fe99849aa0499136082ddb2469c96d47ade4d` | Browser comparison and named native demo runner |

The exact refs and commit graph at archive time are also captured under
`snapshots/`.

## GitHub issue snapshot

`snapshots/github-issues.json` preserves issues 1–8, including bodies, labels,
assignees, comments, timestamps, and links as returned by GitHub on 2026-08-16.
The live issues remain on GitHub; this export prevents later edits from erasing
the historical record.

## Honest technical conclusion

- The UI experiments proved that their synthetic previews and test-event paths
  could render and preserve the documented states.
- They did **not** prove that real pointer-driven menu actions reliably reached
  the notification layer.
- The named demo runner modified and ad-hoc re-signed the app bundles. macOS TCC
  then rejected the existing Accessibility code requirement, invalidating those
  manual trials as detector tests.
- Earlier source and limited installed evidence still left the manual detection
  matrix incomplete. Goal 1 therefore remained unproven.
- None of the prototype branches is a selected production architecture.

## Product decision that ended the prototype phase

The fresh implementation starts from these owner-approved outcomes:

1. One notification-delivery module supports every selected presentation type,
   and users can enable combinations of channels.
2. The app appears in the Dock by default.
3. The app appears in the macOS menu bar by default.
4. Dock and Command-Tab visibility are controlled together through the supported
   macOS activation policy. The default is visible; one setting hides both.
5. Clicking the menu-bar icon opens a Gitify-style inbox. The full application
   window owns settings, history, permissions, and diagnostics.
6. Synthetic presentation tests and installed end-to-end manual-action tests are
   separate gates. Neither may substitute for the other.

## Snapshot contents

- `snapshots/github-issues.json` — complete issue/comment export
- `snapshots/repository.json` — repository metadata
- `snapshots/git-refs.txt` — exact branch refs and commit IDs
- `snapshots/git-history.txt` — reachable commit/parent history
- `docs/app-replica/brand-*` — branding/dependency audit deliverables
- `docs/qa/` — notification QA matrix and structured cases
- linked issue comments and experiment branches — screenshot and video evidence

The new implementation must cite this archive when borrowing a validated user
outcome, but should rewrite production code behind fresh interfaces.
