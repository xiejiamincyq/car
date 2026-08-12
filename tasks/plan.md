# Neon Coast Rush 0.4.0 海岸巡回赛实施计划

> 已确认方向：四节点大地图、六辆横向平衡车型、每关独立原创 BGM、容易上手且标准难度目标约 50% 通关率。详细契约见 [`docs/spec-0.4.0.md`](../docs/spec-0.4.0.md)。0.1.0 历史计划由 Git 保留；0.3.0 正式基线为标签 `v0.3.0`。

## 总体策略

采用“契约先行、纵向切片、风险优先”的顺序：先建立目录和存档契约，再交付可操作的地图闭环；随后接入六辆车和四条赛道；音乐在赛道 ID 稳定后接入；最终用操控与平衡阶段统一校准，避免前期数值反复推倒。

预计总用时 **14–20 个有效工作日（约 80–120 小时）**。这包含原创视觉、四首音乐、本机测试与三次人工试玩窗口，不包含第二台电脑兼容性和三人外部试玩。

## 模型与工具分工

| 工作 | 推荐模型/工具 | 用法 |
|---|---|---|
| 常规 GDScript、菜单、文档、资源接入 | GPT-5.6-Terra | 小切片实现与快速回归 |
| 目录契约、存档迁移、状态机、公平性与平衡 | GPT-5.6-Sol（高推理） | 风险逻辑设计、失败测试根因与复核 |
| 车辆、地图节点、港口/山道/高速环境 | 图像模型 | 只生成原创像素资源，运行时尺寸由脚本验证 |
| 四首 BGM | Sol 编曲设计 + 本地程序化音频渲染 | 生成原创旋律/节奏数据，人工循环听测；不依赖外部授权素材 |
| Windows 打包与文档 | Terra | 导出、哈希、回滚记录和本机启动 |

模型切换原则：Terra 默认执行；涉及迁移、难度、公平性或连续三次失败时转 Sol；视觉资产直接使用图像模型。模型不替代本机测试和人工手感判断。

## 依赖关系

```text
赛道/车辆目录契约
        ├── 存档 v5 与解锁策略
        │       └── 大地图 → 选车 → 开赛闭环
        ├── 六辆车配置与精灵
        ├── 四条赛道配置与环境
        └── 曲目目录与 MusicDirector
                         ↓
              操控/平衡矩阵与发布验证
```

## 可执行任务分解

### Task 1：赛道与车辆目录契约

**验收：** 四条赛道和六辆车 ID 唯一；必填字段、数值范围和性能预算可自动验证；调用者只能获得深复制。
**验证：** 运行新增目录测试，再运行 `scripts/tests/run_tests.ps1`。
**依赖：** T0 批准。
**文件：** `scripts/catalog/track_catalog.gd`、`scripts/catalog/vehicle_catalog.gd`、`tests/test_content_catalog.gd`。
**规模：** M（3 文件）。

### Task 2：巡回进度与解锁策略

**验收：** 线性赛道解锁、三辆初始车和三种后续解锁条件均由纯逻辑模型计算；锁定内容不能被选择。
**验证：** `tests/test_tour_progress.gd` 覆盖新档、逐关通关、奖牌累计和非法 ID。
**依赖：** Task 1。
**文件：** `scripts/catalog/tour_progress.gd`、`tests/test_tour_progress.gd`。
**规模：** S（2 文件）。

### Task 3：存档 v5 迁移

**验收：** v1–v4 保留全部旧数据并补入巡回默认值；旧总音量映射到新的音乐/音效音量；v5 往返不丢逐关成绩、奖牌和选择；损坏字段安全回退。
**验证：** 先让迁移测试失败，再实现并运行 `tests/test_save_store.gd` 与全套测试。
**依赖：** Task 2。
**文件：** `scripts/save_store.gd`、`scripts/progression.gd`、`tests/test_save_store.gd`、`tests/test_persistence_integration.gd`。
**规模：** M（4 文件）。

### Task 4：0.4.0-dev 元数据

**验收：** 项目、Windows 产品版本、标题页和 README 统一为 `0.4.0-dev`，数字文件版本为 `0.4.0.0`。
**验证：** `tests/test_release_metadata.gd`。
**依赖：** Task 3。
**文件：** `project.godot`、`export_presets.cfg`、`scenes/main.tscn`、`README.md`、`tests/test_release_metadata.gd`。
**规模：** M（5 文件）。

