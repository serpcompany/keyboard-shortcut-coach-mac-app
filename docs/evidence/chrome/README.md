# Chrome tab-strip characterization

`chrome-153-tab-strip.json` is the sanitized structural projection of the local Chrome 153.0.8010.12 Accessibility observation described in `docs/research/chrome-non-menu-action-detection.md`.

It intentionally retains only generic browser-chrome semantics used by deterministic tests: bundle identity, role, generic control name, Press support, selected state, tab ancestry, and sibling order. It excludes page content, tab titles, URLs, account/profile data, and browsing history.

The current slice uses a short bounded Accessibility re-query after mouse-up. AXObserver notification support has not yet been characterized on every target control, so observer-backed verification remains an unchecked issue criterion. The fixture and unit suite are not evidence of human physical-pointer behavior.
