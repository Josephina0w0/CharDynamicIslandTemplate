# Mobile Companion Architecture

## Contents

- Targets and modules
- State and persistence
- System-surface synchronization
- Tracker and records
- Non-negotiable failure protections

## Targets and modules

```text
CharacterCompanionMobile
├── Sources/
│   ├── CharacterCompanionMobileApp.swift  lifecycle, notification routing, URLs
│   ├── MobileAppStore.swift               main-actor UI state and preferences
│   ├── ContentView.swift                  companion/home tab
│   ├── TrackerModels.swift                SwiftData models and EventKit adapter
│   ├── TrackerView.swift                  Tracker tab
│   ├── RecordsAnalytics.swift             Foundation-only work statistics
│   └── RecordsView.swift                  daily/weekly/monthly records UI
├── Shared/
│   ├── CompanionProfile.swift             character/product configuration
│   ├── SharedModels.swift                 event ledger and state machine
│   ├── SharedStateRepository.swift        App Group JSON persistence
│   ├── CompanionActions.swift             cross-surface actions and notifications
│   └── CompanionActivityAttributes.swift  Live Activity content state
├── WidgetExtension/
│   └── CharacterCompanionWidgets.swift    small/medium widgets and Live Activity
├── Resources/Assets.xcassets              all bundled art and icon assets
└── Tests/                                 Foundation command-line regression tests
```

The app and Widget extension are separate processes. They communicate only through the App Group file and explicit WidgetKit/ActivityKit refresh requests.

## State and persistence

`CompanionState` is the canonical productivity ledger. It stores the active mode, start date, pause state, work/rest intervals, water events, reminder definitions, preferences, and an event history.

`SharedStateRepository` owns `companion-state-v1.json` inside the App Group. Reads and atomic writes use `NSFileCoordinator`. Do not introduce a second mutable state store for Widget or Live Activity behavior.

Tracker projects and Daily Top 3 use SwiftData in the main app. They do not belong in the Widget state file. System Calendar and Reminders are queried through EventKit and are never copied into mutable project records.

## System-surface synchronization

```text
App / Widget intent / Live Activity intent / notification action
            │
            ▼
CompanionActionRuntime
            │
            ├── atomic shared-state mutation
            ├── WidgetCenter timeline reload request
            ├── ActivityKit content update
            └── local notification scheduling/cancellation
```

Widget entries are state snapshots, not a live binding. Continuous timer motion comes from SwiftUI's `Text(timerInterval:pauseTime:countsDown:showsHours:)`. The provider requests a recovery timeline every 15 minutes so a deferred intent reload cannot leave an obsolete paused/state snapshot visible for hours.

Do not schedule per-second Widget timeline entries. WidgetKit controls refresh budgets and may defer them. Do not extend the recovery horizon to several hours without another freshness mechanism.

Water feedback lasts five seconds and temporarily changes visual content. Its end transition is included in the timeline, but the underlying state start date remains unchanged.

## Tracker and records

Tracker has three independent domains:

- Daily Top 3, keyed by natural day.
- Local projects with stage, status, dates, next action, notes, and history.
- Read-only system Calendar and Reminders, filtered by persisted list selections.

Records are derived only from `WorkInterval`. `RecordsAnalytics` clips intervals to calendar-day boundaries, merges overlaps, supports an open interval ending at `now`, and respects the current time zone and daylight-saving day length.

## Failure protections

- Never make Widget state authoritative.
- Never replace coordinated App Group writes with unrelated `UserDefaults` state.
- Never reset the ledger during a character re-skin.
- Never reuse a baseline App Group or bundle ID for a new installed variant.
- Never attach large original images directly to ActivityKit state; keep compact images in the asset catalog.
- Never rely on a downloaded or temporary image path at runtime.
- Keep widget and app build numbers equal so iOS installs the intended extension.
