import Foundation

struct RecordsDailySummary: Identifiable {
    let dayStart: Date
    let dayEnd: Date
    let intervals: [DateInterval]

    var id: Date { dayStart }

    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }

    var intervalCount: Int {
        intervals.count
    }

    var longestDuration: TimeInterval {
        intervals.map(\.duration).max() ?? 0
    }

    var firstStart: Date? {
        intervals.first?.start
    }

    var lastEnd: Date? {
        intervals.last?.end
    }
}

struct RecordsPeriodSummary {
    let days: [RecordsDailySummary]

    var totalDuration: TimeInterval {
        days.reduce(0) { $0 + $1.totalDuration }
    }

    var averageDuration: TimeInterval {
        guard !days.isEmpty else { return 0 }
        return totalDuration / Double(days.count)
    }

    var activeDayCount: Int {
        days.filter { $0.totalDuration > 0 }.count
    }

    var longestDay: RecordsDailySummary? {
        days.max { lhs, rhs in
            lhs.totalDuration < rhs.totalDuration
        }
    }
}

enum RecordsAnalytics {
    static func dailySummary(
        for date: Date,
        intervals: [WorkInterval],
        now: Date,
        calendar: Calendar
    ) -> RecordsDailySummary {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        let clipped = intervals.compactMap { interval -> DateInterval? in
            let effectiveEnd = interval.endedAt ?? now
            guard effectiveEnd > interval.startedAt else { return nil }

            let start = max(interval.startedAt, dayStart)
            let end = min(effectiveEnd, dayEnd)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }

        return RecordsDailySummary(
            dayStart: dayStart,
            dayEnd: dayEnd,
            intervals: merge(clipped)
        )
    }

    static func periodSummary(
        startingAt start: Date,
        dayCount: Int,
        intervals: [WorkInterval],
        now: Date,
        calendar: Calendar
    ) -> RecordsPeriodSummary {
        let normalizedStart = calendar.startOfDay(for: start)
        let days = (0..<max(0, dayCount)).compactMap { offset -> RecordsDailySummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: normalizedStart) else {
                return nil
            }
            return dailySummary(for: day, intervals: intervals, now: now, calendar: calendar)
        }
        return RecordsPeriodSummary(days: days)
    }

    static func weekStart(
        containing date: Date,
        preference: WeekStart,
        calendar: Calendar
    ) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart)
        let offset: Int

        switch preference {
        case .monday:
            offset = (weekday + 5) % 7
        case .sunday:
            offset = weekday - 1
        }

        return calendar.date(byAdding: .day, value: -offset, to: dayStart) ?? dayStart
    }

    static func monthStart(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
            ?? calendar.startOfDay(for: date)
    }

    static func numberOfDaysInMonth(containing date: Date, calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 0
    }

    static func weekdayOffset(
        for date: Date,
        preference: WeekStart,
        calendar: Calendar
    ) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        switch preference {
        case .monday:
            return (weekday + 5) % 7
        case .sunday:
            return weekday - 1
        }
    }

    static func weekNumber(
        for date: Date,
        preference: WeekStart,
        calendar: Calendar
    ) -> (year: Int, week: Int) {
        var adjusted = calendar
        adjusted.firstWeekday = preference == .monday ? 2 : 1
        adjusted.minimumDaysInFirstWeek = preference == .monday ? 4 : 1
        let components = adjusted.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return (
            components.yearForWeekOfYear ?? adjusted.component(.year, from: date),
            components.weekOfYear ?? 1
        )
    }

    private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.end < rhs.end
            }
            return lhs.start < rhs.start
        }

        var result: [DateInterval] = []
        for interval in sorted {
            guard let last = result.last else {
                result.append(interval)
                continue
            }

            if interval.start <= last.end {
                result[result.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                result.append(interval)
            }
        }
        return result
    }
}
