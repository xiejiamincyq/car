# 开发与验证

玩家直接下载[Windows便携包](https://github.com/xiejiamincyq/car/releases/tag/v0.4.0)，不需要开发环境。以下仅供修改源码或制作新版本使用。

## 环境与运行

项目使用Godot 4.7、GDScript和gl_compatibility渲染器。引擎与导出模板应使用匹配版本；当前项目标识为0.4.0。导入project.godot后运行scenes/main.tscn，或在仓库根目录执行：

```powershell
godot --path .
godot --path . --editor
```

普通主场景会读取或保存当前Windows用户的游戏存档。修改存档、迁移或清理逻辑前应先备份存档；需要隔离验收时，给自有测试子进程设置独立APPDATA，不将真实进度作为合成测试夹具。

## 自动测试

使用仓库运行器，不用固定帧数自动退出代替异步测试完成：

```powershell
./scripts/tests/run_tests.ps1
./scripts/tests/run_tests.ps1 -TestFilter test_release_metadata.gd
./scripts/tests/run_tests.ps1 -GodotExecutable 'C:\Path\To\Godot_v4.7-stable_win64_console.exe'
```

运行器检查子进程退出码、错误输出和要求的TEST_COMPLETE标记，使用墙钟看门狗；默认120秒，部分重型测试有独立预算。超时是失败，不是通过。测试可能生成tmp内本地夹具和日志；不要提交缓存或私人存档。

scripts/tests中的RC4帧观察器和历史采集测试绑定旧包及固定工具哈希，不是通用游戏启动器。缺少前置产物时应拒绝运行，不得删除身份保护来绕过检查。脚本长跑、图形截图、玩家体验和正式EXE验收分别记录，不相互冒充。

## 制作新包

1. 明确新版本与改动范围，保留旧Release和旧包；源码、Windows产品版本和玩家说明一致。
2. 运行受改动影响的测试，使用新的唯一exports目录导出；不得覆盖已发布版本。完整集成门按真实影响执行，不能把旧结果用于已变化的运行文件。
3. 使用Windows Desktop导出预设及其资源白名单；不扩大范围以加入开发脚本或源图。当前默认路径是exports/0.4.0/package/NeonCoastRush.exe，实际发布导出需另选新目录。
4. 按[当前发布检查清单](release-checklist-current.md)核对文件、干净解压、隔离启动、校验值、存档保护和实际验证边界。

0.4.0从独立、仅含Git索引文件的构建目录重新导出，发布前核对运行输入与提交一致；来源见[包清单](releases/v0.4.0/package-manifest.json)。这是本机可追溯构建，不是跨设备逐字节可复现或CI构建证明。旧RC5复用过冻结工作区程序，其[旧清单](releases/v0.4.0-rc.5/package-manifest.json)保留，不追溯改写。

## 历史资料

产品设计见[规格](spec-0.4.0.md)，实施记录见[计划](../tasks/plan.md)。[旧0.3.0清单](release-checklist.md)保持历史原貌，不是当前发行说明。v0.2.0、v0.3.0均为旧源码基线，不能默认读取当前v7存档。
