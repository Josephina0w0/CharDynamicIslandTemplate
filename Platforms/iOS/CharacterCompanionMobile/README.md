# 喻文州 iPhone / iPad 版

这是现有喻文州 macOS 桌宠的独立原生 SwiftUI 移动端工程。它不会读取或修改 Mac 版数据库，首版数据全部离线保存在独立 App Group 中。

## 第一阶段范围

- iPhone/iPad 三 Tab 工程骨架，默认打开“陪伴”。
- 首次初始化直接进入工作状态，不移植 Mac 自动待机。
- 事件驱动的工作／休息状态机，两种休息模式与恢复逻辑。
- 第一阶段所需的小尺寸交互式 Widget；中尺寸 Widget 已提前做出可运行版本。
- 锁屏 Live Activity（iPhone 13 Pro 的主要展示位置）。
- Widget 与 Live Activity 的工作／休息切换和喝水打卡；喝水后五秒内，中组件在状态标题处显示“喝水打卡成功🏅”，小组件在计时处显示“+1”，大小组件、灵动岛和锁屏实时活动都临时使用第一项提醒人物图。灵动岛与锁屏仍保留原状态文字和连续计时，五秒后各界面恢复原展示。
- 倒计时结束通知，以及“是”“否，延长五分钟”操作。
- 喻文州工作、休息、提醒、首页、Tracker 与记录页素材槽位。

四项提醒编辑、Tracker 与完整日／周／月工作统计均已进入对应阶段并完成首轮实现。

## Apple Watch 后续阶段

watchOS 已纳入路线，但会在 iPhone/iPad 第一阶段完成模拟器截图确认后再接入，避免同时扩大两个尚未经过界面验收的 Target。手表端定位为随身伴侣：显示喻文州当前状态与计时、切换工作／休息、喝水打卡，以及 Smart Stack／表盘组件；设置、统计与记录管理仍放在手机端。

手机与手表是两台设备，不能直接依赖同一个 App Group 文件。实现时以手机事件账本为主数据源，使用 WatchConnectivity 同步快照和动作；手表离线时先保存待同步动作，重新连接后按事件 ID 去重合并。详细安排见 [WATCHOS_ROADMAP.md](Docs/WATCHOS_ROADMAP.md)。

## 打开与签名

1. 安装完整 Xcode 27，并在 Xcode Settings → Platforms 安装需要的 iOS Simulator runtime。
2. 打开 `CharacterCompanionMobile.xcodeproj`。
3. 为 `CharacterCompanionMobile` 与 `CharacterCompanionWidgetExtension` 选择同一个 Team。
4. 如果 Bundle ID 已被占用，同时修改两个 Target 的 Bundle ID。
5. 在 Apple Developer/Xcode 中建立 App Group `group.local.codex.yuwenzhou.companion.mobile`，并确保两个 Target 都勾选它。若修改 App Group，也要同步修改两个 entitlements 和 `SharedStateRepository.appGroupIdentifier`。
6. 先运行主 App 并允许通知，再添加 Widget；主 App 打开后会按系统权限启动 Live Activity。

## 验证顺序

优先选择 iPhone 13 Pro 模拟器，再验证 iPad 竖屏、横屏与分屏。状态切换只在 Widget/Live Activity 中提供，主 App 的休息设置只影响下一次开始休息。

当前 Xcode 27 已完成主 App、Widget 的 iOS Simulator 与 iOS arm64 真机架构构建。iOS 27 与 watchOS 27 runtime 均已安装；主 App 与大小两种 Widget 已在 iPhone 13 Pro 模拟器完成显示验收，并已使用 Personal Team 签名、安装和启动在实体 iPhone 13 Pro（Jo’s MagicPhone）上。App 截图保存在 `Docs/Screenshots/phase1-iphone13pro-clean-v7.png`，Widget 截图保存在 `Docs/Screenshots/phase1-home-widgets-fixed-v10.png`。第二阶段提醒区与深色模式截图分别保存在 `Docs/Screenshots/phase2-reminders-top-v1.png` 和 `Docs/Screenshots/phase2-dark-v3.png`。

