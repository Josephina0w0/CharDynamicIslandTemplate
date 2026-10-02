import EventKit
import Foundation
import SwiftData
import UIKit

enum TrackerProjectStage: String, Codable, CaseIterable, Identifiable {
    case planning = "计划中"
    case ready = "待开始"
    case active = "进行中"
    case review = "审核／反馈"
    case delivery = "准备交付"
    case done = "已完成"

    var id: String { rawValue }
}

enum TrackerProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active = "进行中"
    case completed = "已完成"
    case archived = "已归档"

    var id: String { rawValue }
}

enum TrackerProjectFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case active = "进行中"
    case completed = "已完成"
    case archived = "已归档"

    var id: String { rawValue }
}

enum TrackerProjectSort: String, CaseIterable, Identifiable {
    case updated = "最近更新"
    case deadline = "截止日期"
    case followUp = "跟进日期"
    case name = "项目名称"

    var id: String { rawValue }
}

@Model
final class TrackerHistoryEntry {
    var id: UUID
    var date: Date
    var title: String
    var detail: String

    init(id: UUID = UUID(), date: Date = Date(), title: String, detail: String = "") {
        self.id = id
        self.date = date
        self.title = title
        self.detail = detail
    }
}

@Model
final class TrackerProject {
    var id: UUID
    var name: String
    var stageRawValue: String
    var statusRawValue: String
    var deadline: Date?
    var nextAction: String
    var followUpDate: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var history: [TrackerHistoryEntry]

