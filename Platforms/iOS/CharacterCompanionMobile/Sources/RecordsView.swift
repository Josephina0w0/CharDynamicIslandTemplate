import SwiftUI
import UIKit

struct RecordsPhaseView: View {
    @EnvironmentObject private var store: MobileAppStore
    @State private var selectedDay = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var weekAnchor = Date()
    @State private var monthAnchor = Date()

    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            RecordsDailySection(
                                selectedDay: $selectedDay,
                                state: store.state,
                                now: context.date,
                                calendar: calendar
                            )
                            .id("records-daily")

                            RecordsWeeklySection(
                                weekAnchor: $weekAnchor,
                                state: store.state,
                                now: context.date,
                                calendar: calendar,
                                setWeekStart: store.setWeekStart
                            )

                            RecordsMonthlySection(
                                monthAnchor: $monthAnchor,
                                selectedDay: $selectedDay,
                                state: store.state,
                                now: context.date,
                                calendar: calendar,
                                selectDay: { date in
                                    selectedDay = calendar.startOfDay(for: date)
                                    withAnimation {
                                        proxy.scrollTo("records-daily", anchor: .top)
                                    }
                                }
                            )

                            RecordsAppearanceSection(
                                selectedHex: store.state.preferences.workColorHex,
                                setColorHex: store.setWorkColorHex
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("工作记录")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct RecordsDailySection: View {
    @Binding var selectedDay: Date
    let state: CompanionState
    let now: Date
    let calendar: Calendar

    private var summary: RecordsDailySummary {
        RecordsAnalytics.dailySummary(
            for: selectedDay,
            intervals: state.workIntervals,
            now: now,
            calendar: calendar
        )
    }

    private var today: Date {
        calendar.startOfDay(for: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                RecordsArrowButton(systemName: "chevron.left") {
                    moveDay(by: -1)
                }

                VStack(spacing: 2) {
                    Text(calendar.isDate(selectedDay, inSameDayAs: today) ? "今天" : RecordsText.dayTitle(selectedDay, calendar: calendar))
                        .font(.title3.weight(.bold))
                    Text(RecordsText.fullDate(selectedDay, calendar: calendar))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                RecordsArrowButton(systemName: "chevron.right", disabled: selectedDay >= today) {
                    moveDay(by: 1)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("全天工作分布", systemImage: "clock")
                    .font(.headline)
                RecordsTimeline(summary: summary, color: workColor)
            }

            LazyVGrid(columns: RecordsLayout.metrics, spacing: 10) {
                RecordsMetric(title: "工作总时长", value: RecordsText.duration(summary.totalDuration))
                RecordsMetric(title: "工作区间", value: "\(summary.intervalCount) 次")
                RecordsMetric(title: "最长连续", value: RecordsText.duration(summary.longestDuration))
                RecordsMetric(title: "首次／最后", value: RecordsText.timeRange(first: summary.firstStart, last: summary.lastEnd, calendar: calendar))
            }
        }
        .recordsCard()
    }

    private var workColor: Color {
        Color(hex: state.preferences.workColorHex)
    }

    private func moveDay(by amount: Int) {
        guard let newDate = calendar.date(byAdding: .day, value: amount, to: selectedDay) else { return }
        selectedDay = min(calendar.startOfDay(for: newDate), today)
    }
}

private struct RecordsWeeklySection: View {
    @Binding var weekAnchor: Date
    let state: CompanionState
    let now: Date
    let calendar: Calendar
    let setWeekStart: (WeekStart) -> Void

    private var preference: WeekStart {
        state.preferences.weekStart
    }

    private var weekStart: Date {
        RecordsAnalytics.weekStart(containing: weekAnchor, preference: preference, calendar: calendar)
    }

    private var currentWeekStart: Date {
        RecordsAnalytics.weekStart(containing: now, preference: preference, calendar: calendar)
    }

    private var summary: RecordsPeriodSummary {
        RecordsAnalytics.periodSummary(
            startingAt: weekStart,
            dayCount: 7,
            intervals: state.workIntervals,
            now: now,
            calendar: calendar
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("周统计", systemImage: "chart.bar")
                .font(.title3.weight(.bold))

            HStack(spacing: 10) {
                RecordsArrowButton(systemName: "chevron.left") {
                    moveWeek(by: -1)
                }

                VStack(spacing: 2) {
                    let number = RecordsAnalytics.weekNumber(for: weekStart, preference: preference, calendar: calendar)
                    Text(String(format: "%d年 第%d周", number.year, number.week))
                        .font(.headline)
                    Text(RecordsText.periodRange(start: weekStart, dayCount: 7, calendar: calendar))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                RecordsArrowButton(systemName: "chevron.right", disabled: weekStart >= currentWeekStart) {
                    moveWeek(by: 1)
                }
            }

            Picker("每周开始日", selection: Binding(
                get: { preference },
                set: { newValue in
                    weekAnchor = RecordsAnalytics.weekStart(containing: weekAnchor, preference: newValue, calendar: calendar)
                    setWeekStart(newValue)
                }
            )) {
                Text("周一开始").tag(WeekStart.monday)
                Text("周日开始").tag(WeekStart.sunday)
            }
            .pickerStyle(.segmented)

            RecordsWeeklyBars(
                days: summary.days,
                now: now,
                color: Color(hex: state.preferences.workColorHex),
                calendar: calendar
            )

            LazyVGrid(columns: RecordsLayout.metrics, spacing: 10) {
                RecordsMetric(title: "本周总时长", value: RecordsText.duration(summary.totalDuration))
                RecordsMetric(title: "日均", value: RecordsText.duration(summary.averageDuration))
                RecordsMetric(title: "最多一天", value: RecordsText.longestDay(summary.longestDay, calendar: calendar))
                RecordsMetric(title: "活跃天数", value: "\(summary.activeDayCount) 天")
            }
        }
        .recordsCard()
    }

    private func moveWeek(by amount: Int) {
        guard let newDate = calendar.date(byAdding: .day, value: amount * 7, to: weekStart) else { return }
        weekAnchor = min(newDate, currentWeekStart)
    }
}

private struct RecordsMonthlySection: View {
    @Binding var monthAnchor: Date
    @Binding var selectedDay: Date
    let state: CompanionState
    let now: Date
    let calendar: Calendar
    let selectDay: (Date) -> Void

    private var monthStart: Date {
        RecordsAnalytics.monthStart(containing: monthAnchor, calendar: calendar)
    }

    private var currentMonthStart: Date {
        RecordsAnalytics.monthStart(containing: now, calendar: calendar)
    }

    private var summary: RecordsPeriodSummary {
        RecordsAnalytics.periodSummary(
            startingAt: monthStart,
            dayCount: RecordsAnalytics.numberOfDaysInMonth(containing: monthStart, calendar: calendar),
            intervals: state.workIntervals,
            now: now,
            calendar: calendar
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("月统计", systemImage: "calendar")
                .font(.title3.weight(.bold))

            HStack(spacing: 10) {
                RecordsArrowButton(systemName: "chevron.left") {
                    moveMonth(by: -1)
                }
                Text(RecordsText.monthTitle(monthStart, calendar: calendar))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                RecordsArrowButton(systemName: "chevron.right", disabled: monthStart >= currentMonthStart) {
                    moveMonth(by: 1)
                }
            }

            RecordsMonthGrid(
                days: summary.days,
                selectedDay: selectedDay,
                now: now,
                weekStart: state.preferences.weekStart,
                color: Color(hex: state.preferences.workColorHex),
                calendar: calendar,
                selectDay: selectDay
            )

            Text("点按日期可回到上方查看当天详情")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: RecordsLayout.metrics, spacing: 10) {
                RecordsMetric(title: "本月总时长", value: RecordsText.duration(summary.totalDuration))
                RecordsMetric(title: "日均", value: RecordsText.duration(summary.averageDuration))
                RecordsMetric(title: "最多一天", value: RecordsText.longestDay(summary.longestDay, calendar: calendar))
                RecordsMetric(title: "活跃天数", value: "\(summary.activeDayCount) 天")
            }
        }
        .recordsCard()
    }

    private func moveMonth(by amount: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: amount, to: monthStart) else { return }
        monthAnchor = min(newDate, currentMonthStart)
    }
}

private struct RecordsAppearanceSection: View {
    let selectedHex: String
    let setColorHex: (String) -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("工作颜色", systemImage: "paintpalette")
                    .font(.headline)
                Text("日、周、月图表会同步使用这个颜色。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ColorPicker(
                    "选择颜色",
                    selection: Binding(
                        get: { Color(hex: selectedHex) },
                        set: { setColorHex($0.recordsHex(fallback: selectedHex)) }
                    ),
                    supportsOpacity: false
                )
                .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)

            Image(CompanionProfile.current.recordsImage)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 98)
                .accessibilityHidden(true)
        }
        .recordsCard()
    }
}

