# 项目级安装记录

- 技能：`game-ui-ux`
- 上游：https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- 源目录：`skills/disciplines/game-ui-ux`
- 固定提交：`0a70cfc64672d512c5b5b6006b5dcb5cf90dbdbd`
- 安装日期：2026-10-12
- 范围：仅当前赛车项目的 `.agents/skills/`，未更改全局技能或设置。
- 方法：Codex 自带 skill-installer，指定固定提交、项目目标目录和 download 方法。
- 上游 `SKILL.md` 及 `references/layout-and-flow.md` 原样保留；许可证和 NOTICE 随附。

## 使用边界

用于菜单/HUD 的布局适配、焦点导航和界面流程审查，配合已有的 `godot-ui` 实现。
示例是指导片段，不是已经通过本项目验证的游戏代码；使用前核对 API、数值范围、坐标空间和输入处理。
`grab_focus_default()` 示例需要自行实现，不能作为现有 Control API 直接调用。
相关技能名称只是交叉引用，不表示必须额外安装技能、工具或依赖。
不因技能建议扩大平台范围、重写已验证架构，或改变玩家已批准的视觉方案。
人工试玩、图像检查和自动化测试分别报告，不把安装成功等同于游戏体验验证。

此次安装未修改游戏、执行技能示例、安装可执行依赖或启用钩子。
`Taste Skill` 未安装。
