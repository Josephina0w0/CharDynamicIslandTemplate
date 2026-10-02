# 陪伴版-喻文州

这是喻文州原生 iPhone/iPad 陪伴 App 的完整复用入口。当前基线版本为 `0.1.0 (16)`，包含陪伴首页、大小两种交互式 Widget、锁屏实时活动、灵动岛、四项提醒、Tracker、日/周/月工作记录，以及 Widget 凝固与按钮同步修复。

## 入口

- App 源码：[`Platforms/iOS/CharacterCompanionMobile`](../../Platforms/iOS/CharacterCompanionMobile)
- Codex Skill：[`companion-yuwenzhou-mobile`](../skills/companion-yuwenzhou-mobile/SKILL.md)
- 架构：[`architecture.md`](../skills/companion-yuwenzhou-mobile/references/architecture.md)
- 制作工作流：[`workflow.md`](../skills/companion-yuwenzhou-mobile/references/workflow.md)
- 角色资料结构：[`profile-schema.md`](../skills/companion-yuwenzhou-mobile/references/profile-schema.md)
- 图片槽位：[`asset-map.md`](../skills/companion-yuwenzhou-mobile/references/asset-map.md)
- 验收表：[`qa-checklist.md`](../skills/companion-yuwenzhou-mobile/references/qa-checklist.md)
- 构建与分发：[`distribution.md`](../skills/companion-yuwenzhou-mobile/references/distribution.md)

## 在其他 Codex 会话调用

本机安装 Skill 后，在新会话中直接说：

```text
$companion-yuwenzhou-mobile 请以陪伴版-喻文州为蓝本，为【角色名】制作手机版陪伴 App。
```

也可以自然描述“以喻文州手机版为蓝本做另一个角色”，该 Skill 允许自动发现。

GitHub 中的 Skill 路径：

```text
companion-pack/skills/companion-yuwenzhou-mobile
```

其他电脑可先克隆仓库的 `companion` 分支，再把该目录复制到 `~/.codex/skills/`。

## 本机成品包

生成后的文件放在 `dist/`：

- `陪伴版-喻文州-source.zip`：完整移动端源码与文档。
- `陪伴版-喻文州-build16-iphoneos.app.zip`：当前签名环境下的 iPhone App 包。
- `陪伴版-喻文州-build16-simulator.app.zip`：模拟器 App 包。
- `companion-yuwenzhou-mobile.skill.zip`：可单独安装的 Codex Skill。
- `SHA256SUMS`：所有压缩包的完整性校验值。

设备 App 包受 Apple 签名限制，不能作为面向任意 iPhone 的通用安装包；源码包和 Skill 包不受此限制。

## 制作其他角色

不要直接改喻文州基线。使用 Skill 中的复制脚本建立独立目录：

```sh
python3 ../skills/companion-yuwenzhou-mobile/scripts/create_variant.py \
  ../../Platforms/iOS/CharacterCompanionMobile \
  /absolute/path/to/NewCharacterCompanion \
  "新角色名" \
  "com.example.newcharacter.companion" \
  "newcharacter-companion"
```

复制完成后更换 Profile、全部人物素材、Bundle ID、App Group 与签名 Team，并执行完整验收表。

## 权利与隐私

App 数据默认只保存在用户设备；系统日历和提醒事项仅只读展示。公开发布任何角色版本前，需要确认角色名称、立绘、图标、字体和文案的使用授权。
