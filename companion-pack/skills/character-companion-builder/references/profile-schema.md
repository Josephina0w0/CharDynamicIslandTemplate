# Companion Profile Schema

Use `assets/companion-profile.yaml` as the canonical intake and build record. Remove unused optional fields instead of inventing values.

## Identity

- `product.slug`: lowercase filesystem-safe identifier.
- `product.display_name`: Finder and menu display name.
- `product.executable_name`: Swift product and bundle executable.
- `product.bundle_identifier`: unique reverse-DNS identifier.
- `product.version` and `product.build`: release identity.
- `product.data_root`: unique Application Support folder.

## Character

- `character.name`: visible character name.
- `character.default_position`: normally `bottom-right`.
- `character.default_visible_scale`: visual baseline after alpha-bound normalization.
- `character.metrics_pill`: fixed text, background, and appearance rules.
- `character.states`: semantic asset mapping for every supported state.

Pet assets and panel assets are separate. A missing state may deliberately reuse another state only when documented in the profile.

## Tracker

- `tracker.mode`: `general` or a named domain pack.
- `tracker.fields`: columns persisted for each item.
- `tracker.stages`: ordered user-facing stages.
- `tracker.seed_policy`: `none`, `neutral`, or `personal`.
- `tracker.calendar_access`: default `read-only`.

## State and Migration

- `storage.*`: destination files owned by the new app.
- `migration.*`: optional legacy sources and copy-only rules.

Never derive a destination from a legacy product name. State separation is part of product identity.

## Distribution

- `distribution.audience`: `local`, `friend`, or `public`.
- `distribution.signing`: `ad-hoc` or an explicitly supplied Developer ID path.
- `distribution.architectures`: both `arm64` and `x86_64` for shareable builds.