当前移动端版本为 `0.1.0 (15)`。第 15 版把 Widget 工作／休息计时改为系统持续计时区间，并把状态快照的恢复刷新从原来的六小时长窗口收紧为 15 分钟；即使系统延迟一次 AppIntent 刷新，也不会让旧暂停状态或旧界面长时间凝固。

### 第一阶段验收状态

已经实现并通过构建、主 App 运行确认：

- iPhone/iPad 共用的原生 SwiftUI 工程、三 Tab 与首页汇总。
- 工作／休息状态机、正计时／倒计时、休息规则和本地持久化。
- 第一阶段所需的小尺寸交互式 Widget、锁屏 Live Activity、工作／休息切换与喝水打卡。
- 第二阶段的中尺寸 Widget 与 App 第一页汇总已提前做出可运行版本。
- 倒计时通知及“是”“否，延长五分钟”操作。
- App Group 共享状态与喻文州工作／休息语义素材。
- 通知已授权后自动隐藏权限提示卡。
- 产品显示名称统一为“喻文州”，不再使用“Companion”后缀。
- 大、小 Widget 均已实际添加到主屏幕，人物图、状态、计时和高对比度按钮显示正常。
- WidgetKit 与 Live Activity 使用轻量透明人物图，避免原始高清图超过系统归档尺寸后退化为灰色占位。
- 强制结束并重开 App 后，工作／休息状态与计时可继续恢复。
- App 第一页日期时间右侧提供电源按钮：暂停时冻结当前计时但不退出 App，再次点击从原状态和原计时继续。
- Live Activity 的人物图、状态和按钮内容已通过系统归档及渲染日志验证。

第一阶段功能代码已经完成，目前只剩以下最终运行验收：

- 在 Device Hub 锁屏中人工确认 Live Activity 的最终视觉：人物图、按钮对比度，以及状态与计时同排显示。
- 分别点击大、小 Widget 和 Live Activity 的工作／休息及喝水按钮，确认交互回写 App 状态。
- 跑完一次倒计时，分别验证结束、确认完成和延长五分钟通知动作。
- 在 iPhone 13 Pro 真机确认后台计时、通知、Widget 与 Live Activity 行为。这是第一阶段尚未完成的正式验收项。
- iPad 竖屏、横屏和分屏属于整套通用版验收，待后续界面阶段一起检查。

这些项目不阻塞第二阶段继续开发。实体 iPhone 13 Pro 已完成连接、签名、安装和启动；剩余项目需要在手机上观察后台经过时间后的系统行为，不能只由一次启动结果代替。

### 第二阶段进度

已完成首轮实现并通过构建、核心逻辑测试与 iPhone 13 Pro 模拟器深浅色检查：

- App 第一页汇总与中尺寸交互式 Widget。
- 四项可独立开关、修改标题和文案的本地提醒。
- 每项提醒可选择固定时间或时间间隔；修改后立即重新安排本地通知。
- 时间间隔最短为 1 分钟：1–15 分钟按 1 分钟增减，15 分钟以上按 5 分钟增减。提醒间隔与休息倒计时共用带浅色背景、无深色描边的加减按钮；按钮自行维持按压计时，不会因数值重绘中断长按连续调整。
- 四项系统通知保留各自的标题、文案、时间和点击行为，但不再附加额外状态图片；这些提醒图片仍用于 App 和 Widget 内的对应状态展示。
- 点击提醒可回到 App 第一页并定位对应提醒卡。
- 编辑提醒文字后，点击任意非输入区域或滚动页面都会自动收起键盘，同时不拦截按钮、开关和时间选择操作。
- Widget 会预排提醒时间线：提醒触发后短暂显示对应图片、标题和文案，再恢复当前工作／休息状态。
- App 与 Widget 的浅色／深色外观适配。
- 提醒时间计算、错过触发后的恢复、下一次触发推进和事件记录均已加入自动测试。

第二阶段仍需做的运行验收：

- 在模拟器或真机分别触发四项提醒，确认通知不带额外状态图、点击跳转和 Widget 提醒画面。
- 验证提醒期间与恢复后的大小 Widget 时间线切换。
- 在后续通用版检查中验证 iPad 竖屏、横屏与分屏。

watchOS App／表盘组件属于后续阶段。

### 第三阶段进度

