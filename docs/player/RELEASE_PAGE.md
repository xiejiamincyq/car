# Neon Coast Rush · 0.4.0-rc.5

面向PC键盘操作的2D纵向卷轴赛车：穿梭车流、规划路线、收集金币，并在燃油与车辆完整度之间权衡。当前公开版本为Windows x64未签名便携版，仍保留RC预发布标识。

## 下载

- [Windows x64游戏包 · 约69.5MB](https://github.com/xiejiamincyq/car/releases/download/v0.4.0-rc.5/NeonCoastRush-0.4.0-rc.5-Windows-x64.zip)
- [SHA-256校验文件](https://github.com/xiejiamincyq/car/releases/download/v0.4.0-rc.5/SHA256SUMS.txt)

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

已有本机试玩接受、177项冻结技术回归及对应包/资源记录；本轮只完善发布展示，程序和附件未变。四关1080p逐帧性能、30分钟驾驶、20次重开/返回趋势及剩余正常新旧档胜负补证为SKIPPED_BY_USER，不是PASS。历史测试清理诊断继续披露，详见状态说明。

## 帮助与反馈

- [玩家指南](https://github.com/xiejiamincyq/car/blob/codex/product-ready-20261002/docs/player/README.md)
- [常见问题、已知限制、备份和反馈](https://github.com/xiejiamincyq/car/blob/codex/product-ready-20261002/docs/player/SUPPORT.md)
- [报告问题](https://github.com/xiejiamincyq/car/issues)：请提供版本、赛道/车型/难度、复现步骤和必要截图，不要上传私人存档、密码或完整系统转储。
- [发布状态与验证范围](https://github.com/xiejiamincyq/car/blob/v0.4.0-rc.5/docs/releases/v0.4.0-rc.5/RELEASE_STATUS.md)

本次没有重导出、签名或改动游戏；原发布标签及两份下载附件保持不变，构建来源和哈希见标签中的package-manifest.json。包内保留Godot组件声明；仓库公开并不等于为整个游戏指定开源许可证。
