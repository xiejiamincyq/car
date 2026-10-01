# M2 音频退出补证据（2026-10-02）

范围：Godot 4.7，显式 `--headless --audio-driver WASAPI --verbose`；每份日志记录并验证实际 WASAPI。Master 静音，不作物理听感结论。不修改 runtime；4 个获准 test-only 文件除外。

## 1. 同驱动五组退出对照

| 场景 | 立即退出 5 次泄漏对象数 | 条件排空 5 次泄漏对象数 | 条件等待 ms |
|---|---|---|---|
| 单 AudioStreamPlayer | 2,2,2,2,2 | 0,0,0,0,0 | 14,21,14,20,14 |
| 隔离 MainScene | 6,6,0,6,0 | 0,0,0,0,0 | 21,14,13,14,13 |

单播放器每次为 AudioStreamWAV 和 AudioStreamPlaybackWAV 各 1。Main 的每次 6 对象为 WAV、PlaybackWAV、OggVorbis、PlaybackOggVorbis、OggPacketSequence、OggPacketSequencePlayback 各 1，伴随 2 个 OGG 资源仍在用。退出警告有时序竞争，不是每次出现。

探针 `tmp/exit_audio_probe.gd`、`tmp/exit_main_probe.gd`、`tmp/exit_main_no_save.gd`。

日志：`tmp/exit-single-wasapi-{immediate,condition}-{0,1,2,3,4}.log`；`tmp/exit-main-wasapi-{quit,condition}-{0,1,2,3,4}.log`。

## 2. 暖机后自然生命周期，无逐轮人工清理

探针 `tmp/audio_natural_lifecycle_stability.gd`：3 轮暖机 + 20 轮正式采样。同一 Main/AudioDirector，每轮开赛、暂停、恢复、重开、完赛、返回标题；仅真实方法按原逻辑停止对应声音。返回标题固定驻留 0.30 秒后取同状态样本；循环内禁止新增 helper、shutdown、额外 stop/free。最后进程退出前才用条件 helper。

- `tmp/audio-natural-wasapi-20cycles.log`：第 1 轮暖机一项暂存播放引用，第 2、3 轮归零；20 个正式样本 live 均 0。
- 为进一步记录残留所属通道增加诊断字段后，`tmp/audio-natural-wasapi-20cycles-labeled.log`：3 轮暖机及 20 个正式样本均 live=0，未再复现暖机暂存，故不声称已确证原暂存项的具体通道。
- 两次正式样本 AudioStreamPlayer 节点恒定 12、SceneTree 节点恒定 180；累计观察 277 个唯一 Playback 实例，无观察到的跨轮持续积累。
- 日志有 `NATURAL_AUDIO_3_WARMUP_20_SAMPLES_COMPLETE`，退出 0、无 warning/error。
- 限制：按关键阶段捕获的 WeakRef，不是所有引擎对象普查；未采集总堆、长期性能或真人操作。

## 3. 正式连接的退出按钮与窗口关闭路径

`tmp/exit_path_probe.gd` / `tmp/exit_main_isolated_save.gd` 使用真实 MainScene 和真实 SaveStore，仅将文件路径固定到独立 `res://tmp/exit-path-save-<mode>-<pid>.cfg`；持久化启用，但完全不读写正式用户存档。每个 fixture 不覆盖已有文件。

- 按钮：标题界面正式 QuitButton 的 `pressed` 信号，其真实连接为 SceneTree.quit；3 次退出码 0、完整 FINALIZED 标记，无超时或崩溃；总进程耗时 1031/919/921ms（含启动）。
- 窗口：比赛中向 root 发 NOTIFICATION_WM_CLOSE_REQUEST，再发 close_requested，匹配 Window 原生事件回调先通知后信号的路径；SceneTree 默认 auto_accept_quit 接收关闭。3 次退出码 0、完整 FINALIZED 标记，无超时或崩溃；总进程耗时 899/919/904ms。
- 六份 fixture 退出前后 SHA-256 相同；进程退出后独立 PowerShell Get-FileHash 再核对也全部相同。
- 窗口第 2 次仍有 8 个纯音频对象 + 2 资源退出警告，其余两次和 3 次按钮无警告。不能把这批测试表述为已修复游戏退出清理。
- 这是信号/通知代码级模拟，不是鼠标点击、真实 OS 消息投递或真人窗口交互。

日志：`tmp/exit-path-button-{1,2,3}.log`、`tmp/exit-path-window-{1,2,3}.log`；额外初验 `tmp/exit-path-button-0.log` 不计入三次正式样本。

## 复现命令形式

`Godot_v4.7-stable_win64_console.exe --headless --audio-driver WASAPI --verbose --path . --script tmp/exit_audio_probe.gd -- immediate`

将参数改为 condition 获得单播放器条件对照；Main 用 exit_main_probe.gd 的 quit/condition；自然循环用 audio_natural_lifecycle_stability.gd；退出路径用 exit_path_probe.gd 的 button/window。不要加 --quit-after 帧数限制。

## test-only 修复与 runner 证据

获准的四文件：tests/support/audio_teardown.gd、tests/test_audio_teardown.gd、tests/test_audio_director.gd、tests/test_audio_bus_layout.gd。后两者只改收尾；helper不屏蔽诊断、不更改游戏音频行为。

`test_audio_teardown.gd -- --long-timeout-probe` 在旧 --quit-after 60 下 code0 但缺完成标记（tmp/teardown-old-runner-long.log）；无帧数退出限制下确实完成（tmp/teardown-wallclock-long.log）。当前测试末尾包含 `TEST_COMPLETE test_audio_teardown.gd`，可用于 runner 强校验。

状态：网页6Pro完整回复已接受为“本机指定Godot构建／WASAPI下，正式退出偶发音频对象回收时序告警”，M2以非阻断遗留关闭。不要求为消警告改正式退出、加固定延迟或升级引擎；若运行期持续积累、挂死、崩溃、数据影响或非音频残留出现则重开此项。监督者基于提交的证据审查，没有亲自运行本机。

证据代码候选86285b4；随后321f50f只移除结算种子显示，音频运行时代码未改变。诊断脚本及原始日志保留在本机tmp，不包含正式用户存档；Git备份的是此报告与正式回归测试，不含私有存档备份。

## 最终候选告警归类

9e7cd09全95项通过后，将其中22项告警测试原样headless+verbose复跑（无帧数退出，每项20秒墙钟watchdog），22/22退出0，无脚本失败或超时。16项复现，6项本轮未复现；105个实例均属上述六种音频类别，16条资源仅AudioStreamOggVorbis/OggPacketSequence，未发现非音频残留。未复现不算已修复，M2接受范围不变。逐项CSV和完整原始日志保存在本机 `tmp/final-warning-audit-9e7cd09/`。
