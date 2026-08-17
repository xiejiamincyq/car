# Continuous environment sequence sources

The canonical source art lives in the four `*_sections` directories. Each route has five independent 1024×1536, strict top-down sections generated with the built-in image generation model. Runtime panels are downsampled to 256×1024; they are never enlarged from one short master image. Source art is excluded from the Windows export by `export_presets.cfg`.

Prompt briefs:

- `neon_coast_sections`: five uninterrupted night-time tropical neon coast sections with seawalls, palms, maintenance paths, rocks and ocean.
- `freight_harbor_sections`: five night cargo-harbor sections with containers, cranes, warehouses, pipes and wet concrete.
- `storm_ridge_sections`: five stormy mountain sections with wet rock, drainage, retaining structures, sparse vegetation and waterfalls.
- `sunrise_express_sections`: five sunrise urban sections with rooftops, terraces, HVAC, solar panels and landscaping.

The four older `*_master.png` files are retained only as historical references. The build script intentionally has no fallback that can upscale them into runtime art.

Run `scripts/art/build_environment_sequences.ps1` from the repository root to rebuild the 40 runtime panels. It crops both road edges at native width, downsamples each section once, blends 96 rows symmetrically at adjacent boundaries, and shares one exact pixel row at every join. Cars progress from panel `00` through panel `04`; panels never loop or repeat during a race.
