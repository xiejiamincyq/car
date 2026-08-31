"""Render the original 64-second Neon Coast synthwave loop.

The composition, synthesis, and mix are deterministic and use no sampled or
third-party musical material. Requires NumPy and ffmpeg.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 48_000
BPM = 120.0
BEAT_SECONDS = 60.0 / BPM
BARS = 32
DURATION_SECONDS = BARS * 4.0 * BEAT_SECONDS
SAMPLE_COUNT = int(SAMPLE_RATE * DURATION_SECONDS)
RNG_SEED = 20_260_831


def midi_frequency(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def envelope(length: int, attack: float, release: float) -> np.ndarray:
    values = np.ones(length, dtype=np.float32)
    attack_samples = min(length, max(1, int(attack * SAMPLE_RATE)))
    release_samples = min(length, max(1, int(release * SAMPLE_RATE)))
    values[:attack_samples] = np.linspace(0.0, 1.0, attack_samples, endpoint=False)
    values[-release_samples:] *= np.linspace(1.0, 0.0, release_samples)
    return values


def add_note(
    mix: np.ndarray,
    start: float,
    duration: float,
    note: int,
    amplitude: float,
    waveform: str,
    pan: float = 0.0,
    attack: float = 0.01,
    release: float = 0.08,
) -> None:
    start_sample = int(start * SAMPLE_RATE)
    length = min(int(duration * SAMPLE_RATE), SAMPLE_COUNT - start_sample)
    if length <= 1:
        return
    time = np.arange(length, dtype=np.float32) / SAMPLE_RATE
    frequency = midi_frequency(note)
    phase = frequency * time
    if waveform == "triangle":
        signal = 2.0 * np.abs(2.0 * np.mod(phase, 1.0) - 1.0) - 1.0
    elif waveform == "saw":
        signal = 2.0 * np.mod(phase, 1.0) - 1.0
    elif waveform == "square":
        signal = np.tanh(3.0 * np.sin(2.0 * np.pi * phase))
    else:
        signal = np.sin(2.0 * np.pi * phase)
    signal = signal.astype(np.float32) * envelope(length, attack, release) * amplitude
    left = math.sqrt((1.0 - pan) * 0.5)
    right = math.sqrt((1.0 + pan) * 0.5)
    mix[start_sample : start_sample + length, 0] += signal * left
    mix[start_sample : start_sample + length, 1] += signal * right


def add_drums(mix: np.ndarray, rng: np.random.Generator) -> None:
    for beat in range(BARS * 4):
        start = beat * BEAT_SECONDS
        length = int(0.24 * SAMPLE_RATE)
        time = np.arange(length, dtype=np.float32) / SAMPLE_RATE
        phase = 2.0 * np.pi * (86.0 * time - 38.0 * time * time)
        kick = np.sin(phase) * np.exp(-time * 19.0) * 0.42
        index = int(start * SAMPLE_RATE)
        mix[index : index + length] += kick[:, None]
        if beat % 4 in (1, 3):
            noise = rng.standard_normal(length).astype(np.float32)
            tone = np.sin(2.0 * np.pi * 190.0 * time)
            snare = (noise * 0.16 + tone * 0.06) * np.exp(-time * 15.0)
            mix[index : index + length, 0] += snare * 0.82
            mix[index : index + length, 1] += snare
    hat_length = int(0.055 * SAMPLE_RATE)
    hat_envelope = np.exp(-np.arange(hat_length, dtype=np.float32) / SAMPLE_RATE * 62.0)
    for eighth in range(BARS * 8):
        index = int(eighth * BEAT_SECONDS * 0.5 * SAMPLE_RATE)
        noise = rng.standard_normal(hat_length).astype(np.float32)
        bright = np.concatenate(([noise[0]], np.diff(noise))) * hat_envelope * (0.035 if eighth % 2 else 0.05)
        mix[index : index + hat_length, 0] += bright
        mix[index : index + hat_length, 1] += bright * 0.78


def compose() -> np.ndarray:
    mix = np.zeros((SAMPLE_COUNT, 2), dtype=np.float32)
    rng = np.random.default_rng(RNG_SEED)
    chords = [(52, 55, 59), (48, 52, 55), (43, 47, 50), (50, 54, 57)]
    bass_patterns = [(40, 40, 47, 40), (36, 36, 43, 36), (31, 31, 38, 31), (38, 38, 45, 38)]
    arpeggio_order = (0, 1, 2, 1, 0, 2, 1, 2)
    lead_motif = (64, 67, 71, 69, 67, 64, 62, 59, 64, 67, 74, 71, 69, 67, 64, 62)

    for bar in range(BARS):
        bar_start = bar * 4.0 * BEAT_SECONDS
        chord_index = bar % len(chords)
        chord = chords[chord_index]
        for voice_index, note in enumerate(chord):
            add_note(mix, bar_start, 1.72, note, 0.055, "saw", (voice_index - 1) * 0.48, 0.09, 0.22)
            add_note(mix, bar_start, 1.72, note + 12, 0.025, "sine", (1 - voice_index) * 0.34, 0.11, 0.25)
        for step, note in enumerate(bass_patterns[chord_index]):
            add_note(mix, bar_start + step * BEAT_SECONDS, 0.36, note, 0.16, "square", -0.05, 0.008, 0.10)
        for step, chord_voice in enumerate(arpeggio_order):
            add_note(mix, bar_start + step * BEAT_SECONDS * 0.5, 0.18, chord[chord_voice] + 24, 0.055, "triangle", 0.42 if step % 2 else -0.42, 0.006, 0.06)
        if 8 <= bar < 16 or 24 <= bar < 32:
            motif_offset = ((bar % 8) * 2) % len(lead_motif)
            for step in range(4):
                note = lead_motif[(motif_offset + step) % len(lead_motif)]
                add_note(mix, bar_start + step * BEAT_SECONDS, 0.34, note, 0.085, "triangle", 0.16, 0.015, 0.12)

    add_drums(mix, rng)
    mix = np.tanh(mix * 1.18)
    rms = float(np.sqrt(np.mean(np.square(mix))))
    if rms > 0.0:
        mix *= 0.105 / rms
    peak = float(np.max(np.abs(mix)))
    if peak > 0.89:
        mix *= 0.89 / peak
    mix[0] = 0.0
    mix[-1] = 0.0
    return mix


def write_wave(path: Path, samples: np.ndarray) -> None:
    pcm = np.clip(samples * 32767.0, -32768.0, 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def analyze_runtime(path: Path) -> dict[str, float]:
    decoded = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(SAMPLE_RATE), "pipe:1"],
        check=True,
        capture_output=True,
    ).stdout
    samples = np.frombuffer(decoded, dtype="<f4").reshape(-1, 2)
    loudness_run = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-filter_complex", "ebur128=peak=true", "-f", "null", "NUL"],
        check=True,
        capture_output=True,
        text=True,
    )
    summary = loudness_run.stderr.rsplit("Summary:", maxsplit=1)[-1]
    loudness_match = re.search(r"I:\s+(-?\d+(?:\.\d+)?) LUFS", summary)
    true_peak_match = re.search(r"Peak:\s+(-?\d+(?:\.\d+)?) dBFS", summary)
    if loudness_match is None or true_peak_match is None:
        raise RuntimeError("ffmpeg did not return the expected EBU R128 summary")
    return {
        "decoded_duration_seconds": len(samples) / SAMPLE_RATE,
        "loop_seam_max_abs": float(np.max(np.abs(samples[0] - samples[-1]))),
        "integrated_lufs": float(loudness_match.group(1)),
        "true_peak_dbfs": float(true_peak_match.group(1)),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("assets/music/neon_coast.ogg"))
    parser.add_argument("--report", type=Path, default=Path("art/source/music/neon_coast_build.json"))
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)

    samples = compose()
    with tempfile.TemporaryDirectory(prefix="neon-coast-music-") as temp_dir:
        wave_path = Path(temp_dir) / "neon_coast_master.wav"
        write_wave(wave_path, samples)
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wave_path), "-c:a", "libvorbis", "-q:a", "4", "-metadata", "title=Neon Coast Circuit", str(args.output)],
            check=True,
        )

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    runtime_analysis = analyze_runtime(args.output)
    report = {
        "title": "Neon Coast Circuit",
        "original": True,
        "seed": RNG_SEED,
        "sample_rate": SAMPLE_RATE,
        "bpm": BPM,
        "bars": BARS,
        "duration_seconds": DURATION_SECONDS,
        "peak": float(np.max(np.abs(samples))),
        "rms": float(np.sqrt(np.mean(np.square(samples)))),
        "runtime_bytes": args.output.stat().st_size,
        "sha256": digest,
        **runtime_analysis,
    }
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
