import SwiftUI
import UIKit

private enum AppTab: Hashable {
    case summary
    case tracker
    case records
}

struct RootTabView: View {
    @State private var selection: AppTab
    @Environment(\.colorScheme) private var colorScheme

    init() {
#if DEBUG
        let shouldShowRecords = ProcessInfo.processInfo.environment["SHOW_RECORDS"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--show-records")
        let initialTab: AppTab = shouldShowRecords ? .records : .summary
#else
        let initialTab: AppTab = .summary
#endif
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            SummaryView()
                .tabItem { Label("陪伴", systemImage: "person.crop.circle") }
                .tag(AppTab.summary)

            TrackerPhaseView()
                .tabItem { Label("Tracker", systemImage: "checklist") }
                .tag(AppTab.tracker)

            RecordsPhaseView()
                .tabItem { Label("记录", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.records)
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionOpenSummary)) { _ in
            selection = .summary
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionOpenReminder)) { _ in
            selection = .summary
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionOpenTracker)) { _ in
            selection = .tracker
        }
        .tint(Color(hex: colorScheme == .dark
            ? CompanionProfile.current.palette.darkPrimaryHex
            : CompanionProfile.current.palette.primaryHex))
        .background(KeyboardDismissTapArea())
    }
}

private struct SummaryView: View {
    @EnvironmentObject private var store: MobileAppStore
    private let profile = CompanionProfile.current

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日 HH:mm:ss"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            HStack(spacing: 12) {
                                Text(Self.headerDateFormatter.string(from: context.date))
                                    .font(.title2.weight(.semibold))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("今天 \(Self.headerDateFormatter.string(from: context.date))")

                                Button(action: store.toggleTimingPause) {
                                    Image(systemName: "power")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(store.state.isTimingPaused ? Color.secondary : Color.white)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            store.state.isTimingPaused
                                                ? Color(.tertiarySystemFill)
                                                : Color(hex: profile.palette.primaryHex),
                                            in: Circle()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(store.state.isTimingPaused ? "继续计时" : "暂停计时")
                                .accessibilityHint("不会退出应用，也不会改变当前工作或休息状态")
                            }
                        }

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            StatusCard(state: store.state, now: context.date)
                        }

                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            SummaryMetrics(state: store.state, now: context.date)
                        }

                        RestSettingsCard(
                            preferences: store.state.preferences,
                            setMode: store.setRestMode,
                            setMinutes: store.setCountdownMinutes
                        )

                        if !store.notificationsAuthorized {
                            NotificationAccessCard(
                                status: store.notificationStatus,
                                request: store.requestNotifications,
                                openSettings: store.openNotificationSettings
                            )
                        }

                        ReminderSettingsSection(reminders: store.state.reminders)
                            .id("reminders")

                        if let lastError = store.lastError {
                            Text(lastError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("最近错误：\(lastError)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onReceive(NotificationCenter.default.publisher(for: .companionOpenReminder)) { notification in
                    guard let reminderID = notification.object as? String else { return }
                    withAnimation { proxy.scrollTo("reminder-\(reminderID)", anchor: .center) }
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct KeyboardDismissTapArea: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissView {
        KeyboardDismissView()
    }

    func updateUIView(_ uiView: KeyboardDismissView, context: Context) {}
}

private final class KeyboardDismissView: UIView, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?
    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard installedWindow !== window else { return }
        installedWindow?.removeGestureRecognizer(tapRecognizer)
        installedWindow = window
        window?.addGestureRecognizer(tapRecognizer)
    }

    @objc private func dismissKeyboard() {
        installedWindow?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView {
            if view is UITextField || view is UITextView {
                return false
            }
            touchedView = view.superview
        }
        return true
    }

    deinit {
        installedWindow?.removeGestureRecognizer(tapRecognizer)
    }
}

private struct StatusCard: View {
    let state: CompanionState
    let now: Date
    private let profile = CompanionProfile.current
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            artwork
            statusText
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var artwork: some View {
        Image(state.isShowingWaterFeedback(at: now)
            ? profile.waterLoggedImage
            : (state.mode == .working ? profile.widgetWorkingImage : profile.widgetRestingImage))
            .resizable()
            .scaledToFit()
            .frame(width: 108, height: 154)
            .frame(maxHeight: .infinity, alignment: .center)
            .accessibilityLabel("喻文州当前状态形象")
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(hex: colorScheme == .dark ? profile.palette.darkPrimaryHex : profile.palette.primaryHex))
            Text(phrase)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(timerText)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("状态切换请使用 Widget 或锁屏实时活动")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var title: String {
        if state.isAwaitingConfirmation(at: now) { return "等待确认" }
        return state.mode == .working ? profile.workingTitle : profile.restingTitle
    }

