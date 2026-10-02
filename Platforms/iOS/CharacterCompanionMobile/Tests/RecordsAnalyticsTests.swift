import Foundation

@main
enum RecordsAnalyticsTests {
    static func main() {
        testCrossMidnightSplit()
        testOngoingInterval()
        testOverlappingIntervalsMerge()
        testWeekStarts()
        testDaylightSavingBoundary()
        print("RecordsAnalyticsTests: PASS")
    }

    private static func testCrossMidnightSplit() {
        let calendar = calendar(timeZone: "Europe/London")
        let firstDay = date("2026-10-01 23:30", calendar: calendar)
        let end = date("2026-10-02 01:30", calendar: calendar)
        let interval = workInterval(start: firstDay, end: end)

        let dayOne = RecordsAnalytics.dailySummary(
            for: firstDay,
            intervals: [interval],
            now: end,
            calendar: calendar
        )
        let dayTwo = RecordsAnalytics.dailySummary(
            for: end,
            intervals: [interval],
            now: end,
            calendar: calendar
        )

        expect(dayOne.totalDuration == 30 * 60, "跨午夜区间在第一天应只统计午夜前的 30 分钟")
        expect(dayTwo.totalDuration == 90 * 60, "跨午夜区间在第二天应只统计午夜后的 90 分钟")
    }

    private static func testOngoingInterval() {
        let calendar = calendar(timeZone: "Asia/Shanghai")
        let start = date("2026-10-02 09:00", calendar: calendar)
        let now = date("2026-10-02 10:45", calendar: calendar)
        let interval = workInterval(start: start, end: nil)
        let summary = RecordsAnalytics.dailySummary(
            for: now,
            intervals: [interval],
            now: now,
            calendar: calendar
        )
        expect(summary.totalDuration == 105 * 60, "进行中的区间应延伸到当前时刻")
    }

    private static func testOverlappingIntervalsMerge() {
        let calendar = calendar(timeZone: "UTC")
        let day = date("2026-10-02 10:00", calendar: calendar)
        let intervals = [
            workInterval(
                start: date("2026-10-02 10:00", calendar: calendar),
                end: date("2026-10-02 11:00", calendar: calendar)
            ),
            workInterval(
                start: date("2026-10-02 10:30", calendar: calendar),
                end: date("2026-10-02 12:00", calendar: calendar)
            )
        ]
        let summary = RecordsAnalytics.dailySummary(
            for: day,
            intervals: intervals,
            now: date("2026-10-02 13:00", calendar: calendar),
            calendar: calendar
        )
        expect(summary.totalDuration == 2 * 60 * 60, "重叠区间不应重复累计")
        expect(summary.intervalCount == 1, "重叠区间应合并为一个连续区间")
    }

    private static func testWeekStarts() {
        let calendar = calendar(timeZone: "UTC")
        let wednesday = date("2026-09-30 12:00", calendar: calendar)
        let monday = RecordsAnalytics.weekStart(containing: wednesday, preference: .monday, calendar: calendar)
        let sunday = RecordsAnalytics.weekStart(containing: wednesday, preference: .sunday, calendar: calendar)
        expect(calendar.component(.weekday, from: monday) == 2, "周一开始设置应回到周一")
        expect(calendar.component(.weekday, from: sunday) == 1, "周日开始设置应回到周日")
    }

    private static func testDaylightSavingBoundary() {
        let calendar = calendar(timeZone: "America/New_York")
        let day = date("2026-03-08 00:00", calendar: calendar)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        expect(nextDay.timeIntervalSince(day) == 23 * 60 * 60, "夏令时切换日应使用真实的 23 小时自然日")

        let interval = workInterval(start: day, end: nextDay)
        let summary = RecordsAnalytics.dailySummary(
            for: day,
            intervals: [interval],
            now: nextDay,
            calendar: calendar
        )
        expect(summary.totalDuration == 23 * 60 * 60, "夏令时切换日统计不应硬编码为 24 小时")
    }

    private static func workInterval(start: Date, end: Date?) -> WorkInterval {
        WorkInterval(
            id: UUID(),
            startedAt: start,
            endedAt: end,
            source: .app,
            createdAt: start,
            updatedAt: end ?? start
        )
    }

    private static func calendar(timeZone identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private static func date(_ value: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let result = formatter.date(from: value) else {
            fatalError("无法解析测试日期：\(value)")
        }
        return result
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("RecordsAnalyticsTests: FAIL — \(message)\n", stderr)
            exit(1)
        }
    }
}
