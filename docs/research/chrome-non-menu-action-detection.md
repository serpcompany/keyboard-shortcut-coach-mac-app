# Detecting Chrome non-menu actions on macOS

Date: 2026-09-04

## Decision

The existing Keylume/Shortcut Coach boundary is the correct foundation: observe mouse input with a passive Core Graphics event tap, hit-test the pointer into the macOS Accessibility tree, and apply a Chrome-specific mapping. It should not, however, emit a coaching event immediately from `leftMouseDown` or identify controls from a localized title alone.

The production design should be a two-phase correlation pipeline:

1. On mouse-down, record an immutable snapshot of the hit Accessibility element, its bounded ancestor chain, the owning process, the relevant pre-action state, and the input modifiers.
2. On mouse-up, reject drags, modifier variants, moved-off-control releases, and ambiguous contexts. Emit only after the expected postcondition is observed, using an Accessibility notification where supported and a short bounded state re-query as fallback.

This preserves the product's defining property—coaching after a manual pointer action—while avoiding notifications for canceled presses and for clicks that are not behaviorally equivalent to the suggested shortcut.

## Keylume product and installed-app evidence

Keylume's official site describes Coaching Nudges specifically as the result of clicking a **menu item** and describes compatibility in terms of applications exposing shortcuts through the standard menu bar. It does not claim that tab-strip or toolbar clicks are detected. [Keylume official site](https://keylume.app/)

A local black-box inspection of installed Keylume 1.1.2 (bundle `app.keylume.Keylume`, build 7) is consistent with that public boundary. Its local usage store contains Chrome shortcut usage, but the inspected data provides no evidence of mouse-originated Chrome Close Tab or tab-selection coaching. The only mouse-originated Chrome row observed was New Tab (`⌘T`); that row alone does not establish whether the source was Chrome's menu item or its new-tab button. Archived local QA likewise records adjacent-tab coaching as a requested enhancement, not demonstrated Keylume parity.

The installed Chrome AX tree on the same Mac does expose browser chrome: a tab group containing tab elements with child Close buttons, plus New Tab and toolbar buttons. No private tab titles are recorded in this report. This live observation confirms feasibility on the target environment, while the source evidence below explains why it is supported and how it should be implemented safely.

Accordingly, non-menu control coaching should be treated as a deliberate product extension to the clone, not as already-proven behavioral parity with Keylume.

## What the current app already gets right

[`ManualActionDetector.swift`](../../ShortcutCoach/Detection/ManualActionDetector.swift) already:

- creates a session event tap for `leftMouseDown`;
- uses `.listenOnly`, so it does not modify or suppress the event;
- obtains the pointer location from the event;
- calls `AXUIElementCopyElementAtPosition` on the system-wide Accessibility object; and
- requires Accessibility trust before monitoring.

Those choices align with Apple's APIs. `CGEventTapCreate` accepts an event mask and invokes the callback from the run loop to which its source is attached; Apple defines `.listenOnly` as a passive listener. For a passive listener, returning the event or `NULL` does not affect the event stream. [Apple: `CGEventTapCreate`](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29), [Apple: `CGEventTapOptions.listenOnly`](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/listenonly), [Apple: `CGEventTapCallBack`](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback)

