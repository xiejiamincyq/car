# Original art batch A1

- Date: 2026-08-09
- Generation path: built-in image generation tool with `assets/neon-coast-menu.png` as a style reference
- Ownership/source: newly generated for Neon Coast Rush; no third-party or Road Fighter assets used
- Chroma removal: Codex imagegen skill `remove_chroma_key.py`, border sampling, soft matte, despill
- Runtime sizing: cropped from the alpha subject bounds and placed on the frozen canvases from `docs/art-requirements.md`

## Assets

| Runtime asset | Chroma source | Canvas | Visible body |
|---|---|---:|---:|
| `assets/vehicles/player_car.png` | `art/source/generated/player_car_chroma.png` | 96×112 | 58×80 |
| `assets/vehicles/traffic_sedan.png` | `art/source/generated/traffic_sedan_chroma.png` | 80×112 | 50×84 |
| `assets/vehicles/traffic_truck.png` | `art/source/generated/traffic_truck_chroma.png` | 96×176 | 62×148 |
| `assets/pickups/fuel_pickup.png` | `art/source/generated/fuel_pickup_chroma.png` | 64×64 | 48×48 |

## Prompt summary

Each asset requested one isolated, original, perfectly top-down pixel-art subject matching the existing nocturnal cyan/hot-pink coastal style, centered on a uniform `#00ff00` chroma background with no shadow, scenery, text, logo, watermark, or copyrighted game design. Vehicle prompts separately specified a cyan player sports car, violet ordinary sedan and long navy cargo truck; the pickup prompt specified a yellow/cyan diamond fuel icon with a geometric plus mark.

Traffic type semantics remain code-rendered as `I`, `>`, `X` and `=` markers, so accessibility does not depend on generated colors.
