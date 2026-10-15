# Neon Coast Rush

一款面向PC键盘操作的2D纵向卷轴赛车。穿梭车流、规划超车路线、收集金币，在速度、燃油和车辆完整度之间作出选择。

[下载Windows版](https://github.com/xiejiamincyq/car/releases/tag/v0.4.0) · [玩家指南](docs/player/README.md) · [常见问题与反馈](docs/player/SUPPORT.md) · [更新记录](CHANGELOG.md)

## 下载与开始

当前版本是 **0.4.0 正式版 · Windows x64 · 未签名便携版**。游戏内、Windows产品版本和下载包已统一为0.4.0；正式发布不等于对所有设备兼容性作保证。

1. 下载 [NeonCoastRush-0.4.0-Windows-x64.zip](https://github.com/xiejiamincyq/car/releases/download/v0.4.0/NeonCoastRush-0.4.0-Windows-x64.zip)（约70MB）。GitHub的Source code是源码，不是可运行包。
2. 完整解压，运行版本文件夹里的NeonCoastRush.exe；EXE与PCK保持同目录。
3. 选择赛道和赛车，查看性能后确认开赛。玩家无需Godot编辑器、Python或Node.js。

[SHA-256校验文件](https://github.com/xiejiamincyq/car/releases/download/v0.4.0/SHA256SUMS.txt)用于核对下载内容。EXE未签名，Windows可能提示未知发布者或阻止运行；不要为了游戏关闭系统安全功能。仅在当前Windows x64电脑验证，不保证所有设备或驱动兼容。

## 游戏内容

- 四条主题赛道、六款赛车、三种难度，支持中英文和独立背景音乐。
- NPC拥有独立世界速度，可减速绕后再超车；变道预警、施工导流及450km/h红色快车带来不同路况。
- 双击前进键超载；弧线/S形金币路线、燃油和维修补给鼓励路线选择。
- 车辆完整度影响车速与转向；完赛或失败均有评分，生涯记录逐局得分。
- 四个独立存档位，支持加载、复制、可恢复删除，结算自动保存与手动保存并存。

## 基本操作

| 按键 | 操作 |
| --- | --- |
| W / ↑、S / ↓ | 加速、制动 |
| A / ←、D / → | 转向 |
| 双击任意前进键 | 超载；每次按下前先松开全部前进键 |
| Space | 比赛暂停/继续，菜单确认 |
| Enter、Tab / Shift+Tab | 确认、切换焦点 |
| R、Esc、F11 | 重开确认、返回/取消、窗口/全屏 |

声音、存档与完整操作见[玩家指南](docs/player/README.md)。存档在`%APPDATA%\Godot\app_userdata\Neon Coast Rush`，当前为v7；升级或回退前先退出游戏并备份整个目录，不要让旧程序覆盖新档。

## 已知限制与支持

RC5本机试玩已获用户接受，0.4.0仅升级版本与发布资料，不改玩法、美术或v7存档格式。已有177项冻结技术回归；正式版另核验版本、资源、导出及短启动，详见发布状态。四关1080p逐帧性能、30分钟有效驾驶、20次重开/返回趋势及剩余正常新旧档完整胜负补证由用户授权跳过，不是PASS。不承诺固定帧率或长期零内存增长。

[常见问题与已知限制](docs/player/SUPPORT.md)包含未签名提示、无声音、资源错误、卸载与回退方法。发现问题可在[Issues](https://github.com/xiejiamincyq/car/issues)提供版本、复现步骤及必要截图，不需要上传私人存档或完整系统转储。

## 开发、发布与来源

- [开发运行、测试和新包制作](docs/development.md)：Godot 4.7，GDScript，gl_compatibility。
- [当前发布检查清单](docs/release-checklist-current.md) · [0.4.0文件清单](docs/releases/v0.4.0/package-manifest.json) · [验证范围](docs/releases/v0.4.0/RELEASE_STATUS.md)。
- 旧标签v0.2.0、v0.3.0及[0.3.0发布记录](docs/release-checklist.md)保留用于历史追溯，不保证兼容当前v7存档。
- 游戏仅参考经典街机赛车的抽象玩法，不包含Road Fighter的原始素材或关卡内容。[素材与引擎声明](docs/player/ASSET_NOTICES.md)保留制作来源和第三方组件说明。
- 仓库公开不等于已为整个游戏指定开源许可证。暂不签名、不申请SignPath，也不因使用Godot而替游戏自动选择MIT许可。
