# Goal 2 plan — discoverable Keylume management UI

## Outcome

Add one obvious, ordinary window called **Keylume Home** so a user never has to guess that the app lives behind a menu-bar icon. The shortcut overlay and coaching toast remain lightweight, transient tools; Home becomes the durable place to understand status, change settings, and inspect progress.

This is a plan only. No Goal 2 UI has been implemented.

## Recommended shape

Use a compact macOS `NavigationSplitView`, approximately 760×560 points, opened from:

- **Open Keylume Home…** as the first actionable menu-bar item;
- clicking the menu-bar icon with Option held;
- the existing `keylumeclone://settings` route, redirected to the appropriate Home destination;
- `⌘,`, which opens Home with Settings selected.

The sidebar stays shallow—no nested navigation:

1. **Overview**
2. **Shortcuts**
3. **Coaching**
4. **Progress**
5. **Settings**

## Screens

### Overview

Answer “Is Keylume working?” at a glance:

- Accessibility: Granted / Action required
- Monitoring: active app name and number of discovered shortcuts
- Trigger: “Hold Right ⌘ for 1.5 seconds” with a **Try overlay** button
- Coaching: On / paused by quiet hours / off
- This week: keyboard ratio and two small usage totals

Only exceptional states get a callout. A denied Accessibility state gets one primary **Open Accessibility Settings** action and explains that monitoring is paused.

### Shortcuts

Provide a persistent version of the overlay for exploration, not execution-first use:

- current application picker and live refresh;
- native search field;
- menu-grouped shortcut rows using the same `AppShortcut` model as the overlay;
- filters for All, Used, and Not yet used;
- a row action to demonstrate or execute a shortcut, with the target app named explicitly.

### Coaching

Use a grouped `Form` with native controls:

- Enable coaching nudges
- Always show nudges
- Max nudges per hour, with the value visible beside the slider
- Quiet hours, with From/Until controls revealed only when enabled
- Dismissed shortcuts list with per-row restore and **Restore all**

This replaces the ambiguous single reset action with inspectable state.

### Progress

Reuse the existing analytics model and components:

- keyboard ratio and weekly totals;
- mastered shortcuts;
- shortcuts still reached through the mouse;
- per-app totals;
- local-data explanation and **Reset usage data…** destructive confirmation.

### Settings

Keep the flat native macOS form:

- trigger key and hold duration;
- appearance;
- launch at login;
- automatic update checks;
- excluded applications with add/remove controls;
- About, version, privacy, update status, and independent license state at the bottom.

Do not add a second tab bar inside this screen. The sidebar already supplies navigation.

## State and component plan

- Keep `AppModel` as the root observable runtime model; do not create a parallel Home view model.
- Add a local `@State` selection enum for the sidebar and a small item-driven sheet enum for destructive confirmations or app selection.
- Continue binding controls directly to `AppPreferences`.
- Extract reusable `StatusCard`, `MetricTile`, `ShortcutList`, and `PermissionCallout` views; the overlay and Home shortcut list share row content but keep separate containers.
- Use native `Form`, `Section`, `Toggle`, `Picker`, and `Slider` controls. Preserve visible labels and keyboard focus.
- Add preview fixtures for granted, denied, no-shortcuts, empty analytics, populated analytics, quiet-hours-active, and licensed states.

## Delivery slices

1. **Discoverability slice:** Home window, sidebar, Overview status, menu item, `⌘,`, and deep-link routing.
2. **Settings migration:** move existing General/Coaching/About controls into the new flat destinations without changing persistence keys or behavior.
3. **Persistent shortcuts:** shared shortcut rows, search, current-app refresh, and no-result/error states.
4. **Progress migration:** reuse the proven analytics components and add local-data reset confirmation.
5. **Polish and proof:** keyboard navigation, VoiceOver labels, light/dark appearance, window restoration, screenshots, and regression verification of the untouched overlay/coaching workflows.

## Acceptance gate

Goal 2 is ready to implement when the owner accepts the Home-window concept. Implementation is complete only when:

- a first-time user can find Home from the menu bar without prior instruction;
- permission and monitoring state are understandable in under one glance;
- every existing preference remains behaviorally and persistently compatible;
- the overlay, coaching toast, usage recording, and menu-bar-only launch still pass the Goal 1 manifest;
- the window works fully by keyboard and exposes meaningful Accessibility labels;
- no Goal 1 private-identity boundary is weakened.
