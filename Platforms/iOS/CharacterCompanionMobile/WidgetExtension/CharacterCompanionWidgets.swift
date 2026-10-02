import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct CompanionWidgetEntry: TimelineEntry {
    var date: Date
    var state: CompanionState
    var reminder: WidgetReminderSnapshot?
    var waterFeedbackUntil: Date?

    func isShowingWaterFeedback(at date: Date) -> Bool {
        waterFeedbackUntil.map { date < $0 } ?? false
    }
}

struct WidgetReminderSnapshot: Hashable {
    var id: String
    var title: String
    var message: String
    var imageName: String
    var triggerAt: Date
}

struct CompanionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompanionWidgetEntry {
        CompanionWidgetEntry(date: .now, state: .initial(), reminder: nil, waterFeedbackUntil: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CompanionWidgetEntry) -> Void) {
        let now = Date()
        let state = SharedStateRepository.shared.load(now: now)
        completion(CompanionWidgetEntry(
            date: now,
            state: state,
            reminder: CompanionWidgetTimeline.activeReminder(in: state, at: now),
            waterFeedbackUntil: state.isShowingWaterFeedback(at: now) ? state.waterFeedbackUntil : nil
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompanionWidgetEntry>) -> Void) {
        let now = Date()
        let state = SharedStateRepository.shared.load(now: now)
        let waterFeedbackUntil = CompanionWidgetTimeline.waterFeedbackEnd(
            for: state,
            family: context.family,
            at: now
        )
        let result = CompanionWidgetTimeline.entries(
            for: state,
            from: now,
            waterFeedbackUntil: waterFeedbackUntil
        )
        completion(Timeline(entries: result.entries, policy: .after(result.refreshAt)))
    }
}

private enum CompanionWidgetTimeline {
    // The timer text animates without timeline entries, but WidgetKit can defer an
    // explicit reload after an AppIntent. A short recovery request prevents a stale
    // paused/state snapshot from remaining on screen for the old six-hour horizon.
    private static let recoveryRefreshInterval: TimeInterval = 15 * 60

    private struct Transition {
        var date: Date
        var reminder: WidgetReminderSnapshot?
    }

    static func activeReminder(in state: CompanionState, at date: Date) -> WidgetReminderSnapshot? {
        state.reminders
            .filter { reminder in
                guard reminder.isEnabled, let triggered = reminder.lastTriggeredAt else { return false }
                return triggered <= date && date < triggered.addingTimeInterval(CompanionReminderTiming.widgetPresentationDuration)
            }
            .compactMap { reminder in
                guard let trigger = reminder.lastTriggeredAt else { return nil }
                return snapshot(reminder, triggerAt: trigger)
            }
            .max { $0.triggerAt < $1.triggerAt }
    }

    static func waterFeedbackEnd(
        for state: CompanionState,
        family: WidgetFamily,
        at now: Date
    ) -> Date? {
        guard let event = state.waterEvents.last,
              now >= event.date,
              now.timeIntervalSince(event.date) <= 60,
              let defaults = UserDefaults(suiteName: SharedStateRepository.appGroupIdentifier) else {
            return nil
        }

        let familyKey = family == .systemMedium ? "medium" : "small"
        let idKey = "widget-water-feedback-id-\(familyKey)"
        let startKey = "widget-water-feedback-start-\(familyKey)"
        let eventID = event.id.uuidString

        if defaults.string(forKey: idKey) != eventID {
            defaults.set(eventID, forKey: idKey)
            defaults.set(now.timeIntervalSinceReferenceDate, forKey: startKey)
        }

        let startedAtValue = defaults.double(forKey: startKey)
        guard startedAtValue > 0 else { return nil }
        let startedAt = Date(timeIntervalSinceReferenceDate: startedAtValue)
        let end = startedAt.addingTimeInterval(5)
        return end > now ? end : nil
    }

