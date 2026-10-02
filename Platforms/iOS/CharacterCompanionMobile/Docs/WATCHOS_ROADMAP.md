# 喻文州 watchOS 路线

## 产品定位

Apple Watch 版是手机端的随身入口，不复制手机三 Tab。第一版只保留高频、抬腕即可完成的操作：

- 显示喻文州工作／休息状态与实时计时。
- 一键切换工作／休息。
- 一键喝水打卡。
- 倒计时休息结束后的确认或延长五分钟。
- Smart Stack Widget 与表盘 Complication 的紧凑状态展示。

休息模式、提醒时间、完整统计和历史记录由 iPhone/iPad 管理。

## 数据架构

- iPhone 继续持有现有 App Group 事件账本，作为主数据源。
- Watch 使用本地镜像保存最近状态、事件 ID 与尚未送达手机的动作。
- WatchConnectivity 的 application context 负责传递最新完整快照；即时消息用于双方可达时的快速动作回执；后台 user info 用于不要求立即返回的补送。
- 每个动作携带稳定事件 ID，手机合并时去重，避免断网重试造成两次喝水或两次状态切换。
- 手机不可达时，手表立即在本地做乐观更新并标注待同步；恢复连接后以事件顺序合并，手机生成的新快照再回传手表。

## 实施阶段

1. 先完成 iPhone 13 Pro 与 iPad 的第一阶段启动和截图验收。
2. 新增 watchOS App 与 Watch Widget Extension Target，共享纯 Swift 状态模型与喻文州语义素材。
3. 接入 WatchConnectivity 桥接和离线动作队列。
4. 验证手表在线、手机离线、手表离线、重复投递与跨日恢复。
5. 验证 Smart Stack／Complication 的小尺寸可读性和耗电约束。

## 验收标准

- 手机与手表对同一事件最终得到一致状态，重复消息不重复计数。
- 抬腕后可以在一个页面内看清角色、状态和计时，并在一次点击内完成切换或喝水。
- 手表离线操作不会丢失，恢复连接后能补同步。
- 手机端第一阶段功能和既有 macOS 喻文州桌宠不被回归修改。

## Apple 官方依据

- [Watch Connectivity](https://developer.apple.com/documentation/WatchConnectivity)：用于配对的 iOS App 与 watchOS App 双向传递少量数据、文件和后台更新，也支持双方活跃时的即时通信。
- [Transferring data with Watch Connectivity](https://developer.apple.com/documentation/WatchConnectivity/transferring-data-with-watch-connectivity)：Apple 的配套示例包含无网络时的数据交换、后台任务以及真机配对验证要求。
- [WidgetKit](https://developer.apple.com/documentation/widgetkit/)：Apple Watch 的小组件位于 Smart Stack，Complication 位于表盘；系统用时间线以节能方式更新内容。