### Task 5：地图选择模型与界面

**验收：** 720p/1080p 下四节点、连线、锁状态和当前选择清楚；方向键移动、Enter 确认、Esc 返回稳定。
**验证：** 地图模型测试、布局测试和离屏截图复核。
**依赖：** Task 2。
**文件：** `scripts/ui/tour_map_controller.gd`、`scenes/tour_map.tscn`、`tests/test_tour_map.gd`、`tests/test_hud_layout.gd`。
**规模：** M（4 文件）。

### Task 6：选车模型与界面

**验收：** 六车定位、五项属性和解锁条件可读；锁定车辆不可开赛；返回地图保持原赛道选择。
**验证：** 选车状态测试、720p/1080p 键盘焦点测试。
**依赖：** Task 1、Task 2。
**文件：** `scripts/ui/vehicle_select_controller.gd`、`scenes/vehicle_select.tscn`、`tests/test_vehicle_select.gd`、`scripts/game_text.gd`。
**规模：** M（4 文件）。

### Task 7：完整选择流程接线

**验收：** 标题 → 地图 → 选车 → 倒计时 → 比赛 → 结算 → 地图全程无需鼠标，暂停/重开/返回仍合法。
**验证：** 扩展 UI 状态测试和主场景集成测试。
**依赖：** Task 3、Task 5、Task 6。
**文件：** `scripts/main.gd`、`scenes/main.tscn`、`tests/test_ui_flow.gd`、`tests/test_menu_flow.gd`、`tests/test_main_run_loop.gd`。
**规模：** M（5 文件）。

### Task 8：车辆配置接入控制与碰撞

**验收：** 控制器和碰撞惩罚读取统一 `VehicleProfile`；六车无特例；重开保留本局所选车但新选车可立即生效。
**验证：** 驾驶、碰撞、重置和六车参数矩阵测试。
**依赖：** Task 1、Task 7。
**文件：** `scripts/drive_controller.gd`、`scripts/collision_responder.gd`、`scripts/main.gd`、`tests/test_drive_controller.gd`、`tests/test_collision_responder.gd`。
**规模：** M（5 文件）。

### Task 9：六辆原创车辆视觉

**验收：** 六张透明 PNG 使用冻结画布、锚点和近俯视投影；高速下轮廓可辨；源图不进入导出包。
**验证：** 资产尺寸/透明度测试、离屏并排预览和实际速度试玩。
**依赖：** Task 6。
**文件：** `assets/vehicles/player_*.png`、`art/source/vehicles/*`、`art/sprite_manifest.json`、`tests/test_gameplay_art_assets.gd`。
**规模：** M（按资源组计 4 个责任范围）。

### Task 10：四赛道配置接入

**验收：** 每关赛程、交通重点、封路节奏和奖牌阈值来自目录；固定种子可复现；难度不能移除逃生路线。
**验证：** 四关 × 三难度配置测试与动态公平性测试。
**依赖：** Task 1、Task 7。
**文件：** `scripts/run_state.gd`、`scripts/traffic_director.gd`、`scripts/lane_event_director.gd`、`tests/test_track_profiles.gd`、`tests/test_dynamic_fairness.gd`。
**规模：** M（5 文件）。

### Task 11：三套新增赛道视觉

**验收：** 港口、山道和高速与海岸一眼可辨；滚动无接缝；道路碰撞几何不随贴图变化；高对比模式保持核心信息。
**验证：** 环境资源测试、循环边界测试和四关离屏截图。
**依赖：** Task 10。
**文件：** `assets/tracks/*`、`art/source/tracks/*`、`scripts/environment_scroller.gd`、`scripts/main.gd`、`tests/test_environment_art.gd`。
**规模：** M（5 个责任范围）。

### Task 12：逐赛道成绩与奖牌

**验收：** 结算只更新当前赛道的最佳分/时间/奖牌；较差结果不能覆盖较好结果；地图即时反映进度。
**验证：** 结算模型、持久化集成和地图刷新测试。
**依赖：** Task 3、Task 7、Task 10。
**文件：** `scripts/progression.gd`、`scripts/main.gd`、`tests/test_progression.gd`、`tests/test_persistence_integration.gd`。
**规模：** M（4 文件）。

### Task 13：BGM 技术样曲

