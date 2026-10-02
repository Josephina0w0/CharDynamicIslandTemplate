import Foundation

enum CompanionMode: String, Codable, CaseIterable, Sendable {
    case working
    case resting
}

enum RestMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case countdown
    case stopwatch

    var id: String { rawValue }
    var title: String { self == .countdown ? "自定义倒计时" : "正计时" }
}

enum WeekStart: String, Codable, CaseIterable, Identifiable, Sendable {
    case monday
    case sunday

    var id: String { rawValue }
}

enum StateSource: String, Codable, Sendable {
    case app
    case widget
    case liveActivity
    case notificationAction
    case recovery
}

enum StateEventKind: String, Codable, Sendable {
    case initialized
    case workStarted
    case workEnded
    case restStarted
    case restEnded
    case waterLogged
    case reminderTriggered
    case reminderAction
}

struct StateEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: StateEventKind
    var date: Date
    var source: StateSource
    var detail: String?
}

struct WorkInterval: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var source: StateSource
    var createdAt: Date
    var updatedAt: Date
}

struct RestInterval: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var mode: RestMode
    var plannedEndAt: Date?
    var source: StateSource
}

struct WaterEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var date: Date
    var source: StateSource
}

enum ReminderSchedule: Codable, Hashable, Sendable {
    case fixed(hour: Int, minute: Int)
    case interval(minutes: Int)
}

enum ReminderScheduleKind: String, CaseIterable, Identifiable, Sendable {
    case fixed
    case interval

    var id: String { rawValue }
    var title: String { self == .fixed ? "固定时间" : "时间间隔" }
}

struct ReminderConfiguration: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var isEnabled: Bool
    var title: String
    var message: String
    var schedule: ReminderSchedule
    var nextTriggerAt: Date?
    var imageName: String
    var lastTriggeredAt: Date?

    var scheduleKind: ReminderScheduleKind {
        switch schedule {
        case .fixed: .fixed
        case .interval: .interval
        }
    }
}

enum CompanionReminderTiming {
    static let widgetPresentationDuration: TimeInterval = 15 * 60

    static func nextTrigger(
        for schedule: ReminderSchedule,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date {
        switch schedule {
        case .fixed(let hour, let minute):
            let components = DateComponents(hour: min(23, max(0, hour)), minute: min(59, max(0, minute)))
            return calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            ) ?? date.addingTimeInterval(24 * 60 * 60)
        case .interval(let minutes):
            return date.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        }
    }

    static func followingTrigger(
        after occurrence: Date,
        schedule: ReminderSchedule,
        calendar: Calendar = .current
    ) -> Date {
        switch schedule {
        case .fixed:
            return nextTrigger(for: schedule, after: occurrence.addingTimeInterval(1), calendar: calendar)
        case .interval(let minutes):
            return occurrence.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        }
    }

    static func normalizedNextTrigger(
        for reminder: ReminderConfiguration,
        after now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard reminder.isEnabled else { return nil }
        guard let existing = reminder.nextTriggerAt else {
            return nextTrigger(for: reminder.schedule, after: now, calendar: calendar)
        }
        guard existing <= now else { return existing }

        switch reminder.schedule {
        case .fixed:
            return nextTrigger(for: reminder.schedule, after: now, calendar: calendar)
        case .interval(let minutes):
            let interval = TimeInterval(max(1, minutes) * 60)
            let elapsedIntervals = floor(now.timeIntervalSince(existing) / interval) + 1
            return existing.addingTimeInterval(elapsedIntervals * interval)
        }
    }
}

struct CompanionPreferences: Codable, Hashable, Sendable {
    var restMode: RestMode
    var countdownMinutes: Int
    var workColorHex: String
    var weekStart: WeekStart

    static let defaults = CompanionPreferences(
        restMode: .countdown,
        countdownMinutes: 5,
        workColorHex: CompanionProfile.current.palette.defaultWorkHex,
        weekStart: .monday
    )
}

