# 左侧展示图生成记录

内置 imagegen 模式，2026-10-12。用户确认六张 `*_chroma.png` 原始源图作为概念参考，允许合理补全未展示的侧面。
每次调用都实际传入对应原始源图；后五张另外传入Pulse GT生成图，仅作为视角/构图/渲染参考，明确禁止复制蓝车配色和车身设计。原图、比赛贴图和右侧卡片不改。

## pulse_gt

原始参考：`art/source/vehicles/pulse_gt_chroma.png`；输出：`assets/vehicle_showcases/pulse_gt_northwest_v1.png`。

完整提示：

```
Use case: stylized-concept. Asset: transparent full-car showcase portrait for a racing game's LEFT preview frame, not a racing sprite. Input image 1 is the ORIGINAL concept/source design of Pulse GT and is mandatory identity reference; the front/nose in this top-down source is at the BOTTOM (magenta headlamps), the top is the rear. Preserve this exact electric-blue widebody GT, cyan edge lighting, magenta headlamp shape, hood vents, dark glass canopy, wheel/fender profiles and body proportions. Convert to a car-show exhibition view, not a new car design. Geographic frame: car heading straight north; camera situated north-northwest, 30 degrees WEST of its forward/north axis, looking at it from LEFT FRONT, camera level at the middle height of the car body. Zero bird's-eye elevation, zero camera roll; show recognizable FRONT plus LEFT SIDE, wheel circles viewed side-on, not a top-down view or rear view. Infer only previously occluded side panels consistently. Keep the original polished, crisp stylized 3D rendering and materials; no change of colors, branding or car class. Single car, complete four-wheel vehicle fully within a square canvas, centered, 10% clear margin, consistent catalog scale. Real transparent alpha background, no green backdrop, no floor/platform/scenery, no text, no watermarks, no diagrams or other cars.
```

## driftwing

原始参考：`art/source/vehicles/driftwing_chroma.png`；输出：`assets/vehicle_showcases/driftwing_northwest_v1.png`。

完整提示：

```
Use case: stylized-concept. Asset: transparent full-car showcase portrait for a game's LEFT large preview frame (not gameplay sprite). INPUT 1 is the mandatory ORIGINAL concept design for driftwing; preserve THIS CAR's exact silhouette, body structure, cockpit, hood, lamp contours, wheels/fenders, color/material details (pearl-white/purple compact agile wedge, cyan lights, purple roof accents and pointed angular front). The source is top-down with FRONT AT THE BOTTOM. INPUT 2 is ONLY the matching camera/framing/render-quality reference, a blue car already generated for this set; do NOT copy its blue paint, proportions or panels to this car. New car-show view: car heading geographic north, camera 30 degrees WEST of the car's forward/north direction, positioned at LEFT FRONT at car-body middle height, level camera (no overhead/bird-eye view, no roll). Show FRONT and LEFT FLANK, proper upright wheel shapes, low grounded road-car volume. Match input2's camera angle, complete-object framing and catalog scale so the six images are consistent. Infer only previously unseen side details compatibly. Crisp polished stylized 3D render faithful to input1, not photoreal branding and not a generic replacement vehicle. Single car fully visible, square canvas with clear margins, actual transparent alpha, no green backdrop, no showroom floor/platform, no text, no watermark, no other cars.
```

## flashpoint

原始参考：`art/source/vehicles/flashpoint_chroma.png`；输出：`assets/vehicle_showcases/flashpoint_northwest_v1.png`。

完整提示：

```
Use case: stylized-concept. Asset: transparent full-car showcase portrait for a game's LEFT large preview frame (not gameplay sprite). INPUT 1 is the mandatory ORIGINAL concept design for flashpoint; preserve THIS CAR's exact silhouette, body structure, cockpit, hood, lamp contours, wheels/fenders, color/material details (solar-yellow/orange sprinter, white accents, black teardrop forward cockpit, large rear shoulders). The source is top-down with FRONT AT THE BOTTOM. INPUT 2 is ONLY the matching camera/framing/render-quality reference, a blue car already generated for this set; do NOT copy its blue paint, proportions or panels to this car. New car-show view: car heading geographic north, camera 30 degrees WEST of the car's forward/north direction, positioned at LEFT FRONT at car-body middle height, level camera (no overhead/bird-eye view, no roll). Show FRONT and LEFT FLANK, proper upright wheel shapes, low grounded road-car volume. Match input2's camera angle, complete-object framing and catalog scale so the six images are consistent. Infer only previously unseen side details compatibly. Crisp polished stylized 3D render faithful to input1, not photoreal branding and not a generic replacement vehicle. Single car fully visible, square canvas with clear margins, actual transparent alpha, no green backdrop, no showroom floor/platform, no text, no watermark, no other cars.
```

