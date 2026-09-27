# Companion QA Checklist

Record pass/fail evidence only for checks actually performed.

## Process and Menu

- Exactly one Companion process.
- Exactly one status item.
- Left and right status-item clicks expose the unified menu.
- Each surface can be shown/hidden independently and together.
- Quit releases timers, event taps, monitors, panels, and sleep assertions.

## Desktop Pet

- Defaults to the requested screen position.
- Never fades merely because the pointer enters it.
- Body drag moves and persists position.
- Edge drag changes only character scale and persists it.
- Character remains horizontally centered and bottom-anchored during resize.
- Metrics pill dimensions, typography, and content do not scale with the character.
- Click toggles the control panel; an outside click hides it.
- Every state uses the correct image and a comparable visible scale.
- Work/break timers, reminders, idle transition, input totals, APM/EPM, and no-sleep behavior remain functional.

## Tracker

- Window show/hide, month navigation, date selection, and detail updates work.
- Daily tasks and title edit/save/reload correctly.
- Pipeline fields, stages, deadlines, contacts, and next actions match the selected domain pack.
- Recent dates and bundled seed events load from the app bundle.
- EventKit remains read-only and denied permission does not crash.
- Window level and multi-space behavior match the profile.

## State and Migration

- Legacy files are copied only when destinations are absent.
- Existing destinations are never overwritten.
- Source files remain byte-identical.
- Relaunch restores position, character scale, settings, records, and tracker state.
- Test-generated work time, checkboxes, titles, and window positions are removed before delivery.

## Bundle and Release

- `Info.plist` identifiers, executable, version, build, usage descriptions, and accessory-app behavior are correct.
- Runtime resources exist inside the bundle and do not depend on development paths.
- Executable contains `arm64` and `x86_64`.
- Strict deep signature verification passes.
- ZIP extracts without errors and contains exactly one expected app.
- Extracted app independently passes architecture and signature checks.
- The final packaged app, not a development executable, was launched.

## Handoff

- Source, app, and zip paths are supplied.
- Permissions and Gatekeeper caveats are stated.
- Known limitations are explicit.
- Untouched baseline projects and data sources are named.
