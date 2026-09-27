# Character Asset Normalization

## Why Canvas Dimensions Are Misleading

Two PNGs can both be 1668×2388 while one character appears half the size because their transparent margins differ. Conversely, two tightly cropped images with different pose proportions should not be forced into identical width and height.

Inspect the alpha bounding box of every state. The relevant geometry is the non-transparent visible region, not the PNG canvas.

## Semantic State Mapping

Maintain an explicit table for:

- working
- break
- idle
- water
- alert
- AI
- reminder first through fourth
- panel equivalents
- status icon

Detect accidental duplicates with checksums. Dedicated AI or reminder artwork must not silently point to the same file unless the profile says so.

## Normalization Rules

1. Preserve the original aspect ratio.
2. Scale using visible alpha height, not canvas height.
3. Center the visible alpha bounds horizontally.
4. Anchor standing/full-body poses to the visible bottom edge.
5. Use per-state overrides for seated, floating, or wide poses rather than distorting them.
6. Keep the metrics pill outside the character scale transform.
7. Do not permanently edit source artwork merely to compensate for runtime layout when alpha-bound normalization can solve it.

Use `scripts/inspect_png_alpha.sh` to report canvas, visible bounds, insets, and coverage. Large differences in top/bottom inset ratios or visible coverage are a review signal.

## Runtime Model

The renderer should derive a normalized visible frame and then apply the saved user character scale. The image remains centered and bottom-anchored while resizing. State changes reuse the same visible target unless a documented state override applies.

## Visual QA

Preview every affected state in the packaged app. Check:

- no clipping at maximum scale;
- no tiny character caused by transparent padding;
- consistent foot/bottom position;
- fixed metrics pill size and alignment;
- correct asset for the semantic state;
- usable resize edge around transparent artwork;
- acceptable result in both system appearances.