    static func entries(
        for state: CompanionState,
        from now: Date,
        waterFeedbackUntil: Date?
    ) -> (entries: [CompanionWidgetEntry], refreshAt: Date) {
        let horizon = now.addingTimeInterval(recoveryRefreshInterval)
        var transitions: [Transition] = []

        for reminder in state.reminders where reminder.isEnabled {
            var occurrence = reminder.nextTriggerAt
                ?? CompanionReminderTiming.nextTrigger(for: reminder.schedule, after: now)
            var generated = 0
            while occurrence <= horizon && generated < 24 && transitions.count < 72 {
                let presentation = snapshot(reminder, triggerAt: occurrence)
                transitions.append(Transition(date: occurrence, reminder: presentation))
                transitions.append(Transition(
                    date: occurrence.addingTimeInterval(CompanionReminderTiming.widgetPresentationDuration),
                    reminder: nil
                ))
                occurrence = CompanionReminderTiming.followingTrigger(
                    after: occurrence,
                    schedule: reminder.schedule
                )
                generated += 1
            }
        }

        if let feedbackUntil = waterFeedbackUntil,
           feedbackUntil > now,
           feedbackUntil <= horizon {
            transitions.append(Transition(
                date: feedbackUntil,
                reminder: activeReminder(in: state, at: feedbackUntil)
            ))
        }

        transitions.sort { lhs, rhs in
            if lhs.date == rhs.date { return lhs.reminder == nil }
            return lhs.date < rhs.date
        }

        var entries = [CompanionWidgetEntry(
            date: now,
            state: state,
            reminder: activeReminder(in: state, at: now),
            waterFeedbackUntil: waterFeedbackUntil
        )]
        var lastDate: Date?
        for transition in transitions where transition.date > now {
            if lastDate == transition.date {
                entries[entries.count - 1] = CompanionWidgetEntry(
                    date: transition.date,
                    state: state,
                    reminder: transition.reminder,
                    waterFeedbackUntil: waterFeedbackUntil
                )
            } else {
                entries.append(CompanionWidgetEntry(
                    date: transition.date,
                    state: state,
                    reminder: transition.reminder,
                    waterFeedbackUntil: waterFeedbackUntil
                ))
                lastDate = transition.date
            }
        }

        var refreshAt = horizon
        if state.mode == .resting, let end = state.breakEndAt, end > now {
            refreshAt = min(refreshAt, end.addingTimeInterval(1))
        }
        return (entries, refreshAt)
    }

    private static func snapshot(_ reminder: ReminderConfiguration, triggerAt: Date) -> WidgetReminderSnapshot {
        WidgetReminderSnapshot(
            id: reminder.id,
            title: reminder.title,
            message: reminder.message,
            imageName: reminder.imageName,
            triggerAt: triggerAt
        )
    }
}

