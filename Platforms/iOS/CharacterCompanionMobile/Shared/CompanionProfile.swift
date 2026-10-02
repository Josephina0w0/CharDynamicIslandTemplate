import Foundation

/// The only character-specific surface needed by the phase-one mobile app.
/// A future character build should use the character's name alone as productName,
/// then replace this value and its named assets,
/// rather than copy the state machine or Widget/Live Activity code.
struct CompanionProfile: Codable, Hashable, Sendable {
    struct Palette: Codable, Hashable, Sendable {
        var primaryHex: String
        var secondaryHex: String
        var darkPrimaryHex: String
        var defaultWorkHex: String
    }

    struct Placement: Codable, Hashable, Sendable {
        var scale: Double
        var xOffset: Double
        var yOffset: Double
        var anchor: String
    }

    struct ReminderCopy: Codable, Hashable, Sendable {
        var id: String
        var defaultTitle: String
        var defaultMessage: String
        var imageName: String
    }

    var id: String
    var displayName: String
    var productName: String
    var workingTitle: String
    var restingTitle: String
    var workingPhrase: String
    var restingPhrase: String
    var breakFinishedQuestion: String
    var palette: Palette
    var liveActivityWorkingImage: String
    var liveActivityRestingImage: String
    var waterLoggedImage: String
    var widgetWorkingImage: String
    var widgetRestingImage: String
    var homeImage: String
    var trackerImage: String
    var recordsImage: String
    var appIconName: String
    var placements: [String: Placement]
    var reminders: [ReminderCopy]

    static let current = CompanionProfile(
        id: "yu-wenzhou",
        displayName: "喻文州",
        productName: "喻文州",
        workingTitle: "喻文州工作中",
        restingTitle: "喻文州休息中",
        workingPhrase: "稳步推进",
        restingPhrase: "先恢复状态。休息也是计划的一部分。",
        breakFinishedQuestion: "五分钟到了。要结束休息吗？",
        palette: Palette(
            primaryHex: "315A88",
            secondaryHex: "D9E6F4",
            darkPrimaryHex: "86ADD6",
            defaultWorkHex: "315A88"
        ),
        liveActivityWorkingImage: "working-compact",
        liveActivityRestingImage: "break-compact",
        waterLoggedImage: "water-compact",
        widgetWorkingImage: "working-compact",
        widgetRestingImage: "break-compact",
        homeImage: "home",
        trackerImage: "tracker",
        recordsImage: "records",
        appIconName: "AppIcon",
        placements: [
            "working": Placement(scale: 1, xOffset: 0, yOffset: 0, anchor: "bottom"),
            "resting": Placement(scale: 1, xOffset: 0, yOffset: 0, anchor: "bottom"),
            "home": Placement(scale: 1, xOffset: 0, yOffset: 0, anchor: "bottom"),
            "tracker": Placement(scale: 1, xOffset: 0, yOffset: 0, anchor: "bottom"),
            "records": Placement(scale: 1, xOffset: 0, yOffset: 0, anchor: "bottom")
        ],
        reminders: [
            ReminderCopy(id: "water", defaultTitle: "喝水", defaultMessage: "喝口水。状态稳定，后面的安排才不会乱。", imageName: "reminder-first"),
            ReminderCopy(id: "move", defaultTitle: "活动一下", defaultMessage: "起来走一走。调整一下，回来会更专注。", imageName: "reminder-second"),
            ReminderCopy(id: "noon", defaultTitle: "午休", defaultMessage: "看一下当前进度。保留有效的，调整不合适的。", imageName: "reminder-third"),
            ReminderCopy(id: "offwork", defaultTitle: "下班", defaultMessage: "今天先收好尾。清楚地结束，明天才容易开始。", imageName: "reminder-fourth")
        ]
    )
}
