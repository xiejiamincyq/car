# Windows 本机候选：导出前运行资源门禁

状态：R4.3 准备项；没有导出、安装模板、打包或发布。此清单不证明最终 PCK 正确，也不替代 R5.1 固定候选门和 R5.2 实际 release EXE 验收。生产应用身份 `Neon Coast Rush` 与存档位置不变；本片不修改 `0.4.0-dev` 元数据。

## 可复查入口

- `export_presets.cfg`：`export_filter="resources"`，`export_files=PackedStringArray(...)` 为逐文件白名单；`include_filter` 空，不用通配 include 吞入原始资料；`binary_format/embed_pck=false`。
- `scripts/tests/ExportResourceAudit.gd`：只读配置及逻辑依赖；独立运行只输出审核结果，不写预设、不导出，也不访问 `user://`。
- `tests/test_export_resource_manifest.gd`：在现有墙钟 runner 下执行：`./scripts/tests/run_tests.ps1 -TestFilter test_export_resource_manifest.gd`。要求退出 0、`EXPORT_MANIFEST_CHECKS_COMPLETE failures=0`、`TEST_COMPLETE test_export_resource_manifest.gd` 同时出现。

schema 核对采用实际本机引擎 `4.7.stable.official.5b4e0cb0f` 对应的 [Godot 导出配置源码](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/export/editor_export.cpp)：选资源模式为 `resources`，名单字段为 `export_files`，不是臆造的 `include_files`。这是配置/源码核对，并未调用实际导出器。

## 逻辑白名单

本片初次绿测试为 127 项逻辑资源：57 GDScript、3 场景、1 音频总线布局、62 PNG、4 OGG。新依赖加入后计数可能改变，必须审阅并同步逐文件白名单，而不是固定计数冒充完整性。

| 运行组 | 明确保留的源路径 |
| --- | --- |
| 主入口与场景 | `scenes/main.tscn`、`scenes/tour_map.tscn`、`scenes/vehicle_select.tscn`、`default_bus_layout.tres` |
| 运行脚本 | 从主场景和运行脚本字面量 `preload/load/extends` 得到的递归闭包；不等于整个 `scripts/` 目录 |
| 玩家车 | `assets/vehicles/player_{pulse_gt,driftwing,flashpoint,comet_rs,tidebreaker,aurora_x}_c.png`，6 张 |
| NPC | `assets/vehicles/traffic_{sedan,van,hatchback,sports,truck}.png`，5 张 |
| 背景序列 | `assets/environment_sequences/{neon_coast,freight_harbor,storm_ridge,sunrise_express}/{left,right}_00.png` 至 `_04.png`，40 张 |
| 路面 | `assets/pavement/{neon_coast,freight_harbor,storm_ridge,sunrise_express}.png`，4 张 |
| 音乐 | `assets/music/{neon_coast,freight_harbor,storm_ridge,sunrise_express}.ogg`，4 首 |
| 界面/反馈 | `assets/neon-coast-menu.png`、`assets/ui/{hud_frame,event_plate,road_barrier,result_emblem}.png`、`assets/effects/finish_burst.png`、`assets/pickups/fuel_pickup.png` |

