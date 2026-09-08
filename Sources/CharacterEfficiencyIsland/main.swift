import Cocoa
import ApplicationServices
import CoreGraphics
import IOKit.pwr_mgt

enum CharacterMode {
    case idle
    case working
    case breakTime
    case alert
    case ai
    case water
    case reminderSecond
    case reminderThird
    case reminderFourth

    var title: String {
        switch self {
        case .idle: return "角色待命中"
        case .working: return "角色工作中"
        case .breakTime: return "休息倒计时"
        case .alert: return "角色提醒"
        case .ai: return "AI 任务完成"
        case .water: return "喝水时间"
        case .reminderSecond, .reminderThird, .reminderFourth: return "角色提醒"
        }
    }

    var assetName: String {
        switch self {
        case .idle: return "idle"
        case .working: return "working"
        case .breakTime: return "break"
        case .alert: return "alert"
        case .ai: return "alert"
        case .water: return "water"
        case .reminderSecond: return "reminder-second"
        case .reminderThird: return "reminder-third"
        case .reminderFourth: return "reminder-fourth"
        }
    }

    var panelAssetName: String {
        switch self {
        case .idle: return "panel-idle"
        case .working: return "panel-working"
        case .breakTime: return "panel-break"
        case .water: return "panel-water"
        case .alert: return "alert"
        case .ai: return "alert"
        case .reminderSecond: return "panel-reminder-second"
        case .reminderThird: return "panel-reminder-third"
        case .reminderFourth: return "panel-reminder-fourth"
        }
    }

    var symbolName: String {
        switch self {
        case .idle: return "pause.circle.fill"
        case .working: return "timer"
        case .breakTime: return "timer.circle.fill"
        case .alert: return "bell.fill"
        case .ai: return "sparkles"
        case .water: return "cup.and.saucer.fill"
        case .reminderSecond: return "figure.walk"
        case .reminderThird: return "clock.badge.checkmark"
        case .reminderFourth: return "moon.zzz.fill"
        }
    }
}

enum ReminderKind: String, Codable {
    case interval
    case fixedTime
}

struct SoftReminder: Codable {
    var id: String
    var title: String
    var schedule: String
    var enabled: Bool
    var kind: ReminderKind

    static let defaults = [
        SoftReminder(id: "water", title: "喝水", schedule: "每 2 小时", enabled: true, kind: .interval),
        SoftReminder(id: "move", title: "起身活动", schedule: "每 1 小时", enabled: true, kind: .interval),
        SoftReminder(id: "noon", title: "午间校准", schedule: "11:00", enabled: true, kind: .fixedTime),
        SoftReminder(id: "offwork", title: "下班", schedule: "16:30", enabled: true, kind: .fixedTime)
    ]

    var isLockedWater: Bool {
        id == "water"
    }
}

struct StoredSettings: Codable {
    var softReminders: [SoftReminder]
    var showPersistentIsland: Bool
    var islandScale: Double?
}

struct DailyRecord: Codable {
    var date: String
    var workSeconds: Int = 0
    var breakSeconds: Int = 0
    var aiDoneCount: Int = 0
    var waterCheckins: Int = 0
    var printableKeys: Int = 0
    var correctionKeys: Int = 0
    var activeTypingSeconds: Int = 0
    var actionCount: Int = 0
    var activeActionSeconds: Int = 0

    init(
        date: String,
        workSeconds: Int = 0,
        breakSeconds: Int = 0,
        aiDoneCount: Int = 0,
        waterCheckins: Int = 0,
        printableKeys: Int = 0,
        correctionKeys: Int = 0,
        activeTypingSeconds: Int = 0,
        actionCount: Int = 0,
        activeActionSeconds: Int = 0
    ) {
        self.date = date
        self.workSeconds = workSeconds
        self.breakSeconds = breakSeconds
        self.aiDoneCount = aiDoneCount
        self.waterCheckins = waterCheckins
        self.printableKeys = printableKeys
        self.correctionKeys = correctionKeys
        self.activeTypingSeconds = activeTypingSeconds
        self.actionCount = actionCount
        self.activeActionSeconds = activeActionSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        workSeconds = try container.decodeIfPresent(Int.self, forKey: .workSeconds) ?? 0
        breakSeconds = try container.decodeIfPresent(Int.self, forKey: .breakSeconds) ?? 0
        aiDoneCount = try container.decodeIfPresent(Int.self, forKey: .aiDoneCount) ?? 0
        waterCheckins = try container.decodeIfPresent(Int.self, forKey: .waterCheckins) ?? 0
        printableKeys = try container.decodeIfPresent(Int.self, forKey: .printableKeys) ?? 0
        correctionKeys = try container.decodeIfPresent(Int.self, forKey: .correctionKeys) ?? 0
        activeTypingSeconds = try container.decodeIfPresent(Int.self, forKey: .activeTypingSeconds) ?? 0
        actionCount = try container.decodeIfPresent(Int.self, forKey: .actionCount) ?? 0
        activeActionSeconds = try container.decodeIfPresent(Int.self, forKey: .activeActionSeconds) ?? 0
    }
}

extension DailyRecord {
    var hasActivity: Bool {
        workSeconds > 0
            || breakSeconds > 0
            || aiDoneCount > 0
            || waterCheckins > 0
            || printableKeys > 0
            || correctionKeys > 0
            || activeTypingSeconds > 0
            || actionCount > 0
            || activeActionSeconds > 0
    }
}

final class AppState {
    private let reminderDefaultsKey = "softReminders"
    private let islandDefaultsKey = "showPersistentIsland"
    private let islandScaleDefaultsKey = "persistentIslandScale"
    private static let settingsFile: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CharacterEfficiencyIsland/settings.json")
    private static let recordsFile: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CharacterEfficiencyIsland/daily-records.json")

    var mode: CharacterMode = .working
    var isPaused = false
    var isOnBreak = false
    var breakStartedAt: Date?
    var breakStartMouseLocation: NSPoint?
    var isBreakTimerPausedByMenuBar = false
    var wasMouseInBreakToggleArea = false
    var lastExplicitInputAt: Date?
    var breakRemaining = 0
    var workSeconds = 0
    var breakSeconds = 0
    var aiDoneCount = 0
    var waterCheckins = 0
    var totalPrintableKeys = 0
    var totalCorrectionKeys = 0
    var activeTypingSeconds = 0
    var lastTypingAt: Date?
    var keyEventsInLastMinute = [(time: Date, isCorrection: Bool)]()
    var activeTypingSecondMarks = [Date]()
    var lastTypingKeyRecord = [UInt16: Date]()
    var totalActions = 0
    var activeActionSeconds = 0
    var lastActionAt: Date?
    var actionEventsInLastMinute = [Date]()
    var activeActionSecondMarks = [Date]()
    var inputMonitoringTrusted = CGPreflightListenEventAccess()
    var accessibilityTrusted = AXIsProcessTrusted()
    var inputEventTapActive = false
    var inputCaptureChannel = "未启动"
    var remindersEnabled = true
    var softReminders: [SoftReminder]
    var aiRemindersEnabled = true
    var showPersistentIsland = true
    var islandScale = 1.0
    var preventSleepEnabled = false
    var startAtLoginEnabled = false
    var lastReminderMinuteKeys = Set<String>()
    var knownWatchFiles = Set<String>()
    var knownCodexTurns = Set<String>()
    var codexScanTick = 0
    var recordSaveTick = 0
    var currentDayKey = Date().dayKey
    var dailyRecords = [String: DailyRecord]()
    var aiToolStatus = "AI 工具检测准备中"
    var sleepAssertionID: IOPMAssertionID = 0
    var panelVisualMode: CharacterMode?
    var panelVisualExpiresAt: Date?

    let watchFolder: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Codex/.character-efficiency-island-ai-watch", isDirectory: true)
    let codexThreadHistoryDB: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/thread_history_1.sqlite")
    let claudeRoot: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude", isDirectory: true)
    let cursorRoot: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Cursor", isDirectory: true)
    let terminalBridgeFolder: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Codex/.character-efficiency-island-ai-watch/terminal", isDirectory: true)

    init() {
        let storedSettings = Self.loadStoredSettings()
        if let reminders = storedSettings?.softReminders, !reminders.isEmpty {
            softReminders = reminders
        } else if let data = UserDefaults.standard.data(forKey: reminderDefaultsKey),
           let reminders = try? JSONDecoder().decode([SoftReminder].self, from: data),
           !reminders.isEmpty {
            softReminders = reminders
        } else {
            softReminders = SoftReminder.defaults
        }
        softReminders = Self.normalizedReminders(softReminders)

        if let storedSettings {
            showPersistentIsland = storedSettings.showPersistentIsland
            if let scale = storedSettings.islandScale {
                islandScale = Self.clampedIslandScale(scale)
            }
        } else if UserDefaults.standard.object(forKey: islandDefaultsKey) != nil {
            showPersistentIsland = UserDefaults.standard.bool(forKey: islandDefaultsKey)
        }
        if storedSettings?.islandScale == nil,
           UserDefaults.standard.object(forKey: islandScaleDefaultsKey) != nil {
            islandScale = Self.clampedIslandScale(UserDefaults.standard.double(forKey: islandScaleDefaultsKey))
        }

        dailyRecords = Self.loadDailyRecords()
        applyTodayRecord()
        saveReminders()
    }

    private static func clampedIslandScale(_ scale: Double) -> Double {
        min(1.6, max(0.75, scale))
    }

