# RC2 独立候选取证（2026-10-04）

当前按用户取消网页监督的指令自主执行，不访问旧会话。本轮不改玩法、输入、交通、音画或存档；不控制已交给用户的RC1窗口，不重复邮件。结论是完成新候选的构建及短启动子检查，**不是成品或R5/R6整体验收**。

## 固定源码完整回归

源码提交`2a4d839fc771069d0035f5ebd1bb627e8816780f`；原完整回归准确退出0，146测试、67完成标记、一个ALL标记，700.9028797秒。冻结258个源码/测试/场景/配置/玩家资料文件，前后HEAD及全部文件哈希不变；未改变120/600秒看门狗。

日志`tmp/rc-full-2a4d839-20261004.log` SHA `FE891F5991A906817A02FE4DD1D7E1A48E5A05317D6F0C6AE37D9E435D1F994B`；准确终态JSON SHA `5B40FC960A8AF4BDEB5C44E3BCD47EAF1F3D3FD1B41A8751A2B28FFB4DB3A995`。日志保留28 WARNING/12 ERROR：11条退出资源仍在使用，加一条采样器故意注入的不可写目录错误；无断言、解析、脚本或超时失败，不称零诊断。模拟压力、合成状态与交通模型不能充当正常EXE驾驶或真人样本。

## 首次导出失败及根因修复

失败目录`exports/0.4.0-rc.2/2a4d839-d6b9a75d/`原样保留。引擎原生0，但检查器因66条ERROR拒绝通过：22张历史RC1截图各产生一次PNG解码、图像加载及导入错误。它们均位于`res://exports/0.4.0-rc.1/...`，文件头为JPEG `FFD8FFE0...JFIF`而后缀为`.png`。没有正式资源路径错误；66项运行媒体中的62张PNG均具正确PNG签名。运行脚本/场景没有`res://exports`引用，128项资源选择也不包含证据目录，原`exports/*`打包排除规则保持。

失败stderr SHA `B9D5CD91443E3ED04046B80BDCE01343A85427A5F889F76574619A2853E16F8A`。不能因引擎退出0或EXE存在就认定导出通过；未将此失败包发为通过包。

