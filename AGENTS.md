# AI agent instructions

This repository is a clean macOS character-efficiency-island template.

- Read `README.md`, `docs/COPYWRITING.md`, `docs/IMAGE_SLOTS.md`, and `docs/AI_CUSTOMIZATION.md` before customizing.
- Preserve the full feature set unless the user explicitly asks to remove something.
- Never collect or store typed content. Input monitoring may only keep aggregate counts and categories.
- Preserve automatic standby after 30 minutes of mouse/keyboard inactivity, break-mode priority, and automatic return to working mode after real input.
- Keep the daily and all-time record lines visible beneath the idle-time row.
- Replace all names, Bundle IDs, storage directories, bridge directories, copy, assets, and packaging names consistently.
- Keep transparent artwork proportional. Tune `CharacterPlacement` instead of stretching or blindly cropping images.
- Preserve reliable status-panel behavior: both mouse-up events, `hidesOnDeactivate = false`, app activation before ordering the panel front, and one shared show helper.
- Run `./build_app.sh`; shareable builds must contain both `arm64` and `x86_64`.
- Run `scripts/verify_universal_app.sh` on both the app and zip before reporting completion.
