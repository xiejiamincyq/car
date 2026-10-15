# Windows便携包：文档来源纠正完成

日期：2026-10-15。仅本地发布准备；没有公开发布、外部上传、提交或推送。游戏仍为0.4.0-rc.5，没有修改玩法、美术、源工程或存档。

## 本次更正

项目所有者确认素材均由助手制作。菜单图已找到原生生成输出，和现用文件同SHA；20张环境源图、6张概念图、6张C版源图、6张展示图同样匹配，共39张重点源图/输出。六张展示图另有实际completed生图工具记录。撤回原B01/B02关于“缺第三方采购授权”的阻塞，不要求用户重新交付这些素材。

## 本次交付

- NeonCoastRush-0.4.0-rc.5-Windows-x64-docs-corrected.zip：新增文档修正版，校验见DOCS_CORRECTED_SHA256SUMS.txt和review/origin-correction-receipt.json。
- 仍是一个版本文件夹、精确9个文件。只修改README.md、CHANGELOG.md、ASSET_NOTICES.md、RELEASE_STATUS.md；EXE、PCK、玩家指南和两份Godot声明共5个文件保持原字节。
- 原NeonCoastRush-0.4.0-rc.5-Windows-x64.zip及ZIP_SHA256.txt、SHA256SUMS.txt、review/receipt.json未覆盖。旧回执来源阻塞字段仅作历史，不代表当前结论。
- review/RIGHTS_REVIEW.md、BLOCKERS.md、runtime-media-inventory.csv为更正后当前报告；review/history-before-origin-correction保存旧报告。
- review/recovered-generation-calls-20261015.json、generated-output-byte-matches-20261015.json、current-package-origin-bindings.json分别记录实际调用、原生输出字节匹配和当前PCK绑定。来源证据留在ZIP外。

## 验证与复用边界

本次实际核对新ZIP唯一成员、文件大小及SHA、解压一致性；检查仅四份文档变化，EXE/PCK不变。EXE SHA256为6E5A9BB963F57AA9B71C3941D29186FFFFFC59FE84394B527D98DBCA81438F51，PCK为6D6925C0F1A23D4F32B379B081F31707209B2D733C985DCB236E51E20DF8C3CE。

复用原receipt.json和startup目录已有的隔离无头/图形短启动证据（均native exit 0、stderr空，120帧自动退出）。只因相同运行文件而适用，不是本次新启动、驾驶、声音或性能通过。没有关闭、接管或重开原游戏。

用户已通过本机试玩并跳过剩余补证。四关1080p性能、30分钟有效驾驶、20次趋势、剩余正常新/旧档胜负流程继续标为SKIPPED_BY_USER，不记PASS。未签名、其他硬件兼容性及历史退出诊断继续披露。历史生图调用未全部恢复、部分旧处理脚本缺失是归档/重建边界，不是外部采购授权缺口。

## 后续边界

本地准备完成。目标平台、发行主体、用途/收费和分发条款待后续决定；实际公开发布仍须单独授权。没有购买证书、建立账户、签协议或替所有者指定许可证。无需为本次文档更正重测游戏。
