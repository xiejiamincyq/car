"""Original, deterministic audition drafts; never writes runtime music assets."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

import numpy as np
import generate_neon_coast as synth

PROFILES = {
    "freight_harbor": (108, [36, 32, 34, 31], [0, 7, 10, 7, 3, 0, 7, 3], "square"),
    "storm_ridge": (132, [38, 34, 41, 36], [12, 10, 7, 3, 7, 10, 14, 12], "triangle"),
    "sunrise_express": (124, [36, 43, 45, 41], [7, 12, 16, 19, 16, 14, 12, 7], "sine"),
}


def compose(track_id, bpm, roots, motif, voice, bars=8, arranged=False):
    beat = 60.0 / bpm
    duration = bars * 4 * beat
    synth.SAMPLE_COUNT = round(synth.SAMPLE_RATE * duration)
    mix = np.zeros((synth.SAMPLE_COUNT, 2), dtype=np.float32)
    rng = np.random.default_rng(20260915)
    for bar in range(bars):
        root = roots[bar % 4]
        major = track_id == "sunrise_express" and bar % 4 != 2
        chord = [root + 12, root + (16 if major else 15), root + 19]
        for index, note in enumerate(chord):
            synth.add_note(mix, bar * 4 * beat, 3.8 * beat, note, .045, "triangle", (index-1)*.45, .06, .15)
        for step in range(8):
            at = (bar * 4 + step * .5) * beat
            synth.add_note(mix, at, beat * .36, root + (12 if step == 6 else 0), .15, "square", 0, .008, .06)
            # Full songs alternate the approved motif with a sparse bridge and
            # an octave response; the opening retains the audition's melody.
            section = (bar // 8) % 4 if arranged else 0
            if section != 2 or step % 2 == 0:
                melody_gain = .055 if section == 2 else .075
                synth.add_note(mix, at, beat * .42, root + 24 + motif[(step + bar * 2) % 8], melody_gain, voice, .25 if step % 2 else -.25, .012, .09)
            if arranged and section in (1, 3) and step in (1, 5):
                synth.add_note(mix, at, beat * .65, root + 36 + motif[step], .025, "sine", -.35, .025, .12)
        kicks = [0, 1.5, 2.5] if track_id == "storm_ridge" else [0, 1, 2, 3]
        for onset in kicks:
            start = round((bar * 4 + onset) * beat * synth.SAMPLE_RATE)
            t = np.arange(round(.16 * synth.SAMPLE_RATE)) / synth.SAMPLE_RATE
            kick = np.sin(2*np.pi*(65*t + .3*(1-np.exp(-t*45)))) * np.exp(-t*24) * .4
            mix[start:start+len(t)] += kick[:, None]
        for step in range(8):
            start = round((bar * 4 + step*.5) * beat * synth.SAMPLE_RATE)
            t = np.arange(round(.08 * synth.SAMPLE_RATE)) / synth.SAMPLE_RATE
            backbeat = step in (2, 6)
            noise = rng.standard_normal(len(t)) * np.exp(-t * (40 if backbeat else 100)) * (.10 if backbeat else .025)
            mix[start:start+len(t)] += noise[:, None]
    mix = np.tanh(mix)
    mix *= .105 / np.sqrt(np.mean(mix**2))
    mix *= min(1, .85 / np.max(np.abs(mix)))
    fade = round(.02 * synth.SAMPLE_RATE)
    mix[:fade] *= np.linspace(0, 1, fade)[:, None]
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
    assert np.isfinite(mix).all() and np.max(np.abs(mix)) <= .86
    return mix


def main():
    out = Path("docs/previews/music")
    out.mkdir(parents=True, exist_ok=True)
    reports = {}
    for track_id, (bpm, roots, motif, voice) in PROFILES.items():
        samples = compose(track_id, bpm, roots, motif, voice)
        destination = out / f"{track_id}-draft.ogg"
        with tempfile.TemporaryDirectory(prefix="car-music-draft-") as directory:
            source = Path(directory) / "draft.wav"
            synth.write_wave(source, samples)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-af", "loudnorm=I=-20:TP=-3:LRA=7", "-ar", "48000", "-c:a", "libvorbis", "-q:a", "4", str(destination)], check=True)
        report = synth.analyze_runtime(destination)
        assert report["true_peak_dbfs"] <= -1 and 14 <= report["decoded_duration_seconds"] <= 19
        report.update(bpm=bpm, bars=8, seed=20260915, sha256=hashlib.sha256(destination.read_bytes()).hexdigest(), bytes=destination.stat().st_size)
        reports[track_id] = report
    (out / "build-report.json").write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(reports, indent=2))


if __name__ == "__main__":
    main()
