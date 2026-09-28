import Foundation

/// Runtime-facing identity for the reusable Companion baseline.
///
/// Keep character-specific copy here. Bundle identity and release metadata live in
/// `Packaging/Info.plist`, while the product/executable names live in
/// `Package.swift` and `build_app.sh`.
enum CompanionProfile {
    static let productName = "Character Companion"
    static let characterName = "你的角色"
    static let statusFallbackGlyph = "伴"
    static let dataRoot = "CharacterCompanion"
    static let resourceBundleName = "CharacterCompanion_Companion.bundle"
    static let bundleIdentifierFallback = "local.codex.character-companion"

    static var applicationSupportRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(dataRoot, isDirectory: true)
    }

    static func supportDirectory(_ component: String) -> URL {
        applicationSupportRoot.appendingPathComponent(component, isDirectory: true)
    }
}
