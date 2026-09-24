# 赛博谷灵动岛｜纯净通用模板

一个原生 macOS 菜单栏效率工具模板。你可以把角色名、说话风格和透明 PNG 换成任何原创人物、虚拟角色或获得授权的人物素材，做成自己的“OC/角色灵动岛”。

仓库内不包含任何具体角色素材，也不包含任何用户记录。首次运行会使用蓝色占位人物图。

当前版本：**0.1.4**。版本改动、兼容性和升级注意事项见 [CHANGELOG.md](CHANGELOG.md)。

## 它能做什么

- 顶部常驻效率岛：工作、休息、待命、喝水、AI 完成及四类定时提醒。
- 顶部小岛可以拖动边缘缩放，并保存用户设置的比例。
- 记录工作、休息、喝水、AI 完成、打字量、修正率、速度，以及传统自然时间口径的 APM/EPM。
- 鼠标键盘连续 30 分钟无活动后自动待命；恢复真实输入后自动回到工作状态。
- 五分钟休息倒计时、暂停/继续、工作时防止系统休眠。
- 读取 Codex 完成元数据，也支持 Claude、Cursor、Terminal 和其他工具通过本地标记文件桥接。
- 数据只保存在本机；键盘统计只记录数量和类别，不保存输入内容。

### 0.1.4 新增与改动

- 输入仪表分别显示 APM 与 EPM，工作状态常驻小岛显示 EPM。
- APM 统计最近 60 秒内全部非自动重复按键和鼠标点击。
- EPM 使用同一窗口，但排除 Backspace 和 Forward Delete。
- 快捷键和功能键计入操作数，但不会混入普通打字量；不保存具体输入内容。

### 0.1.3 兼容性修复

- 修复部分新版本 macOS 上打包 App 启动即退出、菜单栏图标完全不出现的问题。
- 打包版统一从 `.app` 自身资源目录加载图片，不依赖 SwiftPM 开发资源路径。
- 保持 Universal 2、菜单栏面板可靠打开和现有本地记录格式不变。

## 零基础最快路线

1. 下载本仓库，解压到任意文件夹。
2. 打开 [角色资料表](templates/character-profile.json)，把“你的角色名”和示例文案替换掉。
3. 按 [文案清单](docs/COPYWRITING.md) 准备文案。
4. 按 [图片槽位说明](docs/IMAGE_SLOTS.md) 准备透明 PNG，并覆盖 `Sources/CharacterEfficiencyIsland/Assets` 中的同名文件。
5. 如果不会改代码，把整个文件夹交给 Codex、Claude Code、Cursor 或其他编程 AI，并复制 [AI 定制教程](docs/AI_CUSTOMIZATION.md) 中的提示词。
6. 在终端进入此文件夹，运行：

   ```sh
   ./build_app.sh
   ```

7. 成品位于：

   ```text
   dist/角色效率岛.app
   dist/角色效率岛.zip
   ```

   构建脚本默认生成同时兼容 Apple 芯片与 Intel Mac 的 Universal 2 应用。发布前可运行：

   ```sh
   scripts/verify_universal_app.sh dist/角色效率岛.app
   scripts/verify_universal_app.sh dist/角色效率岛.zip
   ```

如果你是成品包使用者，不需要改代码或换图，可以直接看 [零基础安装和使用教程](docs/BEGINNER_INSTALL_AND_USE.md)。

## 运行要求

- macOS 13 或更高版本。
- Xcode Command Line Tools；未安装时可在终端运行 `xcode-select --install`。
- 首次使用输入统计时，需要在系统设置中允许“输入监控”；部分系统还需要“辅助功能”权限。

此模板使用本地临时签名，未做 Apple 公证。另一台 Mac 打开时可能需要右键 App 选择“打开”，并重新授予输入监控、辅助功能或防休眠相关权限。

## 项目结构

```text
Sources/CharacterEfficiencyIsland/main.swift       应用界面、文案与功能
Sources/CharacterEfficiencyIsland/Assets/          所有可替换图片
Sources/IslandCore/IslandCore.swift                 可复用状态策略
Packaging/Info.plist                                App 名称、Bundle ID、版本号
templates/character-profile.json                    角色资料表
docs/COPYWRITING.md                                 要写哪些文案
docs/IMAGE_SLOTS.md                                 图片放哪里、怎样对齐
docs/AI_CUSTOMIZATION.md                            用不同 AI 工具定制
docs/BEGINNER_INSTALL_AND_USE.md                    给成品用户看的安装和使用教程
docs/RELEASE.md                                     构建与发布检查
build_app.sh                                        一键构建并生成 zip
scripts/verify_universal_app.sh                     验证双架构、签名、版本与 zip
```

## 只想直接让编程 AI 帮你做

把仓库文件夹和你准备的图片交给编程 AI，然后说：

> 请先阅读 README.md、docs/COPYWRITING.md、docs/IMAGE_SLOTS.md 和 docs/AI_CUSTOMIZATION.md。根据 templates/character-profile.json 中的资料制作我的角色效率岛；保留全部功能和隐私规则，只替换角色名、文案、图片、Bundle ID 与打包名。调整每张图的位置后运行 ./build_app.sh，检查 .app 和 .zip 均生成，并告诉我权限设置方法。

更完整、可直接复制的提示词见 [AI 定制教程](docs/AI_CUSTOMIZATION.md)。

## 隐私说明

- 不保存具体键入内容。
- 输入仪表只记录按键类别、数量、时间和鼠标点击等汇总数据。
- 日记录保存在 `~/Library/Application Support/CharacterEfficiencyIsland/`。
- Codex 检测只读取任务完成所需的本地数据；不会改写 Codex 数据库。
- AI 桥接标记保存在 `~/Documents/Codex/.character-efficiency-island-ai-watch/`。

## 使用素材前请确认

请仅使用你原创、已购买许可、属于公有领域，或已获得明确授权的角色图片、字体和标志。公开发布前尤其要检查素材授权。
