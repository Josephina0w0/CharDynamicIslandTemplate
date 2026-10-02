# Asset Map

All assets live in `Resources/Assets.xcassets`. Keep images transparent where appropriate and preserve aspect ratio.

| Imageset | 喻文州 baseline | Purpose |
| --- | ---: | --- |
| `AppIcon` | 1024×1024 | Installed app icon |
| `working` | 1668×2388 | Main app working artwork |
| `break` | 1668×2388 | Main app resting artwork |
| `water` | 1668×2388 | Full-size water success source |
| `working-compact` | 377×540 | Widget and Live Activity working art |
| `break-compact` | 377×540 | Widget and Live Activity resting art |
| `water-compact` | 377×540 | Five-second water feedback art |
| `home` | 1024×1536 | Companion tab decorative art |
| `tracker` | 935×1277 | Tracker Top 3 art |
| `records` | 1024×1536 | Records/color card art |
| `reminder-first` | 1668×2388 | First reminder |
| `reminder-second` | 1225×1284 | Second reminder |
| `reminder-third` | 1668×2388 | Third reminder |
| `reminder-fourth` | 1086×1448 | Fourth reminder |

Pixel dimensions are descriptive, not mandatory. Visual bounds matter more than canvas size. Compact art should remain small enough for ActivityKit archiving and should be checked for gray-placeholder fallback.

For each replacement:

1. Verify transparency and orientation.
2. Preview the full asset in its app card.
3. Preview the compact asset in small Widget, medium Widget, Lock Screen Live Activity, and Dynamic Island.
4. Confirm no unexpected crop, stretch, gray square, or excessive transparent padding.
5. Confirm the app icon has no transparency if the active platform rejects it.
