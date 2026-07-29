# Neon Coast Rush

面向 PC 键盘试玩的原创 2D 纵向卷轴街机赛车。穿过夜间海岸车流，收集燃油并尽可能获得更高分数。

本项目仅参考了经典街机赛车的抽象玩法原则；名称、美术、音效、道路主题、交通行为和数值均为原创，不包含《Road Fighter》的原始素材或关卡内容。

## 试玩操作

| 按键 | 操作 |
| --- | --- |
| `Space` | 开始 |
| `W` / `↑` | 加速 |
| `S` / `↓` | 制动 |
| `A` / `←`、`D` / `→` | 转向 |
| `P` | 暂停 / 继续 |
| `R` | 重新开始 |
| `M` | 静音 / 恢复声音 |
| `-` / `+` | 调低 / 调高音量 |
| `Esc` | 退出 |

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

`tests/test_release_regression.gd` 额外覆盖 20 个随机种子、每局重开清理，以及 300 秒的交通对象池和出生公平性压力模拟。

## Windows 导出

1. 在 Godot 的 **Editor > Manage Export Templates** 安装与编辑器同版本的 Windows 导出模板。
2. 打开 **Project > Export**，选择仓库内的 `Windows Desktop` 预设。
3. 导出至默认路径 `exports/NeonCoastRush.exe`，或改为任意未纳入版本控制的目录。
4. 在新目录中运行 `NeonCoastRush.exe`，至少完成「启动 → 开始 → 暂停 → 燃油结束 → R 重开」冒烟流程。

`exports/` 已被 Git 忽略，构建产物不会提交。

## 发布候选状态

当前版本：`0.1.0-rc.1`。发布与回滚步骤见 [发布检查清单](docs/release-checklist.md)，玩家可见改动见 [CHANGELOG](CHANGELOG.md)。
