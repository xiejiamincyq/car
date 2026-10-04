# 自然交通路线验证工具

本工具仅用于开发验证，不是游戏自动驾驶，也不改变交通、碰撞或资源规则。`scripts/tests/` 和 `tests/` 均被发布预设排除。

## 用途与边界

- `ProductNaturalPathAudit.gd`：原搜索入口，四关 × 六车 × 三难度 × 五种子 × 三种纵向轨迹，共1080个固定配置。
- `NaturalAdaptiveRecoveryAudit.gd`：原搜索优先；有限搜索未验证时增加物理受限的回中偏好，保持已验证输入前缀。
- `NaturalIntentRecoveryAudit.gd`：记录已开始预警的NPC原车道和目标车道，仅用于保守规划，不改实际车身或随机数。
- `NaturalFallbackRecoveryAudit.gd`：意图规划未验证时，最多尝试一次实际几何后缀规划。完整物理记录先校验，不能绕过非法记录；已提交的前缀不丢弃。

每例最多四轮候选/实际反馈；每轮包含7200个真实模型步。候选规划成功不计通过，必须将全部方向输入交还真实交通模型，并校验实际位置、方向输入约束和逐步连续无接触几何。恒定完整度和控制器燃油是明确的模型夹具；Main中的补给、失败、实际碰撞及真人反应另行验收。有限固定配置通过不证明所有种子或所有驾驶操作都能通关。

## 本机命令

在仓库目录执行，`$auditEngine`填写已安装的Godot console引擎路径，不是release模板：

```powershell
./scripts/tests/run_tests.ps1 -TestFilter 'test_product_natural*.gd'
& $auditEngine --headless --path . --script res://scripts/tests/NaturalFallbackRecoveryAudit.gd -- --pilot
& $auditEngine --headless --path . --script res://scripts/tests/NaturalFallbackRecoveryAudit.gd -- --case neon_coast/comet_rs/difficulty2/accelerate/seed9001
```

单例、五例pilot及`--shard 0`至`--shard 17`均使用原1080定义。空参数和非法请求退出2，不会误启动长批。正式执行还必须配置外部墙钟看门狗、等待准确原生退出码，并核对`JOINT_PATH_COMPLETE`和`source_stable`；打印一行通过或只看规划输出不够。运行期间冻结加载文件和HEAD。日志与逐例JSON写入唯一`tmp/product-natural-path-*`目录，保留失败，不能以新证据覆盖旧结果。

`test_product_natural_recovery.gd`包含整道封堵、晚段非法速度、伪造/截断前缀、预警前不预约、非法目标车道及备用状态重复切换的回归约束。它是快速行为门，不等于完整1080重跑。

## 历史证据归属

2026-10-04原完整批在1178eea提交终态为1067条实际witness、13条未验证，原批仍记失败。13条分别用经验证的不同测试规划策略补证，并独立复查实际记录；这是相同游戏规则下的固定配置构造性覆盖，不是同一策略的一次全绿批次。

归档版本仅替换已验证临时工具的引用路径，逐文件等价证明见`tmp/natural-recovery-archive-equivalence-20261004.json`。源码归档本身不产生新的1080覆盖结论。具体执行时间、版本、原退出码和哈希见[本轮验证记录](product-validation-20261003.md)。原始大体积记录保留本机，不随玩家包交付，也不声称已全部上传源码仓库。
