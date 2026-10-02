import ActivityKit
import Foundation

struct CompanionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mode: CompanionMode
        var title: String
        var phrase: String
        var stateStartedAt: Date
        var breakEndAt: Date?
        var isCountdown: Bool
        var isAwaitingConfirmation: Bool
        var isTimingPaused: Bool
        var pausedTimerText: String?
        var isWaterFeedback: Bool
        var waterCountToday: Int
        var imageName: String
    }

    var profileID: String
    var characterName: String
}

extension CompanionActivityAttributes.ContentState {
    static func make(from state: CompanionState, at date: Date = Date()) -> Self {
        let profile = CompanionProfile.current
        let isResting = state.mode == .resting
        let isWaterFeedback = state.isShowingWaterFeedback(at: date)
        let pausedTimerText: String? = if state.isTimingPaused {
            isResting && state.currentRestMode == .countdown
                ? CompanionFormatting.duration(state.remainingBreak(at: date))
                : CompanionFormatting.duration(state.elapsed(at: date))
        } else {
            nil
        }
        return Self(
            mode: state.mode,
            title: isResting ? profile.restingTitle : profile.workingTitle,
            phrase: isResting ? profile.restingPhrase : profile.workingPhrase,
            stateStartedAt: state.stateStartedAt,
            breakEndAt: state.breakEndAt,
            isCountdown: isResting && state.currentRestMode == .countdown,
            isAwaitingConfirmation: state.isAwaitingConfirmation(at: date),
            isTimingPaused: state.isTimingPaused,
            pausedTimerText: pausedTimerText,
            isWaterFeedback: isWaterFeedback,
            waterCountToday: state.waterCount(on: date),
            imageName: isWaterFeedback
                ? profile.waterLoggedImage
                : (isResting ? profile.liveActivityRestingImage : profile.liveActivityWorkingImage)
        )
    }
}
