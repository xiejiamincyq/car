# Neon Coast Rush

面向 PC 键盘试玩的原创 2D 纵向卷轴街机赛车。穿过夜间海岸车流，收集燃油并尽可能获得更高分数。

本项目仅参考了经典街机赛车的抽象玩法原则；名称、美术、音效、道路主题、交通行为和数值均为原创，不包含《Road Fighter》的原始素材或关卡内容。

## 试玩操作

| 按键 | 操作 |
| --- | --- |
| `Space` | 比赛中暂停 / 继续；菜单聚焦按钮时确认 |
| `Enter` | 菜单确认 |
| `W` / `↑` | 加速 |
| 双击任意前进键 | 超载；每次按下前先松开全部前进键 |
| `S` / `↓` | 制动 |
| `A` / `←`、`D` / `→` | 转向 |
| `R` | 重新开始；比赛中需要二次确认，结算页直接重开 |
| `M` | 静音 / 恢复声音 |
| `-` / `+` | 调低 / 调高音量 |
| `F11` | 窗口 / 全屏切换 |
| `Esc` | 返回或取消菜单；退出游戏请使用标题页“退出”按钮 |

## 运行开发版

要求：Godot **4.7**（建议使用兼容渲染器）。

1. 在 Godot 中导入此目录并运行 `scenes/main.tscn`，或直接运行项目。
2. 也可在命令行执行：

```powershell
godot --path .
```

本机固定组合的隔离试玩入口：`./scripts/tests/start_balance_playtest.ps1 -Session 1`（可选1–10）。它自动定位已安装Godot，不写生涯/设置，结果只保存在本机；并不代表已经完成真人试玩。需要编辑项目时再使用 `godot --path . --editor`。

## 运行测试

每个 `tests/test_*.gd` 是独立的无头测试。以下 PowerShell 命令运行全部测试（自动定位本机Godot，也可显式传入）：

```powershell
./scripts/tests/run_tests.ps1
# 单项：./scripts/tests/run_tests.ps1 -TestFilter test_playtest_isolation.gd
# 指定引擎：./scripts/tests/run_tests.ps1 -GodotExecutable 'C:\Path\To\Godot_v4.7-stable_win64_console.exe'
```

运行器默认使用每项120秒墙钟看门狗；完整发布压力矩阵因包含约324万交通子步，默认单独使用600秒。超时均计失败，不使用会提前返回成功的“60帧后自动退出”。关键异步/存档及成品专项必须到达末尾完成标记。显式`-TestTimeoutSeconds`可覆盖上限；不会终止其他游戏进程。

`tests/test_release_regression.gd` 额外覆盖 20 个真实燃油结算与第二局重开流程、四个难度阶段及其实际车种，以及 20 个种子 × 3 个玩家车道 × 3 个速度组合下 300 秒的出生公平性、回收和对象池压力模拟。

## Windows 导出

1. 在 Godot 的 **Editor > Manage Export Templates** 安装与编辑器同版本的 Windows 导出模板。
2. 打开 **Project > Export**，选择仓库内的 `Windows Desktop` 预设。
3. 导出至默认路径 `exports/0.4.0-dev/package/NeonCoastRush.exe`，或改为任意未纳入版本控制的目录。
4. 在新目录中运行 `NeonCoastRush.exe`，至少完成「启动 → 开始 → Space 暂停/继续 → 结算 → R 重开 → 返回标题并退出」冒烟流程。

`exports/` 已被 Git 忽略，构建产物不会提交。

## 当前开发状态

当前开发版本：`0.4.0-dev`。正在执行用户批准的[本机成品计划](tasks/plan-product-ready.md)，包括输入/特效、交通行为、难度补给、存档和本地候选包；最新[验证记录](docs/product-validation-20261003.md)如实区分专项、全回归与未覆盖内容。2026-10-03用户已取消网页端使用，由Codex依据本地证据自主判断，见[执行协议](tasks/pro-supervision.md)。

四节点巡回、六车、四关及原创BGM曾完成旧M1–M4技术验证：9e7cd09的95项与18张实际渲染仅是历史基线，见[旧验证记录](docs/continuous-validation-20261002.md)，不代表新增需求或当前版本通过。[十局真人试玩](docs/balance/manual-sessions.md)和剩余体验仍待实际确认。本地候选包已获授权，但当前尚未实际导出；公开发行须另行授权。

已验收正式版本保存在 Git 标签 `v0.3.0`，稳定回滚基线仍保留 `v0.2.0`。0.4.0 范围见 [技术规格](docs/spec-0.4.0.md) 和 [实施计划](tasks/plan.md)，0.3.0 发布与回滚记录见 [发布检查清单](docs/release-checklist.md)，玩家可见改动见 [CHANGELOG](CHANGELOG.md)。