**验收：** 霓虹海岸样曲原创、60–90 秒、循环接缝不可感知；连续播放 5 分钟不出现爆音或明显累积漂移。
**验证：** 音频元数据测试、波形边界检查、人工循环听测。
**依赖：** Task 1。
**文件：** `art/source/music/*`、`assets/music/neon_coast.*`、`scripts/audio/music_catalog.gd`、`tests/test_music_assets.gd`。
**规模：** M（4 个责任范围）。

### Task 14：MusicDirector 与四曲接入

**验收：** 赛道选择正确切歌；倒计时淡入、暂停/失焦暂停、结算淡出；曲目释放无泄漏；其余三曲通过样曲标准。
**验证：** 音乐状态机测试、场景音频测试和每曲 5 分钟听测。
**依赖：** Task 10、Task 13。
**文件：** `scripts/audio/music_director.gd`、`scripts/audio/music_catalog.gd`、`assets/music/*`、`scripts/main.gd`、`tests/test_music_director.gd`。
**规模：** M（5 个责任范围）。

### Task 15：音乐/音效独立设置

**验收：** Music 与 Effects 独立调节，全局静音继续可用；使用 Task 3 已迁移的两个音量字段；中英文设置文案同步。
**验证：** 音频总线、存档迁移和设置 UI 测试。
**依赖：** Task 3、Task 14。
**文件：** `scripts/save_store.gd`、`scripts/main.gd`、`scripts/game_text.gd`、`tests/test_audio_bus_layout.gd`、`tests/test_main_audio_controls.gd`。
**规模：** M（5 文件）。

### Task 16：速度相关转向曲线

**验收：** 低速精确、高速不瞬移；曲线连续且六车共享；现有道路边界和暂停行为不变。
**验证：** 先写速度端点/中点/连续性测试，再运行驾驶和窗口行为回归。
**依赖：** Task 8。
**文件：** `scripts/drive_controller.gd`、`scripts/catalog/vehicle_catalog.gd`、`tests/test_drive_controller.gd`。
**规模：** M（3 文件）。

### Task 17：跨内容平衡矩阵

**验收：** 四关 × 六车 × 三难度无无解生成、对象上限稳定、没有单车在所有指标占优；人工标准档 10 局通关率 40%–60%。
**验证：** 固定种子矩阵脚本、全套测试和人工记录表。
**依赖：** Task 10、Task 12、Task 15、Task 16。
**文件：** `tests/test_04_balance_matrix.gd`、`scripts/catalog/track_catalog.gd`、`scripts/catalog/vehicle_catalog.gd`、`docs/playtests/0.4.0-balance.md`。
**规模：** M（4 文件）。

### Task 18：0.4.0 发布候选

**验收：** 全部测试、导出审计、干净存档首启和人工完整巡回通过；EXE/ZIP 哈希和 `v0.3.0` 回滚路径有记录。
**验证：** 全套测试、Windows 导出、隔离 APPDATA 冒烟和人工试玩。
**依赖：** Task 17。
**文件：** `README.md`、`CHANGELOG.md`、`docs/release-checklist.md`、`docs/release-notes-0.4.0.md`、`docs/builds/0.4.0.md`。
**规模：** M（5 文件，不含忽略的导出产物）。

## T0：规格与接口冻结（0.5 天，Terra + Sol）

- 完成产品一页纸、技术规格、计划和任务列表。
- 冻结四关、六车、线性解锁、奖牌和 BGM 契约。
- 明确 `main.gd` 不继续吸收目录与状态机逻辑。

**检查点 D：** 人工批准规格后才修改版本和代码。

## T1：目录、版本与存档 v5（1.5–2 天，Sol 主导）

- 新增 `TrackDefinition`、`VehicleProfile` 与只读目录，验证 ID、数值范围和性能预算。
- 新增巡回进度模型：当前选择、逐关成绩、奖牌与车辆解锁。
- 先写 v1–v4 → v5 迁移失败测试，再升级存档；旧设置、成绩和生涯统计不得丢失。
- 项目进入 `0.4.0-dev`，发布元数据测试同步更新。

**自动验收：** 目录契约、迁移往返、损坏回退和解锁无环测试通过。

## T2：地图—选车—比赛纵向闭环（2–3 天，Terra + Godot UI）

