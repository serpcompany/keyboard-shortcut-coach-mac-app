# Verification status

## Evidence levels

| Level | Meaning |
| --- | --- |
| Implemented | Source and build contain the behavior |
| Unit tested | Deterministic test covers the policy or state |
| Synthetic runtime | Exact app delivered a test event |
| Manual runtime | A human action crossed the real detector boundary |
| Accepted | Human reviewed the intended visual/interaction behavior |

## MVP baseline

| Capability | Evidence | Status |
| --- | --- | --- |
| Channel selection and fan-out | Unit tests | Unit tested |
| Per-channel failure reporting | Unit tests | Unit tested |
| Durable inbox and unread lifecycle | Unit tests + relaunch | Manual runtime |
| Preference persistence | Unit tests | Unit tested |
| Shortcut modifier formatting | Unit tests | Unit tested |
| Stable channel identity/copy | Unit tests | Unit tested |
| Synthetic default delivery | Diagnostics reported inbox, toast, and badge delivered | Synthetic runtime |
| App presence policy | LaunchServices changed Foreground → UIElement → Foreground | Manual runtime |
| Stable signing | Developer ID build and strict codesign verification | Manual runtime |
| Accessibility detector | Diagnostics reported Monitoring | Manual runtime |
| Real manual action | Finder → File → New Finder Window produced ⌘N event and notification | Manual runtime |
| Relaunch behavior | Real event and unread count survived relaunch; detector resumed | Manual runtime |

Runtime evidence is stored under [docs/evidence/foundation](evidence/foundation/README.md).

## Chrome non-menu detector branch

Issue #10 adds deterministic classification and correlation coverage for Chrome New Tab, selected-tab Close, direct tab selection, and Settings, including required negative controls. Issues #15 and #16 add production monitors and policy tests for Finder-to-Trash and standard window controls. Unit tests and a signed build do not prove every real-pointer behavior against live application AX trees; each new action remains a human acceptance step before merge.

## Explicitly unproven

- Human physical-pointer acceptance of Chrome Close/Settings, window controls, and Finder-to-Trash detection.
- Browser-toolbar controls and non-menu controls outside the implemented slices.
- Broad application compatibility.
- Native banner authorization and appearance.
- Dock badge and bounce visual appearance.
- Visual acceptance of every custom presentation mode and combination.
- Login-at-launch behavior, update delivery, notarized distribution, and onboarding.

Do not convert an implemented or synthetic status into a broad working claim.

## Commands

~~~sh
xcodegen generate
xcodebuild -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach \
  -configuration Debug \
  -derivedDataPath .derived \
  test

xcodebuild -project ShortcutCoach.xcodeproj \
  -scheme ShortcutCoach \
  -configuration Debug \
  -derivedDataPath .derived \
  clean build

codesign --verify --deep --strict --verbose=2 \
  .derived/Build/Products/Debug/ShortcutCoach.app
~~~
