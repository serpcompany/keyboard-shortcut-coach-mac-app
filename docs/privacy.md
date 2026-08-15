# Privacy and permissions

## Accessibility

Shortcut Coach requires macOS Accessibility permission to identify the menu item under a physical mouse click and read the shortcut metadata exposed by that item.

The detector uses a listen-only mouse event tap. It does not modify or suppress the click.

## Local data

The app stores:

- Enabled notification channels and app-presence preference in UserDefaults.
- Coaching-event history in:
  ~/Library/Application Support/ShortcutCoach/coaching-events.json

A coaching event contains:

- timestamp,
- application display name,
- menu action title,
- keyboard shortcut,
- pointer coordinates,
- read/unread state.

The MVP provides a Clear History control.

## Network and accounts

The MVP has:

- no account system,
- no cloud sync,
- no analytics SDK,
- no advertising SDK,
- no update service,
- no third-party package dependency,
- no product network client.

This is a source-level statement for the MVP baseline, not a permanent policy for future releases. Any future telemetry, sync, account, or update feature requires a new privacy decision and documentation update.

