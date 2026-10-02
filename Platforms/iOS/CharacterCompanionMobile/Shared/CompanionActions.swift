import ActivityKit
import AppIntents
import Foundation
import UserNotifications
import WidgetKit

enum CompanionNotificationID {
    static let breakCategory = "COMPANION_BREAK_FINISHED"
    static let breakFinished = "companion.break.finished"
    static let finishBreak = "COMPANION_FINISH_BREAK"
    static let extendBreak = "COMPANION_EXTEND_BREAK"
    static let reminderCategory = "COMPANION_SCHEDULED_REMINDER"
    static let reminderPrefix = "companion.reminder."
}

enum CompanionWidgetIdentifier {
    static let main = "YuWenzhouCompanionWidget"
}

enum CompanionActionRuntime {
    @discardableResult
    static func toggle(source: StateSource, now: Date = Date()) async throws -> CompanionState {
        let state = try SharedStateRepository.shared.mutate(now: now) { state in
            let target: CompanionMode = state.mode == .working ? .resting : .working
            state.transition(to: target, source: source, now: now)
        }
        requestWidgetReload()
        await finishModeTransition(with: state, at: now)
        return state
    }

    @discardableResult
    static func setMode(
        _ target: CompanionMode,
        source: StateSource,
        now: Date = Date()
    ) async throws -> CompanionState {
        let state = try SharedStateRepository.shared.mutate(now: now) { state in
            state.transition(to: target, source: source, now: now)
        }
        requestWidgetReload()
        await finishModeTransition(with: state, at: now)
        return state
    }

    private static func finishModeTransition(with state: CompanionState, at now: Date) async {
        if state.mode == .resting,
           state.currentRestMode == .countdown,
           let end = state.breakEndAt {
            try? await CompanionNotificationScheduler.scheduleBreakFinished(at: end)
        } else {
            CompanionNotificationScheduler.cancelBreakFinished()
        }
        await refreshSystemSurfaces(with: state, at: now, startLiveActivityIfMissing: true)
    }

    @discardableResult
    static func logWater(source: StateSource, now: Date = Date()) async throws -> CompanionState {
        let state = try SharedStateRepository.shared.mutate(now: now) { state in
            state.logWater(source: source, now: now)
        }
        await refreshSystemSurfaces(with: state, at: now, startLiveActivityIfMissing: true)

        if let feedbackUntil = state.waterFeedbackUntil {
            Task {
                let delay = max(0, feedbackUntil.timeIntervalSinceNow)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                let restoredState = SharedStateRepository.shared.load()
                await refreshSystemSurfaces(with: restoredState)
            }
        }
        return state
    }

    @discardableResult
    static func toggleTimingPause(source: StateSource, now: Date = Date()) async throws -> CompanionState {
        let state = try SharedStateRepository.shared.mutate(now: now) { state in
            state.toggleTimingPause(source: source, now: now)
        }
        if state.isTimingPaused {
            CompanionNotificationScheduler.cancelBreakFinished()
        } else if state.mode == .resting,
                  state.currentRestMode == .countdown,
                  let end = state.breakEndAt {
            try? await CompanionNotificationScheduler.scheduleBreakFinished(at: end)
        }
        await refreshSystemSurfaces(with: state, at: now, startLiveActivityIfMissing: true)
        return state
    }

    @discardableResult
    static func finishBreak(source: StateSource, now: Date = Date()) async throws -> CompanionState {
        let state = try SharedStateRepository.shared.mutate(now: now) { state in
            state.transition(to: .working, source: source, now: now)
            state.events.append(StateEvent(id: UUID(), kind: .reminderAction, date: now, source: source, detail: "finish-break"))
        }
        CompanionNotificationScheduler.cancelBreakFinished()
        await refreshSystemSurfaces(with: state, at: now)
        return state
    }

    @discardableResult
    static func extendBreak(source: StateSource, now: Date = Date()) async throws -> CompanionState {
        let state = try SharedStateRepository.shared.mutate(now: now) { state in
            state.extendBreakByFiveMinutes(source: source, now: now)
        }
        if let end = state.breakEndAt {
            try? await CompanionNotificationScheduler.scheduleBreakFinished(at: end)
        }
        await refreshSystemSurfaces(with: state, at: now)
        return state
    }

    static func refreshSystemSurfaces(
        with state: CompanionState,
        at date: Date = Date(),
        startLiveActivityIfMissing: Bool = false
    ) async {
        requestWidgetReload()
        let content = CompanionActivityAttributes.ContentState.make(from: state, at: date)
        let staleDate = nextSurfaceChangeDate(in: state, at: date)
        let activities = Activity<CompanionActivityAttributes>.activities
        if activities.isEmpty,
           startLiveActivityIfMissing,
           ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(
                attributes: CompanionActivityAttributes(
                    profileID: CompanionProfile.current.id,
                    characterName: CompanionProfile.current.displayName
                ),
                content: ActivityContent(state: content, staleDate: staleDate),
                pushType: nil
            )
        }
        for activity in activities {
            await activity.update(ActivityContent(state: content, staleDate: staleDate))
        }
    }

    private static func requestWidgetReload() {
        WidgetCenter.shared.reloadTimelines(ofKind: CompanionWidgetIdentifier.main)
    }

    private static func nextSurfaceChangeDate(in state: CompanionState, at date: Date) -> Date? {
        if state.isShowingWaterFeedback(at: date) {
            return state.waterFeedbackUntil
        }
        return state.breakEndAt.flatMap { $0 > date ? $0 : nil }
    }
}

