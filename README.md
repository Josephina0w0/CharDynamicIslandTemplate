# 赛博谷 Character Companion｜`companion` 分支

> [!IMPORTANT]
> 当前是 `companion` 开发分支，不是仓库默认的 `main` 分支。本分支在原有角色效率岛模板之外，增加了一个角色无关的「桌宠 + 效率计时 + Tracker」原生 macOS App；不会覆盖 `main` 中的顶部灵动岛模板。

## 分支说明

`companion` 面向需要桌面陪伴形态、工作状态反馈和项目追踪的人。角色默认出现在屏幕右下角，人物与工作信息框分离：人物可以拖动和独立缩放，工作时间与 EPM 信息框保持固定尺寸。点击人物可以开关控制面板，点击面板之外会自动收起。

| 对比项 | `main` | `companion` |
| --- | --- | --- |
| 主要形态 | 顶部角色效率岛模板 | 右下角桌宠 + Tracker |
| 角色绑定 | 无具体角色 | 无具体角色，可配置任意角色 |
| 效率功能 | 工作、休息、提醒、APM/EPM | 保留效率功能，并增加桌宠交互 |
| Tracker | 无 | 日历、Daily Top 3、项目阶段、截止与跟进 |
| 开发资料 | 灵动岛定制文档 | 额外提供 Companion Skill、Workflow、Roadmap 与 QA |

本分支包含：

- [Character Companion 通用源码](variants/character-companion-general/)：可直接构建的角色无关基线，使用蓝色占位素材，不包含私人数据。
- [Companion 通用开发包](companion-pack/)：角色 Profile、架构、图片归一化、测试与发布工具。
- [Character Companion Builder Skill](companion-pack/skills/character-companion-builder/SKILL.md)：制作新角色或新 Tracker 领域时的统一工作流。
- [产品 Roadmap](companion-pack/skills/character-companion-builder/references/roadmap.md) 与 [完整 Workflow](companion-pack/skills/character-companion-builder/references/workflow.md)。
- [陪伴版-喻文州 iPhone/iPad 基线](Platforms/iOS/CharacterCompanionMobile/)：原生 SwiftUI App、大小 Widget、Live Activity、提醒、Tracker 与日/周/月记录。
- [陪伴版-喻文州完整包](companion-pack/陪伴版-喻文州/) 与 [移动端 Skill](companion-pack/skills/companion-yuwenzhou-mobile/SKILL.md)：用于在其他会话或电脑上继续维护，并以当前版本制作其他角色。

移动端 Skill 安装后可以在 Codex 新会话中直接调用：

```text
$companion-yuwenzhou-mobile 请以陪伴版-喻文州为蓝本，为【角色名】制作手机版陪伴 App。
```

通用版保持输入隐私，只统计按键与鼠标操作的数量和类别，不保存具体输入内容；iCloud 日历访问默认为只读。发行构建为 Universal 2，同时支持 Apple 芯片与 Intel Mac。

快速构建 Companion：

```sh
cd variants/character-companion-general
./build_app.sh
```

输出位于 `variants/character-companion-general/dist/`。

## 原始灵动岛模板基线

一个角色效率工具模板。稳定版为原生 macOS 菜单栏灵动岛；仓库同时开始提供 Windows 11 通用版，支持顶部/侧边吸附灵动岛和桌宠两种外壳。你可以把角色名、说话风格和透明 PNG 换成任何原创人物、虚拟角色或获得授权的人物素材。

仓库内不包含任何具体角色素材，也不包含任何用户记录。首次运行会使用蓝色占位人物图。

当前版本：**0.1.4**。版本改动、兼容性和升级注意事项见 [CHANGELOG.md](CHANGELOG.md)。

Windows 版当前为 **0.1.4-win.1 Beta**：`main` 分支构建吸附灵动岛，`companion` 分支构建桌宠。安装、操作、隐私、已知限制和测试清单见 [Windows 11 通用版说明](docs/WINDOWS.md)。

## 它能做什么

- 顶部常驻效率岛：工作、休息、待命、喝水、AI 完成及四类定时提醒。
- 顶部小岛可以拖动边缘缩放，并保存用户设置的比例。
- 记录工作、休息、喝水、AI 完成、打字量、修正率、速度，以及传统自然时间口径的 APM/EPM。
- 鼠标键盘连续 30 分钟无活动后自动待命；恢复真实输入后自动回到工作状态。
- 五分钟休息倒计时、暂停/继续、工作时防止系统休眠。
- 读取 Codex 完成元数据，也支持 Claude、Cursor、Terminal 和其他工具通过本地标记文件桥接。
- 数据只保存在本机；键盘统计只记录数量和类别，不保存输入内容。

> Windows 版按用户选择不提供防休眠功能，AI 完成提醒第一阶段只支持 Codex；macOS 0.1.4 的既有功能保持不变。

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
Windows/CharacterEfficiencyIsland.Windows/          Windows 11 WPF 通用工程
Windows/CharacterPacks/                              Windows 七个角色的独立资料与图片包
Windows/build_windows.ps1                           Windows EXE/ZIP 构建脚本
docs/WINDOWS.md                                     Windows 安装、功能和测试说明
companion-pack/skills/character-companion-builder/  Companion 定制 Skill 与开发资料
variants/character-companion-general/               macOS 通用桌宠与 Tracker 工程
```

Windows 构建脚本支持 `generic`、`huang-shaotian`、`zhang-xinjie`、`ye-xiu`、`ye-xiu-a`、`su-mucheng`、`su-muqiu`、`yu-wenzhou` 八个资料包。每个角色使用独立本地记录目录和启动项名称，不会互相覆盖。

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
