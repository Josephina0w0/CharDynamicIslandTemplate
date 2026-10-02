# Mobile Companion QA Checklist

## Static validation

- Run `scripts/validate_mobile_companion.sh <project-dir>`.
- Confirm the main and Widget build numbers match.
- Confirm bundle IDs, App Group values, URL scheme, and Widget kind are unique and consistent.
- Confirm every required imageset exists.

## Automated tests

Run the Foundation tests with a writable module cache:

```sh
xcrun swiftc -module-cache-path /private/tmp/core-swift-module-cache \
  Shared/CompanionProfile.swift Shared/SharedModels.swift \
  Tests/CoreStateMachineTests.swift -o /private/tmp/core-state-tests
/private/tmp/core-state-tests

xcrun swiftc -module-cache-path /private/tmp/records-swift-module-cache \
  Shared/CompanionProfile.swift Shared/SharedModels.swift \
  Sources/RecordsAnalytics.swift Tests/RecordsAnalyticsTests.swift \
  -o /private/tmp/records-analytics-tests
/private/tmp/records-analytics-tests
```

## Simulator

- Main app launches and all three tabs scroll.
- Light and dark appearance remain legible.
- Daily Top 3 edits, truncates, checks, and persists.
- Project create/edit/archive/delete flows work.
- Calendar/Reminders denial does not block local Tracker functions.
- Records day/week/month navigation and color selection work.

## Physical iPhone

- Existing state survives an upgrade installation.
- Main timer advances with the app foregrounded and after relaunch.
- Small and medium Widget timers advance without opening the app.
- Widget work/rest action changes both Widget and app state.
- Water feedback appears on app, widgets, and Live Activity, then returns without resetting the timer.
- After pausing and resuming in the app, widgets recover immediately or within the recovery refresh window.
- Countdown completion notification and actions work.
- Lock Screen Live Activity and Dynamic Island layout remain intact.

## Handoff evidence

Record the version/build, Xcode version, simulator/device used, tests passed, installed bundle ID, package checksums, and any manual cache-recovery step.
