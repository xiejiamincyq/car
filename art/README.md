# Neon Coast Rush 原创美术来源

- 日期：2026-08-10
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

## A2 海岸环境批次

| 运行时素材 | 原始图 | 画布 | 用途 |
|---|---|---:|---|
| `assets/environment/coast_left.png` | `art/source/generated/coast_left_source.png` | 256×1024 | 岩岸、植被与霓虹路灯 |
| `assets/environment/coast_right.png` | `art/source/generated/coast_right_source.png` | 256×1024 | 海浪、礁石与防护栏 |

环境提示词要求原创严格俯视夜间海岸像素场景、纵向滚动、无道路/车辆/人物/文字/标识。运行时通过 `scripts/tools/prepare_environment_strip.py` 截取 1:2 纵向条带，并将下半段设为上半段的垂直镜像，使 1024 像素纹理首尾精确衔接。原始高分辨率图受 `art/source/.gdignore` 与导出排除规则保护，不进入 Windows 包。

## A3 HUD 与事件反馈批次

| 运行时素材 | 原始色键图 | 画布 | 用途 |
|---|---|---:|---|
| `assets/ui/hud_frame.png` | `art/source/generated/hud_frame_chroma.png` | 512×224 | 左上仪表舱外框 |
| `assets/ui/event_plate.png` | `art/source/generated/event_plate_chroma.png` | 640×96 | 检查点、预警与封路事件铭牌 |
| `assets/ui/road_barrier.png` | `art/source/generated/road_barrier_chroma.png` | 240×80 | 已封闭车道的实体路障 |
| `assets/ui/result_emblem.png` | `art/source/generated/result_emblem_chroma.png` | 160×160 | 结算完成徽章 |

提示词均要求原创 16-bit 海岸霓虹像素风、纯 `#00ff00` 色键背景、无文字/数字/标识/水印。HUD 外框、事件板保留动态信息安全区；路障采用俯视重型横栏、琥珀/浅青警示条与双警示灯；结算徽章由奖杯、速度翼和方格旗组成。HUD 外框、路障与徽章使用等比缩放；事件板属于弹性 UI 装饰，通过 `scripts/tools/prepare_ui_asset.py` 适配固定运行时画布，不参与车辆或碰撞几何。
