# Character Companion 通用开发包

这个目录保存 Companion 系列的可复用开发 Skill，而不是某一个角色的成品。

## 内容

- `skills/character-companion-builder/SKILL.md`：任务路由与必须保持的产品约束。
- `references/architecture.md`：单进程桌宠 + Tracker 架构。
- `references/workflow.md`：从产品 Profile 到打包交付的完整流程。
- `references/roadmap.md`：通用平台、配置化、图片归一化、领域包和发布工程路线。
- `references/profile-schema.md`：角色、Tracker、存储和发行配置字段。
- `references/asset-normalization.md`：透明 PNG 可见边界、底边锚定与跨状态尺寸一致性。
- `references/qa-checklist.md`：交互、数据隔离、隐私、Universal 2 与压缩包验证。
- `assets/companion-profile.yaml`：新 Companion 的配置模板。
- `scripts/`：图片检查与发行验证脚本。

可运行的角色无关基线位于 `variants/character-companion-general`。复制基线制作新版本，不要直接把个人成品或私人 Tracker 数据当成模板。
