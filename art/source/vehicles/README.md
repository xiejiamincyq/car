# 0.4.0 玩家车辆精灵生成记录

六辆车使用 Codex 内置图像模型生成；`*_chroma.png` 是最终源图，运行时 PNG 使用
`remove_chroma_key.py` 去背后，再由 `scripts/tools/prepare_sprite.py` 等比缩放到 `96×112` 画布。

共同提示约束：近俯视 78°、车头向上、居中对称、完整四轮、立体车身高光、纯 `#00ff00`
色键背景、无阴影/文字/标志/道路，禁止几何拉伸。各车差异提示如下：

- Pulse GT：电蓝/青色/洋红，均衡宽体 GT，最终可见比例约 0.77。
- Driftwing：珍珠白/紫色/青色，短轴距灵巧楔形车。
- Flashpoint：太阳黄/橙色/白色，前置水滴座舱与宽后肩冲刺车。
- Comet RS：红色/碳黑/冰蓝，细长箭形极速原型车。
- Tidebreaker：海蓝绿/象牙白/琥珀，宽体稳健旅行车。
- Aurora X：银色/深紫/电青，分裂车鼻与悬浮翼子板实验车。

所有最终运行时图均记录于 `art/sprite_manifest.json`；清单中的 `uniform_scale` 证明缩放保持纵横比。