已完成首轮实现并通过 iPhone 13 Pro 模拟器浅色、深色运行检查：

- Tracker 改用独立 SwiftData 模型保存，不读取或覆盖 Mac 版数据库。
- Daily Top 3 按自然日保存，可直接编辑和勾选完成。
- 本地项目支持名称、阶段、状态、截止日期、下一步行动、跟进日期与备注。
- 支持新增、编辑、完成、重新开始、归档与二次确认删除。
- 支持项目搜索、状态筛选与最近更新／截止日期／跟进日期／名称排序。
- 每次建立、编辑或更改状态都会生成项目历史记录。
- EventKit 只读展示未来 14 天系统日历和未来 30 天未完成提醒事项；系统内容与本地项目使用不同颜色和“只读”标记区分。
- 日历与提醒事项可按系统列表选择是否在 Tracker 展示，选择结果会在本机持续保存；首次权限说明在授权完成后自动隐藏。
- 权限说明明确告知“系统要求完全访问，但本 App 只读取”；拒绝权限不影响 Daily Top 3 和本地项目。
- EventKit 适配层只调用权限、查询和读取接口，不调用保存、修改、删除或提交接口。

浅色、深色截图分别保存在 `Docs/Screenshots/phase3-tracker-light-v1.png` 与 `Docs/Screenshots/phase3-tracker-dark-v1.png`。

第三阶段仍需真机运行验收：新增并编辑一个项目、重启后确认保存，分别允许或拒绝日历与提醒事项权限，并确认系统内容只有展示入口、没有写入操作。

### 第四阶段进度

已完成首轮实现并通过 iPhone 13 Pro 模拟器运行检查与独立统计测试：

- “记录”页按统一工作区间生成日、周、月统计，不依赖屏幕使用时间或系统开关机状态。
- 日视图可前后切换日期，展示 0–24 小时真实工作分布、总时长、区间数、最长连续工作与首次／最后时间。
- 跨午夜区间会按自然日拆分；正在进行的工作区间会持续延伸到当前时刻。
- 周视图展示七天柱状图、总时长、日均、最多一天和活跃天数；可选择周一或周日为每周开始日并立即重算。
- 月视图使用可点击的日历热力图，展示每天是否工作和相对时长；点按日期可回到日视图查看详情。
- 工作颜色可通过完整系统取色器选择并持久保存，日、周、月图表统一使用同一个颜色，同时保留浅色／深色背景下的可见边缘。
- 日期导航不会进入未来日期、未来周或未来月份；当前月的未来日期不可点击。
- 独立统计测试覆盖跨午夜、进行中区间、重叠区间合并、周起始日，以及夏令时切换形成的 23 小时自然日。

第四阶段仍需真机运行验收：切换日／周／月、修改工作颜色和周起始日后重启 App，确认设置保存；再让工作计时跨过一次自然日，确认两天统计正确拆分。

### 可复用完整包

用于其他 Codex 会话或制作其他角色的完整入口位于：

- `companion-pack/陪伴版-喻文州`
- `companion-pack/skills/companion-yuwenzhou-mobile`

Skill 安装后可直接调用 `$companion-yuwenzhou-mobile`。完整包包含架构、工作流、角色资料结构、图片槽位、QA、设备构建安装脚本与源码／安装包打包脚本。

## 在 Xcode 27 中操作模拟器

Xcode 27 把原来的独立 Simulator 窗口整合进了 Device Hub。选择菜单 **Xcode → Open Developer Tool → Device Hub**，在左侧选择 **喻文州 iPhone 13 Pro**；中间出现的手机画面可以直接用鼠标点击和滚动。若显示紧凑窗口，可点工具栏中的展开按钮查看侧栏和完整控制。

重新运行时打开 `CharacterCompanionMobile.xcodeproj`，在 Xcode 顶部依次选择 `CharacterCompanionMobile` Scheme 和 **喻文州 iPhone 13 Pro** 运行目标，再点三角形 Run。主 App 里可以直接操作休息规则、通知权限和底部 Tab；工作／休息切换与喝水打卡按第一阶段设计放在 Widget 和锁屏 Live Activity。

完整限制见 [TECHNICAL_FEASIBILITY.md](Docs/TECHNICAL_FEASIBILITY.md)。