Apple says `AXUIElementCopyElementAtPosition` returns the Accessibility object at top-left-relative screen coordinates, respects window z-order, and can operate across applications when given the system-wide element. This is exactly the primitive needed for a control beneath a global pointer event. The call can also return `noValue`, `invalidUIElement`, `cannotComplete`, or `notImplemented`, so individual failures must be treated as expected misses rather than detector failures. [Apple: `AXUIElementCopyElementAtPosition`](https://developer.apple.com/documentation/applicationservices/1462077-axuielementcopyelementatposition)

The current artificial restriction is this guard:

```swift
stringAttribute(kAXRoleAttribute, from: element) == kAXMenuItemRole as String
```

Removing that guard is necessary, but not sufficient. The event-tap callback currently performs synchronous Accessibility messaging on the main run loop. Apple notes that event taps can be enabled and disabled, and Accessibility messaging can fail with `cannotComplete` when the target is unresponsive. The callback should therefore do minimal work, hand off an immutable event sample, handle `tapDisabledByTimeout`/`tapDisabledByUserInput`, and re-enable the tap when appropriate. [Apple: `CGEvent.tapEnable`](https://developer.apple.com/documentation/coregraphics/cgevent/tapenable%28tap%3Aenable%3A%29), [Apple: `AXUIElement.h`](https://developer.apple.com/documentation/applicationservices/axuielement_h)

## Chrome exposes browser chrome through Accessibility

This is not an attempt to inspect the page DOM. Chromium distinguishes native browser UI (`Views`) from page/WebContents accessibility and says process-wide native accessibility applies to native UI components. [Chromium: content accessibility overview](https://chromium.googlesource.com/chromium/src/+/HEAD/content/browser/accessibility/README.md), [Chromium: Views accessibility](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/views/accessibility/README.md)

Chromium's current tab implementation assigns each tab the semantic role `ax::mojom::Role::kTab`; the macOS platform adapter exposes tabs as radio buttons and maps selected state into the value. [Chromium: `tab.cc`](https://chromium.googlesource.com/chromium/src/+/HEAD/chrome/browser/ui/views/tabs/tab.cc), [Chromium: `ax_platform_node_mac.mm`](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/ui/accessibility/platform/ax_platform_node_mac.mm)

Chrome also creates separate accessible controls for the tab-close button and new-tab button, and gives those controls localized accessible names. Toolbar code similarly assigns accessible names to Back, Forward, Reload, and other controls. This makes AX hit-testing viable for these controls, while also showing why an English title such as `Close` is not a stable identity. [Chromium: `tab_close_button.cc`](https://chromium.googlesource.com/chromium/src/+/137e735d6ddafcb3a8ae3a7a095dfd6a6bd0a52d/chrome/browser/ui/views/tabs/tab_close_button.cc), [Chromium: `horizontal_tab_strip_region_view.cc`](https://chromium.googlesource.com/chromium/src/+/HEAD/chrome/browser/ui/views/frame/horizontal_tab_strip_region_view.cc), [Chromium: `toolbar_view.cc`](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/views/toolbar/toolbar_view.cc)

## Classification strategy

The hit element should be converted into a generic snapshot before any app-specific rule runs:

- owning PID from `AXUIElementGetPid`, then bundle identifier from the running application;
- role, subrole, title, description, identifier, value/selected state, enabled state, position, and size when supported;
- supported action names; and
- the same semantic fields for a bounded parent chain, stopping at the window/application root or a small maximum depth.

Apple defines Accessibility objects as a hierarchy that reports what an object is, where it is, and what actions it can perform. It provides APIs to enumerate supported attributes and actions, and the parent attribute provides the hierarchy link. Optional attributes must be read defensively because targets need not support every attribute. [Apple: `AXUIElement`](https://developer.apple.com/documentation/applicationservices/axuielement), [Apple: `AXUIElementCopyAttributeNames`](https://developer.apple.com/documentation/applicationservices/1459475-axuielementcopyattributenames), [Apple: `AXUIElementCopyActionNames`](https://developer.apple.com/documentation/applicationservices/1462053-axuielementcopyactionnames), [Apple: `kAXParentAttribute`](https://developer.apple.com/documentation/applicationservices/kaxparentattribute)

Use the PID derived from the hit element as the source of application identity. `NSWorkspace.frontmostApplication` alone can misattribute a click that is activating a background application's window.

Rules should be keyed by bundle identifier (initially Google Chrome and, if desired, Chromium) and classify by a conjunction of role, action support, semantic ancestor roles, selected state, sibling position, and characterized identifiers. Localized title/description should be a fallback signal, not the sole discriminator. Geometry should only validate that mouse-up remained within the original target, not identify the action.

Before shipping rules, capture a live characterization matrix from the supported Chrome build(s): raw hit element, all supported attributes/actions, and the ancestor chain for active/inactive tab body, active/inactive tab close, new tab, back, forward, reload/stop, and omnibox. Chromium source proves these controls are intended to be accessible; only the installed build can prove the exact macOS AX shape Keylume will receive.

## Why outcome verification is needed

Mouse-down is evidence of intent, not evidence that the action completed. A user can press a button, drag away, and release; drag a tab; Command-click a tab to alter selection; click a disabled control; or hit a control whose meaning changes while a page loads. The present detector would emit before any of those distinctions are known.

Apple's Accessibility objects send state-change notifications. An `AXObserver` is created for one application/PID; an observer registered on the application element can receive descendant notifications. Relevant postconditions include selected-children/value changes and element destruction. A particular element can reject a notification registration as unsupported, so notifications cannot be the only verification mechanism. [Apple: Accessibility notification overview](https://developer.apple.com/documentation/applicationservices/axnotificationconstants_h), [Apple: `AXObserverCreate`](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate), [Apple: `AXObserverAddNotification`](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification), [Apple: `kAXSelectedChildrenChangedNotification`](https://developer.apple.com/documentation/applicationservices/kaxselectedchildrenchangednotification), [Apple: `kAXValueChangedNotification`](https://developer.apple.com/documentation/applicationservices/kaxvaluechangednotification), [Apple: `kAXUIElementDestroyedNotification`](https://developer.apple.com/documentation/applicationservices/kaxuielementdestroyednotification)

Recommended implementation:

- keep one observer per live target PID when practical, instead of racing to install it after mouse-up;
- correlate notifications to a pending mouse gesture and its original window/tab-list/control identity;
- use a short bounded re-query/diff when the relevant notification is unsupported or not delivered;
- require mouse-up without a drag and the action-specific postcondition; and
- expire the pending action silently if it cannot be verified.

The observer is therefore a verification aid, not a replacement for the event tap. AX notifications alone cannot prove the state change came from a pointer click.

## Shortcut equivalence rules

The coaching rule must answer a stricter question than “did something related happen?” It must answer “would this shortcut have produced materially the same result in this context?”

| Clicked control | Safe initial coaching rule | Reason |
| --- | --- | --- |
| New-tab button | Coach `⌘T` after a new tab appears in the same browser window. | Chromium maps the new-tab command to `⌘T`; this is a strong same-window equivalent. |
| Close button on the active tab | Coach `⌘W` only after that tab closes and no ambiguous multi-selection/split context exists. | Chrome's mouse path closes the exact `Tab*` whose button was pressed, while its keyboard close command starts from the active tab. |
| Close button on a background tab | Do not coach `⌘W`. | The click closes that background tab; `⌘W` closes the active tab. The outcomes differ. |
| Tab body, positions 1–8 | Prefer exact `⌘1`…`⌘8` after that tab becomes active. | Chromium defines direct selection commands for these positions. |
| Last tab | Coach `⌘9` only when the clicked tab is provably the last tab. | Chromium defines `⌘9` as “last tab.” |
| Other arbitrary tab | Suppress initially. | A single default direct-selection shortcut is not available for every position. |
| Adjacent tab | Do not assume Control-Tab is exact. Prefer the direct index mapping above. | Chromium distinguishes cycling commands from positional next/previous commands; cycling behavior can be context/feature dependent. |
| Reload button | Coach `⌘R` only when the control is currently Reload and a reload outcome is verified. | The same toolbar location can represent Stop while loading; Stop is not Reload. |
| Back/Forward buttons | Coach only after live AX characterization and verified one-step history navigation. | Plain left click can be equivalent, but long/modifier/menu variants are not. |
| Omnibox/address-bar interior | Suppress initially. | A pointer click can place the insertion point or preserve/change selection; `⌘L` focuses and selects the location. Those are not reliably the same outcome. |

Chromium's command IDs explicitly distinguish new tab, close tab, next/previous selection, positions 1–8, and last tab. Its macOS keyboard source defines the direct tab-index shortcuts; its accelerator source maps `⌘T` to new tab. Chromium's macOS app-controller test confirms `⌘W` is assigned to Close Tab in a tabbed window. [Chromium: command IDs](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/app/chrome_command_ids.h), [Chromium: macOS keyboard shortcuts](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/global_keyboard_shortcuts_mac.mm), [Chromium: accelerator table](https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/chrome/browser/ui/accelerator_table.cc), [Chromium: macOS app-controller test](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/app_controller_mac_unittest.mm)

The background-close distinction is explicit in Chromium's implementation: the close-button handler records whether the pressed tab is active and asks the controller to close that exact tab; the keyboard command operates on the active tab. [Chromium: tab close-button handler](https://chromium.googlesource.com/chromium/src/+/HEAD/chrome/browser/ui/views/tabs/tab.cc), [Chromium: `CloseTab` keyboard command](https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/chrome/browser/ui/browser_commands.cc)

Where a corresponding native menu item exists, Keylume should prefer its live AX shortcut metadata so macOS user-customized shortcuts are respected. Static Chrome defaults are acceptable only as an explicit fallback backed by a versioned rule and tests. Hidden/non-menu Chrome commands such as direct tab selection require an app-specific mapping.

## Why an extension or DevTools is not the detector

A Chrome content script executes in the context of a loaded web page and works with that page's DOM. The tab strip and toolbar are browser UI, not part of a page DOM. Chromium's extension Tabs API exposes state events such as activation and removal, but those events report what changed, not whether the cause was a tab-strip click, a keyboard shortcut, an extension/API call, or another source. [Chromium: content scripts](https://chromium.googlesource.com/chromium/chromium/+/refs/heads/main/chrome/common/extensions/docs/extensions/content_scripts.html), [Chromium: Tabs API schema](https://chromium.googlesource.com/chromium/chromium/+/HEAD/chrome/common/extensions/api/tabs.json)

The DevTools Protocol similarly exposes targets and target lifecycle/state operations. Its Target and Browser schemas do not define an event that reports a pointer press on browser chrome. It can help confirm that a target appeared, disappeared, or changed, but not attribute that result to the user's click. This is an inference from the canonical protocol schemas, not an explicit forward-compatibility guarantee. [Chromium DevTools Protocol overview](https://chromedevtools.github.io/devtools-protocol/), [CDP Target domain](https://chromedevtools.github.io/devtools-protocol/tot/Target/), [CDP Browser domain](https://chromedevtools.github.io/devtools-protocol/tot/Browser/)

An extension or CDP connection could therefore be a redundant state-verification source, but it would add installation/debugging permissions and still would not replace the event-tap-plus-AX attribution path. It is not justified for this feature.

## “Physical click” caveat

Core Graphics describes Quartz events as low-level events that typically originate from user input, but software can also post events into the event stream. Apple exposes source-related event fields, including a source Unix PID, but does not document a perfect test that proves hardware provenance for every event. [Apple: `CGEvent`](https://developer.apple.com/documentation/coregraphics/cgevent), [Apple: `CGEventField.eventSourceUnixProcessID`](https://developer.apple.com/documentation/coregraphics/cgeventfield/eventsourceunixprocessid), [Apple: `CGEventSourceStateID`](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid)

Product and privacy language should therefore say “observed mouse input” or “manual pointer action,” not promise cryptographic certainty that an event was physically generated. The detector can exclude events attributed to its own PID and known private/synthetic sources where documented, but should not claim perfect synthetic-event rejection.

## Recommended implementation shape

```text
listen-only CGEvent tap
  └─ mouse-down: lightweight event sample
       └─ AX hit test + generic snapshot + pre-state
            └─ bundle-ID adapter classification
                 └─ pending gesture
                      ├─ reject modifier/drag/canceled mouse-up
                      └─ correlate expected AX notification or bounded re-query
                           └─ verify semantic equivalence
                                └─ CoachingEvent
```

Suggested internal seams:

- `PointerEventMonitor`: owns the Core Graphics tap, tap recovery, and lightweight samples.
- `AccessibilitySnapshotter`: hit-tests and produces defensive, app-neutral element/ancestor snapshots.
- `ManualActionRule` / `ApplicationActionAdapter`: classifies a snapshot and declares the expected postcondition plus shortcut resolver.
- `ActionCorrelator`: owns pending gestures, AX-observer events, bounded re-query, expiration, and deduplication.
- `ChromeActionAdapter`: implements only characterized, behaviorally equivalent Chrome rules.

## Acceptance criteria for issue #10

1. The event tap observes at least left down, left up, and drag/cancel conditions; the callback does not perform blocking AX work and recovers from timeout disablement.
2. The Accessibility snapshot includes owning PID/bundle ID, supported semantic attributes/actions, selected/value state, and a bounded ancestor chain.
3. Chrome rules are based on checked-in characterization fixtures from a current installed Chrome build, not English titles or coordinates alone.
4. A candidate emits only after an action-specific postcondition is verified by observer event or bounded re-query.
5. Initial supported mappings are limited to semantically safe cases: New Tab, active-tab Close, direct tab positions 1–8/last, and any toolbar actions separately proven by characterization.
6. Background-tab Close, ambiguous tab positions, tab drags, modified clicks, canceled presses, Reload/Stop ambiguity, and generic omnibox clicks do not emit.
7. Unit tests cover rule classification, localized/missing optional attributes, ancestor variation, active versus background close, tab indexing, observer-unsupported fallback, timeouts, and deduplication.
8. Manual verification demonstrates real pointer input in Chrome and confirms that extension/CDP integration is not required.
9. Privacy and settings copy is updated from “menu item” to the supported broader “manually clicked controls,” while retaining the listen-only/no-network guarantees.

## Bottom line

The earlier design was directionally correct: a native macOS app should use global passive mouse observation plus AX hit-testing and app-specific rules. The implementation should be revised from “click + identify + emit” to “intent + semantic classification + verified outcome + equivalence check.” That revision is material; without it, issue #10 would produce plausible but incorrect coaching in common Chrome tab-strip cases.
