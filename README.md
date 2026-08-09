# Neon Coast Rush

面向 PC 键盘试玩的原创 2D 纵向卷轴街机赛车。穿过夜间海岸车流，收集燃油并尽可能获得更高分数。

本项目仅参考了经典街机赛车的抽象玩法原则；名称、美术、音效、道路主题、交通行为和数值均为原创，不包含《Road Fighter》的原始素材或关卡内容。

## 试玩操作

| 按键 | 操作 |
| --- | --- |
| `Space` | 比赛中暂停 / 继续；菜单聚焦按钮时确认 |
| `Enter` | 菜单确认 |
| `W` / `↑` | 加速 |
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
godot --path . --editor
```

## 运行测试

每个 `tests/test_*.gd` 是独立的无头测试。以下 PowerShell 命令运行全部测试：

```powershell
$godot = "C:\Path\To\Godot_v4.7-stable_win64_console.exe"
Get-ChildItem tests -Filter "test_*.gd" | ForEach-Object {
  & $godot --headless --path . --script $_.FullName
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

`tests/test_release_regression.gd` 额外覆盖 20 个真实燃油结算与第二局重开流程、四个难度阶段及其实际车种，以及 20 个种子 × 3 个玩家车道 × 3 个速度组合下 300 秒的出生公平性、回收和对象池压力模拟。

## Windows 导出

1. 在 Godot 的 **Editor > Manage Export Templates** 安装与编辑器同版本的 Windows 导出模板。
2. 打开 **Project > Export**，选择仓库内的 `Windows Desktop` 预设。
3. 导出至默认路径 `exports/NeonCoastRush.exe`，或改为任意未纳入版本控制的目录。
4. 在新目录中运行 `NeonCoastRush.exe`，至少完成「启动 → 开始 → Space 暂停/继续 → 结算 → R 重开 → 返回标题并退出」冒烟流程。

`exports/` 已被 Git 忽略，构建产物不会提交。

## 当前开发状态

当前版本：`0.2.0`。这是面向当前开发机签署的 Windows 本地正式版，包含完整界面、存档、四赛段终点、中后期交通和程序化音频；不再以多人试玩或其他电脑兼容性作为阻断条件。后续进入原创美术集成，进度见 [完成度加固计划](tasks/plan-foundation.md)。发布与回滚步骤见 [发布检查清单](docs/release-checklist.md)，视觉资产接入约束见 [美术需求清单](docs/art-requirements.md)，玩家可见改动见 [CHANGELOG](CHANGELOG.md)。
