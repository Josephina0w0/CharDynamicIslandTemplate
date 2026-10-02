# AI agent instructions

This repository is a clean macOS character-efficiency-island template.

The repository also contains the maintained native iOS/iPadOS 喻文州 Companion baseline at `Platforms/iOS/CharacterCompanionMobile`. For that project, load `companion-pack/skills/companion-yuwenzhou-mobile/SKILL.md` and follow its architecture and QA references. Do not apply macOS status-item, Universal 2, or input-monitoring requirements to the mobile target.

Mobile Companion invariants:

- Preserve the shared App Group event ledger across the app, Widget, and Live Activity.
- Keep Widget timers on SwiftUI timer intervals and retain the bounded recovery refresh.
- Keep EventKit Calendar and Reminders read-only.
- Derive records only from work intervals, including open and cross-midnight intervals.
- New characters must be copied into independent projects with unique bundle IDs, App Groups, URL schemes, and Widget kinds.
- Build and test the app plus Widget extension together; matching build numbers are required.

- Read `README.md`, `docs/COPYWRITING.md`, `docs/IMAGE_SLOTS.md`, and `docs/AI_CUSTOMIZATION.md` before customizing.
- Preserve the full feature set unless the user explicitly asks to remove something.
- Never collect or store typed content. Input monitoring may only keep aggregate counts and categories.
- Preserve the natural rolling 60-second APM/EPM model: APM counts non-repeating key presses and mouse clicks; EPM uses the same window but excludes Backspace and Forward Delete; the persistent working island displays EPM.
- Preserve automatic standby after 30 minutes of mouse/keyboard inactivity, break-mode priority, and automatic return to working mode after real input.
- Keep the daily and all-time record lines visible beneath the idle-time row.
- Replace all names, Bundle IDs, storage directories, bridge directories, copy, assets, and packaging names consistently.
- Keep transparent artwork proportional. Tune `CharacterPlacement` instead of stretching or blindly cropping images.
- Preserve reliable status-panel behavior: both mouse-up events, `hidesOnDeactivate = false`, app activation before ordering the panel front, and one shared show helper.
- Run `./build_app.sh`; shareable builds must contain both `arm64` and `x86_64`.
- Run `scripts/verify_universal_app.sh` on both the app and zip before reporting completion.
