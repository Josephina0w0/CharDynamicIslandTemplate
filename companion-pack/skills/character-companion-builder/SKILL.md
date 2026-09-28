---
name: character-companion-builder
description: Build, re-skin, extend, migrate, and package native macOS Character Companion apps that combine a draggable character productivity pet with a tracker in one process. Use for this Companion project family, including new character variants, tracker-domain variants, state migration, asset normalization, and Universal 2 releases; not for generic web/mobile companions or one-off image generation.
metadata:
  short-description: Build native macOS character Companion apps
---

# Character Companion Builder

Create an independent Companion variant while preserving existing finished apps and user data. Prefer the repository's clean, character-neutral baseline at `variants/character-companion-general` unless the user explicitly names another source.

## Project Baselines

- Project root: `/Users/joselyn/Documents/Codex/CharacterEfficiencyIsland`
- Maintained general baseline: `variants/character-companion-general`
- Runtime identity: `variants/character-companion-general/Sources/Companion/CompanionProfile.swift`
- Legacy character-only baseline: `variants/zhang-xinjie`

Do not modify a baseline in place when creating a new variant. Copy it without `.git`, `.build`, or `dist`, then work only in the new target. The example artwork is a replaceable theme, not product identity.

## Route the Task

- For a new app or architectural change, read [references/architecture.md](references/architecture.md) and [references/workflow.md](references/workflow.md).
- For character images, state mappings, inconsistent visible sizes, or transparent padding, read [references/asset-normalization.md](references/asset-normalization.md).
- For a new character or tracker domain, read [references/profile-schema.md](references/profile-schema.md) and instantiate [assets/companion-profile.yaml](assets/companion-profile.yaml).
- For release or handoff, read [references/qa-checklist.md](references/qa-checklist.md) and run `scripts/verify_companion_release.sh` on both the final `.app` and `.zip`.
- For product planning or sequencing, read [references/roadmap.md](references/roadmap.md).

## Non-negotiable Invariants

- One `NSApplication`, one app delegate, one status item, and one unified menu.
- Keep desktop-pet and tracker code behind separate coordinators with explicit start/stop cleanup.
- Give every variant a unique bundle identifier, executable name, display name, and Application Support directory.
- Migrate old state by copy-only, only when the destination is absent. Never move, delete, or overwrite legacy state.
- Keep iCloud calendar access read-only unless the user explicitly requests calendar writes.
- Bundle all images and JSON. Never depend on Downloads, attachments, temporary paths, or source-tree absolute paths at runtime.
- Preserve image aspect ratio. Normalize by visible alpha bounds and semantic anchor rather than stretching canvases.
- Keep character resizing separate from the fixed metrics pill; persist the character scale and position.
- Preserve input privacy: count events and categories, never typed content.
- Build Universal 2 (`arm64` and `x86_64`), sign after all bundle mutations, and validate the packaged app and extracted zip.
- Treat successful compilation as intermediate evidence, not completion. Launch the packaged `.app` and verify visible behavior.

## Expected Deliverables

Deliver the independent source directory, packaged `.app`, shareable `.zip`, migration notes, permissions/first-launch notes, completed verification evidence, and known limitations. State which existing projects and data sources were left untouched.