- 新增 720p/1080p 自适应巡回地图和选车界面。
- 纯键盘完成标题 → 地图 → 选车 → 倒计时 → 比赛 → 结算 → 地图。
- 锁定节点不可进入，返回/确认焦点稳定；地图同时使用连线、锁图标和文字。
- 先只使用霓虹海岸与占位车辆配置，证明完整闭环后再扩内容。

**检查点 E（人工试玩）：** 10 秒内理解地图状态，30 秒内开始比赛；确认流程后继续。

## T3：六辆玩家车（2.5–3.5 天，图像模型 + Sol）

- 生成六张原创近俯视车辆精灵，冻结透明画布、锚点和可见尺寸。
- 同一控制模型读取五项车辆配置，不写单车特例。
- 选车界面展示定位与属性条；锁定车辆说明解锁条件。
- 运行 6 车 × 3 难度基础矩阵，验证边界、碰撞、燃油和交通公平性。

**自动验收：** 性能预算、属性描述一致性、碰撞边界和资源清单测试通过。

## T4：四条赛道与地图视觉（3–4 天，图像模型 + Terra）

- 保留霓虹海岸，新增货运港、暴雨山道和日出高速环境资源。
- 每关用 `TrackDefinition` 配置环境、赛程、交通权重、封路节奏和奖牌阈值。
- 雨景只改变可见表现和配置化操控压力，不加入随机打滑或不可见规则。
- 奖牌、最佳分和最佳时间进入结算与地图节点。

**检查点 F（人工试玩）：** 四关一眼可辨、规则提示充分、六辆车在不同赛道均有合理用途。

## T5：四首原创 BGM 与音乐状态机（2.5–4 天，Sol + 本地音频渲染）

- 为四关分别设计 60–90 秒原创复古电子循环曲。
- 新增 `MusicDirector` 处理曲目选择、淡入淡出、暂停、失焦、结算和释放。
- 扩展设置为音乐/音效独立音量，并迁移旧总音量语义。
- 每首做连续 5 分钟循环听测，确保警报和关键音效可辨。

**自动验收：** 资源存在、循环元数据、总线路由、暂停恢复与切换测试通过。

## T6：操控与平衡冻结（2–3 天，Sol 高推理）

- 为统一控制器加入连续的速度相关转向曲线，保持键位不变。
- 固定种子模拟四关、六车和三档难度，先排除无解与明显最优车型。
- 进行至少 10 局标准难度人工试玩，每轮只调整 1–3 个参数。
- 标准通关率目标 40%–60%；轻松与困难必须形成有序差异。

**检查点 G（人工试玩）：** 操控容易上手、车型差异可信、失败公平，批准后冻结数值。

## T7：0.4.0 本机发布（1–1.5 天，Sol 回归 + Terra 打包）

- 全套自动测试、资源审计、存档迁移和干净用户目录冒烟。
- 导出 `0.4.0` EXE/ZIP，记录 Godot 版本、提交、大小和 SHA-256。
- 更新 README、CHANGELOG、发布说明与 `v0.3.0` 回滚步骤。
- 人工最终试玩通过后才创建并推送 `v0.4.0` 标签。

**检查点 H：** 打开正式候选版、发送邮件提醒并等待最终批准。

## 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| `main.gd` 继续膨胀 | 高 | 目录、UI 状态和音乐分别放入新模块；每阶段审查行数和职责 |
| 六辆车出现唯一最优解 | 高 | 冻结性能预算，做跨赛道矩阵，不用解锁顺序暗示强弱 |
| 四关只是换皮 | 高 | 每关配置明确的交通重点和节奏，但不牺牲公平性 |
| 四首 BGM 质量/体积失控 | 中高 | 先做一首完整技术样曲；短循环、压缩导入、逐曲听测后扩展 |
| v5 迁移损坏旧存档 | 高 | 迁移测试先行、备份替换、任何异常回退到保留旧数据的安全路径 |
| 50% 通关率样本不足 | 中 | 自动筛查负责安全边界，人工样本只用于手感；明确样本量和置信限制 |

## 完成定义

- T0–T7 全部验收项完成。
- 四关、六车、四首 BGM、奖牌与解锁均可在当前 Windows 电脑用键盘完整体验。
- v1–v4 存档安全迁移到 v5。
- 标准难度人工样本通关率在 40%–60%，没有无解生成报告。
- 0.4.0 构建可复现、可回滚、哈希已记录并经人工批准。