## comet_rs

原始参考：`art/source/vehicles/comet_rs_chroma.png`；输出：`assets/vehicle_showcases/comet_rs_northwest_v1.png`。

完整提示：

```
Use case: stylized-concept. Asset: transparent full-car showcase portrait for a game's LEFT large preview frame (not gameplay sprite). INPUT 1 is the mandatory ORIGINAL concept design for comet_rs; preserve THIS CAR's exact silhouette, body structure, cockpit, hood, lamp contours, wheels/fenders, color/material details (red and carbon-black narrow long arrow-shaped speed prototype, ice-blue lights, long needle nose and central narrow canopy). The source is top-down with FRONT AT THE BOTTOM. INPUT 2 is ONLY the matching camera/framing/render-quality reference, a blue car already generated for this set; do NOT copy its blue paint, proportions or panels to this car. New car-show view: car heading geographic north, camera 30 degrees WEST of the car's forward/north direction, positioned at LEFT FRONT at car-body middle height, level camera (no overhead/bird-eye view, no roll). Show FRONT and LEFT FLANK, proper upright wheel shapes, low grounded road-car volume. Match input2's camera angle, complete-object framing and catalog scale so the six images are consistent. Infer only previously unseen side details compatibly. Crisp polished stylized 3D render faithful to input1, not photoreal branding and not a generic replacement vehicle. Single car fully visible, square canvas with clear margins, actual transparent alpha, no green backdrop, no showroom floor/platform, no text, no watermark, no other cars.
```

## tidebreaker

原始参考：`art/source/vehicles/tidebreaker_chroma.png`；输出：`assets/vehicle_showcases/tidebreaker_northwest_v1.png`。

完整提示：

```
Use case: stylized-concept. Asset: transparent full-car showcase portrait for a game's LEFT large preview frame (not gameplay sprite). INPUT 1 is the mandatory ORIGINAL concept design for tidebreaker; preserve THIS CAR's exact silhouette, body structure, cockpit, hood, lamp contours, wheels/fenders, color/material details (ocean-teal and ivory broad stable touring body, amber headlamps, wide wheel arches and sturdy side skirts). The source is top-down with FRONT AT THE BOTTOM. INPUT 2 is ONLY the matching camera/framing/render-quality reference, a blue car already generated for this set; do NOT copy its blue paint, proportions or panels to this car. New car-show view: car heading geographic north, camera 30 degrees WEST of the car's forward/north direction, positioned at LEFT FRONT at car-body middle height, level camera (no overhead/bird-eye view, no roll). Show FRONT and LEFT FLANK, proper upright wheel shapes, low grounded road-car volume. Match input2's camera angle, complete-object framing and catalog scale so the six images are consistent. Infer only previously unseen side details compatibly. Crisp polished stylized 3D render faithful to input1, not photoreal branding and not a generic replacement vehicle. Single car fully visible, square canvas with clear margins, actual transparent alpha, no green backdrop, no showroom floor/platform, no text, no watermark, no other cars.
```

## aurora_x

原始参考：`art/source/vehicles/aurora_x_chroma.png`；输出：`assets/vehicle_showcases/aurora_x_northwest_v1.png`。

完整提示：

```
Use case: stylized-concept. Asset: transparent full-car showcase portrait for a game's LEFT large preview frame (not gameplay sprite). INPUT 1 is the mandatory ORIGINAL concept design for aurora_x; preserve THIS CAR's exact silhouette, body structure, cockpit, hood, lamp contours, wheels/fenders, color/material details (silver/deep-purple experimental racer with electric-cyan trim, split nose and separated sculptural fenders around four wheels). The source is top-down with FRONT AT THE BOTTOM. INPUT 2 is ONLY the matching camera/framing/render-quality reference, a blue car already generated for this set; do NOT copy its blue paint, proportions or panels to this car. New car-show view: car heading geographic north, camera 30 degrees WEST of the car's forward/north direction, positioned at LEFT FRONT at car-body middle height, level camera (no overhead/bird-eye view, no roll). Show FRONT and LEFT FLANK, proper upright wheel shapes, low grounded road-car volume. Match input2's camera angle, complete-object framing and catalog scale so the six images are consistent. Infer only previously unseen side details compatibly. Crisp polished stylized 3D render faithful to input1, not photoreal branding and not a generic replacement vehicle. Single car fully visible, square canvas with clear margins, actual transparent alpha, no green backdrop, no showroom floor/platform, no text, no watermark, no other cars.
```
