# 0.4.0 track environment sources

The three `*_source.png` files were generated with the built-in image model as
original, near-top-down roadside concept sheets. Runtime strips are derived with:

```powershell
python scripts/tools/prepare_track_sheet.py --source art/source/tracks/<track>_source.png --output-dir assets/tracks --track-id <track>
```

The tool crops the outer scenery thirds, normalizes each side to 256×512, then
appends a vertical mirror to form a deterministic 256×1024 seamless loop. Source
art remains outside exported builds through `art/source/.gdignore`.

Prompt themes:

- `freight_harbor`: night cargo port, containers, cranes, wet asphalt, teal/amber lights.
- `storm_ridge`: rain-soaked slate mountain pass, pines, drainage and cold lamps.
- `sunrise_express`: elevated coastal city expressway, rooftops, gardens and golden dawn.

All prompts prohibited vehicles, people, brands, text, UI and copied franchise imagery.