表中花括号只用于说明集合；实际 `export_files` 没有通配符，每个源路径逐项列出。直接场景依赖使用 [ResourceLoader.get_dependencies](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html#class-resourceloader-method-get-dependencies)，UID 记录取第 3 段 fallback 路径。实测本机运行时接口不枚举 GDScript 的嵌套 preload，故脚本补充受限字面量扫描，注释不算依赖。

动态路径另外显式枚举：`TrackCatalog` 的左右序列和 `surface_id`、`VehicleCatalog.texture_path`、`MusicCatalog.TRACKS.path`。音乐 `source_path` 是开发复现信息，生成 Python 不入运行包。`MusicCatalog.validate()` 的源文件存在性检查不应作为最终包内运行资源检查。

门禁拒绝：名单缺项、重复、闭包外新增、文件缺失/非资源、必需资源被 exclude 误伤、非空 include、嵌入 PCK、非白名单模式及缺少排除防线。测试含音乐/背景/车辆/路面/嵌套脚本漏选、工具/源素材/旧车额外加入、假缺失文件和错误过滤器的负控。

## 排除与生成文件边界

`tests/`、`tmp/`、`docs/`（含截图/试听/源图预览）、`scripts/tests/`、`scripts/tools/`、`scripts/art/`、`art/`、`tasks/`、`exports/`、`build/`、旧 `assets/environment/`、旧 `assets/tracks/` 明确排除；旧非 C 玩家车不在白名单。私人存档、合成存档、调试日志、录制、源代码工具和素材源图不放玩家包。`.git/`、开发 `.godot/` 与导出凭据也不得作为原始目录复制。

此处是逻辑源文件白名单。Godot 导出器会产生纹理/脚本转换、映射、项目配置及其他内部运行文件；不能用“所有点目录都删掉”误删 PCK 中合法生成的导入资源。最终 PCK 需把实际条目映射回上述源路径，并单列必要引擎生成条目；本片未检查这些实际条目。[官方导出资源说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html#resource-options)

## 许可与来源准备，不替用户选择项目许可

未来包外侧最小组成：`NeonCoastRush.exe`、`NeonCoastRush.pck`、精简玩家 `README.md`、`GODOT_LICENSE.txt`、`GODOT_COPYRIGHT.txt`、现用素材来源/已知限制材料。已从本机引擎的 `Engine.get_license_text()`、`get_license_info()`、`get_copyright_info()` 提取临时取证材料（见下），尚未安装到候选包；应保留第三方版权与适用许可文本，不只一句“使用 MIT”。Godot 不要求游戏代码也选择 MIT。[官方许可说明](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)

现有来源记录可查：

- 菜单图：`docs/ideas/road-dash-mvp.md` 记为项目所有者提供；记录不是独立授权/权属鉴定。
- NPC/UI/拾取/特效：`art/README.md`、`art/sprite_manifest.json` 记为图像模型生成与本地透明/缩放处理。
- 现用六款 C 玩家车：`docs/vehicle-facing-audit.md` 指向 `docs/previews/<id>-c-source.png`，Driftwing 指向 `docs/previews/driftwing-c-approved.png`；旧 `art/source/vehicles/README.md` 与 `sprite_manifest.json` 仍描述非 C 图，不能冒称最新完整清单。
- 40 背景：`art/source/environment_sequences/README.md` 与四个 `*_sections/` 源目录。
- 路面：`docs/previews/pavement/README.md`、`docs/pavement-validation-20261001.md` 与 `art/source/generate_pavement.gd`。
- 4 首音乐：`art/source/music/README.md` 及三份合成脚本；记录说明无外部采样。程序音效见 `scripts/sound_effects.gd`、`scripts/collision_sound.gd`。

目前未发现项目 LICENSE/NOTICE 或用户字体文件。游戏自身版权声明、许可选择、菜单图授权证据与完整最新版素材清单仍待确认/整理，不填未知版权所有者，不把来源记录当法律结论。

### 本机引擎与现用媒体事实取证

本地目录`tmp/r4-license-e9db487-2a9a2b2ef69547898c55227ca8c5012d/`保存独立最小工程、提取脚本、API原始JSON、许可全文、验证/哈希和66项媒体来源映射；没有加载游戏或访问正式存档。实际4.7 editor API返回19项非空许可、102个组件、106组版权条目，名称映射检查0失败、退出0且stderr空。入口`README-evidence.md`保留命令与范围；这些是editor材料，不证明未来export template或EXE组件完全相同。

- `engine-license-api-raw.json` SHA-256：`1522e423aca163a07c6374ea53e00344a3af85ef765aa3aa379c4729c3bff4f5`。
- `GODOT_LICENSE.txt` SHA-256：`b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80`。
- `GODOT_COPYRIGHT.txt` SHA-256：`92b24143f6083111537353995ac84f0f89077b444d513c942c1d9106df272c7c`，包含组件声明及其引用许可全文，不是本游戏版权声明。
- `runtime-media-provenance-facts.json` SHA-256：`27b3e84a962a31acda73ae2ea5ece2c9e5a4c1ead4a3e1a286559a776903d3d3`，覆盖18张界面/车辆等PNG、40背景、4程序路面、4音乐及59个现有来源/工具/记录文件。四首音乐实际大小/SHA与构建记录相符。

发现的材料缺口继续保留：`art/README.md`提到的`remove_chroma_key.py`仓库内未找到，不能声称完整可重建；旧非C车清单不适用于现用六车；菜单只有项目所有者提供的记录，原作者/授权/必需署名未知。未重生成素材、未替用户选择游戏开源许可证、未宣称权属审计通过。上述原始材料只在本地tmp，源码仓库目前仅备份本索引，不声称已备份全文。

## 后续门槛与未覆盖项

1. 新代码/目录依赖出现时重新运行静态门禁；当前扫描适用于现有单行字面量与已知动态目录，不是通用 GDScript 解析器，未来的新计算路径/多行调用必须增补检查。
2. R5.1 条件达到后固定候选，统一 project/场景/Windows/玩家文档的版本和身份，补许可材料。保留应用名和正式存档位置；本片不改 README、项目版本、图标或未知版权字段。
3. 再导出真实 EXE+PCK，记录命令、源码提交、匹配模板/引擎、尺寸与 SHA-256；核对实际 PCK 和包外侧清单。正式身份下的测试必须使用明确隔离 APPDATA/合成旧档，不靠新解压目录假定存档隔离。
4. 使用同一真实包验证动态加载四关背景/六车/路面/BGM、中文字体和首启→保存→关闭→重启，以及计划性能/稳定性与真人验收。未签名需披露，不承诺无 Windows 提示，不自动公开发布。

证据：`tmp/r4-export-manifest-red.log` 为旧预设 9 个配置失败点；扩展闭包红证据为 `tmp/r4-export-manifest-closure-red-v2.log`；原始缓存拒绝补测为 `tmp/r4-export-manifest-cache-guard-red.log`（1 失败）；最终绿证据为 `tmp/r4-export-manifest-final-green.log`。独立审核入口的 20 秒墙钟核验见 `tmp/r4-export-audit-cli.stdout.log`（127 项、0 失败、COMPLETE，退出 0，stderr 空），元数据专项见 `tmp/r4-export-metadata-regression-green.log`。尚未验证真实导出/PCK条目、模板当前状态、实际包字体/BGM、许可文本完整性或运行包性能。

### 2026-10-04模板许可更新

上述“模板当前状态/许可文本未验证”为旧片快照。当前已对实际安装的Windows x64 release模板运行独立四文件许可PCK，原生0、完整末尾标记、stderr为空；模板SHA、版本、release/template/editor特征与许可名称/版权字段均已实际核对。两份逐字节许可声明已整理至[发布许可目录](release-licenses/README.md)，供R5放入EXE/PCK外侧；不改变运行资源白名单，不替游戏选择许可证。原始API结果与旧编辑器记录相同，具体命令、哈希、失败尝试和范围见该目录说明。

这不是游戏RC导出或独立游戏流程验收。最终包所用模板/许可材料仍需实际核对；游戏素材授权、身份元数据、实际PCK/字体/BGM、图形性能和真人门仍未关闭。此许可取证时自然驾驶矩阵尚在运行，仅新增未加载文档和独立临时许可工程；现原1080已准确终态并完成固定配置补证。菜单修复02b1b90的143全量已准确失败终态，242源码/测试/配置及HEAD无变化，仅difficulty_profiles超时；同代码与原120秒限制隔离复验通过。新增路线归档回归使下一次全量为144项，尚未以隔离结果替代完整门；许可文档尚未随游戏打包。

后续终态更新：bd5acf2完整144项测试native0、246加载源/配置与HEAD稳定，原记录脚本四条零值误判经独立只读复核通过，原日志/外层exit1保留。见[联合技术门结论](product-gate-review-20261004.md)；源码依赖名单没有扩张。此后可以继续R4/R5准备，但尚未实际导出、没有取得包内/PCK/性能或真人验收。
