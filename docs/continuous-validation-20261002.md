# 连续收尾技术验证记录

日期：2026-10-02。路线：[M1–M4](../tasks/plan-continuous-completion.md)。监督：[网页6Pro](https://chatgpt.com/c/6abeba46-7a48-83ea-8fb9-60cb28c3c397)。这是技术证据，不是人工试玩或发布验收。

## 基线与数据边界

- 开始提交：8f69d86（代码最近提交7fa5981）；Godot实测 `4.7.stable.official.5b4e0cb0f`。
- 原有ADR-001未提交变化、CLAUDE.md、生成的uid/import与其他临时文件不纳入本轮提交。
- 正式 `user://save.cfg` 在本机独立临时目录备份并核对哈希一致；不上传其内容。六项M1专项测试前后SHA256均为 `D91F4FC7E54E2ABFE9FC3131C0DAF5B5B14147D875EAE827958B2C58B8243288`。
- 本轮新增存档测试使用合成隔离SaveStore；进程仍会写自己的测试/引擎日志，不声称操作系统级零写入。既有test_main_persistence_mode通过正式主场景启动验证启用持久化，会在进程内部正常只读加载正式档，但不触发设置/结算写入、不输出或外传内容；不声称全量测试完全不读正式档。强杀/断电不能保证保存最后一局日志。

## M1：同帧终态修复与隔离验证

**根因**：可选试玩记录器逐帧观察Main；结算后的重开/返回可以在下一次观察前清空旧RunState，使clear/failed降级为aborted。

**红→绿**：`test_playtest_isolation.gd` 的clear/failed × replay/title四个同帧变体原均失败、退出1；最小修复后退出0。原始日志：`tmp/playtest-isolation-red.log`、`tmp/playtest-isolation-green.log`。

**修复**：Main在 `_reset_run` 清状态前发出通用 `run_resetting`；试玩记录器订阅后同步snapshot→observe→finish。正式游戏没有该记录器，未引入测试脚本依赖。`_finished` 保证结束一次，新局观察重新开启。

**历史首轮**：六项 `test_playtest_isolation`、`test_playtest_recorder`、`test_playtest_recording_flow`、`test_save_store`、`test_persistence_integration`、`test_audio_settings_ui` 曾报告退出0，无脚本/断言失败；命令为 `Godot --headless --path . --quit-after 60 --script res://tests/<test>.gd`，不能单凭退出0作为最终通过。Windows不区分路径大小写，原 `tmp/M1-<test>.log` 已被下述 `tmp/m1-<test>.log` 墙钟重跑覆盖；现存文件仅代表新运行器证据，不再冒称保留旧首轮原始日志。

隔离测试有启用持久化确实能写的正控；禁写后真实设置、结算、重开、返回、退出不改变合成哨兵哈希和回读内容，无残留.tmp/.bak；日志路径不可写时仍可重开驾驶。`PLAYTEST_ISOLATION checks complete; failures=0`。不可写路径警告是预期负例，退出音频警告不是预期通过项。

独立审查未发现阻断：构造阶段无记录器监听、旧局先保存、新局重置状态无重复。限制：写盘失败后本进程停止记录，不宣称自动恢复；不覆盖磁盘写满或JSONL半行恢复。

**补齐证据**：修复已提交并备份为 `db9d0a0`，运行时差异严格Main +3行、Recorder +10行。六项专项随后用新墙钟运行器 `run_tests.ps1 -TestFilter <test>.gd` 重跑，均有 `TEST_COMPLETE <test>.gd` 和 `ALL 1 TESTS PASSED`，退出0；日志 `tmp/m1-<test>.log`。新增初始化重复reset不产档、连续两次同帧重开只记录三个实际开始的倒计时尝试；已观察终态后reset不重复由既有flow覆盖。四竞态均打印 `M1_TERMINAL_CASE ... status=pass`。

原四红日志SHA256：`E3B1344820F94A8CC5CF30F55282953BD438C7CB24D2F062E5EB2841783F6C3D`；新isolation绿日志SHA256：`5D4ACF557D8766467ED507BAAD94F062CE646C7761C71553C24D0883A67A4CA9`。哈希只标识该次历史证据，不代表重跑后日志字节不变。

## 测试运行器的假绿修复

`--quit-after 60` 实为引擎主循环次数；音频负控延长到1秒时旧参数返回0却未打印末尾标记，无帧退出限制才真正完成。证据 `tmp/teardown-old-runner-long.log` 与 `tmp/teardown-wallclock-long.log`。这证明运行器存在提前成功风险，不表示历史所有测试均被截断。

现改为每项120秒墙钟看门狗：只结束自己启动的子进程，超时计失败；首版八项关键测试强制准确末尾标记，最终9e7cd09增加rating_ui和persistence_restart至十项。独立审查无阻断。手工验收fixture `tests/runner_watchdog_probe.gd` 在1秒上限被判失败、10秒上限到达 `WATCHDOG_PROBE_COMPLETE` 并通过；缺末尾标记的负控也确实失败。该fixture不匹配默认test_*.gd，不加入常规测试数量。

## M2：测试专用音频收尾

网页批准仅先改测试，不改正式游戏退出：新增 `tests/support/audio_teardown.gd`，停止前捕获播放实例弱引用，停止后条件等待实际回收（默认2秒上限），附静音退休探针；超时不能判通过，原日志不屏蔽。专门负控保留强引用必超时，解除后才通过。两项旧音频测试保留原断言，仅替换收尾。

当前/最后一次播放实例的弱引用不能证明全部历史实例已消失；除条件检查外还看退出完整日志。WASAPI即退与条件排空对照、正常循环稳定性及正式退出代码路径继续补证，非阻断遗留必须经网页明确接受。

后续补证已完成：[音频退出调查与日志索引](audio-exit-investigation-20261002.md)。实际WASAPI单播放器/Main各5组立即退出与条件清理对照；3暖机+20轮没有额外清理的自然生命周期，观察实例无跨轮积累；按钮与窗口代码退出路径各3次均正常结束且隔离存档哈希不变。游戏退出仍可能警告，没有伪称已清零或已证明长期内存稳定。

## M3：实际自然拾取烟测

`tests/test_dynamic_pickup_smoke.gd` 沿用十组标准难度配置，每组最多60秒；起始完整度60%，约70%车型极速，正常油门/刹车/有界转向与短视危险否决。完整Main._process生成交通、施工和物品；没有强制生成、补注燃油、瞬移或关闭碰撞。

历史首轮命令：`Godot --headless --path . --quit-after 60 --script res://tests/test_dynamic_pickup_smoke.gd`，退出0；因旧帧数上限存在假绿风险，不单凭该退出码作为最终验收。后文的新墙钟运行器和完成标记取代此轮门禁。`tmp/M3-test_dynamic_pickup_smoke.log`关键输出：

```text
DYNAMIC_PICKUP_TOTAL samples=10 {"coins":934,"collision_frames":16,"construction_frames":6572,"fuel":29,"oracle_frames":35933,"repair":22,"traffic_frames":35383} failures=0
```

10/10均实际接触拾得自然生成的三类物品，并经历交通/施工。接触几何oracle独立核对删除、回收、奖励一次性；16碰撞帧仅跳过燃油/维修数值oracle，1完赛终态帧未进入检查。

**审查限制**：NPC重叠/三车墙使用正式安全检测器，不能独立证明检测器无错；油耗计算复用fuel_load，只验证组合接线，不独立证明油耗公式；策略读取NPC目标车道，不模拟人类视野。不能推出人类胜率、所有种子、高速/超载或全部72组合拾取成功。

**按监督意见补齐碰撞帧**：测试专用透明子类只在Run.tick、Integrity.apply_damage/repair入口记参数并调用super；从帧前油量/完整度正向重放阻力、赛段/拾取奖励与有序损伤/维修封顶账本，不根据最终值反推。数值oracle扩大到35,949帧，包含全部16碰撞帧/16损伤事件；逐组轨迹、油量、完整度和拾取数量与原样本相同。新运行器退出0，末尾 `TEST_COMPLETE test_dynamic_pickup_smoke.gd`，日志 `tmp/dynamic-pickup-ledger.log`。燃油oracle不再直接调用fuel_load，仍复用获批常量；不独立重算ImpactModel的接触法向/能量，1个完赛终态帧仍未覆盖。

附加专项：content_catalog、tour_traffic_matrix（216配置交通样本）、traffic_all_speed_safety、coin_dynamic_fairness、menu_flow、main_run_loop、rating_persistence均退出0，日志 `tmp/M3-<test>.log`。曾尝试的 `test_tour_ui_flow` 文件不存在，没有执行，不能算通过；完整选择流程以现有ui_flow/menu_flow全量回归为准。

`BalanceAudit.gd -- res://tmp/balance-M3-20261002` 重跑退出0：432燃油/维修模型、1728路线尝试、0保守跟随标记。拒绝生成仍不算成功；补给注入模型不算实战拾取。原始CSV保留在该临时目录，和动态烟测严格分开。

## M4 候选复验

候选 `86285b4` 用新运行器完成 `ALL 94 TESTS PASSED`，shell退出0，日志 `tmp/continuous-candidate-suite-20261002.log`。八项关键完成标记到达；原有快速退出音频警告仍保留。

实际渲染并逐张查看14张中英720p/1080p设置、车库、标题和结算图，未发现裁切/按钮越界；发现结算仍显示种子，与用户旧要求不符。新增8组合回归（两语言×两分辨率×完赛/失败）先红退出1，再移除中英显示模板的种子字段及Main对应参数；内部随机种子和试玩JSONL不改，绿退出0且录制仍含seed。独立审查无阻断。候选更新为 `321f50f`，红绿日志 `tmp/result-seed-{red,green}.log`。

321f50f重新生成18张图：settings/garage/clear/failed × zh/en × 720/1080，另title中文720/英文1080；路径 `tmp/freeze-321f50f-<界面>-<语言>-<高度>.png`。所有捕获进程退出0。设置/车库八图与已审旧图SHA256逐一相同，结算八图另做实际视觉复核；静态检查不冒称键盘手感/物理声音/全部选车状态人工验收。

321f50f最终全量 `tmp/continuous-final-suite-20261002.log`：`ALL 94 TESTS PASSED`，shell退出0，9个实际TEST_COMPLETE标记（其中8项受强门禁）到达，无脚本/断言/超时/缺标记错误；音频退出警告仍保留。八张新结算图已逐张检查：种子消失、评分与统计完整、两个按钮及焦点框完整，无空白占位或新增对齐退化。设置/车库720p雷达小字是非阻断可读性限制，不擅自重做样式。

全scripts/scenes调用点检查仅rating.summary用于当前可见种子字段；旧result.summary/hud.controls字符串保留但无调用，HUD提示已隐藏且有回归检查。未把无调用的旧文案误报为当前可见问题。正式存档SHA256仍与起始备份一致。

## 网页阶段复核

6Pro已根据86285b4证据关闭M1、以已接受的非阻断遗留关闭M2；M3动态拾取/数值集成烟测通过，要求补定位“正常写入结算→返回→重启读档”。现有测试为进程等价重建Main，不完整覆盖该顺序，因此补最小真实跨进程隔离用例，不扩充玩法矩阵。M4种子显示修复已批准，待最终候选复核。

**M3最后一条已补齐**：`test_persistence_restart.gd` 启动真实writer/reader两个Godot子进程，使用唯一tmp合成有效SaveStore且启用正常持久化。writer由合成临近终点状态经过真实RunState完成、Main结算、真实TitleButton返回标题再退出；reader全新Main读同档，核对1500分、累计10局/4450m、生涯明细、三路音量/静音/难度/语言及赛道通关，标题也显示001500。writer文件哈希改变，返回标题及reader不改写；正式save.cfg哈希保持基线。

每个子进程9秒运行看门狗+最多1秒清理，仅针对自己创建的PID；退出码0、脚本错误扫描和阶段完成标记都必须满足。父测试末尾也纳入运行器强标记门禁，独立审查无剩余阻断。日志 `tmp/persistence-restart-green.log` 与主线程复验 `tmp/persistence-restart-verified.log` 均退出0，含WRITER/READER_COMPLETE和TEST_COMPLETE。这是合成成绩持久化证据，不是人工通关。按网页“此条满足即可关闭M3”的裁决，M3退出条件满足。

## 最终候选9e7cd09复验

最后运行时代码为321f50f；9e7cd09补充跨进程回归及文档，不改玩法。该提交已备份到指定GitHub仓库。

- 完整命令：`./scripts/tests/run_tests.ps1`；日志 `tmp/continuous-frozen-suite-20261002.log`，`ALL 95 TESTS PASSED`，调用shell记录 `FROZEN_SUITE_EXIT=0`。十项受强门禁的准确TEST_COMPLETE全部到达，无脚本、断言、超时或缺标记错误。音频退出警告仍原样保留，不称“无错误日志”。
- 全量内跨进程writer PID15364、reader PID39344，均退出0并到达阶段标记；不能把同进程重建Main称为此证据。
- 同提交重新生成18张 `tmp/freeze-9e7cd09-<界面>-<语言>-<高度>.png`，所有捕获退出0。每一张都与已实际审阅的321f50f对应图SHA256相同；覆盖四界面×双语×两分辨率，加两张标题。没有用旧代码截图替代未渲染的新候选。
- 冻结全量中22项ObjectDB/resource告警测试全部原样headless+verbose定向复跑，不加帧退出限制；每项仅对自建子进程设置20秒墙钟上限。22/22退出0，无超时或脚本失败。
- 本轮16项复现、6项未复现；105个实例只含AudioStreamWAV 22、AudioStreamPlaybackWAV 33、AudioStreamOggVorbis 8、AudioStreamPlaybackOggVorbis 17、OggPacketSequence 8、OggPacketSequencePlayback 17。16条仍用资源仅OggVorbis和OggPacketSequence各8；未见非音频类型。未复现不等于修复，不能外推全部未来情况。逐项CSV和完整日志见本机 `tmp/final-warning-audit-9e7cd09/`。
- 上述复验及告警归类后，正式存档SHA256仍为基线值。既有test_main_persistence_mode内部正常只读正式档的限制仍成立；没有上传存档或覆盖用户ADR改动。

## 最终网页裁决与交付边界

6Pro完整回复已明确：M3、M4可关闭，批准按既定范围完成本机技术交付；M1保持关闭，M2维持接受限定非阻断遗留后关闭，本轮没有新增技术阻断。它依据上述执行证据裁决，没有自行读取仓库、运行本机测试或查看截图。最终文档提交只改文档，技术候选仍对应9e7cd09；若以后改代码、资源、配置或测试逻辑，须重新验证。

### 技术通过

四关六车三难度既定功能的M1–M4技术门关闭；95项回归、十项完成标记、自然拾取/碰撞账本、真实跨进程持久化、18张渲染与存档哈希检查具备本轮证据。修复终态记录竞态、测试提前假绿和结算种子显示遗漏。当前仅完成约定范围的本机技术验证，不是产品全面人工验收。

### 已接受遗留

- 本机指定Godot构建/WASAPI下正式退出偶发音频对象回收时序告警；日志保留，未证明引擎缺陷或长期全堆无泄漏。运行期持续积累、挂死、崩溃、数据影响或非音频残留出现时重新打开M2。
- 720p设置/车库小字略小，静态检查仍可读；真实可读性保留人工确认。

### 未覆盖范围

全种子/全速/全部车型关卡难度的实际通关、ImpactModel独立物理正确性、动态烟测排除的一个终态帧、全堆长期内存稳定、真实OS关闭消息及断电/强杀日志恢复均未证明。静态截图不代替键盘交互、扬声器听感或全部UI状态。

### 真人待验

[十局标准难度](balance/manual-sessions.md)、剩余HUD/菜单/路面动态观感、轻擦/重撞/维修频率与完整驾驶手感仍未确认。既有用户音乐确认保留，不重复宣布未验或把自动播放当新听测。隔离入口启动只记interactive_unverified，不填充真人样本。不打包、不发布，继续保留用户发布权限。

## 本机交付记录

- 原始日志/CSV/18图的相对路径及SHA256见[最终证据索引](reviews/final-evidence-manifest-20261002.md)。本机tmp保留；Git不替代这批原始文件留存。
- 代码候选9e7cd09已推送并以git ls-remote核对与origin/master一致。最终归档只含本轮Markdown，不夹带用户ADR、生成uid/import或tmp，不机械重跑未变代码。
- 已执行 `./scripts/tests/start_balance_playtest.ps1 -Session 1`，可见游戏子进程PID41016启动成功并响应；霓虹海岸/Pulse GT/标准难度，禁生涯与设置写回。未用桌面控制确认画面，不称已完成交互体验或真人驾驶。
- 按用户既有授权，Gmail自邮阶段提醒已发送成功；内容为技术结果、候选仓库链接、隔离入口和未完验收边界，不含正式存档、私人邮件或无关资料。
