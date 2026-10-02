# Mobile Companion Profile Schema

Use `assets/companion-profile.yaml` as the canonical intake and build record. Do not infer legal rights to a person's or fictional character's name and artwork.

## Identity

- Character name and product display name.
- Profile slug.
- Main bundle identifier.
- Widget bundle identifier, normally `<main>.widget`.
- App Group, normally `group.<main>`.
- URL scheme.
- Widget kind identifier.
- Version and build number.

All identifiers must be unique for independently installed variants.

## Copy

- Working and resting titles.
- Working and resting phrases.
- Break-finished question.
- Four reminder titles and messages.

Keep titles short enough for the medium Widget and expanded Live Activity.

## Palette

- Primary light color.
- Secondary background color.
- Primary dark color.
- Default records/work color.

## Assets

Map working, resting, water feedback, home, Tracker, records, four reminders, and App icon. Compact Widget/Live Activity images must be separately optimized instead of relying on the largest source PNG.

## Product behavior

- Default rest mode and duration.
- Reminder schedules.
- Week start.
- Minimum iOS version.
- Whether iPad remains in scope.
- Whether watchOS is deferred or included.

## Distribution

- `personal-device`: free Personal Team; expires under Apple's provisioning limits.
- `testflight`: paid Apple Developer Program and beta review.
- `app-store`: paid program, metadata, privacy declaration, and review.

Public distribution requires rights to all names, images, fonts, and copy.
