# 车辆朝向校正

## C版试装（后续人工批准）

用户指出仅旋转旧图不能解决透视问题，已批准重新生成顶视图，并选定C机械细节版。内置图像工具两次透明化均返回RGB棋盘格，拒绝接入；用户随后明确批准本地抠图。

本次仅替换driftwing，原图和其余车型保留。获批源图归档为 `docs/previews/driftwing-c-approved.png`，新精灵为 `assets/vehicles/player_driftwing_c.png`。执行 `python scripts/tools/prepare_driftwing_c.py docs/previews/driftwing-c-approved.png assets/vehicles/player_driftwing_c.png` 可复现。抠图采用边界连通深蓝色背景去除，保留封闭深色玻璃；RGBA透明通道已验证，后视镜经目视检查保留。

新图800×1360，以0.1等比显示为80×136，不叠加旧版1.22纵向拉伸；源车头朝上，因此取消driftwing的180度修正。选车预览、游戏本体及残影使用同一新图。实际游戏转向/超载截图已检查，等待单车人工验收后再扩展其他车型。

2026-09-08：人工报告并批准校正前后朝向。

- 游戏前方为屏幕上方（-Y），尾焰和车尾轨迹位于后方（+Y）。
- 逐张检查六款玩家源图：pulse_gt、driftwing、flashpoint、comet_rs、tidebreaker、aurora_x的车头在源图下方。保留原PNG，通过逐车型贴图旋转表修正180°。
- 已检查NPC轿车、厢式车、两厢车、跑车和卡车，保持车头朝上，不改其绘制朝向。
- 玩家贴图及超载残影共享旋转修正；损伤绘制仍使用原物理朝向，避免碰撞位置和烟雾被翻到反侧。
- 选车页围绕图片中心应用同样修正，布局尺寸变化时同步中心点。
- 回归验证源图下方向经校正变为上方向、左右转向车头朝正确侧倾斜，以及NPC不误翻转。
- 使用Godot实际渲染检查driftwing转向、NPC双向并线及超载残影/尾焰。截图为固定场景视觉检查，不是人工驾驶验收。