private struct RecordsTimeline: View {
    let summary: RecordsDailySummary
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let fullDuration = max(1, summary.dayEnd.timeIntervalSince(summary.dayStart))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemFill))

                    ForEach(Array(summary.intervals.enumerated()), id: \.offset) { _, interval in
                        let startFraction = interval.start.timeIntervalSince(summary.dayStart) / fullDuration
                        let durationFraction = interval.duration / fullDuration
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.primary.opacity(0.22), lineWidth: 0.7)
                            )
                            .frame(width: max(3, geometry.size.width * durationFraction))
                            .offset(x: max(0, geometry.size.width * startFraction))
                    }

                    ForEach(1..<4, id: \.self) { index in
                        Rectangle()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: 0.5)
                            .offset(x: geometry.size.width * Double(index) / 4)
                    }
                }
            }
            .frame(height: 44)

            HStack {
                Text("00")
                Spacer()
                Text("06")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("24")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("全天工作分布，共工作 \(RecordsText.duration(summary.totalDuration))")
    }
}

private struct RecordsWeeklyBars: View {
    let days: [RecordsDailySummary]
    let now: Date
    let color: Color
    let calendar: Calendar

    private var maximum: TimeInterval {
        max(days.map(\.totalDuration).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(day.totalDuration > 0 ? color : Color(.tertiarySystemFill))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(Color.primary.opacity(0.18), lineWidth: 0.7)
                                )
                                .frame(height: day.totalDuration > 0
                                    ? max(4, geometry.size.height * day.totalDuration / maximum)
                                    : 4)
                        }
                    }
                    Text(RecordsText.weekday(day.dayStart, calendar: calendar))
                        .font(.caption.weight(calendar.isDate(day.dayStart, inSameDayAs: now) ? .bold : .regular))
                        .foregroundStyle(calendar.isDate(day.dayStart, inSameDayAs: now) ? Color.primary : Color.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(RecordsText.weekday(day.dayStart, calendar: calendar))，工作 \(RecordsText.duration(day.totalDuration))")
            }
        }
        .frame(height: 132)
    }
}

