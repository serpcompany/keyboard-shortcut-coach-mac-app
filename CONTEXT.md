# Shortcut Coach domain

Shortcut Coach observes a **manual action** in another macOS app and turns it into a **coaching event** when a keyboard shortcut could have performed the same action.

- A **manual action detector** emits coaching events. It does not present UI.
- A **coaching event** is the durable, presentation-independent fact recorded in the inbox.
- The **notification delivery module** records each event once and fans it out to the user's selected **presentation channels**.
- A **presentation channel** is one user-visible delivery mechanism such as a native banner, custom toast, Dock badge, or sound.
- The **coaching inbox** is durable history and unread state. It is not optional, even when transient presentation channels are disabled.
- **App presence** means the coupled macOS Dock and Cmd-Tab visibility policy. The menu-bar item remains present.

