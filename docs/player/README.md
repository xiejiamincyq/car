# Neon Coast Rush — 0.4.0-rc.2

Windows x64本机验收候选版，不是已验收的最终发行版。四条赛道、六种车型、三种难度；支持中文和英文。

## 开始游戏

完整解压后双击`NeonCoastRush.exe`，保留同目录的`NeonCoastRush.pck`。无需安装Godot编辑器。先选择赛道，再选择车辆查看属性，按“确认选择并开始比赛”开局；锁定车型需要完成对应解锁条件。

| 按键 / Key | 操作 / Action |
| --- | --- |
| W / ↑、S / ↓ | 加速、制动 / Accelerate, brake |
| A / ←、D / → | 转向 / Steer |
| 双击前进键 / Double-tap forward | 超载；两次按下之间先松开全部前进键 |
| Space | 比赛暂停/继续；菜单确认 / Pause, resume, confirm |
| Enter、Tab / Shift+Tab | 菜单确认、切换焦点 / Confirm, move focus |
| R、Esc | 重开确认、返回/取消 / Restart, back/cancel |
| M、- / +、F11 | 静音、音量、全屏 / Mute, volume, fullscreen |

收集金币提高过程评分；油罐补充燃油，工具箱修复完整度。燃油耗尽或完整度低于20%会失败；困难模式通常需要沿路补油。完整度降低会影响车速和转向。超载最多额外100 km/h，持续4.5秒，逐步消耗15%油箱容量；不要把按住前进键的键盘重复当成双击。

声音设置可分别调整音乐与音效；设置中也可切换语言、高对比、减少闪烁及屏幕震动。没声音时先检查游戏静音、三路音量与Windows当前输出设备。

## 存档与反馈

正常游戏保存生涯和设置；游戏报告保存失败时不要假定已保存。用户目录为Windows默认Godot位置`%APPDATA%\Godot\app_userdata\Neon Coast Rush`，与解压目录无关。备份该目录后再迁移或回退，不删除唯一有效的`save.cfg`或`save.cfg.bak`；旧版本可能不支持新进度。

此候选未签名，Windows可能提示安全警告。实际包的性能、稳定性、中文字体、音频与真人体验以随包验收记录为准；发现异常请记录赛道、车型、难度、操作步骤和截图，不需要提供私人存档。来源与未确认授权见`ASSET_NOTICES.md`，引擎声明见两份`GODOT_*.txt`。不要将候选验收状态当作公开发布授权。
