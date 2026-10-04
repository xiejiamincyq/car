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