    private var phrase: String {
        return state.mode == .working ? profile.workingPhrase : profile.restingPhrase
    }

    private var timerText: String {
        if state.mode == .resting && state.currentRestMode == .countdown {
            return CompanionFormatting.duration(state.remainingBreak(at: now))
        }
        return CompanionFormatting.duration(state.elapsed(at: now))
    }
}

private struct ReminderSettingsSection: View {
    let reminders: [ReminderConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("四项定时提醒", systemImage: "bell.badge")
                .font(.headline)
            Text("每项可单独设置固定时间或时间间隔。保存后会立即重新安排通知，并预排 Widget 的提醒图片时间线。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(reminders) { reminder in
                ReminderEditorCard(reminder: reminder)
                    .id("reminder-\(reminder.id)")
            }
        }
        .cardStyle()
    }
}

private struct ReminderEditorCard: View {
    @EnvironmentObject private var store: MobileAppStore
    let reminder: ReminderConfiguration

    private static let nextTriggerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(reminder.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 76)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("提醒标题", text: Binding(
                            get: { reminder.title },
                            set: { store.setReminderTitle(reminder.id, title: $0) }
                        ))
                        .font(.headline)
                        .textFieldStyle(.plain)

                        Toggle("启用", isOn: Binding(
                            get: { reminder.isEnabled },
                            set: { store.setReminderEnabled(reminder.id, enabled: $0) }
                        ))
                        .labelsHidden()
                    }

                    TextField("提醒文案", text: Binding(
                        get: { reminder.message },
                        set: { store.setReminderMessage(reminder.id, message: $0) }
                    ), axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2...4)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Picker("提醒方式", selection: scheduleKindBinding) {
                    ForEach(ReminderScheduleKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                switch reminder.schedule {
                case .fixed:
                    DatePicker(
                        "提醒时间",
                        selection: fixedTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                case .interval(let minutes):
                    FlatStepperControl(
                        label: "每 \(minutes) 分钟",
                        value: minutes,
                        minimumValue: 1,
                        maximumValue: 720,
                        decrementAccessibilityLabel: "减少提醒间隔",
                        incrementAccessibilityLabel: "增加提醒间隔",
                        decrement: {
                            store.setReminderSchedule(
                                reminder.id,
                                schedule: .interval(minutes: previousInterval(from: minutes))
                            )
                        },
                        increment: {
                            store.setReminderSchedule(
                                reminder.id,
                                schedule: .interval(minutes: nextInterval(from: minutes))
                            )
                        }
                    )
                }

                if reminder.isEnabled, let next = reminder.nextTriggerAt {
                    Label("下次预计：\(Self.nextTriggerFormatter.string(from: next))", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("已停用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!reminder.isEnabled)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var scheduleKindBinding: Binding<ReminderScheduleKind> {
        Binding(
            get: { reminder.scheduleKind },
            set: { kind in
                switch kind {
                case .fixed:
                    let nextHour = Calendar.current.component(.hour, from: Date().addingTimeInterval(60 * 60))
                    store.setReminderSchedule(reminder.id, schedule: .fixed(hour: nextHour, minute: 0))
                case .interval:
                    store.setReminderSchedule(reminder.id, schedule: .interval(minutes: 60))
                }
            }
        )
    }

    private var fixedTimeBinding: Binding<Date> {
        Binding(
            get: {
                guard case .fixed(let hour, let minute) = reminder.schedule else { return Date() }
                return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.setReminderSchedule(
                    reminder.id,
                    schedule: .fixed(hour: components.hour ?? 9, minute: components.minute ?? 0)
                )
            }
        )
    }

    private func previousInterval(from minutes: Int) -> Int {
        guard minutes > 15 else { return max(1, minutes - 1) }
        return max(15, ((minutes - 1) / 5) * 5)
    }

    private func nextInterval(from minutes: Int) -> Int {
        guard minutes >= 15 else { return min(15, minutes + 1) }
        return min(720, ((minutes / 5) + 1) * 5)
    }
}

private struct FlatStepperControl: View {
    let label: String
    let value: Int
    let minimumValue: Int
    let maximumValue: Int
    let decrementAccessibilityLabel: String
    let incrementAccessibilityLabel: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .monospacedDigit()
            Spacer()
            HStack(spacing: 0) {
                flatButton(
                    systemName: "minus",
                    accessibilityLabel: decrementAccessibilityLabel,
                    disabled: value <= minimumValue,
                    action: decrement
                )
                flatButton(
                    systemName: "plus",
                    accessibilityLabel: incrementAccessibilityLabel,
                    disabled: value >= maximumValue,
                    action: increment
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(label)
    }

    private func flatButton(
        systemName: String,
        accessibilityLabel: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        RepeatStepperButton(
            systemName: systemName,
            accessibilityLabel: accessibilityLabel,
            isEnabled: !disabled,
            action: action
        )
        .frame(width: 38, height: 32)
    }
}

/// UIKit owns the entire press lifecycle so SwiftUI row updates cannot cancel
/// a held stepper button after the first value change.
private struct RepeatStepperButton: UIViewRepresentable {
    let systemName: String
    let accessibilityLabel: String
    let isEnabled: Bool
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)),
            for: .normal
        )
        button.tintColor = .label
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 9
        button.layer.cornerCurve = .continuous
        button.accessibilityLabel = accessibilityLabel
        button.addTarget(context.coordinator, action: #selector(Coordinator.touchDown), for: .touchDown)
        button.addTarget(context.coordinator, action: #selector(Coordinator.touchUpInside), for: .touchUpInside)
        button.addTarget(context.coordinator, action: #selector(Coordinator.cancelPress), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        context.coordinator.button = button
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.action = action
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? 1 : 0.32
        button.accessibilityLabel = accessibilityLabel
        if !isEnabled {
            context.coordinator.stopRepeating()
        }
    }

    static func dismantleUIView(_ button: UIButton, coordinator: Coordinator) {
        coordinator.stopRepeating()
    }

    final class Coordinator: NSObject {
        weak var button: UIButton?
        var action: () -> Void
        private var delayTimer: Timer?
        private var repeatTimer: Timer?
        private var didRepeat = false

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func touchDown() {
            stopRepeating()
            didRepeat = false
            delayTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self] _ in
                self?.beginRepeating()
            }
        }

        @objc func touchUpInside() {
            let shouldPerformSingleStep = !didRepeat
            stopRepeating()
            if shouldPerformSingleStep {
                action()
            }
        }

        @objc func cancelPress() {
            stopRepeating()
        }

        private func beginRepeating() {
            guard button?.isHighlighted == true, button?.isEnabled == true else { return }
            didRepeat = true
            action()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in
                guard let self,
                      self.button?.isHighlighted == true,
                      self.button?.isEnabled == true else {
                    self?.stopRepeating()
                    return
                }
                self.action()
            }
        }

        func stopRepeating() {
            delayTimer?.invalidate()
            repeatTimer?.invalidate()
            delayTimer = nil
            repeatTimer = nil
        }

        deinit {
            stopRepeating()
        }
    }
}

private struct SummaryMetrics: View {
    let state: CompanionState
    let now: Date

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            MetricCell(title: "累计陪伴", value: "\(CompanionFormatting.companionDays(from: state.initializedAt, through: now)) 天", symbol: "calendar")
            MetricCell(title: "累计工作", value: humanDuration(state.completedWorkDuration(through: now)), symbol: "timer")
            MetricCell(title: "今日喝水", value: "\(state.waterCount(on: now)) 次", symbol: "drop.fill")
            MetricCell(
                title: "当前状态",
                value: state.currentStatusDisplayName,
                symbol: "circle.fill"
            )
        }
    }

    private func humanDuration(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration) / 60)
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }
}

