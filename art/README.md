# Neon Coast Rush 原创美术来源

- 日期：2026-08-09
- 生成方式：内置图像模型，以 `assets/neon-coast-menu.png` 作为风格参考
- 权属：为本项目全新生成；未使用 Road Fighter 或第三方游戏素材
- 透明处理：`remove_chroma_key.py`，边缘采样、soft matte、despill
- 运行时处理：`scripts/tools/prepare_sprite.py` 等比缩放、透明居中，不改变碰撞盒

## A1.1 立体车辆批次

| 运行时素材 | 原始色键图 | 画布 | 等比可见尺寸 |
|---|---|---:|---:|
| `assets/vehicles/player_car.png` | `art/source/generated/player_car_volume_chroma.png` | 96×112 | 67×96 |
| `assets/vehicles/traffic_sedan.png` | `art/source/generated/traffic_sedan_volume_chroma.png` | 80×112 | 58×90 |
| `assets/vehicles/traffic_van.png` | `art/source/generated/traffic_van_chroma.png` | 80×112 | 56×94 |
| `assets/vehicles/traffic_hatchback.png` | `art/source/generated/traffic_hatchback_chroma.png` | 80×112 | 60×88 |
| `assets/vehicles/traffic_sports.png` | `art/source/generated/traffic_sports_chroma.png` | 80×112 | 60×92 |
| `assets/vehicles/traffic_truck.png` | `art/source/generated/traffic_truck_volume_chroma.png` | 96×176 | 54×156 |
| `assets/pickups/fuel_pickup.png` | `art/source/generated/fuel_pickup_chroma.png` | 64×64 | 48×48 |

具体源图与运行时边界记录在 `art/sprite_manifest.json`，测试会校验源图和运行时长宽比误差小于 0.02。

## 提示词摘要

所有车辆均要求：原创夜间海岸霓虹像素风、单车居中、纯 `#00ff00` 色键背景、无阴影/文字/标识/水印。视角从原先的“严格垂直正交俯视”改为约 70° 的近俯视街机投影，明确呈现前保险杠厚度、侧裙、轮拱、车顶高度，以及车顶到侧面的明暗分离；禁止扁平车顶剪影、压扁比例和极端透视。

车型分别为：青色玩家运动轿跑、紫色慢速三厢轿车、橙蓝慢速厢式车、洋红/青色变道掀背车、橙红快速超跑、深蓝长途货车。交通类型继续叠加 `I`、`>`、`X`、`=` 非颜色标记，保证可访问性不依赖颜色。