struct CompanionState: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var initializedAt: Date
    var updatedAt: Date
    var mode: CompanionMode
    var stateStartedAt: Date
    var breakEndAt: Date?
    var breakAwaitingConfirmation: Bool
    var activeWorkIntervalID: UUID?
    var activeRestIntervalID: UUID?
    var workIntervals: [WorkInterval]
    var restIntervals: [RestInterval]
    var waterEvents: [WaterEvent]
    var events: [StateEvent]
    var reminders: [ReminderConfiguration]
    var preferences: CompanionPreferences
    var lastRecordedBreakReminderID: UUID?
    var timingPausedAt: Date?
    var waterFeedbackUntil: Date?

    static func initial(now: Date = Date(), source: StateSource = .app) -> CompanionState {
        let workID = UUID()
        return CompanionState(
            schemaVersion: currentSchemaVersion,
            initializedAt: now,
            updatedAt: now,
            mode: .working,
            stateStartedAt: now,
            breakEndAt: nil,
            breakAwaitingConfirmation: false,
            activeWorkIntervalID: workID,
            activeRestIntervalID: nil,
            workIntervals: [WorkInterval(id: workID, startedAt: now, endedAt: nil, source: source, createdAt: now, updatedAt: now)],
            restIntervals: [],
            waterEvents: [],
            events: [
                StateEvent(id: UUID(), kind: .initialized, date: now, source: source, detail: nil),
                StateEvent(id: UUID(), kind: .workStarted, date: now, source: source, detail: "initial")
            ],
            reminders: CompanionProfile.current.reminders.enumerated().map { index, copy in
                ReminderConfiguration(
                    id: copy.id,
                    isEnabled: true,
                    title: copy.defaultTitle,
                    message: copy.defaultMessage,
                    schedule: index < 2 ? .interval(minutes: index == 0 ? 120 : 60) : .fixed(hour: index == 2 ? 12 : 19, minute: 0),
                    nextTriggerAt: nil,
                    imageName: copy.imageName,
                    lastTriggeredAt: nil
                )
            },
            preferences: .defaults,
            lastRecordedBreakReminderID: nil,
            timingPausedAt: nil,
            waterFeedbackUntil: nil
        )
    }

    var isTimingPaused: Bool {
        timingPausedAt != nil
    }

    var currentStatusDisplayName: String {
        if isTimingPaused { return "待机中" }
        return mode == .working ? "工作中" : "休息中"
    }

    var activeRestInterval: RestInterval? {
        guard let activeRestIntervalID else { return nil }
        return restIntervals.first { $0.id == activeRestIntervalID }
    }

    var currentRestMode: RestMode? {
        activeRestInterval?.mode
    }

    func isAwaitingConfirmation(at date: Date) -> Bool {
        let effectiveDate = timingPausedAt ?? date
        return mode == .resting && currentRestMode == .countdown && (breakEndAt.map { effectiveDate >= $0 } ?? false)
    }

    func elapsed(at date: Date) -> TimeInterval {
        max(0, (timingPausedAt ?? date).timeIntervalSince(stateStartedAt))
    }

    func remainingBreak(at date: Date) -> TimeInterval {
        max(0, breakEndAt?.timeIntervalSince(timingPausedAt ?? date) ?? 0)
    }

    func isShowingWaterFeedback(at date: Date) -> Bool {
        waterFeedbackUntil.map { date < $0 } ?? false
    }

    func waterCount(on date: Date, calendar: Calendar = .current) -> Int {
        waterEvents.reduce(into: 0) { count, event in
            if calendar.isDate(event.date, inSameDayAs: date) { count += 1 }
        }
    }

    func completedWorkDuration(through date: Date) -> TimeInterval {
        workIntervals.reduce(0) { total, interval in
            let end = interval.endedAt ?? date
            return total + max(0, end.timeIntervalSince(interval.startedAt))
        }
    }

    mutating func normalize(at now: Date) {
        schemaVersion = Self.currentSchemaVersion
        breakAwaitingConfirmation = isAwaitingConfirmation(at: now)
        if breakAwaitingConfirmation,
           let restID = activeRestIntervalID,
           lastRecordedBreakReminderID != restID {
            events.append(StateEvent(id: UUID(), kind: .reminderTriggered, date: breakEndAt ?? now, source: .recovery, detail: "break-finished"))
            lastRecordedBreakReminderID = restID
        }

        for index in reminders.indices {
            guard reminders[index].isEnabled else {
                reminders[index].nextTriggerAt = nil
                continue
            }
            if reminders[index].nextTriggerAt == nil {
                reminders[index].nextTriggerAt = CompanionReminderTiming.nextTrigger(
                    for: reminders[index].schedule,
                    after: now
                )
            } else if let due = reminders[index].nextTriggerAt, due <= now {
                if reminders[index].lastTriggeredAt != due {
                    reminders[index].lastTriggeredAt = due
                    events.append(StateEvent(
                        id: UUID(),
                        kind: .reminderTriggered,
                        date: due,
                        source: .recovery,
                        detail: reminders[index].id
                    ))
                }
                reminders[index].nextTriggerAt = CompanionReminderTiming.normalizedNextTrigger(
                    for: reminders[index],
                    after: now
                )
            }
        }
    }

    @discardableResult
    mutating func transition(to target: CompanionMode, source: StateSource, now: Date = Date()) -> Bool {
        normalize(at: now)
        guard target != mode else { return false }
        let remainsPaused = isTimingPaused

        switch (mode, target) {
        case (.working, .resting):
            closeActiveWork(at: now, source: source)
            events.append(StateEvent(id: UUID(), kind: .workEnded, date: now, source: source, detail: nil))
            let restID = UUID()
            let plannedEnd = preferences.restMode == .countdown
                ? now.addingTimeInterval(TimeInterval(max(1, preferences.countdownMinutes) * 60))
                : nil
            restIntervals.append(RestInterval(id: restID, startedAt: now, endedAt: remainsPaused ? now : nil, mode: preferences.restMode, plannedEndAt: plannedEnd, source: source))
            activeRestIntervalID = restID
            activeWorkIntervalID = nil
            mode = .resting
            stateStartedAt = now
            breakEndAt = plannedEnd
            breakAwaitingConfirmation = false
            lastRecordedBreakReminderID = nil
            events.append(StateEvent(id: UUID(), kind: .restStarted, date: now, source: source, detail: preferences.restMode.rawValue))

        case (.resting, .working):
            closeActiveRest(at: now)
            events.append(StateEvent(id: UUID(), kind: .restEnded, date: now, source: source, detail: nil))
            let workID = UUID()
            workIntervals.append(WorkInterval(id: workID, startedAt: now, endedAt: remainsPaused ? now : nil, source: source, createdAt: now, updatedAt: now))
            activeWorkIntervalID = workID
            activeRestIntervalID = nil
            mode = .working
            stateStartedAt = now
            breakEndAt = nil
            breakAwaitingConfirmation = false
            events.append(StateEvent(id: UUID(), kind: .workStarted, date: now, source: source, detail: nil))

        default:
            return false
        }

        if remainsPaused {
            timingPausedAt = now
        }

        updatedAt = now
        return true
    }

    mutating func logWater(source: StateSource, now: Date = Date()) {
        waterEvents.append(WaterEvent(id: UUID(), date: now, source: source))
        events.append(StateEvent(id: UUID(), kind: .waterLogged, date: now, source: source, detail: nil))
        waterFeedbackUntil = now.addingTimeInterval(5)
        updatedAt = now
    }

    @discardableResult
    mutating func toggleTimingPause(source: StateSource, now: Date = Date()) -> Bool {
        normalize(at: now)
        if let pausedAt = timingPausedAt {
            let pausedDuration = max(0, now.timeIntervalSince(pausedAt))
            stateStartedAt = stateStartedAt.addingTimeInterval(pausedDuration)
            breakEndAt = breakEndAt?.addingTimeInterval(pausedDuration)

            switch mode {
            case .working:
                let workID = UUID()
                workIntervals.append(WorkInterval(
                    id: workID,
                    startedAt: now,
                    endedAt: nil,
                    source: source,
                    createdAt: now,
                    updatedAt: now
                ))
                activeWorkIntervalID = workID
            case .resting:
                let restMode = currentRestMode ?? preferences.restMode
                let restID = UUID()
                restIntervals.append(RestInterval(
                    id: restID,
                    startedAt: now,
                    endedAt: nil,
                    mode: restMode,
                    plannedEndAt: breakEndAt,
                    source: source
                ))
                activeRestIntervalID = restID
            }
            timingPausedAt = nil
        } else {
            switch mode {
            case .working:
                closeActiveWork(at: now, source: source)
            case .resting:
                closeActiveRest(at: now)
            }
            timingPausedAt = now
        }
        updatedAt = now
        return isTimingPaused
    }

    mutating func extendBreakByFiveMinutes(source: StateSource, now: Date = Date()) {
        normalize(at: now)
        guard mode == .resting else { return }
        breakEndAt = now.addingTimeInterval(5 * 60)
        breakAwaitingConfirmation = false
        if let id = activeRestIntervalID,
           let index = restIntervals.firstIndex(where: { $0.id == id }) {
            restIntervals[index].plannedEndAt = breakEndAt
        }
        events.append(StateEvent(id: UUID(), kind: .reminderAction, date: now, source: source, detail: "extend-five-minutes"))
        updatedAt = now
    }

    private mutating func closeActiveWork(at now: Date, source: StateSource) {
        guard let id = activeWorkIntervalID,
              let index = workIntervals.firstIndex(where: { $0.id == id }) else { return }
        guard workIntervals[index].endedAt == nil else { return }
        workIntervals[index].endedAt = now
        workIntervals[index].updatedAt = now
    }

    private mutating func closeActiveRest(at now: Date) {
        guard let id = activeRestIntervalID,
              let index = restIntervals.firstIndex(where: { $0.id == id }) else { return }
        guard restIntervals[index].endedAt == nil else { return }
        restIntervals[index].endedAt = now
    }
}

enum CompanionFormatting {
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    static func companionDays(from start: Date, through now: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let currentDay = calendar.startOfDay(for: now)
        return max(1, (calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0) + 1)
    }
}
