# Pre-Project UI Lab

This throwaway prototype answers one question: can an owner try and compare the
Gitify-style reliability experiment and the HeyClicky-style presentation
experiment without merging either direction into the product?

## Run it

From this worktree:

```sh
./prototypes/preproject-ui-lab/run.sh
```

The command builds a missing packaged experiment when necessary, starts a
localhost-only controller, and opens the comparison view:

- Compare: <http://127.0.0.1:8765/?variant=compare>
- Gitify guided trial: <http://127.0.0.1:8765/?variant=gitify>
- HeyClicky mode controls: <http://127.0.0.1:8765/?variant=heyclicky>

Use the floating arrows or the keyboard left/right arrows to switch views. The
dashboard includes the full screenshot galleries and buttons that launch the
exact packaged experiment builds. Because the experiments share one bundle ID,
the lab stops the other allowed experiment before launching a new one.

Press Control-C in the terminal to stop the dashboard. Use **Stop demo** in the
dashboard to stop an experiment app.

## Boundaries and safety

- This is pre-project evidence, not production architecture or a merge target.
- The server binds only to `127.0.0.1` and stores no state.
- Mutating requests require an in-memory token embedded in the served page.
- Process control is allowlisted to the exact packaged executables in the two
  experiment worktrees. It does not quit unrelated apps.
- The expected commits are pinned and displayed as ready only when they match.
- Override sibling worktree locations with `KEYLUME_GITIFY_WORKTREE` and
  `KEYLUME_HEYCLICKY_WORKTREE` if needed.

Tracking: [issue #8](https://github.com/serpcompany/keylume-mac-hotkey-app-clone/issues/8).
The eventual human comparison decision remains in [issue #7](https://github.com/serpcompany/keylume-mac-hotkey-app-clone/issues/7).