    private static func loadStoredSettings() -> StoredSettings? {
        guard let data = try? Data(contentsOf: settingsFile) else { return nil }
        return try? JSONDecoder().decode(StoredSettings.self, from: data)
    }

    private static func loadDailyRecords() -> [String: DailyRecord] {
        guard let data = try? Data(contentsOf: recordsFile) else { return [:] }
        return (try? JSONDecoder().decode([String: DailyRecord].self, from: data)) ?? [:]
    }

    private static func normalizedReminders(_ reminders: [SoftReminder]) -> [SoftReminder] {
        var byID = [String: SoftReminder]()
        for reminder in reminders {
            byID[reminder.id] = reminder
        }
        let order = SoftReminder.defaults.map(\.id)
        return order.compactMap { id in
            guard var reminder = byID.removeValue(forKey: id) ?? SoftReminder.defaults.first(where: { $0.id == id }) else {
                return nil
            }
            if id == "water" {
                reminder.title = "喝水"
                reminder.kind = .interval
            }
            return reminder
        }
    }

    private func applyTodayRecord() {
        guard let record = dailyRecords[currentDayKey] else { return }
        workSeconds = record.workSeconds
        breakSeconds = record.breakSeconds
        aiDoneCount = record.aiDoneCount
        waterCheckins = record.waterCheckins
        totalPrintableKeys = record.printableKeys
        totalCorrectionKeys = record.correctionKeys
        activeTypingSeconds = record.activeTypingSeconds
        totalActions = record.actionCount
        activeActionSeconds = record.activeActionSeconds
    }

    func formatted(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    func enableNoSleep(_ enabled: Bool) {
        preventSleepEnabled = enabled
        if enabled, sleepAssertionID == 0 {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "角色效率岛防休眠" as CFString,
                &sleepAssertionID
            )
        } else if !enabled, sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }

    func updateReminder(id: String, enabled: Bool? = nil, title: String? = nil, schedule: String? = nil) {
        guard let index = softReminders.firstIndex(where: { $0.id == id }) else { return }
        if let enabled {
            softReminders[index].enabled = enabled
        }
        if let title, !softReminders[index].isLockedWater {
            softReminders[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let schedule {
            softReminders[index].schedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if enabled != nil {
            remindersEnabled = softReminders.contains { $0.enabled }
        }
        saveReminders()
    }

    func setAllRemindersEnabled(_ enabled: Bool) {
        remindersEnabled = enabled
        for index in softReminders.indices {
            softReminders[index].enabled = enabled
        }
        saveReminders()
    }

    func saveReminders() {
        if let data = try? JSONEncoder().encode(softReminders) {
            UserDefaults.standard.set(data, forKey: reminderDefaultsKey)
        }
        saveSettingsFile()
    }

    func saveIslandPreference() {
        UserDefaults.standard.set(showPersistentIsland, forKey: islandDefaultsKey)
        UserDefaults.standard.set(islandScale, forKey: islandScaleDefaultsKey)
        saveSettingsFile()
    }

    func updateIslandScale(_ scale: Double) {
        islandScale = Self.clampedIslandScale(scale)
        saveIslandPreference()
    }

    private func saveSettingsFile() {
        let settings = StoredSettings(
            softReminders: softReminders,
            showPersistentIsland: showPersistentIsland,
            islandScale: islandScale
        )
        guard let data = try? JSONEncoder().encode(settings) else { return }
        let folder = Self.settingsFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: Self.settingsFile, options: .atomic)
    }

    func recordsFolderURL() -> URL {
        Self.recordsFile.deletingLastPathComponent()
    }

    func currentDailyRecord() -> DailyRecord {
        DailyRecord(
            date: currentDayKey,
            workSeconds: workSeconds,
            breakSeconds: breakSeconds,
            aiDoneCount: aiDoneCount,
            waterCheckins: waterCheckins,
            printableKeys: totalPrintableKeys,
            correctionKeys: totalCorrectionKeys,
            activeTypingSeconds: activeTypingSeconds,
            actionCount: totalActions,
            activeActionSeconds: activeActionSeconds
        )
    }

    func saveTodayRecord() {
        dailyRecords[currentDayKey] = currentDailyRecord()
        guard let data = try? JSONEncoder().encode(dailyRecords) else { return }
        let folder = Self.recordsFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: Self.recordsFile, options: .atomic)
    }

    func saveTodayRecordOccasionally() {
        recordSaveTick += 1
        guard recordSaveTick >= 10 else { return }
        recordSaveTick = 0
        saveTodayRecord()
    }

    func clearTodayRecord() {
        dailyRecords[currentDayKey] = DailyRecord(date: currentDayKey)
        saveTodayRecord()
    }

    func clearAllRecords() {
        dailyRecords.removeAll()
        resetRecordCounters()
        recordSaveTick = 0
        guard let data = try? JSONEncoder().encode(dailyRecords) else { return }
        let folder = Self.recordsFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: Self.recordsFile, options: .atomic)
    }

    func resetRecordCounters() {
        workSeconds = 0
        breakSeconds = 0
        aiDoneCount = 0
        waterCheckins = 0
        totalPrintableKeys = 0
        totalCorrectionKeys = 0
        activeTypingSeconds = 0
        lastTypingAt = nil
        keyEventsInLastMinute.removeAll()
        activeTypingSecondMarks.removeAll()
        lastTypingKeyRecord.removeAll()
        totalActions = 0
        activeActionSeconds = 0
        lastActionAt = nil
        actionEventsInLastMinute.removeAll()
        activeActionSecondMarks.removeAll()
    }

    func recordsSnapshot() -> [String: DailyRecord] {
        var records = dailyRecords
        let today = currentDailyRecord()
        if today.hasActivity || records[currentDayKey] != nil {
            records[currentDayKey] = today
        }
        return records
    }

    var activeRecordDays: Int {
        recordsSnapshot().values.filter(\.hasActivity).count
    }

    var totalRecord: DailyRecord {
        recordsSnapshot().values.reduce(DailyRecord(date: "total")) { partial, record in
            guard record.hasActivity else { return partial }
            return DailyRecord(
                date: "total",
                workSeconds: partial.workSeconds + record.workSeconds,
                breakSeconds: partial.breakSeconds + record.breakSeconds,
                aiDoneCount: partial.aiDoneCount + record.aiDoneCount,
                waterCheckins: partial.waterCheckins + record.waterCheckins,
                printableKeys: partial.printableKeys + record.printableKeys,
                correctionKeys: partial.correctionKeys + record.correctionKeys,
                activeTypingSeconds: partial.activeTypingSeconds + record.activeTypingSeconds,
                actionCount: partial.actionCount + record.actionCount,
                activeActionSeconds: partial.activeActionSeconds + record.activeActionSeconds
            )
        }
    }

    func rolloverDayIfNeeded(now: Date = Date()) {
        let key = now.dayKey
        guard key != currentDayKey else { return }
        saveTodayRecord()
        currentDayKey = key
        workSeconds = 0
        breakSeconds = 0
        aiDoneCount = 0
        waterCheckins = 0
        totalPrintableKeys = 0
        totalCorrectionKeys = 0
        activeTypingSeconds = 0
        totalActions = 0
        activeActionSeconds = 0
        keyEventsInLastMinute.removeAll()
        activeTypingSecondMarks.removeAll()
        actionEventsInLastMinute.removeAll()
        activeActionSecondMarks.removeAll()
        lastTypingKeyRecord.removeAll()
        lastReminderMinuteKeys.removeAll()
        applyTodayRecord()
    }

    func recordTypingEvent(isCorrection: Bool, at date: Date = Date()) {
        if isCorrection {
            totalCorrectionKeys += 1
        } else {
            totalPrintableKeys += 1
        }
        lastTypingAt = date
        keyEventsInLastMinute.append((date, isCorrection))
        pruneTypingWindows(now: date)
    }

    func recordWaterCheckin() {
        waterCheckins += 1
        saveTodayRecord()
    }

    func setPanelVisualMode(_ mode: CharacterMode, duration: TimeInterval) {
        panelVisualMode = mode
        panelVisualExpiresAt = Date().addingTimeInterval(duration)
    }

    func clearPanelVisualMode() {
        panelVisualMode = nil
        panelVisualExpiresAt = nil
    }

    func currentPanelMode(now: Date = Date()) -> CharacterMode {
        if let panelVisualMode, let expiresAt = panelVisualExpiresAt, now < expiresAt {
            return panelVisualMode
        }
        clearPanelVisualMode()
        return mode
    }

    func recordActionEvent(at date: Date = Date()) {
        totalActions += 1
        lastActionAt = date
        actionEventsInLastMinute.append(date)
        pruneActionWindows(now: date)
    }

    func shouldAcceptTypingKey(_ keyCode: UInt16, at date: Date = Date()) -> Bool {
        if let last = lastTypingKeyRecord[keyCode], date.timeIntervalSince(last) < 0.05 {
            return false
        }
        lastTypingKeyRecord[keyCode] = date
        return true
    }

    func markActiveTypingSecond(now: Date = Date()) {
        if let lastTypingAt, now.timeIntervalSince(lastTypingAt) <= 5 {
            activeTypingSeconds += 1
            activeTypingSecondMarks.append(now)
        }
        if let lastActionAt, now.timeIntervalSince(lastActionAt) <= 5 {
            activeActionSeconds += 1
            activeActionSecondMarks.append(now)
        }
        pruneTypingWindows(now: now)
        pruneActionWindows(now: now)
    }

    func pruneTypingWindows(now: Date = Date()) {
        keyEventsInLastMinute.removeAll { now.timeIntervalSince($0.time) > 60 }
        activeTypingSecondMarks.removeAll { now.timeIntervalSince($0) > 60 }
    }

