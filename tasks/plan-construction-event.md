# 实施计划：施工导流封道

## 架构决定

- 扩展 `LaneEventDirector`，保留现有事件编排入口，同时把单个 `lane` 升级为局部 `closed_lanes` 和阶段进度。
- `LaneEventDirector` 只负责确定性状态、几何标记与碰撞消费；`main.gd` 负责绘制和把碰撞结果应用到玩家。
- `TrafficDirector` 和 `FuelSpawnDirector` 只消费事件公开的封闭车道集合，不直接了解绘制细节。
- 每个切片先写失败测试，再写最小实现。

## 阶段一：单车道施工纵向切片

### Task 1：局部事件契约

**验收：** 单车道事件只选择外侧车道；状态包含预警、施工和恢复所需进度；不再强制投射玩家位置。

**验证：** `tests/test_lane_event_director.gd` 先失败后通过。

**文件：** `scripts/lane_event_director.gd`、`scripts/game_config.gd`、`tests/test_lane_event_director.gd`。

### Task 2：可视施工与碰撞

**验收：** 锥桶渐进进入、可撞开且有重复伤害保护；核心障碍不可穿；旧全屏蒙层和强制横移被移除。

**验证：** 新增逻辑测试，运行主场景烟雾测试。

**文件：** `scripts/main.gd`、`scripts/lane_event_director.gd`、相关测试。

### Checkpoint：单车道

- 相关测试与完整测试通过。
- 人工确认导流方向、撞锥桶手感和施工核心可读性。

## 阶段二：困难难度双车道封闭

### Task 3：双车道安全选择

**验收：** 仅困难难度启用；只封相邻两车道；玩家位于中间车道时回退到单封道；每局最多一次并始终保留安全通道。

**验证：** 固定种子、事件次数、双封道上限和安全通道测试。

**文件：** `scripts/difficulty_profile.gd`、`scripts/lane_event_director.gd`、相关测试。

### Task 4：交通与燃油协调

**验收：** 新 NPC、随机变道、高速超车和燃油不会占用施工通道；已有 NPC 不消失；事件冲突时延迟或取消。

**验证：** `tests/test_dynamic_fairness.gd`、`tests/test_traffic_director.gd` 和完整测试。

**文件：** `scripts/traffic_director.gd`、`scripts/main.gd`、相关测试。

### Checkpoint：完成

- 完整测试通过、差异检查无错误。
- 提交并推送到 `xiejiamincyq/car`。
- 打开游戏进行人工试玩，重点检查双封道反应时间和锥桶连续碰撞。

## 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 双封道与交通叠加导致无解 | 高 | 事件前预检安全通道，冲突时回退单封道或延迟 |
| 锥桶连续碰撞惩罚过重 | 中 | 0.5 秒伤害冷却，减速比例设上限 |
| 即时绘制几何与碰撞不一致 | 高 | 由同一逻辑方法返回锥桶/核心标记供绘制和碰撞共用 |
| 事件过多影响普通交通 | 中 | 每局 2～4 次上限、事件互斥和最小间隔 |
