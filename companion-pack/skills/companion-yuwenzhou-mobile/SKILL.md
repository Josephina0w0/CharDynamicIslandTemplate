---
name: companion-yuwenzhou-mobile
description: Build, debug, re-skin, extend, install, and package the native iOS/iPadOS Character Companion app using the completed 喻文州 mobile app as the behavioral baseline. Use for new character variants that need widgets, Live Activities, reminders, Tracker, and work records; not for the macOS desktop-pet baseline or generic SwiftUI apps.
metadata:
  short-description: Build mobile companions from the 喻文州 baseline
---

# 陪伴版-喻文州

Use the completed 喻文州 iPhone/iPad app as a tested product baseline, while keeping every new character build independent. The local baseline is:

```text
/Users/joselyn/Documents/Codex/CharacterEfficiencyIsland-companion/Platforms/iOS/CharacterCompanionMobile
```

The GitHub baseline is the `companion` branch of:

```text
https://github.com/Josephina0w0/CharDynamicIslandTemplate
```

Do not overwrite this baseline when producing another character. Run `scripts/create_variant.sh`, then work only in the copied target.

## Route the task

- For architecture, state ownership, or synchronization bugs, read [references/architecture.md](references/architecture.md).
- For a new character/person version or broad feature work, read [references/workflow.md](references/workflow.md) and [references/profile-schema.md](references/profile-schema.md).
- For image replacement, read [references/asset-map.md](references/asset-map.md).
- For build, device installation, handoff, or GitHub packaging, read [references/qa-checklist.md](references/qa-checklist.md) and [references/distribution.md](references/distribution.md).

## Product invariants

- The app, Widget extension, and Live Activity use one App Group event ledger. Preserve atomic coordinated writes.
- A state transition closes the current work/rest interval before opening the next one. Never infer work from screen time, app foreground time, or device uptime.
- Widget buttons and Live Activity buttons mutate the same shared state, then request refreshes for all system surfaces.
- Widget timers must use SwiftUI timer intervals so they continue without per-second timeline entries. Keep the 15-minute recovery refresh; do not restore the old six-hour stale-state horizon.
- Water feedback is visual and temporary. It must not interrupt the underlying work/rest timer.
- Tracker data remains independent SwiftData content. EventKit calendars and reminders remain read-only unless the user explicitly broadens scope.
- Character-specific names, copy, colors, image slots, bundle identifiers, App Group, URL scheme, and Widget kind must be changed together.
- Keep the product display name to the character's name unless the user requests another name.
- Preserve existing source projects and user data. New variants get new identifiers and storage.

## Expected handoff

Provide the independent source directory, build/version identity, simulator build evidence, core and records test results, device installation result when authorized, source package, installable app package for the signed device, the reusable Skill package, and known Apple-signing limitations.
