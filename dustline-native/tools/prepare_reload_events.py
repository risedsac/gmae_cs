#!/usr/bin/env python3
"""Split recorded reload Foley into short mechanism events.

This does not synthesize weapon Foley. It finds separated transients in the
recorded pistol/rifle reload takes already downloaded by the installer and
exports compact event clips so gameplay can trigger them at authored animation
beats. Each gameplay platform receives an independent output namespace, even
when a recorded source is shared, so a weapon-specific recording can replace
one profile later without changing runtime code.
"""
from __future__ import annotations

from array import array
from pathlib import Path
import argparse
import sys
import wave


def read_wav(path: Path) -> tuple[int, array]:
    with wave.open(str(path), "rb") as r:
        if r.getsampwidth() != 2:
            raise RuntimeError(f"expected 16-bit PCM: {path}")
        rate = r.getframerate()
        channels = r.getnchannels()
        raw = r.readframes(r.getnframes())
    values = array("h")
    values.frombytes(raw)
    if sys.byteorder != "little":
        values.byteswap()
    if channels == 2:
        values = array(
            "h",
            ((int(values[i]) + int(values[i + 1])) // 2 for i in range(0, len(values) - 1, 2)),
        )
    elif channels != 1:
        raise RuntimeError(f"unsupported channel count {channels}: {path}")
    return rate, values


def write_wav(path: Path, rate: int, samples: array) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = array("h", samples)
    if sys.byteorder != "little":
        data.byteswap()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


def peaks(samples: array, rate: int, count=4) -> list[int]:
    hop = max(1, int(rate * .004))
    window = max(hop, int(rate * .018))
    stride = max(1, hop // 5)
    energy = []
    for start in range(0, max(1, len(samples) - window), hop):
        peak = max(
            (abs(int(samples[i])) for i in range(start, min(len(samples), start + window), stride)),
            default=0,
        )
        energy.append((peak, start))
    chosen = []
    for _, frame in sorted(energy, reverse=True):
        if all(abs(frame - old) > int(rate * .12) for old in chosen):
            chosen.append(frame)
            if len(chosen) >= count:
                break
    chosen.sort()
    while len(chosen) < count:
        chosen.append(chosen[-1] if chosen else 0)
    return chosen


def event_slice(samples: array, rate: int, center: int, pre=.045, post=.20) -> array:
    start = max(0, center - int(rate * pre))
    end = min(len(samples), center + int(rate * post))
    result = array("h", samples[start:end])
    fade = min(len(result), int(rate * .04))
    for i in range(fade):
        idx = len(result) - fade + i
        gain = 1 - i / max(1, fade - 1)
        result[idx] = round(int(result[idx]) * gain)
    return result


def normalize(samples: array, target=.62) -> array:
    peak = max((abs(int(v)) for v in samples), default=0)
    if peak <= 0:
        return samples
    gain = min(5., target * 32767. / peak)
    return array(
        "h",
        (max(-32768, min(32767, round(int(v) * gain))) for v in samples),
    )


def export_profile(source: Path, out: Path, profile: str) -> None:
    rate, samples = read_wav(source)
    points = peaks(samples, rate, 4)
    names = ("mag_out", "mag_in", "action_pull", "action_release")
    for name, point in zip(names, points):
        write_wav(out / f"{profile}_{name}.wav", rate, normalize(event_slice(samples, rate, point)))
    print(f"reload events {profile}: {dict(zip(names, points))}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    export_profile(args.input / "pistol_reload.wav", args.output, "p226")
    export_profile(args.input / "rifle_reload.wav", args.output, "ak74")
    export_profile(args.input / "rifle_reload.wav", args.output, "m4a1")
    export_profile(args.input / "rifle_reload.wav", args.output, "awm")


if __name__ == "__main__":
    main()
