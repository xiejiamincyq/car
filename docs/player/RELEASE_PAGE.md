# Neon Coast Rush · 0.4.0 正式版

面向PC键盘操作的2D纵向卷轴赛车：穿梭车流、规划路线、收集金币，并在燃油与车辆完整度之间权衡。0.4.0正式版已同步游戏内版本、Windows产品版本、仓库与包内说明，并重新导出Windows x64未签名便携包。

## 下载

- [Windows x64游戏包 · 约70MB](https://github.com/xiejiamincyq/car/releases/download/v0.4.0/NeonCoastRush-0.4.0-Windows-x64.zip)
- [SHA-256校验文件](https://github.com/xiejiamincyq/car/releases/download/v0.4.0/SHA256SUMS.txt)

请选择上面的游戏ZIP，不要下载Source code源码包来运行。完整解压后打开版本文件夹中的NeonCoastRush.exe，保持PCK同目录；无需Godot编辑器、Python或Node.js。

## 这个版本有什么

- 四条主题赛道、六款赛车与三种难度，独立背景音乐和中英文界面。
- 独立速度NPC、醒目变道预警、施工导流与固定450km/h红色快车。
- 双击前进键超载，弧线/S形金币路线、燃油及维修补给。
- 车辆完整度影响驾驶表现；完赛与未完赛都有评分，生涯记录逐局得分。
- 四个独立存档位，支持加载、复制、可恢复删除、结算自动保存与手动保存。

W/↑加速，S/↓制动，A/D或←/→转向；双击前进键超载，Space暂停/继续，F11切换全屏。

## 运行前须知

EXE未签名，Windows可能显示未知发布者或阻止运行。请核对下载来源与SHA256，不要关闭系统安全功能。当前仅在一台Windows x64电脑验证，其他设备兼容性、固定帧率及长期零内存增长未作保证。

存档位于`%APPDATA%\Godot\app_userdata\Neon Coast Rush`，当前格式v7。升级或回退前先退出并备份整个存档目录，不能保证旧版程序读取新档。退出后移除解压目录可卸载程序，存档不会自动删除。

本版不改变RC5玩法、美术或v7存档格式。已有RC5本机试玩接受及177项冻结回归；本轮对0.4.0执行版本与菜单/存档专项、新PCK资源检查、解压校验和隔离短启动，具体范围见发布状态。四关1080p逐帧性能、30分钟驾驶、20次重开/返回趋势及剩余正常新旧档胜负补证为SKIPPED_BY_USER，不是PASS。历史测试清理诊断继续披露，不承诺零告警。

## 帮助与反馈

- [玩家指南](https://github.com/xiejiamincyq/car/blob/codex/product-ready-20261002/docs/player/README.md)
- [常见问题、已知限制、备份和反馈](https://github.com/xiejiamincyq/car/blob/codex/product-ready-20261002/docs/player/SUPPORT.md)
- [报告问题](https://github.com/xiejiamincyq/car/issues)：请提供版本、赛道/车型/难度、复现步骤和必要截图，不要上传私人存档、密码或完整系统转储。
- [发布状态与验证范围](https://github.com/xiejiamincyq/car/blob/v0.4.0/docs/releases/v0.4.0/RELEASE_STATUS.md)

旧RC5标签和附件保留，不覆盖。0.4.0使用新标签及新包，构建输入和哈希见本标签下的package-manifest.json。Windows数字文件版本0.4.0.6是构建序号，不是另一个游戏版本。包内保留Godot组件声明；本次不签名、不改变游戏许可证。
