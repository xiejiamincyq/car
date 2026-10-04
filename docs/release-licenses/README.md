# 本机 Windows release 模板许可材料

2026-10-04；R4发布准备，不是最终游戏包验收，也不为游戏选择开源许可证。

这里的两份文本直接来自当前安装的 Godot 4.7 Windows x64 release 模板。`GODOT_LICENSE.txt`是引擎许可全文；`GODOT_COPYRIGHT.txt`包含API返回的全部组件版权、文件范围、许可表达式及19份引用许可全文，不是本游戏的版权声明。文本与原始输出逐字节相同，未删减或翻译。

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| GODOT_LICENSE.txt | 1149 | B0435E3B3E4E55238F05F4B306F30524A1B2E20147810D436EAA554FA6855C80 |
| GODOT_COPYRIGHT.txt | 93347 | 92B24143F6083111537353995AC84F0F89077B444D513C942C1D9106DF272C7C |

目录内`.gitattributes`保持这些声明的LF换行，避免Windows检出时改变上述字节哈希。R5正式构建时把两份文本放在EXE/PCK外侧，逐字节校验；不要为放入声明而扩大PCK资源白名单。

## 取证对象和方法

模板路径：`C:/Users/21604/AppData/Roaming/Godot/export_templates/4.7.stable/windows_release_x86_64.exe`。

- 大小109160448字节，SHA-256 `C42EB5D17F683EB8BCD52C19A9F36EBF811B1788623878D5276A7D9FFC09F95C`。
- PE签名0x4550，machine=0x8664；文件版本4.7。实际运行API版本`4.7.stable.official.5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。
- 实际运行特征：template=true、release=true、editor=false；不是通过编辑器模拟这些特征。

在独立临时目录复制同一模板，复制前后SHA相同。配套测试PCK只有最小project.godot、Node场景、许可提取脚本与空全局类缓存四个文件，不含任何游戏代码、素材、存档或自动加载。使用PCKPacker生成，未调用游戏导出预设。模板以`--headless`自行加载同名PCK，读取`Engine.get_license_text/get_license_info/get_copyright_info`；仅将结果写入测试EXE自身目录，不调用SaveStore或访问user://。

最终入口`tmp/run-r4-template-license-pack-20261004.ps1`；源工程`tmp/r4-template-license-20261004/`；有效终态证据`tmp/r4-template-license-20261004/v2/`。20秒看门狗只结束精确匹配的自有进程，持有Process Handle且要求原生退出码和末尾标记。原生0、完整标记failures=0、stderr为空；19个非空许可、102个唯一组件记录、106组非空版权条目、未解析许可名称0，写入后UTF-8原文核对通过。

当次实际命令（项目根目录PowerShell）：

```powershell
& 'C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe' --headless --path 'C:/Users/21604/Documents/car/tmp/r4-template-license-20261004' --script res://build_probe_pack.gd
powershell -NoProfile -File tmp/run-r4-template-license-pack-20261004.ps1
```

第一条只用编辑器建立四文件的合成PCK；第二条实际调用release模板副本，其参数只有`--headless`。既有证据目录及PCK禁止覆盖，直接重跑会被碰撞检查拒绝；需要复取证时应改用新的空临时目录和新的日志/包名称，并重新核对复制模板SHA。不要删除旧失败记录来重跑。

| 证据 | SHA-256 |
| --- | --- |
| 四文件测试PCK | F70273173DEBF45AB6C7A5B6FBDF2C81D09E938B95E003314139F608AF5CE02D |
| API原始JSON | 1522E423ACA163A07C6374EA53E00344A3AF85EF765AA3AA379C4729C3BFF4F5 |
| engine-license-validation.json | E2CC0775D2901674D1C3A418622A5EC76885C8736E19EB9EA2EB2260F9864E8D |
| stdout-pack.log | D0BB08A71353554F5998BFA4296B4BAF864B74156525CAAEB1210794B0AE8764 |
| 空stderr-pack.log | E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855 |

这些原始许可API字节与2026-10-03旧编辑器提取完全相同；现在有实际release模板证据，不再仅由旧编辑器结果推断。API组件清单不等于逐组件运行功能测试。

失败尝试保留：该官方release模板禁止`--path`和工作目录裸工程加载；两次日志未通过。第一版三文件测试PCK虽许可读取成功/原生0，但stderr有缺失全局类缓存ERROR，审核入口准确返回失败；补齐此独立工程合法空缓存后四文件v2才通过。没有关闭错误输出、改引擎或覆盖失败证据。

## 使用边界

本次只是模板许可事实，不证明最终EXE身份、图标、应用版本、签名、实际PCK清单、性能、音频、字体或真人体验。R5需记录所用模板哈希，确认没有换模板，并核验包内外实际材料。如果模板变化，应重新取证。

现用66项游戏媒体的来源与未确认权属见[资源清单](../release-runtime-manifest.md)。菜单图原作者/授权仍无独立证据；旧素材处理脚本缺口仍保留。不能从引擎许可推断素材版权或公开发行许可，也不填未知游戏版权所有者。公开发行须另行授权和处理权属问题。

2026-10-04候选准备补充：[runtime-media-sources.csv](runtime-media-sources.csv)归档66项现用图片/音乐的相对路径、字节、SHA、源输入、构建依赖、来源记录及已知缺口。归档前重新核对全部66媒体和59来源/工具/记录文件，均与原事实映射的哈希一致；不改变原JSON的历史版本归属，也不把来源声明升级为许可结论。玩家包仅附简短来源说明，不复制开发源图或这份开发清单。两份引擎文本保持API原始字节，包括原版权文本的末尾空行；不为消除格式检查提示而改动许可原文。