    func pruneActionWindows(now: Date = Date()) {
        actionEventsInLastMinute.removeAll { now.timeIntervalSince($0) > 60 }
        activeActionSecondMarks.removeAll { now.timeIntervalSince($0) > 60 }
    }

    var totalEffectiveKeys: Int {
        max(0, totalPrintableKeys - totalCorrectionKeys)
    }

    var typingCorrectionRate: Int {
        guard totalPrintableKeys > 0 else { return 0 }
        return Int((Double(totalCorrectionKeys) / Double(totalPrintableKeys) * 100).rounded())
    }

    var averageEffectiveSpeed: Int {
        guard activeTypingSeconds > 0 else { return 0 }
        return Int((Double(totalEffectiveKeys) / Double(activeTypingSeconds) * 60).rounded())
    }

    var currentRawSpeed: Int {
        let activeSeconds = max(1, activeTypingSecondMarks.count)
        let printable = keyEventsInLastMinute.filter { !$0.isCorrection }.count
        return Int((Double(printable) / Double(activeSeconds) * 60).rounded())
    }

    var currentEffectiveSpeed: Int {
        let activeSeconds = max(1, activeTypingSecondMarks.count)
        let printable = keyEventsInLastMinute.filter { !$0.isCorrection }.count
        let corrections = keyEventsInLastMinute.filter(\.isCorrection).count
        return Int((Double(max(0, printable - corrections)) / Double(activeSeconds) * 60).rounded())
    }

    var currentAPM: Int {
        let activeSeconds = max(1, activeActionSecondMarks.count)
        return Int((Double(actionEventsInLastMinute.count) / Double(activeSeconds) * 60).rounded())
    }

    var averageAPM: Int {
        guard activeActionSeconds > 0 else { return 0 }
        return Int((Double(totalActions) / Double(activeActionSeconds) * 60).rounded())
    }
}

@MainActor
final class ResizableIslandView: NSVisualEffectView {
    struct ResizeEdges: OptionSet {
        let rawValue: Int
        static let left = ResizeEdges(rawValue: 1 << 0)
        static let right = ResizeEdges(rawValue: 1 << 1)
        static let top = ResizeEdges(rawValue: 1 << 2)
        static let bottom = ResizeEdges(rawValue: 1 << 3)
    }

    var currentScaleProvider: (() -> Double)?
    var resizeHandler: ((Double) -> Void)?
    var resizeEndedHandler: (() -> Void)?
    private let baseSize: NSSize
    private let edgeBand: CGFloat = 9
    private var dragEdges: ResizeEdges = []
    private var dragStartMouse = NSPoint.zero
    private var dragStartScale = 1.0
    private(set) var isResizing = false

    init(baseSize: NSSize) {
        self.baseSize = baseSize
        super.init(frame: NSRect(origin: .zero, size: baseSize))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func isNearResizeEdge(globalMouse: NSPoint, panelFrame: NSRect) -> Bool {
        guard NSMouseInRect(globalMouse, panelFrame.insetBy(dx: -8, dy: -8), false) else { return false }
        let point = NSPoint(x: globalMouse.x - panelFrame.minX, y: globalMouse.y - panelFrame.minY)
        return !resizeEdges(at: point, size: panelFrame.size).isEmpty
    }

    override func mouseDown(with event: NSEvent) {
        dragEdges = resizeEdges(at: convert(event.locationInWindow, from: nil), size: bounds.size)
        guard !dragEdges.isEmpty else { return }
        isResizing = true
        dragStartMouse = NSEvent.mouseLocation
        dragStartScale = currentScaleProvider?() ?? 1.0
    }

    override func mouseDragged(with event: NSEvent) {
        guard isResizing else { return }
        let mouse = NSEvent.mouseLocation
        let delta = NSPoint(x: mouse.x - dragStartMouse.x, y: mouse.y - dragStartMouse.y)
        var scaleDeltas = [Double]()

        if dragEdges.contains(.right) {
            scaleDeltas.append(Double(delta.x / baseSize.width))
        }
        if dragEdges.contains(.left) {
            scaleDeltas.append(Double(-delta.x / baseSize.width))
        }
        if dragEdges.contains(.top) {
            scaleDeltas.append(Double(delta.y / baseSize.width))
        }
        if dragEdges.contains(.bottom) {
            scaleDeltas.append(Double(-delta.y / baseSize.width))
        }

        guard let strongestDelta = scaleDeltas.max(by: { abs($0) < abs($1) }) else { return }
        resizeHandler?(dragStartScale + strongestDelta)
    }

    override func mouseUp(with event: NSEvent) {
        guard isResizing else { return }
        isResizing = false
        dragEdges = []
        resizeEndedHandler?()
    }

    private func resizeEdges(at point: NSPoint, size: NSSize) -> ResizeEdges {
        let scale = currentScaleProvider?() ?? 1.0
        let activeBand = max(8, edgeBand * scale)
        var edges: ResizeEdges = []
        if point.x <= activeBand {
            edges.insert(.left)
        }
        if point.x >= size.width - activeBand {
            edges.insert(.right)
        }
        if point.y <= activeBand {
            edges.insert(.bottom)
        }
        if point.y >= size.height - activeBand {
            edges.insert(.top)
        }
        return edges
    }
}

@MainActor
final class IslandController {
    private let panelSize = NSSize(width: 316, height: 68)
    private let minScale = 0.75
    private let maxScale = 1.6
    private let panel: NSPanel
    private let container: ResizableIslandView
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let timerLabel = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private var hideWorkItem: DispatchWorkItem?
    private var persistentSnapshot: (mode: CharacterMode, detail: String, timer: String?)?
    private var showingTransient = false
    private var currentMode: CharacterMode = .working
    private var hoverTimer: Timer?
    private var islandScale = 1.0
    var onScaleChanged: ((Double) -> Void)?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true

        container = ResizableIslandView(baseSize: panelSize)
        container.material = .hudWindow
        container.blendingMode = .withinWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 20
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.86).cgColor
        container.layer?.masksToBounds = true
        container.currentScaleProvider = { [weak self] in
            self?.islandScale ?? 1.0
        }
        container.resizeHandler = { [weak self] scale in
            self?.setScale(scale, persist: false, keepCurrentCenter: true)
        }
        container.resizeEndedHandler = { [weak self] in
            guard let self else { return }
            self.onScaleChanged?(self.islandScale)
            self.updateHoverVisibility()
        }
        panel.contentView = container

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.contentTintColor = NSColor(calibratedRed: 0.94, green: 0.18, blue: 0.2, alpha: 1)
        iconView.translatesAutoresizingMaskIntoConstraints = true

        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = true

        detailLabel.textColor = .white.withAlphaComponent(0.72)
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.maximumNumberOfLines = 1
        detailLabel.translatesAutoresizingMaskIntoConstraints = true

