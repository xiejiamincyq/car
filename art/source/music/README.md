# Original music sources

`generate_neon_coast.py` deterministically synthesizes **Neon Coast Circuit** from the note, rhythm, oscillator, envelope, and mix data in the script. It uses no samples and no copied melody.

Regenerate from the repository root:

```powershell
python art/source/music/generate_neon_coast.py
```

The generated OGG is the runtime asset. The JSON build report records encoded duration, loop-boundary discontinuity, EBU R128 integrated loudness, true peak, file size, seed, and SHA-256 for reproducibility. The game applies a further `-4 dB` catalog gain so warning and collision cues remain legible.