struct CharacterCompanionWidget: Widget {
    let kind = CompanionWidgetIdentifier.main

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompanionWidgetProvider()) { entry in
            CompanionWidgetView(entry: entry)
                // Character art and productivity state are intentionally non-sensitive.
                // Keep the gallery preview useful instead of showing an all-gray skeleton.
                .unredacted()
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: CompanionProfile.current.palette.secondaryHex).opacity(0.82), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName(CompanionProfile.current.productName)
        .description("查看工作或休息计时，并快速切换状态或喝水打卡。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct CompanionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: CompanionWidgetEntry

    var body: some View {
        Group {
            if entry.isShowingWaterFeedback(at: entry.date) {
                if family == .systemMedium {
                    medium
                } else {
                    small
                }
            } else if let reminder = entry.reminder {
                if family == .systemMedium {
                    reminderMedium(reminder)
                } else {
                    reminderSmall(reminder)
                }
            } else if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .invalidatableContent()
    }

    private var small: some View {
        HStack(spacing: 10) {
            characterImage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(1.14)
                .padding(.trailing, 3)
                .layoutPriority(1)
            VStack(alignment: .center, spacing: 7) {
                if entry.isShowingWaterFeedback(at: entry.date) {
                    Text("+1")
                        .font(.callout.monospacedDigit().weight(.semibold))
                } else {
                    CompanionTimerView(state: entry.state, date: entry.date)
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                smallControls
            }
            .frame(width: 56)
        }
        .widgetURL(URL(string: "yuwenzhou-companion://summary"))
    }

    private var medium: some View {
        HStack(spacing: 16) {
            characterImage
                .frame(width: 122)
            VStack(alignment: .leading, spacing: 7) {
                Text(fullTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(entry.state.mode == .working ? CompanionProfile.current.workingPhrase : CompanionProfile.current.restingPhrase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                CompanionTimerView(state: entry.state, date: entry.date)
                .font(.title3.monospacedDigit().weight(.semibold))
                controls
            }
        }
        .widgetURL(URL(string: "yuwenzhou-companion://summary"))
    }

    private var characterImage: some View {
        Image(entry.isShowingWaterFeedback(at: entry.date)
            ? CompanionProfile.current.waterLoggedImage
            : (entry.state.mode == .working ? CompanionProfile.current.widgetWorkingImage : CompanionProfile.current.widgetRestingImage))
            .resizable()
            .scaledToFit()
            .unredacted()
            .accessibilityLabel(CompanionProfile.current.displayName)
    }

    private func reminderSmall(_ reminder: WidgetReminderSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(reminder.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .unredacted()
            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(reminder.triggerAt, style: .time)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(primaryColor)
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(primaryColor)
            }
            .frame(width: 60, alignment: .leading)
        }
        .widgetURL(URL(string: "yuwenzhou-companion://summary?reminder=\(reminder.id)"))
    }

    private func reminderMedium(_ reminder: WidgetReminderSnapshot) -> some View {
        HStack(spacing: 16) {
            Image(reminder.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 122)
                .unredacted()
            VStack(alignment: .leading, spacing: 7) {
                Text(reminder.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(reminder.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Label {
                    Text(reminder.triggerAt, style: .time)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "bell.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryColor)
            }
        }
        .widgetURL(URL(string: "yuwenzhou-companion://summary?reminder=\(reminder.id)"))
    }

    private var smallControls: some View {
        VStack(spacing: 6) {
            Button(intent: SetModeFromWidgetIntent(
                target: entry.state.mode == .working ? .resting : .working
            )) {
                Image(systemName: entry.state.mode == .working ? "cup.and.saucer.fill" : "play.fill")
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 18)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(primaryColor)

            Button(intent: LogWaterFromWidgetIntent()) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 18)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(primaryColor)
        }
        .font(.caption2)
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button(intent: SetModeFromWidgetIntent(
                target: entry.state.mode == .working ? .resting : .working
            )) {
                Label(entry.state.mode == .working ? "休息" : "工作", systemImage: entry.state.mode == .working ? "cup.and.saucer.fill" : "play.fill")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryColor)

            Button(intent: LogWaterFromWidgetIntent()) {
                Label("喝水", systemImage: "drop.fill")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(primaryColor)
        }
        .font(.caption2)
    }

    private var fullTitle: String {
        if entry.isShowingWaterFeedback(at: entry.date) { return "喝水打卡成功🏅" }
        if entry.state.isAwaitingConfirmation(at: entry.date) { return "休息结束，等待确认" }
        return entry.state.mode == .working ? CompanionProfile.current.workingTitle : CompanionProfile.current.restingTitle
    }

    private var primaryColor: Color {
        Color(hex: colorScheme == .dark
            ? CompanionProfile.current.palette.darkPrimaryHex
            : CompanionProfile.current.palette.primaryHex)
    }
}

private struct CompanionTimerView: View {
    let state: CompanionState
    let date: Date

    var body: some View {
        if state.isAwaitingConfirmation(at: date) {
            Text("等待确认")
        } else if state.mode == .resting, state.currentRestMode == .countdown, let endAt = state.breakEndAt {
            Text(
                timerInterval: state.stateStartedAt...max(endAt, state.stateStartedAt.addingTimeInterval(1)),
                pauseTime: state.timingPausedAt,
                countsDown: true,
                showsHours: true
            )
        } else {
            Text(
                timerInterval: state.stateStartedAt...Date.distantFuture,
                pauseTime: state.timingPausedAt,
                countsDown: false,
                showsHours: true
            )
        }
    }
}

struct YuWenzhouLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompanionActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: CompanionProfile.current.palette.secondaryHex).opacity(0.92))
                .activitySystemActionForegroundColor(Color(hex: CompanionProfile.current.palette.primaryHex))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    liveImage(imageName(for: context), size: 54)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title).font(.headline)
                        LiveActivityTimer(state: context.state).font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityControls(mode: context.state.mode)
                }
            } compactLeading: {
                liveImage(imageName(for: context), size: 22)
            } compactTrailing: {
                LiveActivityTimer(state: context.state).font(.caption2.monospacedDigit())
            } minimal: {
                liveImage(imageName(for: context), size: 22)
            }
            .keylineTint(Color(hex: CompanionProfile.current.palette.primaryHex))
        }
    }

    private func liveImage(_ name: String, size: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .unredacted()
    }

    private func imageName(for context: ActivityViewContext<CompanionActivityAttributes>) -> String {
        if context.state.isWaterFeedback && !context.isStale {
            return CompanionProfile.current.waterLoggedImage
        }
        return context.state.mode == .working
            ? CompanionProfile.current.liveActivityWorkingImage
            : CompanionProfile.current.liveActivityRestingImage
    }

}

private struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<CompanionActivityAttributes>

    private var isShowingWaterFeedback: Bool {
        context.state.isWaterFeedback && !context.isStale
    }

    private var imageName: String {
        if isShowingWaterFeedback { return CompanionProfile.current.waterLoggedImage }
        return context.state.mode == .working
            ? CompanionProfile.current.liveActivityWorkingImage
            : CompanionProfile.current.liveActivityRestingImage
    }

    private var title: String {
        return context.state.mode == .working
            ? CompanionProfile.current.workingTitle
            : CompanionProfile.current.restingTitle
    }

    private var phrase: String {
        return context.state.mode == .working
            ? CompanionProfile.current.workingPhrase
            : CompanionProfile.current.restingPhrase
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 106)
                .offset(x: 0, y: 8)
                .unredacted()
                .accessibilityLabel(context.attributes.characterName)
            Text(context.state.isAwaitingConfirmation ? "休息结束，等待确认" : title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 220, alignment: .leading)
                .offset(x: 104, y: 16)

            Text(phrase)
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 92, alignment: .leading)
                .offset(x: 104, y: 47)

            LiveActivityTimer(state: context.state)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 110, alignment: .leading)
                .offset(x: 170, y: 47)

            LiveActivityControls(mode: context.state.mode)
                .offset(x: 104, y: 80)
        }
        .frame(width: 330, height: 126, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

private struct LiveActivityTimer: View {
    let state: CompanionActivityAttributes.ContentState

    var body: some View {
        if state.isAwaitingConfirmation {
            Text("等待确认")
        } else if state.isTimingPaused, let pausedTimerText = state.pausedTimerText {
            Text(pausedTimerText)
        } else if state.mode == .resting, state.isCountdown, let end = state.breakEndAt {
            Text(end, style: .timer)
        } else {
            Text(state.stateStartedAt, style: .timer)
        }
    }
}

private struct LiveActivityControls: View {
    let mode: CompanionMode

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: ToggleFromLiveActivityIntent()) {
                Label(mode == .working ? "休息" : "工作", systemImage: mode == .working ? "cup.and.saucer.fill" : "play.fill")
                    .foregroundStyle(.white)
                    .frame(minWidth: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: CompanionProfile.current.palette.primaryHex))

            Button(intent: LogWaterFromLiveActivityIntent()) {
                Label("喝水", systemImage: "drop.fill")
                    .foregroundStyle(.white)
                    .frame(minWidth: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: CompanionProfile.current.palette.primaryHex))
        }
        .font(.caption)
        .controlSize(.small)
    }
}

@main
struct CharacterCompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CharacterCompanionWidget()
        YuWenzhouLiveActivityWidget()
    }
}

private extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(clean, radix: 16) ?? 0x315A88
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
