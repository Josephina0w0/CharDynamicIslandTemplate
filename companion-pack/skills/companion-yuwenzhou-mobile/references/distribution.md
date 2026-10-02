# Build, Installation, and Distribution

## Local simulator build

Use `CODE_SIGNING_ALLOWED=NO` and a dedicated DerivedData directory. A simulator `.app` cannot be installed on a physical iPhone.

## Personal-device build

Select a Team for both targets, keep the same App Group entitlement, build for the connected iPhone, then install the resulting `Debug-iphoneos/CharacterCompanionMobile.app` with Xcode or `devicectl`.

A Personal Team build is not a general-purpose shareable installer. Apple's free provisioning expires and is tied to registered devices. Label every zipped device `.app` with this limitation.

## TestFlight/App Store

Before the first upload, replace placeholder/local bundle identifiers with permanent unique identifiers. Prepare privacy policy, app privacy responses, screenshots, support contact, export-compliance answers, and proof of rights for all character assets.

## Package set

For a complete local handoff, produce:

- `陪伴版-喻文州-source.zip`: source and documentation, excluding local build caches.
- `陪伴版-喻文州-build<build>-iphoneos.app.zip`: signed device bundle for the current signing context.
- `陪伴版-喻文州-build<build>-simulator.app.zip`: simulator build.
- `companion-yuwenzhou-mobile.skill.zip`: portable Codex Skill.
- `SHA256SUMS`: integrity hashes.

The GitHub repository is the durable source. Do not commit DerivedData, private provisioning profiles, signing certificates, user state, or exported Tracker data.
