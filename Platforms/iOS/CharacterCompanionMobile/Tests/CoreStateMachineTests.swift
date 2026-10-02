import Foundation

@main
enum CoreStateMachineTests {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var state = CompanionState.initial(now: start)
        expect(state.mode == .working, "首次初始化后应进入工作状态")
        expect(state.workIntervals.count == 1 && state.workIntervals[0].endedAt == nil, "初始化应创建未结束工作区间")

        state.preferences.restMode = .countdown
        state.preferences.countdownMinutes = 5
        let breakStart = start.addingTimeInterval(600)
        expect(state.transition(to: .resting, source: .widget, now: breakStart), "应能从工作切换到休息")
        expect(state.workIntervals[0].endedAt == breakStart, "开始休息时应结束工作区间")
        expect(state.breakEndAt == breakStart.addingTimeInterval(300), "倒计时结束时间应使用设置值")
        state.preferences.restMode = .stopwatch
        state.preferences.countdownMinutes = 30
        expect(state.currentRestMode == .countdown, "休息中修改设置不应改变当前休息方式")

        let due = breakStart.addingTimeInterval(301)
        state.normalize(at: due)
        expect(state.isAwaitingConfirmation(at: due), "倒计时结束后必须等待确认")
        expect(state.mode == .resting, "未处理通知时不得自动切回工作")

        state.extendBreakByFiveMinutes(source: .notificationAction, now: due)
        expect(state.breakEndAt == due.addingTimeInterval(300), "选择否应从操作时刻延长五分钟")
        expect(!state.isAwaitingConfirmation(at: due), "延长后应清除等待确认")

        let resume = due.addingTimeInterval(60)
        expect(state.transition(to: .working, source: .notificationAction, now: resume), "选择是应恢复工作")
        expect(state.restIntervals[0].endedAt == resume, "恢复工作时应结束休息区间")
        expect(state.workIntervals.count == 2, "恢复工作时应新建工作区间")

        state.logWater(source: .widget, now: resume)
        expect(state.waterCount(on: resume) == 1, "喝水事件应按自然日统计")
        expect(state.isShowingWaterFeedback(at: resume.addingTimeInterval(4.9)), "喝水后五秒内应显示打卡反馈")
        expect(!state.isShowingWaterFeedback(at: resume.addingTimeInterval(5)), "喝水反馈满五秒后应恢复原状态")

        let openWork = state.workIntervals.filter { $0.endedAt == nil }
        expect(openWork.count == 1, "并发安全状态应最多保留一个进行中工作区间")

        var pausedState = CompanionState.initial(now: start)
        expect(pausedState.currentStatusDisplayName == "工作中", "正常工作时当前状态应显示工作中")
        let pauseDate = start.addingTimeInterval(120)
        expect(pausedState.toggleTimingPause(source: .app, now: pauseDate), "电源按钮首次点击应暂停计时")
        expect(pausedState.currentStatusDisplayName == "待机中", "暂停计时后当前状态应显示待机中")
        expect(pausedState.elapsed(at: pauseDate.addingTimeInterval(60)) == 120, "暂停期间工作计时应冻结")
        expect(pausedState.workIntervals[0].endedAt == pauseDate, "暂停时应结束当前计时区间，避免累计暂停时长")
        let resumeDate = pauseDate.addingTimeInterval(60)
        expect(!pausedState.toggleTimingPause(source: .app, now: resumeDate), "电源按钮再次点击应继续计时")
        expect(pausedState.currentStatusDisplayName == "工作中", "恢复计时后当前状态应恢复为工作中")
        expect(pausedState.elapsed(at: resumeDate) == 120, "继续计时时应续上暂停前的数值")
        expect(pausedState.workIntervals.count == 2 && pausedState.workIntervals[1].endedAt == nil, "继续后应建立新的活动工作区间")
        expect(pausedState.elapsed(at: resumeDate.addingTimeInterval(30)) == 150, "继续后计时应正常向前推进")

        var pausedBreak = CompanionState.initial(now: start)
        pausedBreak.preferences.restMode = .countdown
        pausedBreak.preferences.countdownMinutes = 5
        _ = pausedBreak.transition(to: .resting, source: .widget, now: start)
        let breakPauseDate = start.addingTimeInterval(60)
        _ = pausedBreak.toggleTimingPause(source: .app, now: breakPauseDate)
        expect(pausedBreak.remainingBreak(at: breakPauseDate.addingTimeInterval(90)) == 240, "暂停期间休息倒计时应冻结")
        _ = pausedBreak.toggleTimingPause(source: .app, now: breakPauseDate.addingTimeInterval(90))
        expect(pausedBreak.breakEndAt == start.addingTimeInterval(390), "继续休息时应把结束时间顺延暂停时长")

        var reminderState = CompanionState.initial(now: start)
        reminderState.normalize(at: start)
        expect(reminderState.reminders.count == 4, "首次初始化应创建四项提醒")
        expect(reminderState.reminders.allSatisfy { $0.nextTriggerAt != nil }, "启用的提醒应生成下一次触发时间")

        let intervalTrigger = CompanionReminderTiming.nextTrigger(
            for: .interval(minutes: 60),
            after: start
        )
        expect(intervalTrigger == start.addingTimeInterval(3_600), "间隔提醒应按设定分钟数推进")

        let oneMinuteTrigger = CompanionReminderTiming.nextTrigger(
            for: .interval(minutes: 1),
            after: start
        )
        expect(oneMinuteTrigger == start.addingTimeInterval(60), "最短间隔提醒应支持一分钟")

        let calendar = Calendar(identifier: .gregorian)
        let fixedTrigger = CompanionReminderTiming.nextTrigger(
            for: .fixed(hour: 12, minute: 34),
            after: start,
            calendar: calendar
        )
        let fixedComponents = calendar.dateComponents([.hour, .minute], from: fixedTrigger)
        expect(fixedTrigger > start, "固定时间提醒必须指向未来")
        expect(fixedComponents.hour == 12 && fixedComponents.minute == 34, "固定时间提醒应保留小时和分钟")

        let dueReminderDate = start.addingTimeInterval(-30)
        reminderState.reminders[0].schedule = .interval(minutes: 60)
        reminderState.reminders[0].nextTriggerAt = dueReminderDate
        reminderState.reminders[0].lastTriggeredAt = nil
        reminderState.normalize(at: start)
        expect(reminderState.reminders[0].lastTriggeredAt == dueReminderDate, "恢复时应记录已到期提醒")
        expect((reminderState.reminders[0].nextTriggerAt ?? start) > start, "恢复后应推进到下一次未来提醒")
        expect(
            reminderState.events.contains { $0.kind == .reminderTriggered && $0.detail == reminderState.reminders[0].id },
            "提醒触发应写入统一事件流"
        )
        print("CoreStateMachineTests: PASS")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("CoreStateMachineTests: FAIL — \(message)\n", stderr)
            exit(1)
        }
    }
}