enum CompanionNotificationScheduler {
    private static let reminderContentRevision = 2
    private static let reminderContentRevisionKey = "companion-reminder-content-revision"

    static func registerCategories() {
        let yes = UNNotificationAction(
            identifier: CompanionNotificationID.finishBreak,
            title: "是",
            options: []
        )
        let no = UNNotificationAction(
            identifier: CompanionNotificationID.extendBreak,
            title: "否，延长五分钟",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: CompanionNotificationID.breakCategory,
            actions: [yes, no],
            intentIdentifiers: [],
            options: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: CompanionNotificationID.reminderCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category, reminderCategory])
    }

    static func scheduleBreakFinished(at date: Date) async throws {
        cancelBreakFinished()
        let content = UNMutableNotificationContent()
        content.title = "休息时间到了"
        content.body = CompanionProfile.current.breakFinishedQuestion
        content.sound = .default
        content.categoryIdentifier = CompanionNotificationID.breakCategory
        content.userInfo = ["route": "summary", "kind": "break-finished"]
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: CompanionNotificationID.breakFinished, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    static func cancelBreakFinished() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [CompanionNotificationID.breakFinished])
    }

    static func ensureScheduledReminders(using state: CompanionState) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))
        let reminderPendingIDs = pendingIDs.filter {
            $0.hasPrefix(CompanionNotificationID.reminderPrefix)
        }
        if UserDefaults.standard.integer(forKey: reminderContentRevisionKey) < reminderContentRevision {
            center.removePendingNotificationRequests(withIdentifiers: Array(reminderPendingIDs))
            for reminder in state.reminders where reminder.isEnabled {
                try? await schedule(reminder)
            }
            UserDefaults.standard.set(reminderContentRevision, forKey: reminderContentRevisionKey)
            return
        }

        let enabledIDs = Set(state.reminders.filter(\.isEnabled).map { reminderIdentifier(for: $0.id) })
        let obsoleteIDs = reminderPendingIDs.filter {
            !enabledIDs.contains($0)
        }
        center.removePendingNotificationRequests(withIdentifiers: Array(obsoleteIDs))

        for reminder in state.reminders where reminder.isEnabled {
            let identifier = reminderIdentifier(for: reminder.id)
            guard !pendingIDs.contains(identifier) else { continue }
            try? await schedule(reminder)
        }
    }

    static func reschedule(_ reminder: ReminderConfiguration) async throws {
        let center = UNUserNotificationCenter.current()
        let identifier = reminderIdentifier(for: reminder.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard reminder.isEnabled else { return }
        try await schedule(reminder)
    }

    static func cancelAllScheduledReminders() {
        let center = UNUserNotificationCenter.current()
        Task {
            let pending = await center.pendingNotificationRequests()
            let identifiers = pending.map(\.identifier).filter {
                $0.hasPrefix(CompanionNotificationID.reminderPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static func schedule(_ reminder: ReminderConfiguration) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.categoryIdentifier = CompanionNotificationID.reminderCategory
        content.threadIdentifier = CompanionNotificationID.reminderCategory
        content.userInfo = ["route": "summary", "kind": "scheduled-reminder", "reminderID": reminder.id]

        let trigger: UNNotificationTrigger
        switch reminder.schedule {
        case .fixed(let hour, let minute):
            trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: min(23, max(0, hour)), minute: min(59, max(0, minute))),
                repeats: true
            )
        case .interval(let minutes):
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(max(1, minutes) * 60),
                repeats: true
            )
        }

        let request = UNNotificationRequest(
            identifier: reminderIdentifier(for: reminder.id),
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    private static func reminderIdentifier(for id: String) -> String {
        CompanionNotificationID.reminderPrefix + id
    }
}

enum CompanionWidgetMode: String, AppEnum {
    case working
    case resting

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "陪伴状态")
    static let caseDisplayRepresentations: [CompanionWidgetMode: DisplayRepresentation] = [
        .working: "工作",
        .resting: "休息"
    ]

    var mode: CompanionMode {
        self == .working ? .working : .resting
    }
}

/// LiveActivityIntent deliberately runs in the containing app process. The widget
/// action also schedules notifications and updates ActivityKit, which can be
/// deferred or terminated when an ordinary AppIntent runs in the widget process.
struct SetModeFromWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "设置工作或休息"
    static let description = IntentDescription("结束当前区间并开始指定的工作或休息区间。")
    static let openAppWhenRun = false

    @Parameter(title: "目标状态")
    var target: CompanionWidgetMode

    init() {
        target = .resting
    }

    init(target: CompanionWidgetMode) {
        self.target = target
    }

    func perform() async -> some IntentResult {
        do {
            _ = try await CompanionActionRuntime.setMode(target.mode, source: .widget)
        } catch {
            // Returning normally guarantees WidgetKit asks the provider for a new
            // timeline even if a transient shared-container write failed.
            WidgetCenter.shared.reloadTimelines(ofKind: CompanionWidgetIdentifier.main)
        }
        return .result()
    }
}

struct LogWaterFromWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "喝水打卡"
    static let openAppWhenRun = false

    func perform() async -> some IntentResult {
        do {
            _ = try await CompanionActionRuntime.logWater(source: .widget)
        } catch {
            WidgetCenter.shared.reloadTimelines(ofKind: CompanionWidgetIdentifier.main)
        }
        return .result()
    }
}

struct ToggleFromLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "切换工作或休息"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        _ = try await CompanionActionRuntime.toggle(source: .liveActivity)
        return .result()
    }
}

struct LogWaterFromLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "喝水打卡"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        _ = try await CompanionActionRuntime.logWater(source: .liveActivity)
        return .result()
    }
}