        timerLabel.textColor = .white.withAlphaComponent(0.95)
        timerLabel.lineBreakMode = .byTruncatingTail
        timerLabel.maximumNumberOfLines = 1
        timerLabel.translatesAutoresizingMaskIntoConstraints = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = true

        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(detailLabel)
        container.addSubview(timerLabel)
        container.addSubview(imageView)
        layoutContent()

        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHoverVisibility()
            }
        }
    }

    func setScale(_ scale: Double, persist: Bool = true, keepCurrentCenter: Bool = false) {
        let clamped = min(maxScale, max(minScale, scale))
        guard abs(clamped - islandScale) > 0.001 else { return }

        let oldFrame = panel.frame
        let center = NSPoint(x: oldFrame.midX, y: oldFrame.midY)
        islandScale = clamped

        let scaledSize = NSSize(
            width: panelSize.width * clamped,
            height: panelSize.height * clamped
        )
        var frame = NSRect(origin: oldFrame.origin, size: scaledSize)
        if keepCurrentCenter, oldFrame.width > 0, oldFrame.height > 0 {
            frame.origin = NSPoint(x: center.x - scaledSize.width / 2, y: center.y - scaledSize.height / 2)
        }

        panel.setFrame(frame, display: true)
        container.frame = NSRect(origin: .zero, size: scaledSize)
        container.bounds = NSRect(origin: .zero, size: scaledSize)
        container.needsLayout = true
        layoutContent()

        if !keepCurrentCenter {
            position()
        }
        if persist {
            onScaleChanged?(clamped)
        }
        updateHoverVisibility()
    }

    func resetScale() {
        setScale(1.0)
    }

    var scalePercent: Int {
        Int((islandScale * 100).rounded())
    }

    func show(mode: CharacterMode, detail: String, timer: String? = nil, autoHideAfter seconds: TimeInterval? = nil) {
        if seconds == nil {
            persistentSnapshot = (mode, detail, timer)
            if showingTransient {
                return
            }
        } else {
            showingTransient = true
        }

        render(mode: mode, detail: detail, timer: timer)
        position()
        panel.orderFrontRegardless()
        hideWorkItem?.cancel()

        if let seconds {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.showingTransient = false
                if let snapshot = self.persistentSnapshot {
                    self.render(mode: snapshot.mode, detail: snapshot.detail, timer: snapshot.timer)
                    self.position()
                    self.panel.orderFrontRegardless()
                } else {
                    self.panel.orderOut(nil)
                }
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
        }
    }

    func clearPersistentSnapshot() {
        persistentSnapshot = nil
        if !showingTransient {
            panel.orderOut(nil)
        }
    }

    private func render(mode: CharacterMode, detail: String, timer: String?) {
        currentMode = mode
        iconView.image = NSImage(systemSymbolName: mode.symbolName, accessibilityDescription: mode.title)
        titleLabel.stringValue = mode.title
        detailLabel.stringValue = detail
        timerLabel.stringValue = timer ?? ""
        imageView.image = loadImage(named: mode.assetName)
        layoutContent()
        updateHoverVisibility()
    }

    private func layoutContent() {
        let scale = CGFloat(islandScale)
        let size = NSSize(width: panelSize.width * scale, height: panelSize.height * scale)
        container.frame = NSRect(origin: .zero, size: size)
        container.bounds = NSRect(origin: .zero, size: size)
        container.layer?.cornerRadius = 20 * scale

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16 * scale, weight: .semibold)
        titleLabel.font = .systemFont(ofSize: 16 * scale, weight: .bold)
        detailLabel.font = .systemFont(ofSize: 10 * scale, weight: .medium)
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 14 * scale, weight: .semibold)

        let leftPadding = 20 * scale
        let imageWidth = 48 * scale
        let imageHeight = 58 * scale
        let imageRightPadding = 12 * scale
        let textGap = 8 * scale
        let rowGap = 7 * scale
        let titleTop = 16 * scale
        let iconSize = 20 * scale
        let titleHeight = 22 * scale
        let detailHeight = 14 * scale
        let imageFrame = NSRect(
            x: size.width - imageRightPadding - imageWidth,
            y: 5 * scale,
            width: imageWidth,
            height: imageHeight
        )
        imageView.frame = imageFrame

        let titleX = leftPadding + iconSize + textGap
        let titleY = size.height - titleTop - titleHeight
        let availableTextRight = imageFrame.minX - 10 * scale
        let timerWidth = timerLabel.stringValue.isEmpty ? 0 : min(timerLabel.intrinsicContentSize.width + 4 * scale, 70 * scale)
        let timerGap = timerWidth > 0 ? 10 * scale : 0
        let titleWidth = max(30 * scale, availableTextRight - titleX - timerWidth - timerGap)

        iconView.frame = NSRect(
            x: leftPadding,
            y: titleY + (titleHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        titleLabel.frame = NSRect(x: titleX, y: titleY, width: titleWidth, height: titleHeight)
        timerLabel.frame = NSRect(
            x: titleX + titleWidth + timerGap,
            y: titleY + 1 * scale,
            width: timerWidth,
            height: titleHeight
        )
        detailLabel.frame = NSRect(
            x: titleX,
            y: titleY - rowGap - detailHeight,
            width: max(30 * scale, availableTextRight - titleX),
            height: detailHeight
        )
    }

    private func position() {
        if let screen = NSScreen.main {
            let width = panel.frame.width
            let height = panel.frame.height
            let x = screen.frame.midX - width / 2
            let y = screen.frame.maxY - height - 30
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        panel.alphaValue = 1
        panel.orderOut(nil)
    }

    func containsMouse(expandedBy padding: CGFloat = 0) -> Bool {
        guard panel.isVisible else { return false }
        return NSMouseInRect(NSEvent.mouseLocation, panel.frame.insetBy(dx: -padding, dy: -padding), false)
    }

    private func updateHoverVisibility() {
        guard panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        let nearResizeEdge = container.isResizing || container.isNearResizeEdge(globalMouse: mouse, panelFrame: panel.frame)
        panel.ignoresMouseEvents = !nearResizeEdge

        guard currentMode != .breakTime else {
            panel.alphaValue = 1
            return
        }

        let hoverFrame = panel.frame.insetBy(dx: -6, dy: -6)
        if nearResizeEdge {
            panel.alphaValue = 0.62
        } else {
            panel.alphaValue = NSMouseInRect(mouse, hoverFrame, false) ? 0.04 : 1
        }
    }

    private func loadImage(named name: String) -> NSImage? {
        ImageResources.load(named: name)
    }
}

@MainActor
final class ControlPanelViewController: NSViewController, NSTextFieldDelegate {
    static let panelWidth: CGFloat = 520
    static let panelBodyHeight: CGFloat = 500
    static let bottomCharacterOverflow: CGFloat = 150

    private struct CharacterPlacement {
        let height: CGFloat
        let bottom: CGFloat
        let trailing: CGFloat
    }

    private let state: AppState
    private let island: IslandController
    private let resetAction: () -> Void
    private let resetAllAction: () -> Void
    private let titleLabel = NSTextField(labelWithString: "角色工作中")
    private let subtitleLabel = NSTextField(labelWithString: "当前计划正在执行，请保持节奏。")
    private let workLabel = NSTextField(labelWithString: "工作 00:00")
    private let breakLabel = NSTextField(labelWithString: "休息 00:00")
    private let aiLabel = NSTextField(labelWithString: "AI 完成 0")
    private let idleLabel = NSTextField(labelWithString: "键鼠空闲 00:00")
    private let todayRecordLabel = NSTextField(labelWithString: "今天 工作 00:00 · 休息 00:00 · AI 0")
    private let totalRecordLabel = NSTextField(labelWithString: "累计 0 天 · 工作 00:00 · 字 0 · AI 0")
    private let typingTotalLabel = NSTextField(labelWithString: "打字量 0")
    private let typingRawSpeedLabel = NSTextField(labelWithString: "当前 0/min")
    private let typingCorrectionLabel = NSTextField(labelWithString: "修正率 0%")
    private let typingAverageLabel = NSTextField(labelWithString: "均速 0/min")
    private let apmLabel = NSTextField(labelWithString: "APM 0/min")
    private let waterCheckinLabel = NSTextField(labelWithString: "喝水 0")
    private let inputPermissionLabel = NSTextField(labelWithString: "输入权限：检查中")
    private let toolStatusLabel = NSTextField(labelWithString: "AI 工具检测准备中")
    private let islandScaleLabel = NSTextField(labelWithString: "小岛大小 100%")
    private let characterView = TransparentCharacterView()
    private var buttons = [String: NSButton]()
    private var reminderControls = [String: (enabled: NSButton, title: NSTextField, schedule: NSTextField)]()

    init(
        state: AppState,
        island: IslandController,
        resetAction: @escaping () -> Void,
        resetAllAction: @escaping () -> Void
    ) {
        self.state = state
        self.island = island
        self.resetAction = resetAction
        self.resetAllAction = resetAllAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: Self.panelWidth,
                height: Self.panelBodyHeight + Self.bottomCharacterOverflow
            )
        )
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.masksToBounds = false

        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 22
        blur.layer?.masksToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blur, positioned: .below, relativeTo: nil)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 14, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let typingStack = NSStackView()
        typingStack.orientation = .vertical
        typingStack.alignment = .leading
        typingStack.spacing = 6
        typingStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(typingStack)

        let typingTitle = NSTextField(labelWithString: "输入仪表")
        typingTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        typingTitle.textColor = .secondaryLabelColor
        typingStack.addArrangedSubview(typingTitle)

        [typingTotalLabel, typingRawSpeedLabel, typingCorrectionLabel, typingAverageLabel, apmLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            $0.textColor = .labelColor
            $0.lineBreakMode = .byTruncatingTail
            $0.maximumNumberOfLines = 1
            typingStack.addArrangedSubview($0)
        }

        inputPermissionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        inputPermissionLabel.textColor = .secondaryLabelColor
        inputPermissionLabel.lineBreakMode = .byTruncatingTail
        inputPermissionLabel.maximumNumberOfLines = 2
        typingStack.addArrangedSubview(inputPermissionLabel)
        typingStack.addArrangedSubview(actionButton("打开权限", #selector(openInputPermissions)))
        typingStack.addArrangedSubview(actionButton("修复权限", #selector(resetInputPermissions)))

        titleLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(separator())

        let stats = NSStackView()
        stats.orientation = .horizontal
        stats.spacing = 14
        [workLabel, breakLabel, aiLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
            stats.addArrangedSubview($0)
        }
        stack.addArrangedSubview(stats)

        idleLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        idleLabel.textColor = .secondaryLabelColor
        waterCheckinLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        waterCheckinLabel.textColor = .secondaryLabelColor
        let idleRow = NSStackView()
        idleRow.orientation = .horizontal
        idleRow.alignment = .centerY
        idleRow.spacing = 8
        idleRow.addArrangedSubview(idleLabel)
        idleRow.addArrangedSubview(actionButton("喝水打卡", #selector(checkInWater)))
        idleRow.addArrangedSubview(waterCheckinLabel)
        stack.addArrangedSubview(idleRow)

        [todayRecordLabel, totalRecordLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            $0.textColor = .tertiaryLabelColor
            $0.lineBreakMode = .byTruncatingTail
            $0.maximumNumberOfLines = 1
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
            $0.widthAnchor.constraint(equalToConstant: 310).isActive = true
            stack.addArrangedSubview($0)
        }

        stack.addArrangedSubview(section("定时提醒"))
        addCheckbox("reminders", "启用定时提醒", enabled: state.remindersEnabled, to: stack)
        let reminderStack = NSStackView()
        reminderStack.orientation = .vertical
        reminderStack.alignment = .leading
        reminderStack.spacing = 3
        reminderStack.translatesAutoresizingMaskIntoConstraints = false
        state.softReminders.forEach { addReminderRow($0, to: reminderStack) }
        stack.addArrangedSubview(reminderStack)

        stack.addArrangedSubview(separator())
        let functionLabel = section("功能")
        stack.addArrangedSubview(functionLabel)
        addCheckbox("ai", "AI 完成提醒", enabled: state.aiRemindersEnabled, to: stack)
        addCheckbox("island", "顶部常驻小岛", enabled: state.showPersistentIsland, to: stack)

        let islandScaleRow = NSStackView()
        islandScaleRow.orientation = .horizontal
        islandScaleRow.spacing = 8
        islandScaleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        islandScaleLabel.textColor = .secondaryLabelColor
        islandScaleLabel.widthAnchor.constraint(equalToConstant: 92).isActive = true
        islandScaleRow.addArrangedSubview(islandScaleLabel)
        islandScaleRow.addArrangedSubview(actionButton("重置小岛大小", #selector(resetIslandScale)))
        stack.addArrangedSubview(islandScaleRow)

        addCheckbox("nosleep", "禁止休眠", enabled: state.preventSleepEnabled, to: stack)
        addCheckbox("login", "登录时启动角色", enabled: state.startAtLoginEnabled, to: stack)

        let buttonRowA = NSStackView()
        buttonRowA.orientation = .horizontal
        buttonRowA.spacing = 8
        buttonRowA.addArrangedSubview(actionButton("休息 5 分钟", #selector(startBreak)))
        buttonRowA.addArrangedSubview(actionButton("结束休息", #selector(endBreak)))
        buttonRowA.addArrangedSubview(actionButton("暂停/继续", #selector(togglePause)))
        stack.addArrangedSubview(buttonRowA)

        let buttonRowC = NSStackView()
        buttonRowC.orientation = .horizontal
        buttonRowC.spacing = 6
        buttonRowC.addArrangedSubview(actionButton("清零今日", #selector(resetCounters)))
        buttonRowC.addArrangedSubview(actionButton("清空全部", #selector(resetAllCounters)))
        buttonRowC.addArrangedSubview(actionButton("打开记录", #selector(openRecords)))
        buttonRowC.addArrangedSubview(actionButton("退出", #selector(quitApp)))
        stack.addArrangedSubview(buttonRowC)

        toolStatusLabel.font = .systemFont(ofSize: 11)
        toolStatusLabel.textColor = .tertiaryLabelColor
        toolStatusLabel.lineBreakMode = .byTruncatingTail
        toolStatusLabel.maximumNumberOfLines = 1
        toolStatusLabel.widthAnchor.constraint(equalToConstant: 310).isActive = true
        stack.addArrangedSubview(toolStatusLabel)

        characterView.image = loadImage(named: CharacterMode.working.panelAssetName)
        characterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(characterView, positioned: .above, relativeTo: blur)

        let initialPlacement = characterPlacement(for: .working)
        characterView.imageHeight = initialPlacement.height
        characterView.imageBottom = initialPlacement.bottom
        characterView.imageTrailing = initialPlacement.trailing

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.heightAnchor.constraint(equalToConstant: Self.panelBodyHeight),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.topAnchor.constraint(equalTo: blur.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: blur.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: 325),
            typingStack.trailingAnchor.constraint(equalTo: blur.trailingAnchor, constant: -22),
            typingStack.topAnchor.constraint(equalTo: blur.topAnchor, constant: 38),
            typingStack.widthAnchor.constraint(equalToConstant: 142),
            characterView.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            characterView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            characterView.widthAnchor.constraint(equalToConstant: 340),
            characterView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
    }

    func refresh() {
        let panelMode = state.currentPanelMode()
        titleLabel.stringValue = panelMode.title
        subtitleLabel.stringValue = subtitle(for: panelMode)
        workLabel.stringValue = "工作 \(state.formatted(state.workSeconds))"
        breakLabel.stringValue = "休息 \(state.formatted(state.breakSeconds))"
        aiLabel.stringValue = "AI 完成 \(state.aiDoneCount)"
        idleLabel.stringValue = "键鼠空闲 \(state.formatted(currentIdleSeconds()))"
        waterCheckinLabel.stringValue = "喝水 \(state.waterCheckins)"
        typingTotalLabel.stringValue = "打字量 \(state.totalPrintableKeys)"
        typingRawSpeedLabel.stringValue = "当前 \(state.currentRawSpeed)/min"
        typingCorrectionLabel.stringValue = "修正率 \(state.typingCorrectionRate)%"
        typingAverageLabel.stringValue = "均速 \(state.averageEffectiveSpeed)/min"
        apmLabel.stringValue = "APM \(state.currentAPM)/min"
        let totalRecord = state.totalRecord
        todayRecordLabel.stringValue = "今天 工作 \(state.formatted(state.workSeconds)) · 休息 \(state.formatted(state.breakSeconds)) · 水 \(state.waterCheckins) · AI \(state.aiDoneCount)"
        totalRecordLabel.stringValue = "累计 \(state.activeRecordDays) 天 · 工作 \(state.formatted(totalRecord.workSeconds)) · 字 \(totalRecord.printableKeys) · 水 \(totalRecord.waterCheckins) · AI \(totalRecord.aiDoneCount)"
        inputPermissionLabel.stringValue = state.inputEventTapActive
            ? "输入监控：采集中 · \(state.inputCaptureChannel)"
            : inputPermissionStatusText()
        toolStatusLabel.stringValue = state.aiToolStatus
        islandScaleLabel.stringValue = "小岛大小 \(island.scalePercent)%"
        characterView.image = loadImage(named: panelMode.panelAssetName)
        applyCharacterPlacement(for: panelMode)
        buttons["reminders"]?.state = state.remindersEnabled ? .on : .off
        buttons["ai"]?.state = state.aiRemindersEnabled ? .on : .off
        buttons["island"]?.state = state.showPersistentIsland ? .on : .off
        buttons["nosleep"]?.state = state.preventSleepEnabled ? .on : .off
        buttons["login"]?.state = state.startAtLoginEnabled ? .on : .off
        for reminder in state.softReminders {
            reminderControls[reminder.id]?.enabled.state = reminder.enabled ? .on : .off
            if reminderControls[reminder.id]?.title.currentEditor() == nil {
                reminderControls[reminder.id]?.title.stringValue = reminder.title
            }
            if reminderControls[reminder.id]?.schedule.currentEditor() == nil {
                reminderControls[reminder.id]?.schedule.stringValue = reminder.schedule
            }
        }
    }

    private func applyCharacterPlacement(for mode: CharacterMode) {
        let placement = characterPlacement(for: mode)
        characterView.imageHeight = placement.height
        characterView.imageBottom = placement.bottom
        characterView.imageTrailing = placement.trailing
        characterView.setNeedsDisplay(characterView.bounds)
    }

    private func characterPlacement(for mode: CharacterMode) -> CharacterPlacement {
        switch mode {
        case .working:
            return CharacterPlacement(height: 310, bottom: 72, trailing: 42)
        case .breakTime:
            return CharacterPlacement(height: 282, bottom: 104, trailing: 12)
        case .water:
            return CharacterPlacement(height: 238, bottom: 128, trailing: -32)
        case .idle:
            return CharacterPlacement(height: 330, bottom: 52, trailing: 42)
        case .reminderSecond:
            return CharacterPlacement(height: 310, bottom: 72, trailing: 42)
        case .reminderThird:
            return CharacterPlacement(height: 232, bottom: 150, trailing: 42)
        case .reminderFourth:
            return CharacterPlacement(height: 310, bottom: 64, trailing: 42)
        case .alert, .ai:
            return CharacterPlacement(height: 230, bottom: 150, trailing: 42)
        }
    }

    private func subtitle(for mode: CharacterMode) -> String {
        switch mode {
        case .idle: return "暂无异常，等待下一项任务。"
        case .working: return "当前计划正在执行，请保持节奏。"
        case .breakTime: return "扫过小岛或状态栏可暂停/继续倒计时。"
        case .alert: return "当前效率偏离计划，请校准。"
        case .ai: return "检测到 AI 任务完成，建议验收。"
        case .water: return "喝水时间到了。"
        case .reminderSecond, .reminderThird, .reminderFourth: return "定时提醒到了，轻轻校准一下。"
        }
    }

    private func inputPermissionStatusText() -> String {
        if !state.inputMonitoringTrusted {
            return "输入监控：未授权"
        }
        if !state.accessibilityTrusted {
            return "输入监控：已授权 · 辅助功能未授权"
        }
        return "输入权限：已授权 · 通道未启动"
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func section(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func addCheckbox(_ id: String, _ title: String, enabled: Bool, to stack: NSStackView) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggle(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(id)
        button.state = enabled ? .on : .off
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor

        buttons[id] = button
        row.addArrangedSubview(button)
        row.addArrangedSubview(label)
        stack.addArrangedSubview(row)
    }

    private func addIndented(_ title: String, trailing: String, to stack: NSStackView) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let leading = NSTextField(labelWithString: "   \(title)")
        leading.font = .systemFont(ofSize: 13)
        leading.textColor = .labelColor

        let tail = NSTextField(labelWithString: trailing)
        tail.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        tail.textColor = .secondaryLabelColor

        row.addArrangedSubview(leading)
        row.addArrangedSubview(tail)
        stack.addArrangedSubview(row)
    }

    private func addReminderRow(_ reminder: SoftReminder, to stack: NSStackView) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggle(_:)))
        checkbox.identifier = NSUserInterfaceItemIdentifier("reminder-enabled-\(reminder.id)")
        checkbox.state = reminder.enabled ? .on : .off
        checkbox.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let titleField = NSTextField(string: reminder.title)
        titleField.identifier = NSUserInterfaceItemIdentifier("reminder-title-\(reminder.id)")
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.bezelStyle = .roundedBezel
        titleField.widthAnchor.constraint(equalToConstant: 106).isActive = true
        titleField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        if reminder.isLockedWater {
            titleField.isEditable = false
            titleField.isSelectable = false
            titleField.isEnabled = true
            titleField.textColor = .labelColor
        } else {
            titleField.isEditable = true
            titleField.delegate = self
            titleField.target = self
            titleField.action = #selector(commitReminderField(_:))
        }

        let scheduleField = NSTextField(string: reminder.schedule)
        scheduleField.identifier = NSUserInterfaceItemIdentifier("reminder-schedule-\(reminder.id)")
        scheduleField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        scheduleField.textColor = .secondaryLabelColor
        scheduleField.delegate = self
        scheduleField.target = self
        scheduleField.action = #selector(commitReminderField(_:))
        scheduleField.bezelStyle = .roundedBezel
        scheduleField.widthAnchor.constraint(equalToConstant: 82).isActive = true
        scheduleField.heightAnchor.constraint(equalToConstant: 24).isActive = true

        row.addArrangedSubview(checkbox)
        row.addArrangedSubview(titleField)
        row.addArrangedSubview(scheduleField)
        reminderControls[reminder.id] = (checkbox, titleField, scheduleField)
        stack.addArrangedSubview(row)
    }

    private func actionButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        return button
    }

    @objc private func toggle(_ sender: NSButton) {
        switch sender.identifier?.rawValue {
        case "reminders":
            state.setAllRemindersEnabled(sender.state == .on)
        case "ai":
            state.aiRemindersEnabled = sender.state == .on
        case "island":
            state.showPersistentIsland = sender.state == .on
            state.saveIslandPreference()
            if !state.showPersistentIsland {
                island.clearPersistentSnapshot()
            } else {
                island.show(mode: state.isOnBreak ? .breakTime : state.mode, detail: "顶部小岛已恢复。")
            }
        case "nosleep":
            state.enableNoSleep(sender.state == .on)
        case "login":
            state.startAtLoginEnabled = sender.state == .on
            island.show(mode: .alert, detail: "登录启动需要打包成 .app 后接入。当前先保存开关状态。", autoHideAfter: 4)
        default:
            if let id = sender.identifier?.rawValue.replacingOccurrences(of: "reminder-enabled-", with: ""),
               sender.identifier?.rawValue.hasPrefix("reminder-enabled-") == true {
                state.updateReminder(id: id, enabled: sender.state == .on)
            }
            break
        }
        refresh()
    }

    @objc private func commitReminderField(_ sender: NSTextField) {
        applyReminderField(sender)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        applyReminderField(field)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        applyReminderField(field)
    }

    private func applyReminderField(_ field: NSTextField) {
        guard let raw = field.identifier?.rawValue else { return }
        if raw.hasPrefix("reminder-title-") {
            state.updateReminder(id: raw.replacingOccurrences(of: "reminder-title-", with: ""), title: field.stringValue)
        } else if raw.hasPrefix("reminder-schedule-") {
            state.updateReminder(id: raw.replacingOccurrences(of: "reminder-schedule-", with: ""), schedule: field.stringValue)
        }
    }

    @objc private func resetIslandScale() {
        island.resetScale()
        refresh()
        island.show(mode: state.isOnBreak ? .breakTime : state.mode, detail: "顶部小岛大小已重置。", autoHideAfter: 4)
    }

    @objc private func startBreak() {
        state.isOnBreak = true
        state.breakStartedAt = Date()
        state.breakStartMouseLocation = NSEvent.mouseLocation
        state.isBreakTimerPausedByMenuBar = false
        state.wasMouseInBreakToggleArea = false
        state.mode = .breakTime
        state.breakRemaining = 5 * 60
        island.show(
            mode: .breakTime,
            detail: "休息已开始。扫过小岛或状态栏可暂停倒计时。",
            timer: state.formatted(state.breakRemaining),
            autoHideAfter: state.showPersistentIsland ? nil : 5
        )
        state.clearPanelVisualMode()
        refresh()
    }

    @objc private func endBreak() {
        guard state.isOnBreak else {
            island.show(mode: .working, detail: "当前不在休息计时中。", autoHideAfter: 3)
            return
        }
        state.isOnBreak = false
        state.breakStartedAt = nil
        state.breakStartMouseLocation = nil
        state.isBreakTimerPausedByMenuBar = false
        state.wasMouseInBreakToggleArea = false
        state.mode = state.isPaused ? .idle : .working
        state.clearPanelVisualMode()
        island.show(mode: state.mode, detail: "休息已手动结束，继续执行当前计划。", autoHideAfter: 4)
        refresh()
    }

    @objc private func togglePause() {
        state.isPaused.toggle()
        state.mode = state.isPaused ? .idle : .working
        state.clearPanelVisualMode()
        island.show(
            mode: state.mode,
            detail: state.isPaused ? "计时已暂停。恢复前不计入工作或休息。" : "计时已恢复。继续执行当前计划。",
            autoHideAfter: 4
        )
        refresh()
    }

    @objc private func checkInWater() {
        let duration: TimeInterval = 7
        state.recordWaterCheckin()
        state.setPanelVisualMode(.water, duration: duration)
        NSSound(named: .init("Ping"))?.play()
        island.show(mode: .water, detail: "喝水打卡 +1。今天第 \(state.waterCheckins) 次喝水。", autoHideAfter: duration)
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.refresh()
        }
    }

    @objc private func resetCounters() {
        resetAction()
        state.clearPanelVisualMode()
        island.show(mode: .idle, detail: "今天的记录已清零。历史累计还在。", autoHideAfter: 4)
        refresh()
    }

    @objc private func resetAllCounters() {
        let alert = NSAlert()
        alert.messageText = "清空全部记录？"
        alert.informativeText = "这会清掉所有历史每日记录，以及当前面板上的今日统计。定时提醒设置不会被清掉。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空全部")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        resetAllAction()
        state.clearPanelVisualMode()
        island.show(mode: .idle, detail: "全部记录已清空。提醒设置保留。", autoHideAfter: 4)
        refresh()
    }

    @objc private func openRecords() {
        state.saveTodayRecord()
        NSWorkspace.shared.open(state.recordsFolderURL())
        island.show(mode: .alert, detail: "已打开本地记录文件夹。", autoHideAfter: 4)
    }

    @objc private func openInputPermissions() {
        state.inputMonitoringTrusted = requestInputMonitoringPermissionPrompt()
        state.accessibilityTrusted = requestAccessibilityPermissionPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        island.show(mode: .alert, detail: "请在输入监控里开启角色效率岛；若仍不动，再确认辅助功能也已开启。", autoHideAfter: 7)
        refresh()
    }

    @objc private func resetInputPermissions() {
        resetInputMonitoringPermission()
        state.inputMonitoringTrusted = false
        state.inputEventTapActive = false
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        island.show(mode: .alert, detail: "已重置输入监控记录。请重新勾选角色效率岛，然后重启 App。", autoHideAfter: 8)
        refresh()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func currentIdleSeconds() -> Int {
        currentInputIdleSeconds()
    }

    private func loadImage(named name: String) -> NSImage? {
        ImageResources.load(named: name)
    }
}

enum ImageResources {
    static func load(named name: String) -> NSImage? {
        let appResourceURL = Bundle.main.resourceURL
        let bundledResourceURL = appResourceURL?
            .appendingPathComponent("CharacterEfficiencyIsland_CharacterEfficiencyIsland.bundle", isDirectory: true)
            .appendingPathComponent("\(name).png")

        let urls = [
            Bundle.main.url(forResource: name, withExtension: "png"),
            appResourceURL?.appendingPathComponent("\(name).png"),
            bundledResourceURL,
            Bundle.module.url(forResource: name, withExtension: "png")
        ]

        for url in urls {
            if let url, let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
}

@MainActor
final class FloatingControlPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class TransparentCharacterView: NSView {
    var image: NSImage? {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    var imageHeight: CGFloat = 300 {
        didSet { setNeedsDisplay(bounds) }
    }
    var imageBottom: CGFloat = 8 {
        didSet { setNeedsDisplay(bounds) }
    }
    var imageTrailing: CGFloat = 24 {
        didSet { setNeedsDisplay(bounds) }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    override var isOpaque: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)

        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        let availableWidth = max(1, bounds.width - imageTrailing)
        let scale = min(
            imageHeight / image.size.height,
            availableWidth / image.size.width
        )
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawRect = NSRect(
            x: bounds.maxX - imageTrailing - drawSize.width,
            y: imageBottom,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    fileprivate let state = AppState()
    private let island = IslandController()
    private lazy var panelController = ControlPanelViewController(
        state: state,
        island: island,
        resetAction: { [weak self] in
            self?.resetSessionCounters()
        },
        resetAllAction: { [weak self] in
            self?.resetAllRecords()
        }
    )
    private var controlPanel: FloatingControlPanel?
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private let automaticIdleThresholdSeconds: Int = {
        if let rawValue = ProcessInfo.processInfo.environment["CHARACTER_ISLAND_IDLE_THRESHOLD_SECONDS"],
           let value = Int(rawValue), value > 0 {
            return value
        }
        return 30 * 60
    }()
    private var isAutomaticallyIdle = false
    private var eventMonitors = [Any]()
    fileprivate var keyboardEventTap: CFMachPort?
    private var keyboardEventTapRunLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        island.setScale(state.islandScale, persist: false)
        island.onScaleChanged = { [weak self] scale in
            guard let self else { return }
            self.state.updateIslandScale(scale)
            self.panelController.refresh()
        }
        updateInputPermissionStatus(prompt: false)
        prepareWatchFolder()
        refreshAIToolStatus()
        seedKnownCodexTurns()
        setupMenuBar()
        setupPopover()
        setupActivityMonitors()
        setupKeyboardEventTap()
        setupTimer()
        _ = updateAutomaticIdleState()
        showPersistentStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.saveTodayRecord()
        if let source = keyboardEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = keyboardEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        state.enableNoSleep(false)
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = ImageResources.load(named: "statusIcon") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            item.button?.image = image
        } else {
            item.button?.title = "新"
            item.button?.font = .systemFont(ofSize: 14, weight: .bold)
        }
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item
    }

    private func setupPopover() {
        let panel = FloatingControlPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ControlPanelViewController.panelWidth,
                height: ControlPanelViewController.panelBodyHeight + ControlPanelViewController.bottomCharacterOverflow
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.contentViewController = panelController
        controlPanel = panel
    }

    private func setupActivityMonitors() {
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.state.lastExplicitInputAt = Date()
            return event
        })
        if let monitor = localMonitor {
            eventMonitors.append(monitor)
        }

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in
                self?.state.lastExplicitInputAt = Date()
                if event.type == .keyDown {
                    self?.recordTypingIfNeeded(event)
                } else {
                    self?.recordPointerActionIfNeeded(event)
                }
            }
        })
        if let monitor = globalMonitor {
            eventMonitors.append(monitor)
        }
    }

    private func setupKeyboardEventTap() {
        if let source = keyboardEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            keyboardEventTapRunLoopSource = nil
        }
        if let tap = keyboardEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            keyboardEventTap = nil
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let candidates: [(CGEventTapLocation, String)] = [
            (.cghidEventTap, "HID"),
            (.cgSessionEventTap, "Session")
        ]

        for candidate in candidates {
            if let tap = CGEvent.tapCreate(
                tap: candidate.0,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: keyboardEventTapCallback,
                userInfo: refcon
            ) {
                keyboardEventTap = tap
                keyboardEventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                if let source = keyboardEventTapRunLoopSource {
                    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                }
                CGEvent.tapEnable(tap: tap, enable: true)
                state.inputEventTapActive = true
                state.inputCaptureChannel = candidate.1
                return
            }
        }

        state.inputEventTapActive = false
        state.inputCaptureChannel = "未启动"
        state.inputMonitoringTrusted = CGPreflightListenEventAccess()
    }

    private func updateInputPermissionStatus(prompt: Bool) {
        state.inputMonitoringTrusted = prompt
            ? requestInputMonitoringPermissionPrompt()
            : CGPreflightListenEventAccess()
        state.accessibilityTrusted = prompt
            ? requestAccessibilityPermissionPrompt()
            : AXIsProcessTrusted()

        if state.inputMonitoringTrusted, keyboardEventTap == nil {
            setupKeyboardEventTap()
        }
    }

    private func recordTypingIfNeeded(_ event: NSEvent) {
        guard event.type == .keyDown, !event.isARepeat else { return }
        guard !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.control),
              !event.modifierFlags.contains(.option) else {
            return
        }

        if isCorrectionKey(event.keyCode) {
            recordTypingKey(keyCode: event.keyCode, isCorrection: true)
            return
        }

        guard isPrintableTypingKey(event) else { return }
        recordTypingKey(keyCode: event.keyCode, isCorrection: false)
    }

    func recordTypingKeyFromEventTap(keyCode: UInt16, flags: CGEventFlags, isRepeat: Bool) {
        guard !isRepeat else { return }
        guard !flags.contains(.maskCommand),
              !flags.contains(.maskControl),
              !flags.contains(.maskAlternate) else {
            return
        }
        guard isCorrectionKey(keyCode) || isPrintableTypingKeyCode(keyCode) else { return }
        state.lastExplicitInputAt = Date()
        recordTypingKey(keyCode: keyCode, isCorrection: isCorrectionKey(keyCode))
    }

    private func recordTypingKey(keyCode: UInt16, isCorrection: Bool) {
        let now = Date()
        guard state.shouldAcceptTypingKey(keyCode, at: now) else { return }
        state.recordActionEvent(at: now)
        state.recordTypingEvent(isCorrection: isCorrection, at: now)
    }

    private func recordPointerActionIfNeeded(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            state.recordActionEvent()
        default:
            break
        }
    }

    private func isCorrectionKey(_ keyCode: UInt16) -> Bool {
        keyCode == 51 || keyCode == 117
    }

    private func isPrintableTypingKey(_ event: NSEvent) -> Bool {
        guard isPrintableTypingKeyCode(event.keyCode) else { return false }
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return false }
        return characters.unicodeScalars.contains { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
    }

    private func isPrintableTypingKeyCode(_ keyCode: UInt16) -> Bool {
        let ignoredKeyCodes: Set<UInt16> = [
            36, 48, 49, 51, 53, 57, 71, 76, 117,
            96, 97, 98, 99, 100, 101, 103, 105, 106, 107, 109, 111, 113, 114, 115, 116, 118, 119, 120, 121, 122, 123, 124, 125, 126
        ]
        return !ignoredKeyCodes.contains(keyCode)
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let panel = controlPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            refreshAIToolStatus()
            panelController.refresh()
            positionControlPanel(panel, under: button)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionControlPanel(_ panel: NSPanel, under button: NSStatusBarButton) {
        guard let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = window.convertToScreen(buttonFrameInWindow)
        let size = panel.frame.size
        let margin: CGFloat = 12
        var x = buttonFrameOnScreen.midX - size.width / 2
        var y = buttonFrameOnScreen.minY - size.height - 8

        x = max(screen.visibleFrame.minX + margin, min(x, screen.visibleFrame.maxX - size.width - margin))
        y = max(screen.visibleFrame.minY + margin, y)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func tick() {
        guard !state.isPaused else { return }
        state.rolloverDayIfNeeded()
        updateInputPermissionStatus(prompt: false)
        state.markActiveTypingSecond()

        if state.isOnBreak {
            let mouseInToggleArea = isMouseInBreakToggleArea()
            if mouseInToggleArea, !state.wasMouseInBreakToggleArea {
                state.isBreakTimerPausedByMenuBar.toggle()
            }
            state.wasMouseInBreakToggleArea = mouseInToggleArea
            if !state.isBreakTimerPausedByMenuBar {
                state.breakSeconds += 1
                state.breakRemaining = max(0, state.breakRemaining - 1)
            }
            state.mode = .breakTime
            showPersistentStatus()
            if state.breakRemaining == 0 {
                finishBreak()
            }
        } else {
            let isIdle = updateAutomaticIdleState()
            if !isIdle {
                state.workSeconds += 1
            }
            showPersistentStatus()
        }

        checkIdle()
        checkReminderSchedule()
        checkAIWatchFolder()
        checkCodexTurns()
        state.saveTodayRecordOccasionally()
        panelController.refresh()
    }

    private func showPersistentStatus() {
        guard state.showPersistentIsland else {
            island.clearPersistentSnapshot()
            return
        }

        if state.isOnBreak {
            island.show(
                mode: .breakTime,
                detail: state.isBreakTimerPausedByMenuBar ? "倒计时已暂停。再次扫过小岛或状态栏可继续。" : "休息进行中。扫过小岛或状态栏可暂停倒计时。",
                timer: state.formatted(state.breakRemaining)
            )
        } else if state.mode == .idle {
            island.show(
                mode: .idle,
                detail: "暂时没有新任务。整理状态，等待下一步。"
            )
        } else {
            let apmText = state.actionEventsInLastMinute.isEmpty
                ? "--"
                : String(format: "%02d", state.currentAPM)
            island.show(
                mode: .working,
                detail: "陪伴工作 \(state.formatted(state.workSeconds)) · APM \(apmText)"
            )
        }
    }

    private func finishBreak() {
        state.isOnBreak = false
        state.breakStartedAt = nil
        state.breakStartMouseLocation = nil
        state.isBreakTimerPausedByMenuBar = false
        state.wasMouseInBreakToggleArea = false
        state.breakRemaining = 0
        state.mode = state.isPaused ? .idle : .working
        state.setPanelVisualMode(.alert, duration: 8)
        NSSound(named: .init("Glass"))?.play()
        island.show(mode: .alert, detail: "休息结束，角色回到工作中。", timer: state.formatted(0), autoHideAfter: 8)
        showPersistentStatus()
        panelController.refresh()
    }

    private func resetSessionCounters() {
        state.isOnBreak = false
        state.breakStartedAt = nil
        state.breakStartMouseLocation = nil
        state.isBreakTimerPausedByMenuBar = false
        state.wasMouseInBreakToggleArea = false
        state.breakRemaining = 0
        state.resetRecordCounters()
        state.lastReminderMinuteKeys.removeAll()
        state.mode = .idle
        state.clearTodayRecord()

        state.knownWatchFiles = bridgeMarkerFiles()
        state.knownCodexTurns = completedCodexTurns()
    }

    private func resetAllRecords() {
        state.isOnBreak = false
        state.breakStartedAt = nil
        state.breakStartMouseLocation = nil
        state.isBreakTimerPausedByMenuBar = false
        state.wasMouseInBreakToggleArea = false
        state.breakRemaining = 0
        state.lastReminderMinuteKeys.removeAll()
        state.mode = .idle
        state.clearAllRecords()

        state.knownWatchFiles = bridgeMarkerFiles()
        state.knownCodexTurns = completedCodexTurns()
    }

    private func checkIdle() {
        let idle = currentInputIdleSeconds()
        guard state.remindersEnabled, !state.isOnBreak else { return }
        if idle > 15 * 60, idle < automaticIdleThresholdSeconds {
            let key = "idle-\(Date().minuteBucket)"
            if !state.lastReminderMinuteKeys.contains(key) {
                state.lastReminderMinuteKeys.insert(key)
                state.mode = .alert
                island.show(mode: .alert, detail: "已空闲 15 分钟。若是休息，请主动开始休息计时。", autoHideAfter: 6)
            }
        }
    }

    @discardableResult
    private func updateAutomaticIdleState() -> Bool {
        guard !state.isOnBreak else {
            isAutomaticallyIdle = false
            return false
        }

        let shouldBeIdle = currentInputIdleSeconds() >= automaticIdleThresholdSeconds
        if shouldBeIdle != isAutomaticallyIdle {
            isAutomaticallyIdle = shouldBeIdle
            state.clearPanelVisualMode()
        }
        state.mode = shouldBeIdle ? .idle : .working
        return shouldBeIdle
    }

    private func isMouseInMenuBarArea() -> Bool {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return false }
        return point.y >= screen.frame.maxY - 32
    }

    private func isMouseInBreakToggleArea() -> Bool {
        isMouseInMenuBarArea() || island.containsMouse(expandedBy: 6)
    }

    private func checkReminderSchedule() {
        guard state.remindersEnabled else { return }
        let calendar = Calendar.current
        let now = Date()
        let elapsedMinutes = state.workSeconds / 60

        for reminder in state.softReminders where reminder.enabled {
            if let target = fixedTime(from: reminder.schedule) {
                let hour = calendar.component(.hour, from: now)
                let minute = calendar.component(.minute, from: now)
                remindOnce(key: "\(reminder.id)-\(calendar.startOfDay(for: now))", condition: hour == target.hour && minute == target.minute) {
                    showSoftReminder(reminder)
                }
            } else if let interval = intervalMinutes(from: reminder.schedule), interval > 0 {
                remindOnce(key: "\(reminder.id)-\(elapsedMinutes / interval)", condition: elapsedMinutes > 0 && elapsedMinutes % interval == 0) {
                    showSoftReminder(reminder)
                }
            }
        }
    }

    private func intervalMinutes(from text: String) -> Int? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "，", with: ",")
        guard let value = firstNumber(in: normalized), value > 0 else { return nil }

        if normalized.contains("小时")
            || normalized.contains("hour")
            || normalized.contains("hr")
            || normalized.range(of: #"(^|[^a-z])h([^a-z]|$)"#, options: .regularExpression) != nil {
            return max(1, Int((value * 60).rounded()))
        }

        if normalized.contains("分钟")
            || normalized.contains("分")
            || normalized.contains("minute")
            || normalized.contains("min")
            || normalized.range(of: #"(^|[^a-z])m([^a-z]|$)"#, options: .regularExpression) != nil {
            return max(1, Int(value.rounded()))
        }

        return max(1, Int(value.rounded()))
    }

    private func firstNumber(in text: String) -> Double? {
        guard let match = text.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) else { return nil }
        return Double(text[match])
    }

    private func fixedTime(from text: String) -> (hour: Int, minute: Int)? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func showSoftReminder(_ reminder: SoftReminder) {
        let duration: TimeInterval = 7
        let mode = visualMode(for: reminder)
        state.mode = mode
        state.setPanelVisualMode(mode, duration: duration)

        if mode == .water {
            island.show(mode: mode, detail: "\(reminder.title)。不要用意志力替代杯子。", autoHideAfter: duration)
        } else {
            island.show(mode: mode, detail: "\(reminder.title)。按计划校准一下。", autoHideAfter: duration)
        }
        panelController.refresh()
    }

    private func visualMode(for reminder: SoftReminder) -> CharacterMode {
        if reminder.isLockedWater || reminder.title.contains("喝水") || reminder.title.contains("补给") {
            return .water
        }
        guard let index = state.softReminders.firstIndex(where: { $0.id == reminder.id }) else {
            return .alert
        }
        switch index {
        case 1: return .reminderSecond
        case 2: return .reminderThird
        case 3: return .reminderFourth
        default: return .alert
        }
    }

    private func remindOnce(key: String, condition: Bool, action: () -> Void) {
        guard condition, !state.lastReminderMinuteKeys.contains(key) else { return }
        state.lastReminderMinuteKeys.insert(key)
        NSSound(named: .init("Ping"))?.play()
        action()
    }

    private func prepareWatchFolder() {
        for folder in bridgeFolders() {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        state.knownWatchFiles = bridgeMarkerFiles()
    }

    private func checkAIWatchFolder() {
        guard state.aiRemindersEnabled else { return }
        let current = bridgeMarkerFiles()
        let added = current.subtracting(state.knownWatchFiles)
        state.knownWatchFiles = current
        guard !added.isEmpty else { return }
        state.aiDoneCount += added.count
        state.mode = .ai
        state.setPanelVisualMode(.ai, duration: 8)
        NSSound(named: .init("Glass"))?.play()
        island.show(mode: .ai, detail: "新增 \(added.count) 个完成标记。建议验收输出。", autoHideAfter: 8)
    }

    private func bridgeFolders() -> [URL] {
        [
            state.watchFolder,
            state.watchFolder.appendingPathComponent("claude", isDirectory: true),
            state.watchFolder.appendingPathComponent("cursor", isDirectory: true),
            state.terminalBridgeFolder,
            state.watchFolder.appendingPathComponent("other", isDirectory: true)
        ]
    }

    private func bridgeMarkerFiles() -> Set<String> {
        guard FileManager.default.fileExists(atPath: state.watchFolder.path),
              let enumerator = FileManager.default.enumerator(
                at: state.watchFolder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var files = Set<String>()
        for case let url as URL in enumerator {
            guard !url.lastPathComponent.hasPrefix(".") else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let prefix = state.watchFolder.path + "/"
            let relativePath = url.path.hasPrefix(prefix)
                ? String(url.path.dropFirst(prefix.count))
                : url.lastPathComponent
            files.insert(relativePath)
        }
        return files
    }

    private func refreshAIToolStatus() {
        let codex = FileManager.default.fileExists(atPath: state.codexThreadHistoryDB.path)
            ? "Codex 原生"
            : "Codex 待启动"
        let claude = FileManager.default.fileExists(atPath: state.claudeRoot.path)
            ? "Claude 桥接"
            : "Claude 可桥接"
        let cursor = FileManager.default.fileExists(atPath: state.cursorRoot.path)
            ? "Cursor 桥接"
            : "Cursor 可桥接"
        state.aiToolStatus = "\(codex) · \(claude) · \(cursor) · Terminal/其他桥接"
    }

    private func seedKnownCodexTurns() {
        state.knownCodexTurns = completedCodexTurns()
    }

    private func checkCodexTurns() {
        guard state.aiRemindersEnabled else { return }
        state.codexScanTick += 1
        guard state.codexScanTick >= 5 else { return }
        state.codexScanTick = 0

        let current = completedCodexTurns()
        let added = current.subtracting(state.knownCodexTurns)
        state.knownCodexTurns = current
        guard !added.isEmpty else { return }

        state.aiDoneCount += added.count
        state.mode = .ai
        state.setPanelVisualMode(.ai, duration: 8)
        NSSound(named: .init("Glass"))?.play()
        island.show(mode: .ai, detail: "Codex 新完成 \(added.count) 个回合。请验收输出。", autoHideAfter: 8)
    }

    private func completedCodexTurns() -> Set<String> {
        guard FileManager.default.fileExists(atPath: state.codexThreadHistoryDB.path) else {
            return []
        }

        let query = """
        select thread_id || ':' || turn_id
        from thread_turns
        where status = 'completed' and completed_at is not null
        order by completed_at desc
        limit 200;
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [state.codexThreadHistoryDB.path, query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return state.knownCodexTurns }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return Set(text.split(separator: "\n").map(String.init))
        } catch {
            return state.knownCodexTurns
        }
    }
}

private extension Date {
    var minuteBucket: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: self)
    }

    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

private func currentInputIdleSeconds() -> Int {
    let eventTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .scrollWheel,
        .keyDown
    ]
    let candidates = eventTypes
        .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
        .filter { $0 > 0 }
    return Int(candidates.min() ?? 0)
}

private func requestInputMonitoringPermissionPrompt() -> Bool {
    CGRequestListenEventAccess()
}

private func requestAccessibilityPermissionPrompt() -> Bool {
    let key = "AXTrustedCheckOptionPrompt"
    return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
}

private func resetInputMonitoringPermission() {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.example.character-efficiency-island"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
    process.arguments = ["reset", "ListenEvent", bundleID]
    try? process.run()
    process.waitUntilExit()
}

private func keyboardEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        let refconAddress = UInt(bitPattern: refcon)
        Task { @MainActor in
            guard let pointer = UnsafeMutableRawPointer(bitPattern: refconAddress) else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
            if let tap = delegate.keyboardEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                delegate.state.inputEventTapActive = true
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    let flagsRawValue = event.flags.rawValue
    let refconAddress = UInt(bitPattern: refcon)

    Task { @MainActor in
        guard let pointer = UnsafeMutableRawPointer(bitPattern: refconAddress) else { return }
        let delegate = Unmanaged<AppDelegate>.fromOpaque(pointer).takeUnretainedValue()
        delegate.recordTypingKeyFromEventTap(
            keyCode: keyCode,
            flags: CGEventFlags(rawValue: flagsRawValue),
            isRepeat: isRepeat
        )
    }

    return Unmanaged.passUnretained(event)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
