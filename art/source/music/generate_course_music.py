"""Expand the three approved audition themes into original runtime loops."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import generate_neon_coast as synth
from generate_track_previews import PROFILES, compose


def main():
    for track_id, (bpm, roots, motif, voice) in PROFILES.items():
        bars = 40 if track_id == "storm_ridge" else 32
        samples = compose(track_id, bpm, roots, motif, voice, bars=bars, arranged=True)
        destination = Path("assets/music") / f"{track_id}.ogg"
        with tempfile.TemporaryDirectory(prefix="car-course-music-") as directory:
            source = Path(directory) / "master.wav"
            synth.write_wave(source, samples)
            subprocess.run([
                "ffmpeg", "-v", "error", "-y", "-i", str(source),
                "-af", "loudnorm=I=-18.5:TP=-3:LRA=7", "-ar", "48000",
                "-c:a", "libvorbis", "-q:a", "4", str(destination),
            ], check=True)
        report = synth.analyze_runtime(destination)
        assert 60 <= report["decoded_duration_seconds"] <= 90
        assert report["loop_seam_max_abs"] <= .01
        assert report["true_peak_dbfs"] <= -1
        assert report["integrated_lufs"] - 4 <= -20
        assert destination.stat().st_size <= 2_500_000
        report.update(original=True, seed=20260915, bpm=bpm, bars=bars,
                      runtime_bytes=destination.stat().st_size,
                      sha256=hashlib.sha256(destination.read_bytes()).hexdigest())
        Path(f"art/source/music/{track_id}_build.json").write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(track_id, json.dumps(report))


if __name__ == "__main__":
    main()