原因是打包排除不等于编辑器扫描排除。按[Godot 4.7官方目录组织说明](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html#ignoring-specific-folders)，在**仅存导出包及取证产物**的`exports/`添加空白`.gdignore`，让编辑器不把历史截图当游戏素材导入。文件内容不作为模式规则。没有改名、转换、覆盖或删除旧截图，没有隐藏`assets/`错误或放宽ERROR过滤；临时导出脚本增加该固定目录边界检查。原失败和全部旧证据仍在。

此为运行资源范围之外的编辑器导入边界修复；冻结的258文件及HEAD在重新导出时仍保持，未用文档提交冒称新完整回归。

## 新目录真实构建与资源核对

新目录`exports/0.4.0-rc.2/2a4d839-5c48bdf4/`，相同固定源码与匹配4.7引擎/模板；真实导出准确原生0、检查通过、7.3834874秒、无ERROR/超时/源变化。仍保留一个`tmp`中另一个project.godot被忽略的WARNING，不称零警告。

EXE元数据实际为产品`Neon Coast Rush`、版本`0.4.0-rc.2`、文件版本`0.4.0.2`、描述`release candidate 2`。实际包目录仅EXE、PCK、README、素材说明及两份Godot许可文件。

| 产物 | 字节 | SHA-256 |
| --- | ---: | --- |
| NeonCoastRush.exe | 109019648 | `2DAAA00880E8A9123B966B45BEE6DD9B6D7F288E7485C3DB1FB28867768B9811` |
| NeonCoastRush.pck | 26210616 | `EDEA4A1CA684809FF055D79683C41AE7FCA65448894623C497601F8AACA39C17` |
| NeonCoastRush-0.4.0-rc.2-2a4d839.zip | 64394615 | `8E87FFCC1505CAC18A2433A828E7EA67CE8EAF99A87BFF729F9D2E51DB7DC4B7` |

只读PCK审计准确0：259个物理条目，128项逻辑依赖全部解析，各条目MD5及SHA已核对，无测试、历史证据、存档或开发素材混入。独立源码隔离解码项目挂载此实际PCK，准确原生0，128项可加载、62纹理尺寸有效、4音乐时长有效、3场景可实例化、主场景126节点；未执行比赛，不证明听感。ZIP准确0，六个无重复条目逐项字节和SHA与实际包一致。原始依据分别为export-ledger.json、pck-audit-rc2.json、pck-decode-rc2.log、zip-ledger.json。

## 正常release短启动及采样开关

两个新子APPDATA运行同一实际EXE/PCK、正常主场景；没有脚本覆盖、测试包或输入注入。`--headless --quit-after 120`仅用于明确有界的启动检查，**不用于异步测试通过或比赛性能证明**。它们是独立运行，不能拼成长期稳定性。

- `runtime-dec2e0e7`，PID9112，采样开关0，1.4393061秒，准确原生0、无错误/超时，隔离目录没有JSONL。
- `runtime-1cce6f86`，PID24048，开关1，1.4278662秒，准确原生0、无错误/超时；唯一会话JSONL含start、一个真实title sample及closed。schema/PID/session/单调时钟/关闭计数均核对，`debug_build=false`。样本nodes181/objects2003/resources74，release不可用的orphan_nodes及static_memory_bytes明确为null，非0。run/reset均0；没有比赛局。

两个运行的包哈希、父APPDATA及运行前已有正式存档哈希均不变。JSONL SHA `D73FCDD084F5AD2F287F8E42A8B8C8CF927AD0F8137FAECFD19D6C6705F01ABA`；独立检查capture-smoke-audit.json SHA `BD34DADEE1790C4A4540465DDE0C6BE38B73E88B82870EABCEA89455074F5405`。headless窗口64×64/FPS1只是启动状态，不当作720p/1080p渲染或60FPS结果。

## 仍开放的门槛

默认关闭的采样入口已在实际release证明可用，性能补片的候选构建子项完成。但仍缺新RC完整成功/失败流程、四关复杂交通/施工/超载1080p60FPS/P95≤20ms、连续30分钟与20次真实重开/返回的内存/节点/对象趋势，以及R6十局标准难度及简单/困难体验。RC1旧帧记录和人工入口不会自动成为RC2证据。

继续保留真人听感/手感和新增权限边界。不重复已稳定大批测试制造进展，不改目前手动游戏，不访问网页监督，不公开tag/发行。`.gdignore`及本轮归档单独提交备份，不将用户ADR改动或无关生成文件夹带入。

自查范围仅导入边界与证据归档：忽略目录没有运行引用，正式媒体与128依赖保持；原失败未被改写，新构建保留相同ERROR拒绝规则；无新依赖、网络发送、存档或输入变化。`test_export_resource_manifest.gd`在修复后准确0/失败0/128项及末尾标记齐全（tmp/rc2-post-ignore-manifest-20261004.log）。这是本地自查，不伪称网页/独立模型审查或真人认可。

## 续验：同一RC2的正常入口读档

继续使用以上EXE/PCK/ZIP，没有源码、包、正式存档或当前RC1窗口变化；当前进程查询仍是RC1/PID24164及原创建时间。全部新增运行仅120帧headless标题入口、子APPDATA隔离，显式开启取证，不触发自动开局或保存。

使用明确合成的v5困难档、v6简单档与坏档；12345分/7次生涯/四关金牌是兼容性夹具，不是获得的成绩。采样只验证实际采用的difficulty，不能由此宣称分数/生涯/音量/车库画面全部正确。Main在开局时才应用所选赛道/车辆，标题sample里的默认track/vehicle不能拿来断言选项丢失或正确。

| 条件 | 实际难度 | 游戏原生退出 | 原始ERROR |
| --- | ---: | ---: | ---: |
| 仅有效v5困难主档 | 2 | 0 | 0 |
| 主档缺失、有效v5困难备份 | 2 | 0 | 0 |
| 有效v6简单主档、有效v5困难备份 | 0（主档优先） | 0 | 0 |
| 语法坏主档、有效v5困难备份 | 2 | 0 | 1个预期解析错误 |
| 主档/备份均语法坏 | 1（默认） | 0 | 2个预期解析错误 |

前三例分别为runtime-8cc5ace1/c27854fc/c1f6100f，1.4595921/1.3975296/1.402316秒，原检查通过。后两例分别runtime-7a361f39/39596b29，1.4309728/1.4020226秒，通用检查脚本如实返回2而非掩盖故障ERROR；只读复核按严格预期诊断验证故障处理。各次实际采样均为release、title、0局/0重置，PID绑定且正常closed；全部输入主档/备份原字节和文件集合不变，没有标题启动静默迁移写回、覆盖坏档或新增save.cfg。

### 两次检查器失败全部保留

首次`legacy-entry-ac8562de/summary.json`整体false，SHA `380F6350D30ADE9E2999AAB48BA06EC83F92D7EE6682E7640B14394B29F12857`。两坏档例的夹具只有一行无赋值字符串，检查器错误假定会有解析ERROR；最小同版本ConfigFile探针证实实际parse=OK/无节，是语义无效的空配置，不是语法错误。实际备份/default难度仍正确，但不能算原定语法故障覆盖。该轮全部原档/日志保留。

另建`[meta]`及`version=this ...`夹具，同版本独立探针明确parse=43/ERR_PARSE_ERROR；只重跑受影响两例，没重跑前三例。第二次`legacy-entry-31475d34/summary.json`仍false，SHA `2630547C592EBCF5AE7BA51190350CE8CCA0D3A888F1351C1F379D217217EC3B`：检查器误把该夹具的诊断行号写成2，实际引擎报告`<string>:1`，两例实际行为/错误数量/输入不变均正确。调查参考匹配版本的[ConfigFile源码](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/io/config_file.cpp)，最终期待文本仍以本机探针和原始输出为准，不泛化所有坏档的行号。

修正仅临时检查器的具体夹具期待，不改游戏或通用ERROR过滤。随后直接只读复核已有两次真实运行，而非为了绿色标记重开游戏：重新核对terminal/trace SHA、精确1/2条诊断、actual difficulty、PID/title/release/closed、包/正式档边界及合成输入哈希。新增无关ERROR和错误难度负控均被拒绝。`legacy-entry-31475d34/reviewed-parser-line.json`通过，SHA `8A042C22D64BAA8AC3AFF95653E22ECE0C060CC8B423AD36A6B53D6D1A5AF5E9`。两份原false账本不改写；不能把前三例和两例复核拼称“一次五例全绿”。

本子项只证明正常release启动读档/优先级/备份/default难度及不写盘，**不关闭存档写回、完整开局→结算→重启读档或R5/R6整门**。尚无新真人回报；当前已确认的人工窗口是RC1，不自动关闭或更换。下一步需用户结束旧试玩后交接同一RC2的实际键盘驾驶与被动采样，当前工具不能通过正常release入口自动输入；不以测试主场景/编辑器或合成驾驶代替。

## 用户授权后的RC2真人入口（覆盖上一节旧RC1窗口状态）

用户明确要求“开始RC2试玩”。启动前已查询旧PID24164不存在；同一不可变RC2于2026-10-04T10:32:39.1785550Z以正常入口启动，PID49744、1920×1080、独立空APPDATA、`NEON_COAST_PERF_CAPTURE=1`，没有复制正式进度或合成成绩。命令只含verbose、指定游戏日志、windowed、resolution；无脚本覆盖、输入自动化、定时退出或游戏看门狗。正式save.cfg哈希与原备份/临时档存在性在交接后不变。

本地原始证据均在成功构建根`exports/0.4.0-rc.2/2a4d839-5c48bdf4/manual-74853869/`：`handoff.json`和`live-verification.json`记录入口、EXE/PCK哈希、PID/创建时间、隔离边界；正常Main生成`appdata/Godot/app_userdata/Neon Coast Rush/performance/capture-49744-1441987.jsonl`，实际release/schema1，阶段、局号/重置号、赛道、难度、施工、超载、分辨率、焦点与节点/对象可逐样本核验。当前JSONL仍持续追加，不把活动文件哈希写作最终摘要。

`handoff.json`中的`parent_capture_restored=false`原样保留：临时PowerShell启动壳用null恢复原本不存在的变量，.NET调用将其转为空字符串。独立最小验证证实用`[NullString]::Value`才恢复真正不存在；启动壳已结束，后续壳检查变量不存在，没有持久/global环境修改。子游戏按授权继承1且正常采样；空字符串本来也不触发采样。不伪称该诊断字段通过，也不为更改账本而重启真人游戏。

2026-10-04T10:34:37.5629622Z启动唯一针对PID49744的PresentMon原观察会话，工具PID35144、1800秒、terminate_on_proc_exit、no_track_input；原会话78230及`observation-9f551d02/start.json`绑定同一EXE/PCK身份。同时采集进程私有内存/工作集；观察器仅能结束自有PresentMon，绝不结束游戏。后续以原会话/原进程终态判定，不因观察超时或暂时无输出重启。

10:36:02 UTC的交接核验与后续只读查询确认游戏/观察器身份活跃；目前读取的样本均为title、0局/0重置，没有真人终态反馈。此节只关闭“已交接RC2且取证渠道活跃”的入口事实，**不关闭驾驶、复杂场景性能、30分钟/20重开、完整存档或R6体验门**。PresentMon相对时钟和游戏elapsed时间须校核后才能做阶段帧关联；全帧P95不自动等于四关复杂驾驶达标。下一步保留原游戏与原采集会话，等待真实驾驶/终态和人类反馈，再据原始数据验收。
