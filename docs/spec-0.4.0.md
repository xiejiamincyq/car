# Spec：Neon Coast Rush 0.4.0 海岸巡回赛

## Objective

为当前 Windows x64、PC 键盘单机玩家增加一套完整但轻量的巡回赛成长结构。玩家应能从大地图选择赛道、选择具有明确取舍的车辆、伴随每关独立 BGM 完成短局比赛，并通过通关、奖牌和最佳成绩解锁后续内容。

成功体验是：首次玩家无需查看 README，即可在 30 秒内完成“标题 → 地图 → 选车 → 比赛”；标准难度经过调校后，具备 0.3.0 基础经验的玩家约一半比赛能够通关，同时失败仍能被归因于可理解的驾驶决策。

## Product Contract

### 巡回地图

四个节点线性解锁，已解锁节点可以自由回玩：

1. **霓虹海岸**：0.3.0 赛道的兼容版本，教学基线。
2. **货运港**：货车与窄逃生窗口更突出，但预警更长。
3. **暴雨山道**：道路视觉与操控压力更高，不使用不可见摩擦或随机打滑。
4. **日出高速**：高速交通和综合机制决赛，不引入新规则偷袭玩家。

每关仍是 3–5 分钟的四赛段有限赛程。地图必须以位置、连线、锁图标和文字同时表达状态，不能只依赖颜色。

### 六辆玩家车

车辆共享相同的总体性能预算，只允许在最大速度、加速度、制动、转向和碰撞恢复之间做取舍：

| 类型 | 定位 | 初始状态 |
|---|---|---|
| 均衡型 | 无明显短板，默认推荐 | 开放 |
| 灵活型 | 转向/制动强，极速较低 | 开放 |
| 冲刺型 | 加速强，碰撞恢复较弱 | 开放 |
| 高速型 | 极速高，转向较慢 | 首次通关解锁 |
| 稳定型 | 碰撞损失低，加速较慢 | 获得 4 枚奖牌解锁 |
| 专家型 | 高速与加速强，制动/转向容错低 | 四关通关解锁 |

车辆不修改道路宽度、交通公平性判定和拾取可达性。碰撞框最多只随可见车身尺寸做受限调整，必须纳入所有公平性测试。

### 奖牌与进度

- 每条赛道分别保存最佳分、最佳时间、最高奖牌和是否通关。
- 铜牌以通关为基础；银牌和金牌使用每赛道配置化分数阈值。
- 车辆解锁仅依赖通关和奖牌总数，不使用货币或消耗品。
- 存档升级为 v5；v1–v4 必须无损迁移设置、历史成绩和生涯统计。旧 `audio_volume` 同时映射为新的 `music_volume` 与 `effects_volume`，避免开发中重复升级存档版本。

### BGM

- 四首原创复古街机电子循环曲，每首 60–90 秒，循环接缝不可感知。
- 音乐进入现有 `Music` 总线；音效继续进入 `Effects` 总线。
- 倒计时开始时淡入，暂停/失焦时同步暂停，结算时淡出或切换短结束尾奏。
- 封路、低油量、倒计时和碰撞提示在音乐开启时仍清楚；全局静音、音乐音量和音效音量分别持久化。
- 不使用授权不明素材，不模仿任何现有游戏的可识别旋律。

### 操控与平衡

- 键位保持不变。
- 引入速度相关但连续的转向响应，低速更易精确，高速避免瞬时横跳；不加入随机打滑。
- 六辆车使用同一控制模型和不同配置，不为单车编写特例。
- 标准难度目标：人工样本至少 10 局时通关率落在 40%–60%；轻松档高于标准档，困难档低于标准档。

## Tech Stack

- Godot 4.7，GDScript，`gl_compatibility` 渲染器。
- PNG 原创像素资源，Godot 导入纹理。
- 原创程序化编曲生成的 WAV/压缩导入资源；若本机工具链验证支持，可在不增加运行时依赖的前提下转为 OGG。
- `ConfigFile` 本机存档，无联网、账号或遥测。

