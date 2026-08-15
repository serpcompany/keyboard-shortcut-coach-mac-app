# Domain docs

This repository uses a single-context domain-doc layout.

## Before exploring

Read these when they exist:

- `CONTEXT.md` at the repository root;
- ADRs under `docs/adr/` that touch the area being changed.

Proceed silently when either location is absent. Create or update domain documentation only when terminology or an architectural decision is actually resolved.

## Consumer rules

- Use terminology defined in `CONTEXT.md` in issues, tests, documentation, and code.
- Treat a missing term as a signal to reconsider the wording or record a genuine domain-model gap.
- Surface any proposed change that contradicts an existing ADR instead of silently overriding it.
