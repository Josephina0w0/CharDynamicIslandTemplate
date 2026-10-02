import ActivityKit
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@MainActor
final class MobileAppStore: ObservableObject {
    @Published private(set) var state: CompanionState
    @Published private(set) var notificationStatus = "正在检查"
    @Published private(set) var notificationsAuthorized = false
    @Published var lastError: String?

    private let repository = SharedStateRepository.shared
    private var liveActivityTask: Task<Void, Never>?
    private var reminderScheduleTask: Task<Void, Never>?

    init() {
        do {
            state = try repository.ensureInitialized()
        } catch {
            state = repository.load()
            lastError = error.localizedDescription
        }
        refreshNotificationStatus()
    }

    func refresh(now: Date = Date()) {
        do {
            state = try repository.mutate(now: now) { _ in }
        } catch {
            state = repository.load(now: now)
            lastError = error.localizedDescription
        }
    }

    func setRestMode(_ mode: RestMode) {
        updatePreferences { $0.restMode = mode }
    }

    func setCountdownMinutes(_ minutes: Int) {
        updatePreferences { $0.countdownMinutes = min(180, max(1, minutes)) }
    }

    func setWorkColorHex(_ hex: String) {
        updatePreferences { $0.workColorHex = hex }
    }

    func setWeekStart(_ weekStart: WeekStart) {
        updatePreferences { $0.weekStart = weekStart }
    }

    func toggleTimingPause() {
        Task {
            do {
                state = try await CompanionActionRuntime.toggleTimingPause(source: .app)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func setReminderEnabled(_ id: String, enabled: Bool) {
        updateReminder(id) { reminder in
            reminder.isEnabled = enabled
        }
    }

    func setReminderTitle(_ id: String, title: String) {
        updateReminder(id) { reminder in
            reminder.title = title
        }
    }

    func setReminderMessage(_ id: String, message: String) {
        updateReminder(id) { reminder in
            reminder.message = message
        }
    }

    func setReminderSchedule(_ id: String, schedule: ReminderSchedule) {
        updateReminder(id) { reminder in
            reminder.schedule = schedule
        }
    }

    func requestNotifications() {
        Task {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                refreshNotificationStatus()
                ensureReminderNotifications()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func refreshSystemSurfaces() {
        WidgetCenter.shared.reloadAllTimelines()
        ensureReminderNotifications()
        liveActivityTask?.cancel()
        let stateSnapshot = state
        liveActivityTask = Task { [weak self] in
            // ActivityKit can briefly reject a request while the scene is still
            // becoming active. Wait for the foreground transition and retry once.
            for delay in [350_000_000, 900_000_000] as [UInt64] {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }

                guard UIApplication.shared.applicationState == .active else { continue }

                do {
                    try await CompanionLiveActivityManager.ensureActive(with: stateSnapshot)
                    return
                } catch {
                    // A later scene activation will try again. Keep this recoverable
                    // system timing issue out of the user's persistent data errors.
                    if Task.isCancelled { return }
                }
            }
            self?.liveActivityTask = nil
        }
    }

    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self?.notificationStatus = "已开启"
                    self?.notificationsAuthorized = true
                case .denied:
                    self?.notificationStatus = "已关闭"
                    self?.notificationsAuthorized = false
                case .notDetermined:
                    self?.notificationStatus = "尚未请求"
                    self?.notificationsAuthorized = false
                @unknown default:
                    self?.notificationStatus = "未知"
                    self?.notificationsAuthorized = false
                }
            }
        }
    }

    func ensureReminderNotifications() {
        let stateSnapshot = state
        Task {
            await CompanionNotificationScheduler.ensureScheduledReminders(using: stateSnapshot)
        }
    }

    private func updatePreferences(_ body: (inout CompanionPreferences) -> Void) {
        do {
            state = try repository.mutate { state in body(&state.preferences) }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func updateReminder(
        _ id: String,
        body: (inout ReminderConfiguration) -> Void
    ) {
        let now = Date()
        do {
            state = try repository.mutate(now: now) { state in
                guard let index = state.reminders.firstIndex(where: { $0.id == id }) else { return }
                body(&state.reminders[index])
                if state.reminders[index].isEnabled {
                    state.reminders[index].nextTriggerAt = CompanionReminderTiming.nextTrigger(
                        for: state.reminders[index].schedule,
                        after: now
                    )
                } else {
                    state.reminders[index].nextTriggerAt = nil
                    state.reminders[index].lastTriggeredAt = nil
                }
            }
            WidgetCenter.shared.reloadAllTimelines()
            guard let reminder = state.reminders.first(where: { $0.id == id }) else { return }
            reminderScheduleTask?.cancel()
            reminderScheduleTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    try Task.checkCancellation()
                    try await CompanionNotificationScheduler.reschedule(reminder)
                } catch is CancellationError {
                    return
                } catch {
                    self?.lastError = error.localizedDescription
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}

enum CompanionLiveActivityManager {
    private static let layoutRevision = 8
    private static let layoutRevisionKey = "companion-live-activity-layout-revision"

    static func ensureActive(with state: CompanionState, at date: Date = Date()) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let contentState = CompanionActivityAttributes.ContentState.make(from: state, at: date)
        let staleDate = state.isShowingWaterFeedback(at: date)
            ? state.waterFeedbackUntil
            : state.breakEndAt.flatMap { $0 > date ? $0 : nil }
        let content = ActivityContent(state: contentState, staleDate: staleDate)

        let defaults = UserDefaults.standard
        if defaults.integer(forKey: layoutRevisionKey) < layoutRevision {
            for activity in Activity<CompanionActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            defaults.set(layoutRevision, forKey: layoutRevisionKey)
        }

        if let existing = Activity<CompanionActivityAttributes>.activities.first {
            await existing.update(content)
            return
        }
        _ = try Activity.request(
            attributes: CompanionActivityAttributes(
                profileID: CompanionProfile.current.id,
                characterName: CompanionProfile.current.displayName
            ),
            content: content,
            pushType: nil
        )
    }
}