## Commands

```powershell
# 全部测试
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1

# 单项测试
& 'C:\Users\21604\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/test_name.gd

# Windows 导出（版本冻结后使用相应路径）
& 'C:\Users\21604\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' 'exports/0.4.0/package/NeonCoastRush.exe'
```

## Project Structure

```text
scripts/catalog/       赛道、车辆与解锁目录模型
scripts/ui/            地图和选车界面控制器
scripts/audio/         BGM 播放、淡入淡出和曲目目录
assets/tracks/         每关运行时环境资源
assets/vehicles/       六辆玩家车运行时精灵
assets/music/          四首原创循环音乐
art/source/            生成源图和音乐工程源，不进入导出包
tests/                 纯逻辑、集成、布局与发布回归
docs/                  规格、构建与原创来源记录
```

`scripts/main.gd` 只负责编排现有比赛和新模块，不承载地图目录、解锁规则、车辆属性表或音乐状态机。0.4.0 不得让该文件明显超过当前 1116 行；新功能优先通过独立对象和窄接口接入。

## Code Style

```gdscript
class_name VehicleProfile
extends RefCounted

var id: StringName
var max_speed: float
var steering_speed: float

func _init(profile_id: StringName, speed: float, steering: float) -> void:
	id = profile_id
	max_speed = speed
	steering_speed = steering
```

- 类使用 PascalCase，方法和变量使用 snake_case，常量使用 UPPER_SNAKE_CASE。
- 配置返回深复制，运行时不得修改全局目录常量。
- UI 文案进入 `GameText`，不可在控制器中散落中英文字符串。
- 不为单一车辆、赛道或语言增加硬编码分支。

## Testing Strategy

- 每项行为变更先写失败测试，再实现最小修复。
- 目录模型：ID 唯一、字段范围、性能预算、解锁依赖无环。
- 存档：v1–v4 → v5 迁移、损坏/缺失字段回退、进度往返。
- UI：720p/1080p 键盘焦点、锁定节点不可进入、返回路径正确。
- 车辆：6 × 4 赛道 × 3 难度的参数与公平性矩阵；没有车辆突破道路边界或生成安全约束。
- 音乐：循环长度、总线、暂停/恢复、曲目切换和资源释放。
- 平衡：固定种子自动驾驶筛查 + 至少 10 局人工标准难度记录。
- 每个大阶段运行全部 `tests/test_*.gd`，发布阶段执行 Windows 干净用户目录冒烟。

## Boundaries

### Always

- 保留固定种子确定性和生成公平性。
- 每个切片测试、审查、提交并推送备份。
- 记录所有图像和音乐的原创生成方法与源文件。
- 保持键盘完整可访问和非颜色语义。

### Ask First

- 改变四关、六车或线性解锁的冻结范围。
- 新增第三方运行时依赖、授权音乐或外部服务。
- 删除/重置玩家已有存档或改变旧成绩含义。

### Never

- 提交密钥、玩家真实存档或测试生成的用户数据。
- 复制《Road Fighter》或其他作品的素材、旋律、地图布局和名称。
- 用降低生成公平性来制造难度。
- 修改或提交用户现有的 ADR 与 `CLAUDE.md` 工作区改动。

## Success Criteria

- 四个地图节点可用纯键盘选择、线性解锁并自由回玩。
- 六辆车在界面上清楚显示五项属性，实际驾驶表现与描述一致且无绝对最优车。
- 四条赛道具有可辨识的视觉、交通参数和独立原创 BGM。
- 存档 v5 能迁移旧数据并保存选车、赛道成绩、奖牌和解锁状态。
- 标准难度 10 局人工样本通关率在 40%–60%，无不可避免碰撞报告。
- 全部自动测试、Windows 导出审计和当前电脑人工试玩通过。

## Open Questions

无阻断性产品问题。车辆和赛道最终名称、数值、奖牌阈值及曲目编排属于分阶段试玩调校项，不改变本规格范围。