    init(
        id: UUID = UUID(),
        name: String,
        stage: TrackerProjectStage = .planning,
        status: TrackerProjectStatus = .active,
        deadline: Date? = nil,
        nextAction: String = "",
        followUpDate: Date? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        history: [TrackerHistoryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.stageRawValue = stage.rawValue
        self.statusRawValue = status.rawValue
        self.deadline = deadline
        self.nextAction = nextAction
        self.followUpDate = followUpDate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.history = history
    }

    var stage: TrackerProjectStage {
        get { TrackerProjectStage(rawValue: stageRawValue) ?? .planning }
        set { stageRawValue = newValue.rawValue }
    }

    var status: TrackerProjectStatus {
        get { TrackerProjectStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }
}

@Model
final class DailyFocusItem {
    var id: UUID
    var dayKey: String
    var slot: Int
    var text: String
    var isDone: Bool

    init(id: UUID = UUID(), dayKey: String, slot: Int, text: String = "", isDone: Bool = false) {
        self.id = id
        self.dayKey = dayKey
        self.slot = slot
        self.text = text
        self.isDone = isDone
    }
}

enum TrackerDateKey {
    static func make(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct SystemCalendarItem: Identifiable, Hashable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarName: String
}

struct SystemReminderItem: Identifiable, Hashable {
    var id: String
    var title: String
    var dueDate: Date?
    var listName: String
    var isCompleted: Bool
}

struct TrackerSystemListOption: Identifiable, Hashable {
    var id: String
    var title: String
    var sourceTitle: String
}

@MainActor
final class TrackerSystemReader: ObservableObject {
    @Published private(set) var calendarItems: [SystemCalendarItem] = []
    @Published private(set) var reminderItems: [SystemReminderItem] = []
    @Published private(set) var calendarAuthorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var reminderAuthorization = EKEventStore.authorizationStatus(for: .reminder)
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var calendarLists: [TrackerSystemListOption] = []
    @Published private(set) var reminderLists: [TrackerSystemListOption] = []
    @Published private(set) var selectedCalendarIDs: Set<String>?
    @Published private(set) var selectedReminderListIDs: Set<String>?

    private let eventStore = EKEventStore()
    private let defaults: UserDefaults
    private static let selectedCalendarIDsKey = "tracker-selected-calendar-ids"
    private static let selectedReminderListIDsKey = "tracker-selected-reminder-list-ids"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedCalendarIDs = Self.storedSelection(forKey: Self.selectedCalendarIDsKey, defaults: defaults)
        selectedReminderListIDs = Self.storedSelection(forKey: Self.selectedReminderListIDsKey, defaults: defaults)
    }

    var canReadCalendars: Bool { Self.canRead(calendarAuthorization) }
    var canReadReminders: Bool { Self.canRead(reminderAuthorization) }
    var hasAnyDeniedAccess: Bool {
        calendarAuthorization == .denied || reminderAuthorization == .denied
    }

    var permissionSummary: String {
        if canReadCalendars && canReadReminders { return "日历与提醒事项均为只读显示" }
        if calendarAuthorization == .notDetermined || reminderAuthorization == .notDetermined {
            return "尚未完成系统权限设置"
        }
        if hasAnyDeniedAccess { return "部分或全部系统权限已拒绝" }
        return "系统权限受限，本地 Tracker 仍可使用"
    }

    func isCalendarSelected(_ id: String) -> Bool {
        selectedCalendarIDs?.contains(id) ?? true
    }

    func isReminderListSelected(_ id: String) -> Bool {
        selectedReminderListIDs?.contains(id) ?? true
    }

    func setCalendarSelected(_ id: String, selected: Bool) async {
        var selection = selectedCalendarIDs ?? Set(calendarLists.map(\.id))
        if selected {
            selection.insert(id)
        } else {
            selection.remove(id)
        }
        selectedCalendarIDs = selection
        defaults.set(Array(selection).sorted(), forKey: Self.selectedCalendarIDsKey)
        await reload()
    }

    func setReminderListSelected(_ id: String, selected: Bool) async {
        var selection = selectedReminderListIDs ?? Set(reminderLists.map(\.id))
        if selected {
            selection.insert(id)
        } else {
            selection.remove(id)
        }
        selectedReminderListIDs = selection
        defaults.set(Array(selection).sorted(), forKey: Self.selectedReminderListIDsKey)
        await reload()
    }

    func requestReadAccess() async {
        lastError = nil
        do {
            if calendarAuthorization == .notDetermined {
                _ = try await eventStore.requestFullAccessToEvents()
            }
            if reminderAuthorization == .notDetermined {
                _ = try await eventStore.requestFullAccessToReminders()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refreshAuthorization()
        await reload()
    }

    func refreshAuthorization() {
        calendarAuthorization = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorization = EKEventStore.authorizationStatus(for: .reminder)
    }

    func reload() async {
        refreshAuthorization()
        isLoading = true
        defer { isLoading = false }

        if canReadCalendars {
            let calendars = eventStore.calendars(for: .event)
            calendarLists = calendars
                .map {
                    TrackerSystemListOption(
                        id: $0.calendarIdentifier,
                        title: $0.title,
                        sourceTitle: $0.source.title
                    )
                }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            let visibleCalendars = selectedCalendarIDs.map { selectedIDs in
                calendars.filter { selectedIDs.contains($0.calendarIdentifier) }
            } ?? calendars
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start.addingTimeInterval(14 * 86_400)
            if visibleCalendars.isEmpty {
                calendarItems = []
            } else {
                let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: visibleCalendars)
                calendarItems = eventStore.events(matching: predicate)
                    .map { event in
                        SystemCalendarItem(
                            id: event.eventIdentifier ?? UUID().uuidString,
                            title: event.title?.isEmpty == false ? event.title! : "无标题日程",
                            startDate: event.startDate,
                            endDate: event.endDate,
                            isAllDay: event.isAllDay,
                            calendarName: event.calendar.title
                        )
                    }
                    .sorted { $0.startDate < $1.startDate }
            }
        } else {
            calendarItems = []
            calendarLists = []
        }

        if canReadReminders {
            let calendars = eventStore.calendars(for: .reminder)
            reminderLists = calendars
                .map {
                    TrackerSystemListOption(
                        id: $0.calendarIdentifier,
                        title: $0.title,
                        sourceTitle: $0.source.title
                    )
                }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            let visibleCalendars = selectedReminderListIDs.map { selectedIDs in
                calendars.filter { selectedIDs.contains($0.calendarIdentifier) }
            } ?? calendars
            if visibleCalendars.isEmpty {
                reminderItems = []
            } else {
                let predicate = eventStore.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                    calendars: visibleCalendars
                )
                let reminders = await fetchReminders(matching: predicate)
                reminderItems = reminders
                    .map { reminder in
                        SystemReminderItem(
                            id: reminder.calendarItemIdentifier,
                            title: reminder.title?.isEmpty == false ? reminder.title! : "无标题提醒事项",
                            dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                            listName: reminder.calendar.title,
                            isCompleted: reminder.isCompleted
                        )
                    }
                    .sorted { lhs, rhs in
                        switch (lhs.dueDate, rhs.dueDate) {
                        case let (left?, right?): return left < right
                        case (_?, nil): return true
                        case (nil, _?): return false
                        case (nil, nil): return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                        }
                    }
            }
        } else {
            reminderItems = []
            reminderLists = []
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private static func canRead(_ status: EKAuthorizationStatus) -> Bool {
        status == .fullAccess
    }

    private static func storedSelection(forKey key: String, defaults: UserDefaults) -> Set<String>? {
        guard let values = defaults.array(forKey: key) as? [String] else { return nil }
        return Set(values)
    }
}
