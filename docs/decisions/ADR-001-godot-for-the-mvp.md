# ADR-001：MVP 采用 Godot 4 与 GDScript

## 状态

已接受（2026-07-28）

## 背景

这是一个从空仓库起步、PC 键盘优先的轻量 2D 街机赛车项目。核心需求是快速迭代纵向卷轴、碰撞、车辆生成、音效反馈和 Windows 导出；不需要复杂 3D、联网或商业化基础设施。

## 决策

使用 Godot 4 + GDScript。场景按职责拆分为：`Main`（流程）、`PlayerCar`、`TrafficCar`、`Road`、`HUD` 与 `RunState`（运行规则）。

## 备选方案

### JavaScript + Canvas/Phaser

浏览器试玩便利，但碰撞、资源管理与 Windows 打包都需要额外的工程取舍；不作为当前的最快路径。

### Unity

工具成熟、平台覆盖广，但对这个原型而言项目和编辑器复杂度较高。

## 后果

- 开发机须安装 Godot 4。
- 代码与场景文件以 GDScript、`.tscn` 为项目约定。
- Windows 是首个导出目标；核心循环稳定后再评估 Web。
- 不在项目中使用或导入任何《Road Fighter》原始资源或可识别内容。
