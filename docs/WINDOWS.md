# Windows 11 通用版

Windows 版与 macOS 0.1.4 使用同一组角色图片、提醒语义、30 分钟自动待命规则，以及自然 60 秒窗口的 APM/EPM 口径，但不是把 AppKit 程序直接跨平台编译。系统托盘、透明窗口、全局输入统计、启动项和 Codex 检测均使用 Windows 原生能力重新实现。

## 两个产品分支

- `main`：顶部/侧边吸附的灵动岛版。首次启动锁定在当前屏幕工作区顶部中央；拖到左右侧后会吸附屏幕边缘，并允许沿边缘上下调整。侧边模式使用纵向文案，人物保持正向并位于小岛底部。
- `companion`：桌宠版。人物可以在桌面自由拖动和等比缩放，双击桌宠打开控制面板。

两者共用状态、提醒、统计、记录、Codex 检测和托盘面板实现。角色版本应修改同一份 `profile.json` 和图片资源，而不是复制功能代码。

## 内置角色包

仓库目前包含一个纯净通用资料包和七个角色资料包：黄少天、张新杰、叶修、叶修A、苏沐橙、苏沐秋、喻文州。角色包位于 `Windows/CharacterPacks/<角色代号>/`，分别保存 `profile.json` 与 19 张状态图片。功能代码仍只有一份。

每个角色使用独立的 App 名、单实例标识及 `%LOCALAPPDATA%` 根目录；灵动岛和桌宠再使用各自的子目录与 Windows 启动项名称。因此多个角色、同一角色的两种外壳均可同时保留，设置和记录不会互相覆盖。叶修A的界面角色名仍显示“叶修”，但安装包名和存储标识保持独立。

## 当前范围

- Windows 11 x64 优先。
- ZIP 与独立 EXE 两种产物，均为自包含版本，不要求用户预装 .NET。
- 顶部常驻角色、工作/休息/待命/提醒/喝水/Codex 完成状态。
- 传统电竞口径 APM 与 EPM；EPM 排除 Backspace 和 Delete。
- 不保存具体键入内容、剪贴板、窗口标题或输入文本。
- 本地记录保存在 `%LOCALAPPDATA%\CharacterEfficiencyIsland\`。
- 不读取和迁移 macOS 记录。
- 不提供防休眠功能。
- AI 完成提醒第一版只检测 Codex。

## 安装与首次运行

优先把 ZIP 发给测试者：

1. 解压到一个长期保留的文件夹，不要直接在压缩包预览中运行。
2. 双击 `CharacterEfficiencyIsland.exe`。
3. 如果 SmartScreen 显示“Windows 已保护你的电脑”，确认文件来自本仓库后，选择“更多信息”→“仍要运行”。未签名测试包可能出现此提示。
4. 首次启动会自动展开控制面板。以后点击任务栏通知区域里的角色图标即可打开。
5. 如果任务栏上没看到图标，点击右下角 `^` 查看隐藏图标；Windows 只允许用户决定哪些第三方图标常驻任务栏。

启用“登录 Windows 时启动”前，请先把程序放到不会移动的位置。启动项保存的是当前 EXE 的完整路径。

## 操作方式

### 灵动岛版

- 拖动岛身：释放后自动吸附顶部中央、左边缘或右边缘。
- 顶部模式：始终锁定所在屏幕工作区的顶部中央。
- 侧边模式：始终贴住屏幕边缘，沿纵向自由调整。
- 拖动右下角透明缩放区：按原比例缩放，范围 75%—160%。
- 休息状态双击小岛：暂停或继续休息倒计时。
- 工作状态鼠标移到小岛上：临时降低透明度，避免挡住内容。

### 桌宠版

- 拖动人物：自由移动；释放后自动限制在可见工作区内。
- 拖动右下角透明缩放区：按原比例缩放。
- 双击桌宠：打开控制面板。

### 控制面板

点击托盘图标后，面板会在托盘所在任务栏的内侧贴边展开。任务栏位于顶部、底部、左侧或右侧时会自动识别方向。

## 构建

需要 Windows 11 和 .NET 10 SDK：

```powershell
./Windows/build_windows.ps1 -Flavor dynamic-island -Runtime win-x64
./Windows/verify_windows_package.ps1 -Flavor dynamic-island -Runtime win-x64
```

构建指定角色时增加 `-CharacterPack`：

```powershell
./Windows/build_windows.ps1 -Flavor dynamic-island -CharacterPack ye-xiu -Runtime win-x64
./Windows/verify_windows_package.ps1 -Flavor dynamic-island -CharacterPack ye-xiu -Runtime win-x64
```

`companion` 分支使用：

```powershell
./Windows/build_windows.ps1 -Flavor companion -Runtime win-x64
./Windows/verify_windows_package.ps1 -Flavor companion -Runtime win-x64
```

可用的 `CharacterPack` 值为：

```text
generic
huang-shaotian
zhang-xinjie
ye-xiu
ye-xiu-a
su-mucheng
su-muqiu
yu-wenzhou
```

成品位于 `dist/windows/`。角色包会生成角色名明确的 `.exe` 和 `.zip`；ZIP 内的主程序同样使用对应角色名。GitHub Actions 会在 `main` 和 `companion` 分支更新时为通用版和七个角色分别构建下载 Artifact。

## 测试重点

Windows 图形和输入行为必须在真实 Windows 11 机器验证，自动构建成功不能替代以下测试：

1. 100%、125%、150% 和 200% 显示缩放。
2. 主屏、副屏和不同缩放比例的混合多屏。
3. 任务栏位于顶部、底部、左侧、右侧以及自动隐藏。
4. 小岛顶部吸附、左右侧吸附、侧边上下拖动和缩放后重新启动。
5. 托盘图标处于可见区与隐藏区时打开面板。
6. APM/EPM 是否忽略按键自动重复，以及 EPM 是否过滤 Backspace/Delete。
7. Codex 未安装、已安装、数据库正在写入及数据库结构不兼容时都不能导致程序退出。
8. 开机启动后是否只运行一个实例。

## 已知限制

- 未签名 EXE/ZIP 可能触发 SmartScreen，某些企业电脑可能禁止继续运行。
- 安全桌面、UAC 确认界面和高权限程序中的输入可能不计入统计；效率岛不应要求管理员权限。
- Windows 会决定托盘图标是否进入隐藏区，应用不能强制永久显示。
- 第一版 Codex 检测依赖本机 `~\.codex\thread_history_1.sqlite` 及当前数据库结构；读取失败时只停用 AI 完成统计，不影响其他功能。
