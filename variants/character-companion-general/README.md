# Character Companion

角色无关的原生 macOS 桌宠效率工具与通用 Tracker 基线。它不绑定喻文州或任何特定人物；仓库内图片只作为可运行的示例主题，新角色通过替换语义图片槽位和少量集中配置即可制作。

## 已包含

- 单一 `NSApplication`、状态栏图标与统一菜单。
- 屏幕右下角桌宠；可拖动、按人物边缘缩放并保存位置和比例。
- 人物点击开关控制面板，点击面板外自动收起。
- 固定大小的工作时间 / EPM 圆角信息框，不随人物缩放。
- 工作、休息、待命、喝水、AI 与四种提醒状态。
- 通用 Tracker：月历、Daily Top 3、项目阶段、截止日期、跟进与下一步。
- 只读 iCloud 日历，不创建、修改或删除日历内容。
- 独立数据目录 `~/Library/Application Support/CharacterCompanion/`。

## 做一个新角色版本

1. 复制本目录，排除 `.build` 和 `dist`。
2. 修改 `Sources/Companion/CompanionProfile.swift` 中的运行时名称。
3. 修改 `Package.swift`、`Packaging/Info.plist` 与 `build_app.sh` 中的唯一产品身份。
4. 替换 `Sources/Companion/Assets/EfficiencyIsland/` 下的语义图片槽位；保留文件名即可无需改状态逻辑。
5. 替换 Tracker 的 `character.png` 与 `statusIcon.png`，按需要选择通用或领域 Tracker。
6. 使用 `companion-pack/skills/character-companion-builder/` 的 Workflow 和 QA 清单完成校验。

角色图片槽位为：`working`、`break`、`idle`、`water`、`alert`、`ai`、`reminder-first` 至 `reminder-fourth`；`panel-*` 是设置面板中的独立预览图。

## 构建

```sh
./build_app.sh
```

输出为 Universal 2（Apple 芯片 + Intel）的 `dist/Character Companion.app` 和 `dist/Character Companion.zip`。仓库只提交源码和资源，不提交本地构建产物。

## 隐私与数据隔离

- 不包含私人 PhD 申请、联系人、学校、论文节点或个人日历种子。
- 输入统计只记录数量、速度和活跃状态，不记录输入内容。
- 新变体必须使用新的 Bundle ID、可执行文件名和 Application Support 根目录。
