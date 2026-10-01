# 连续收尾技术验证记录

日期：2026-10-02。路线：[M1–M4](../tasks/plan-continuous-completion.md)。监督：[网页6Pro](https://chatgpt.com/c/6abeba46-7a48-83ea-8fb9-60cb28c3c397)。这是技术证据，不是人工试玩或发布验收。

## 基线与数据边界

- 开始提交：8f69d86（代码最近提交7fa5981）；Godot实测 `4.7.stable.official.5b4e0cb0f`。
- 原有ADR-001未提交变化、CLAUDE.md、生成的uid/import与其他临时文件不纳入本轮提交。
- 正式 `user://save.cfg` 在本机独立临时目录备份并核对哈希一致；不上传其内容。六项M1专项测试前后SHA256均为 `D91F4FC7E54E2ABFE9FC3131C0DAF5B5B14147D875EAE827958B2C58B8243288`。
- 测试使用合成隔离SaveStore；进程仍会写自己的测试/引擎日志，不声称操作系统级零写入。强杀/断电不能保证保存最后一局日志。

## M1：同帧终态修复与隔离验证

**根因**：可选试玩记录器逐帧观察Main；结算后的重开/返回可以在下一次观察前清空旧RunState，使clear/failed降级为aborted。

**红→绿**：`test_playtest_isolation.gd` 的clear/failed × replay/title四个同帧变体原均失败、退出1；最小修复后退出0。原始日志：`tmp/playtest-isolation-red.log`、`tmp/playtest-isolation-green.log`。

**修复**：Main在 `_reset_run` 清状态前发出通用 `run_resetting`；试玩记录器订阅后同步snapshot→observe→finish。正式游戏没有该记录器，未引入测试脚本依赖。`_finished` 保证结束一次，新局观察重新开启。

**验证**：六项 `test_playtest_isolation`、`test_playtest_recorder`、`test_playtest_recording_flow`、`test_save_store`、`test_persistence_integration`、`test_audio_settings_ui` 均退出0，无脚本/断言失败；日志 `tmp/M1-<test>.log`。命令为 `Godot --headless --path . --quit-after 60 --script res://tests/<test>.gd`。首轮依然使用旧运行器参数，最终候选需再次完整回归。

隔离测试有启用持久化确实能写的正控；禁写后真实设置、结算、重开、返回、退出不改变合成哨兵哈希和回读内容，无残留.tmp/.bak；日志路径不可写时仍可重开驾驶。`PLAYTEST_ISOLATION checks complete; failures=0`。不可写路径警告是预期负例，退出音频警告不是预期通过项。

独立审查未发现阻断：构造阶段无记录器监听、旧局先保存、新局重置状态无重复。限制：写盘失败后本进程停止记录，不宣称自动恢复；不覆盖磁盘写满或JSONL半行恢复。

**补齐证据**：修复已提交并备份为 `db9d0a0`，运行时差异严格Main +3行、Recorder +10行。六项专项随后用新墙钟运行器 `run_tests.ps1 -TestFilter <test>.gd` 重跑，均有 `TEST_COMPLETE <test>.gd` 和 `ALL 1 TESTS PASSED`，退出0；日志 `tmp/m1-<test>.log`。新增初始化重复reset不产档、连续两次同帧重开只记录三个实际开始的倒计时尝试；已观察终态后reset不重复由既有flow覆盖。四竞态均打印 `M1_TERMINAL_CASE ... status=pass`。

原四红日志SHA256：`E3B1344820F94A8CC5CF30F55282953BD438C7CB24D2F062E5EB2841783F6C3D`；新isolation绿日志SHA256：`5D4ACF557D8766467ED507BAAD94F062CE646C7761C71553C24D0883A67A4CA9`。哈希只标识该次历史证据，不代表重跑后日志字节不变。

## 测试运行器的假绿修复

`--quit-after 60` 实为引擎主循环次数；音频负控延长到1秒时旧参数返回0却未打印末尾标记，无帧退出限制才真正完成。证据 `tmp/teardown-old-runner-long.log` 与 `tmp/teardown-wallclock-long.log`。这证明运行器存在提前成功风险，不表示历史所有测试均被截断。

现改为每项120秒墙钟看门狗：只结束自己启动的子进程，超时计失败；八项关键异步/存档/拾取测试必须有准确末尾标记。独立审查无阻断。手工验收fixture `tests/runner_watchdog_probe.gd` 在1秒上限被判失败、10秒上限到达 `WATCHDOG_PROBE_COMPLETE` 并通过；缺末尾标记的负控也确实失败。该fixture不匹配默认test_*.gd，不加入常规测试数量。

## M2：测试专用音频收尾

网页批准仅先改测试，不改正式游戏退出：新增 `tests/support/audio_teardown.gd`，停止前捕获播放实例弱引用，停止后条件等待实际回收（默认2秒上限），附静音退休探针；超时不能判通过，原日志不屏蔽。专门负控保留强引用必超时，解除后才通过。两项旧音频测试保留原断言，仅替换收尾。

当前/最后一次播放实例的弱引用不能证明全部历史实例已消失；除条件检查外还看退出完整日志。WASAPI即退与条件排空对照、正常循环稳定性及正式退出代码路径继续补证，非阻断遗留必须经网页明确接受。

## M3：实际自然拾取烟测

`tests/test_dynamic_pickup_smoke.gd` 沿用十组标准难度配置，每组最多60秒；起始完整度60%，约70%车型极速，正常油门/刹车/有界转向与短视危险否决。完整Main._process生成交通、施工和物品；没有强制生成、补注燃油、瞬移或关闭碰撞。

独立重跑命令：`Godot --headless --path . --quit-after 60 --script res://tests/test_dynamic_pickup_smoke.gd`，退出0；`tmp/M3-test_dynamic_pickup_smoke.log`关键输出：

```text
DYNAMIC_PICKUP_TOTAL samples=10 {"coins":934,"collision_frames":16,"construction_frames":6572,"fuel":29,"oracle_frames":35933,"repair":22,"traffic_frames":35383} failures=0
```

10/10均实际接触拾得自然生成的三类物品，并经历交通/施工。接触几何oracle独立核对删除、回收、奖励一次性；16碰撞帧仅跳过燃油/维修数值oracle，1完赛终态帧未进入检查。

**审查限制**：NPC重叠/三车墙使用正式安全检测器，不能独立证明检测器无错；油耗计算复用fuel_load，只验证组合接线，不独立证明油耗公式；策略读取NPC目标车道，不模拟人类视野。不能推出人类胜率、所有种子、高速/超载或全部72组合拾取成功。

**按监督意见补齐碰撞帧**：测试专用透明子类只在Run.tick、Integrity.apply_damage/repair入口记参数并调用super；从帧前油量/完整度正向重放阻力、赛段/拾取奖励与有序损伤/维修封顶账本，不根据最终值反推。数值oracle扩大到35,949帧，包含全部16碰撞帧/16损伤事件；逐组轨迹、油量、完整度和拾取数量与原样本相同。新运行器退出0，末尾 `TEST_COMPLETE test_dynamic_pickup_smoke.gd`，日志 `tmp/dynamic-pickup-ledger.log`。燃油oracle不再直接调用fuel_load，仍复用获批常量；不独立重算ImpactModel的接触法向/能量，1个完赛终态帧仍未覆盖。

附加专项：content_catalog、tour_traffic_matrix（216配置交通样本）、traffic_all_speed_safety、coin_dynamic_fairness、menu_flow、main_run_loop、rating_persistence均退出0，日志 `tmp/M3-<test>.log`。曾尝试的 `test_tour_ui_flow` 文件不存在，没有执行，不能算通过；完整选择流程以现有ui_flow/menu_flow全量回归为准。

`BalanceAudit.gd -- res://tmp/balance-M3-20261002` 重跑退出0：432燃油/维修模型、1728路线尝试、0保守跟随标记。拒绝生成仍不算成功；补给注入模型不算实战拾取。原始CSV保留在该临时目录，和动态烟测严格分开。

## 待关闭

- M2：退出播放对象延迟回收已复现；正常Dummy与WASAPI退出、条件排空、同进程循环证据整理中，等待网页裁决，不屏蔽日志。
- M4：最终同提交全回归、渲染、备份与网页复核尚未完成。
- 十局真人与剩余主观体验仍未确认；不打包、不发布。
