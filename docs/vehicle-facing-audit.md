# 车辆朝向校正

## C版全车型接入（2026-09-09）

用户已确认 driftwing C 版试玩效果，允许扩展同风格。其余五款玩家车已接入 `assets/vehicles/player_<id>_c.png`，原图全部保留；NPC、车辆性能、碰撞判定与燃油数值未改。

五款源图存于 `docs/previews/<id>-c-source.png`，使用内置 imagegen（非 CLI）生成，再按已授权流程本地抠图。每张采用原车型作身份参考、driftwing-c-approved.png 作风格和镜头参考。

生成提示要点：ONE production sprite; strict orthographic plan view; nose UP / rear BOTTOM; only top projections; no vertical grille, bumper or wheel sidewalls; natural 2.2:1 proportions; full symmetric car; detailed mechanical rendering; solid navy RGB(8,18,38); no shadow, road, text, logo or flame. 分车型保留蓝色 GT、黄橙椭圆座舱、红色尖楔、青色巡航车、紫银棱面超跑特征。Comet RS 首版误画蓝色尾灯，追加精确编辑：仅将底部两条灯改为红色，顶部青色头灯及其余几何保持不变。

复现透明处理（当前系统请使用 `C:/ProgramData/miniconda3/python.exe`）：`scripts/tools/prepare_driftwing_c.py docs/previews/<id>-c-source.png assets/vehicles/player_<id>_c.png`。六款均为800×1360 RGBA，以0.1等比显示；不再使用180°翻转和旧1.22纵向拉伸。已逐车检查720p实际转向/超载截图及Aurora X的1080p受损截图，等待本轮人工试玩验收。

回归测试扩展到六款车的零旋转、透明背景、不透明玻璃、统一画布和等比尺寸。修改前测试明确失败于旧180°旋转规则；接入后全量78项通过，退出阶段仍有ObjectDB/资源清理警告。截图留在 `tmp/c-<id>.png`，本地全量日志为 `tmp/c-fleet-tests.log`。代码审查确认改动仅涉及贴图路径、渲染变换和对应测试，无性能参数或存档结构变化。

## C版单车试装记录（已获人工确认）

用户指出仅旋转旧图不能解决透视问题，已批准重新生成顶视图，并选定C机械细节版。内置图像工具两次透明化均返回RGB棋盘格，拒绝接入；用户随后明确批准本地抠图。

本次仅替换driftwing，原图和其余车型保留。获批源图归档为 `docs/previews/driftwing-c-approved.png`，新精灵为 `assets/vehicles/player_driftwing_c.png`。执行 `python scripts/tools/prepare_driftwing_c.py docs/previews/driftwing-c-approved.png assets/vehicles/player_driftwing_c.png` 可复现。抠图采用边界连通深蓝色背景去除，保留封闭深色玻璃；RGBA透明通道已验证，后视镜经目视检查保留。

新图800×1360，以0.1等比显示为80×136，不叠加旧版1.22纵向拉伸；源车头朝上，因此取消driftwing的180度修正。选车预览、游戏本体及残影使用同一新图。实际游戏转向/超载截图已检查，等待单车人工验收后再扩展其他车型。

## 历史方案：仅旋转旧图（已被C版替代）

2026-09-08：人工报告并批准校正前后朝向。

- 游戏前方为屏幕上方（-Y），尾焰和车尾轨迹位于后方（+Y）。
- 逐张检查六款玩家源图：pulse_gt、driftwing、flashpoint、comet_rs、tidebreaker、aurora_x的车头在源图下方。保留原PNG，通过逐车型贴图旋转表修正180°。
- 已检查NPC轿车、厢式车、两厢车、跑车和卡车，保持车头朝上，不改其绘制朝向。
- 玩家贴图及超载残影共享旋转修正；损伤绘制仍使用原物理朝向，避免碰撞位置和烟雾被翻到反侧。
- 选车页围绕图片中心应用同样修正，布局尺寸变化时同步中心点。
- 回归验证源图下方向经校正变为上方向、左右转向车头朝正确侧倾斜，以及NPC不误翻转。
- 使用Godot实际渲染检查driftwing转向、NPC双向并线及超载残影/尾焰。截图为固定场景视觉检查，不是人工驾驶验收。
