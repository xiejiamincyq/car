# Original music sources

`generate_neon_coast.py` deterministically synthesizes **Neon Coast Circuit** from the note, rhythm, oscillator, envelope, and mix data in the script. It uses no samples and no copied melody.

Regenerate from the repository root:

```powershell
python art/source/music/generate_neon_coast.py
```

The generated OGG is the runtime asset. The JSON build report records encoded duration, loop-boundary discontinuity, EBU R128 integrated loudness, true peak, file size, seed, and SHA-256 for reproducibility. The game applies a further `-4 dB` catalog gain so warning and collision cues remain legible.

## Approved course themes

The Freight Harbor, Storm Ridge, and Sunrise Express audition themes were approved by the user on 2026-10-01. `generate_course_music.py` expands the same notes, voices, and rhythm into 32/40/32-bar loops, with a sparse bridge and octave responses. It imports `generate_track_previews.py` and the Neon Coast synthesis primitives; retain all three scripts to reproduce them. No external samples are used.

```powershell
& C:/ProgramData/miniconda3/python.exe art/source/music/generate_course_music.py
```

Each course has its own `assets/music/<id>.ogg` and `<id>_build.json`. Durations are 71.11, 72.73, and 61.94 seconds. Encoded loudness is approximately -18.5 LUFS, with a further -4 dB game mix gain. Audition approval does not replace in-game listening to the full loop and warning mix.
