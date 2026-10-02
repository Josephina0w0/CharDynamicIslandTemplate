# 第一阶段技术可行性结论

## 系统原生可实现

- iPhone 13 Pro 没有 Dynamic Island，最可靠的 Live Activity 展示面是锁屏；通知中心、主屏或顶部等其他展示位置取决于当前 iOS 版本与系统调度，App 不能指定或保证。
- Widget 与 Live Activity 的按钮使用 App Intents；状态切换、喝水打卡和通知操作写入同一个 App Group 事件账本。
- 交互意图采用 `LiveActivityIntent`，让系统在 App 进程中执行关键动作，而不打开 App 界面；这样可可靠更新仍存在的 Live Activity，并按新休息状态安排本地通知。
- 工作和休息计时由开始／结束时间推导，Widget 与 Live Activity 使用系统计时文本，不需要 App 每秒后台运行或写盘。
- 自定义倒计时结束通过本地通知触发；“是”结束休息并开始新工作区间，“否”从操作时刻延长五分钟。
- 用户不处理通知时，持久状态仍为休息；下次系统界面刷新或 App 恢复时显示“等待确认”。
- 正计时休息没有自动结束通知，只能由 Widget 或 Live Activity 切回工作。

## 系统限制与对应方案

- WidgetKit 时间线不是闹钟，不能保证精确刷新，所以准时提醒以本地通知为准。
- iOS 不保证 Live Activity 永久保留；用户或系统移除它不会删除事件账本，App 下次打开时可以恢复或重新创建显示。
- 若 Live Activity 已被系统结束，主 App 打开时会恢复显示；Widget 的交互意图也会在系统授权允许时尝试重新创建，但最终是否展示仍由系统决定。
- 倒计时到点时，扩展不会获得持续后台执行机会；未处理通知期间，事件账本按结束时间推导“等待确认”，但锁屏标题何时重绘仍由系统调度。
- 真机签名必须让主 App 与 Widget Extension 使用同一开发团队，并创建与源码一致的 App Group；免费个人签名能力是否开放由 Apple 当前签名服务决定。

## Apple 官方依据

- [ActivityKit](https://developer.apple.com/documentation/ActivityKit)：Live Activity 由 App 启动和更新，界面由 WidgetKit/SwiftUI 承载，显示位置由系统管理。
- [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)：交互式按钮使用 App Intents；`LiveActivityIntent` 在 App 进程中执行。
- [Displaying dynamic dates in widgets](https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates)：系统计时文本可以在扩展不持续运行时继续更新。
- [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)：App 或 App Extension 都可以管理本地通知；通知分类与操作按钮由系统分发给 delegate。

## 当前开发机验证状态

2026-10-01 最新检查结果：Xcode 27（27A266a）已安装并选为活动开发目录，iPhoneOS 27.0 SDK 可用。主 App 与 Widget Extension 已分别完成 iOS Simulator 构建和 iOS arm64 真机架构构建，资源目录、App Intents 元数据及嵌入扩展均通过 Xcode 验证。

iOS 27（24A434）与 watchOS 27（24R362）runtime 均已由 `simctl` 识别。已创建并启动专用 iPhone 13 Pro 模拟器，主 App 完成安装和首次启动，首页角色、实时计时、统计卡片及三 Tab 导航均可渲染；当前验收截图见 `Docs/Screenshots/phase1-iphone13pro-layout-v3.png`。

这次首次运行只确认主界面能够真实启动和渲染。通知操作、交互式 Widget、Live Activity、状态切换持久化以及 iPad 竖屏／横屏／分屏仍需分别完成运行验收。
