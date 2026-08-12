# Continuous environment sequence sources

These four master images were generated with the built-in image generation model as continuous, top-down racing environments. They are source art only and are excluded from the Windows export by `export_presets.cfg`.

Prompt briefs:

- `neon_coast_master.png`: a single uninterrupted night-time tropical neon coast, dense jungle on the left and rocky ocean shoreline on the right, orthographic top-down game art, with no vehicles, text, UI, or perspective horizon.
- `freight_harbor_master.png`: a single uninterrupted night cargo harbor, containers, cranes, wet concrete, industrial lighting and dock details, orthographic top-down game art, with no vehicles, text, UI, or perspective horizon.
- `storm_ridge_master.png`: a single uninterrupted stormy mountain ridge, wet rock, waterfalls, drainage structures and sparse vegetation, orthographic top-down game art, with no vehicles, text, UI, or perspective horizon.
- `sunrise_express_master.png`: a single uninterrupted warm sunrise urban expressway, rooftops, landscaped terraces and modern city infrastructure, orthographic top-down game art, with no vehicles, text, UI, or perspective horizon.

Run `scripts/art/build_environment_sequences.ps1` from the repository root to rebuild the 40 runtime panels. The script preserves aspect ratio, extracts five ordered panels for each side of every track, and deliberately shares one exact pixel row at each adjacent boundary. Cars progress from panel `00` through panel `04`; panels never loop or repeat during a race.
