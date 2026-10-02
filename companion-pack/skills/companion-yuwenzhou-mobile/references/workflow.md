# Variant and Maintenance Workflow

## Maintain the 喻文州 baseline

1. Work in `Platforms/iOS/CharacterCompanionMobile`.
2. Diagnose shared-state, Widget, Live Activity, notification, Tracker, and records behavior separately.
3. Preserve persisted schema compatibility unless a migration is implemented and tested.
4. Increment the main app and Widget build numbers together.
5. Run the core state and records tests.
6. Build for the iOS Simulator.
7. For device work, build with the selected Team, install with `devicectl`, and launch the installed app.
8. Verify the actual system surfaces, not only the main app.

## Create another character version

Run:

```sh
scripts/create_variant.sh \
  /absolute/path/to/CharacterCompanionMobile \
  /absolute/path/to/NewCharacterCompanion \
  "角色名" \
  "com.example.character.companion" \
  "character-companion"
```

The script copies the baseline, excludes local build state, changes bundle/App Group/URL/Widget identities, replaces the visible character name, and clears the baseline development-team value. It deliberately does not invent character copy or image mappings.

Then:

1. Complete `assets/companion-profile.yaml` as the build record.
2. Edit `Shared/CompanionProfile.swift` for state titles, phrases, palette, reminder copy, and image mappings.
3. Replace every required asset catalog PNG using the existing imageset names.
4. Inspect the app icon and compact images at actual Widget/Live Activity sizes.
5. Select the new signing Team in both Xcode targets.
6. Register the new App Group and enable it for both targets.
7. Run `scripts/validate_mobile_companion.sh` on the copied project.
8. Complete the QA checklist before packaging.

## Feature changes

Choose the true owner before editing:

- State transition, persistence, timing: `Shared/`.
- Main-app presentation or settings: `Sources/`.
- Widget/Live Activity presentation: `WidgetExtension/`.
- Tracker persistence/integration: `TrackerModels.swift` and `TrackerView.swift`.
- Work-record calculations: `RecordsAnalytics.swift`, with Foundation tests.

When a feature affects multiple surfaces, make one shared action and keep the individual surfaces as presenters. Avoid parallel implementations with slightly different behavior.

## Widget freeze recovery

For a report that the app timer moves but Widget does not:

1. Confirm the stored state is not paused in the app.
2. Confirm app and Widget build numbers match.
3. Preserve timer-interval text; do not replace it with a manually formatted entry-date snapshot.
4. Keep a bounded recovery refresh (currently 15 minutes).
5. Confirm every AppIntent mutation calls the shared surface refresh.
6. Install the whole app bundle, not only run the main executable.
7. Launch the app once after installation to request timeline reload.
8. Observe both small and medium widgets through at least one state switch and one water feedback cycle.

If iOS still shows an old extension after a confirmed new installation, remove and add that Widget once; report this as a system cache recovery step, not as the primary fix.
