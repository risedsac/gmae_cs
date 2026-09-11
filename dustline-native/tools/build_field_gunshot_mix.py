#!/usr/bin/env python3
"""Build richer first-person gunshots from the installed field recordings.

The downloaded Steel Tide near/world/distant files are all derived from real CC0
firearm recordings.  The near file is intentionally very dry/short, which can
sound synthetic when played by itself in an FPS.  This script keeps that real
muzzle transient but adds low-level delayed early reflection and a faded-in tail
from the separate distant microphone recording.  No generated oscillator/noise
is used; every audible layer comes from recorded gunfire.
"""

from __future__ import annotations

import shutil
import sys
import wave
from array import array
from pathlib import Path

PROFILES = ("ak74", "p226", "m4a1", "awm")


def read_pcm16(path: Path):
    with wave.open(str(path), "rb") as reader:
        channels = reader.getnchannels()
        width = reader.getsampwidth()
        rate = reader.getframerate()
        frames = reader.getnframes()
        if width != 2:
            raise RuntimeError(f"{path}: expected 16-bit PCM, got {width * 8}-bit")
        samples = array("h")
        samples.frombytes(reader.readframes(frames))
    return channels, rate, samples


def write_pcm16(path: Path, channels: int, rate: int, samples: array) -> None:
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(channels)
        writer.setsampwidth(2)
        writer.setframerate(rate)
        writer.writeframes(samples.tobytes())


def mix_profile(root: Path, profile: str) -> None:
    folder = root / profile
    near_path = folder / f"{profile}_player_near.wav"
    distant_path = folder / f"{profile}_enemy_distant.wav"
    dry_path = folder / f"{profile}_player_near_dry.wav"
    if not near_path.exists() or not distant_path.exists():
        print(f"warning: {profile}: missing near/distant source; skipping", file=sys.stderr)
        return

    shutil.copy2(near_path, dry_path)
    near_channels, near_rate, near = read_pcm16(dry_path)
    far_channels, far_rate, distant = read_pcm16(distant_path)
    if (near_channels, near_rate) != (far_channels, far_rate):
        raise RuntimeError(
            f"{profile}: incompatible recordings: near={near_channels}ch/{near_rate}Hz "
            f"distant={far_channels}ch/{far_rate}Hz"
        )

    channels = near_channels
    rate = near_rate
    reflection_delay = int(rate * 0.028) * channels
    tail_delay = int(rate * 0.018) * channels
    fade_samples = max(1, int(rate * 0.085) * channels)
    output_len = max(len(near), tail_delay + len(distant), reflection_delay + len(near))
    mixed = [0.0] * output_len

    # Preserve the recorded close-mic crack.
    for i, sample in enumerate(near):
        mixed[i] += sample * 0.94

    # Quiet early reflection from the same real shot.  This makes headphones
    # sound less like an isolated sample without adding synthetic noise.
    for i, sample in enumerate(near):
        j = reflection_delay + i
        if j >= output_len:
            break
        decay = max(0.0, 1.0 - i / max(1, len(near)))
        mixed[j] += sample * 0.10 * decay

    # Bring in only the spatial body/tail from the separately recorded distant
    # microphone.  Fade-in suppresses its duplicate muzzle transient.
    for i, sample in enumerate(distant):
        j = tail_delay + i
        if j >= output_len:
            break
        fade = min(1.0, i / fade_samples)
        mixed[j] += sample * 0.26 * fade

    peak = max((abs(value) for value in mixed), default=1.0)
    gain = min(1.0, 30000.0 / peak) if peak else 1.0
    output = array("h", (int(max(-32768, min(32767, value * gain))) for value in mixed))
    write_pcm16(near_path, channels, rate, output)
    seconds = len(output) / channels / rate
    print(f"FIELD_GUNSHOT_MIX {profile}: {seconds:.2f}s -> {near_path}")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: build_field_gunshot_mix.py AUDIO_ROOT")
    root = Path(sys.argv[1]).resolve()
    for profile in PROFILES:
        mix_profile(root, profile)


if __name__ == "__main__":
    main()
