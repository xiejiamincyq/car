# R5被动采样器切片1本地复核

依据tasks/plan-runtime-performance-evidence.md；本地自行审查，不声称另一个模型/网页已复核。

正确性：先缺失实现红测失败1，再实现默认关闭、白名单、单调时钟限流/状态补样及生命周期；中途IO错误的文件边界夹具红测实际失败2，再抽出最小存储边界后准确通过。第一次故障夹具引用尚不存在的super方法导致解析失败，原日志保留，不称有效行为红例。最终专项`tmp/performance-capture-terminal-20261004.log`原生0、failures=0和TEST_COMPLETE齐全。不可写目录夹具产生一条预期引擎ERROR，未过滤，不称零告警；磁盘实际耗尽等系统级故障未实施。

输出独立读取：最终本体fixture 7行JSONL（开始、5样本、结束），结束时间不早于末样本，schema/会话/PID一致，额外private_payload没有泄露；真实debug引擎监测输出非零节点/对象/资源。测试中模拟release能力表仅验证不可用项为null，**还不是release EXE验证**。

其余四轴：RefCounted单一职责，无节点、网络、依赖或随机调用；调用方字典不修改，固定字段而非整个数据快照；文件按PID/单调时刻唯一命名并拒绝已存在路径，默认关闭不创建目录；每秒刷新及状态切换日志的IO开销须在接入后实际包测量，不提前称无性能影响。通用磁盘接口仅作测试边界，不引入异步日志框架。正常Main尚无引用，导出闭包专项仍为127资源/失败0/准确完成标记；旧RC1未重建、不混用本体fixture与玩家驾驶证据。

范围：新增采样器、本体测试、runner完成标记和相关记录；Main/交通/油耗/完整度/输入/存档/音画及用户ADR不修改。当前用例总数145，**未声称新145项全量通过**；Main接入与新候选需要后续集成、完整回归和release验证。R5/R6继续开放。

## 切片2：正常入口与候选身份（上述切片1是历史）

已在Main末尾_ready精确检查current_scene及NEON_COAST_PERF_CAPTURE=1，默认不实例化采样器；帧入口取样覆盖全部早返回，_exit_tree关闭。Window.size/has_focus采用匹配的[Godot 4.7 Window接口](https://docs.godotengine.org/en/4.7/classes/class_window.html)，没有读取键盘或操作窗口。采样字典白名单新增可见界面和重置计数，只有启用状态读取监测/写文件。

新集成测试先因缺少Main入口在四子模式均准确失败；接入后通过。随后明确_ reset并非开局的语义红例在启用子进程准确失败4（reset、restart、return及账本各项），修为开局/重开计run_number，返回/其他重置只增reset_number，通过。全程保留红例，不放宽测试。最终`tmp/performance-integrated-20261004.log`原生0/ALL 2/两末尾标记，SHA `11AF0CCE5EADA4C47969BF2F083FBC5EE534D6653DC822D885023D3A9DA6DEA0`；不可写目录ERROR仍为本体预期故障注入，不隐去。

四种开关用独立新子APPDATA，启动前同时核验OS.user_data_dir和user://落在精确owned tmp目录；父APPDATA/开关立即恢复。默认及非精确值无文件，非current_scene附属Main不能重复采集；启用样本覆盖六阶段、窗口字段、独立开局/重置、退出终态，采样前后保存数据/玩法/两随机源/输入快照相同，未产生save.cfg。独立读出合成debug样本节点181、对象2111～2130、资源76～78；不是release表现、不证明没有泄漏或20局通过。

导出门先失败1，明确Missing selection新采样脚本，精确白名单补一项后128项通过；禁止目录规则不变。元数据与玩家说明为rc.2/0.4.0.2，隐藏版本标签仍隐藏，正常主场景及应用名不变。菜单、存档隔离、前进键和版本专项准确通过；README首次补丁上下文不匹配而未写入，按实际完整行重做，无部分覆盖。原RC1 EXE/PCK/ZIP不更改，用户ADR不暂存。待同提交146全量及实际release验证；新的运行期计数开销/完整比赛/四关长期性能仍未验。
