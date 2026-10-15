# Neon Coast Rush — Windows x64 便携版

程序版本：0.4.0-rc.5；文件版本：0.4.0.5。本包由项目所有者批准通过GitHub Release公开提供，仍保留RC预发布标识，不冒称1.0稳定版。验证范围与已知限制见RELEASE_STATUS.md。

## 启动

完整解压ZIP，进入`NeonCoastRush-0.4.0-rc.5-Windows-x64`文件夹，双击`NeonCoastRush.exe`。EXE与`NeonCoastRush.pck`必须保持同目录，不要直接在压缩包预览中运行。

无需Godot编辑器、Python或Node.js。程序使用Godot 4.7兼容渲染器；本轮只在当前Windows x64电脑验证，不承诺其他Windows版本、显卡或驱动的兼容性，也不把本机结果写成通用最低配置。

W/↑加速，S/↓制动，A/D或左右箭头转向；双击前进键超载；Space暂停/继续；F11切换全屏；退出使用标题页按钮。选择车辆只预览，按确认按钮才开局。详细操作、难度和评分见PLAYER_GUIDE.md。

## 存档与安全

四个存档位保存到`%APPDATA%\Godot\app_userdata\Neon Coast Rush`，不在解压文件夹中。比赛结算自动保存，也可手动保存。删除游戏文件夹不会自动删除存档。复制/删除存档前留意确认框。

当前格式v7。升级或回退前，先退出游戏并备份整个上述目录。不要让旧程序覆盖v7档；切换程序时成套保留EXE/PCK，不能保证旧版可读取新进度。

EXE未签名，Windows可能显示安全提示；不要因此关闭系统安全功能。仅从你确认可信的来源运行。音乐不响时检查游戏静音/三路音量及Windows输出设备。

## 文件与反馈

包内包含程序、PCK、玩家指南、更新说明、状态说明、素材来源及两份Godot声明，不含源图、测试、开发工具或私人存档。发现异常请记录版本、赛道、车型、难度、操作步骤和截图；无需上传私人存档。

发布页面：https://github.com/xiejiamincyq/car/releases/tag/v0.4.0-rc.5 。使用附件SHA256SUMS.txt核对下载文件。项目所有者确认游戏素材均由助手生成或制作；来源见ASSET_NOTICES.md。Godot许可不代表整个游戏采用同一许可，本说明不另行指定游戏代码或素材许可证。