private struct MetricCell: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RestSettingsCard: View {
    let preferences: CompanionPreferences
    let setMode: (RestMode) -> Void
    let setMinutes: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("休息规则", systemImage: "cup.and.saucer")
                .font(.headline)
            Picker("默认休息方式", selection: Binding(get: { preferences.restMode }, set: setMode)) {
                ForEach(RestMode.allCases) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)

            if preferences.restMode == .countdown {
                FlatStepperControl(
                    label: "倒计时 \(preferences.countdownMinutes) 分钟",
                    value: preferences.countdownMinutes,
                    minimumValue: 1,
                    maximumValue: 180,
                    decrementAccessibilityLabel: "减少休息倒计时",
                    incrementAccessibilityLabel: "增加休息倒计时",
                    decrement: { setMinutes(preferences.countdownMinutes - 1) },
                    increment: { setMinutes(preferences.countdownMinutes + 1) }
                )
            }
            Text("设置只影响下一次从 Widget 或实时活动开始的休息，不改变当前状态。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

private struct NotificationAccessCard: View {
    let status: String
    let request: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("通知权限", systemImage: "bell")
                    .font(.headline)
                Spacer()
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            Text("倒计时结束依靠本地通知准时提醒；Widget 不是闹钟。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("请求通知权限", action: request).buttonStyle(.borderedProminent)
                Button("打开系统设置", action: openSettings).buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(clean, radix: 16) ?? 0x315A88
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