private struct RecordsMonthGrid: View {
    let days: [RecordsDailySummary]
    let selectedDay: Date
    let now: Date
    let weekStart: WeekStart
    let color: Color
    let calendar: Calendar
    let selectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var maximum: TimeInterval {
        max(days.map(\.totalDuration).max() ?? 0, 1)
    }

    private var leadingOffset: Int {
        guard let first = days.first else { return 0 }
        return RecordsAnalytics.weekdayOffset(for: first.dayStart, preference: weekStart, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        weekStart == .monday
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(0..<leadingOffset, id: \.self) { _ in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
            }

            ForEach(days) { day in
                let isFuture = day.dayStart > calendar.startOfDay(for: now)
                let intensity = day.totalDuration > 0 ? 0.22 + (0.70 * day.totalDuration / maximum) : 0
                Button {
                    selectDay(day.dayStart)
                } label: {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(day.totalDuration > 0 ? color.opacity(intensity) : Color(.tertiarySystemFill))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(
                                        calendar.isDate(day.dayStart, inSameDayAs: selectedDay)
                                            ? color
                                            : Color.primary.opacity(day.totalDuration > 0 ? 0.18 : 0.06),
                                        lineWidth: calendar.isDate(day.dayStart, inSameDayAs: selectedDay) ? 2 : 0.7
                                    )
                            )
                        Text("\(calendar.component(.day, from: day.dayStart))")
                            .font(.caption2.weight(calendar.isDate(day.dayStart, inSameDayAs: now) ? .bold : .medium))
                            .padding(6)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(isFuture ? 0.35 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isFuture)
                .accessibilityLabel("\(calendar.component(.day, from: day.dayStart))日，工作 \(RecordsText.duration(day.totalDuration))")
            }
        }
    }
}

private struct RecordsMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RecordsArrowButton: View {
    let systemName: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(.tertiarySystemFill), in: Circle())
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}

private enum RecordsLayout {
    static let metrics = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
}

private enum RecordsText {
    static let chineseLocale = Locale(identifier: "zh_CN")

    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 {
            return "\(seconds)秒"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)分"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)小时" : "\(hours)小时\(remainingMinutes)分"
    }

    static func dayTitle(_ date: Date, calendar: Calendar) -> String {
        format(date, pattern: "M月d日 EEEE", calendar: calendar)
    }

    static func fullDate(_ date: Date, calendar: Calendar) -> String {
        format(date, pattern: "yyyy年M月d日", calendar: calendar)
    }

    static func monthTitle(_ date: Date, calendar: Calendar) -> String {
        format(date, pattern: "yyyy年M月", calendar: calendar)
    }

    static func weekday(_ date: Date, calendar: Calendar) -> String {
        format(date, pattern: "E", calendar: calendar)
    }

    static func timeRange(first: Date?, last: Date?, calendar: Calendar) -> String {
        guard let first, let last else { return "—" }
        return "\(format(first, pattern: "HH:mm", calendar: calendar))–\(format(last, pattern: "HH:mm", calendar: calendar))"
    }

    static func periodRange(start: Date, dayCount: Int, calendar: Calendar) -> String {
        let end = calendar.date(byAdding: .day, value: max(0, dayCount - 1), to: start) ?? start
        return "\(format(start, pattern: "M月d日", calendar: calendar)) – \(format(end, pattern: "M月d日", calendar: calendar))"
    }

    static func longestDay(_ day: RecordsDailySummary?, calendar: Calendar) -> String {
        guard let day, day.totalDuration > 0 else { return "—" }
        return "\(format(day.dayStart, pattern: "M月d日", calendar: calendar)) · \(duration(day.totalDuration))"
    }

    private static func format(_ date: Date, pattern: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private extension View {
    func recordsCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }
}

private extension Color {
    func recordsHex(fallback: String) -> String {
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection.current)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return fallback
        }
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}
