#!/usr/bin/env python3
"""Prepare four real single-shot variants per weapon and role.

Only Python's standard library is used. Inputs are multi-shot field recordings
from The Free Firearm Sound Library mirrored by fps-asset-kit. We detect
separated transients rather than cloning one take with pitch shifts. Runtime
outputs keep the dry report and environmental tail separate so the game can mix
space-dependent ambience instead of baking one fixed echo into every shot.
"""
from __future__ import annotations

import argparse
from array import array
from pathlib import Path
import sys
import urllib.request
import wave

BASE = "https://raw.githubusercontent.com/petroulacl/fps-asset-kit/main/sfx/firearm_sfx/Prepared%20SFX%20Library"
PROFILES = {
    "ak74": ("AK-47", "C_28P.wav", "C_31P.wav"),
    "m4a1": ("AR-15", "D_32P.wav", "D_24P.wav"),
    "p226": ("Walther PPQ", "X_39P.wav", "X_31P.wav"),
    "awm": ("Tikka", "W_29P.wav", "W_24P.wav"),
}


def quote_folder(folder: str) -> str:
    return folder.replace(" ", "%20")


def download(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 4096:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "DustlineAssetPrep/1.0"})
    with urllib.request.urlopen(req) as response, dest.open("wb") as output:
        output.write(response.read())


def read_mono16(path: Path) -> tuple[int, array]:
    with wave.open(str(path), "rb") as reader:
        channels = reader.getnchannels()
        width = reader.getsampwidth()
        rate = reader.getframerate()
        raw = reader.readframes(reader.getnframes())
    if width != 2:
        raise RuntimeError(f"expected 16-bit PCM, got {width * 8}-bit: {path}")
    samples = array("h")
    samples.frombytes(raw)
    if sys.byteorder != "little":
        samples.byteswap()
    if channels == 1:
        return rate, samples
    if channels == 2:
        mono = array("h", ((int(samples[i]) + int(samples[i + 1])) // 2 for i in range(0, len(samples) - 1, 2)))
        return rate, mono
    raise RuntimeError(f"unsupported channel count {channels}: {path}")


def detect_transients(samples: array, rate: int, count: int = 4) -> list[int]:
    frames = len(samples)
    hop = max(1, int(rate * 0.004))
    window = max(hop, int(rate * 0.012))
    stride = max(1, hop // 6)
    envelope: list[tuple[int, int]] = []
    for start in range(0, max(1, frames - window), hop):
        peak = max((abs(int(samples[i])) for i in range(start, min(frames, start + window), stride)), default=0)
        envelope.append((peak, start))
    if not envelope:
        return [0] * count
    maximum = max(v for v, _ in envelope)
    candidates = sorted((item for item in envelope if item[0] >= maximum * 0.30), reverse=True)
    chosen: list[int] = []
    for _, frame in candidates:
        if all(abs(frame - old) >= int(rate * 0.34) for old in chosen):
            chosen.append(frame)
            if len(chosen) >= count:
                break
    if len(chosen) < count:
        for _, frame in sorted(envelope, reverse=True):
            if all(abs(frame - old) >= int(rate * 0.20) for old in chosen):
                chosen.append(frame)
                if len(chosen) >= count:
                    break
    chosen.sort()
    if not chosen:
        chosen = [0]
    # Do not pitch-clone a take. If a source contains fewer than four usable
    # transients, keep the duplicate only as a last-resort compatibility slot
    # and report it loudly so the asset set can be replaced during review.
    while len(chosen) < count:
        chosen.append(chosen[-1])
    return chosen[:count]


def slice_samples(samples: array, rate: int, center: int, pre: float, post: float) -> array:
    start = max(0, center - int(pre * rate))
    end = min(len(samples), center + int(post * rate))
    return array("h", samples[start:end])


def peak_normalize(samples: array, target_peak: float) -> array:
    peak = max((abs(int(v)) for v in samples), default=0)
    if peak <= 0:
        return array("h", samples)
    gain = min(8.0, target_peak * 32767.0 / peak)
    return array("h", (max(-32768, min(32767, round(int(v) * gain))) for v in samples))


def fade(samples: array, rate: int, fade_out: float = 0.08) -> array:
    output = array("h", samples)
    fade_frames = min(len(output), int(rate * fade_out))
    for n in range(fade_frames):
        gain = 1.0 - n / max(1, fade_frames - 1)
        idx = len(output) - fade_frames + n
        output[idx] = max(-32768, min(32767, round(int(output[idx]) * gain)))
    return output


def write(path: Path, samples: array, rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = array("h", samples)
    if sys.byteorder != "little":
        payload.byteswap()
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(rate)
        writer.writeframes(payload.tobytes())


def prep_profile(profile: str, folder: str, near_name: str, distant_name: str, cache: Path, out_root: Path) -> None:
    folder_url = quote_folder(folder)
    near_src = cache / profile / near_name
    distant_src = cache / profile / distant_name
    download(f"{BASE}/{folder_url}/{near_name}", near_src)
    download(f"{BASE}/{folder_url}/{distant_name}", distant_src)
    near_rate, near = read_mono16(near_src)
    far_rate, far = read_mono16(distant_src)
    near_hits = detect_transients(near, near_rate, 4)
    far_hits = detect_transients(far, far_rate, 4)
    output = out_root / profile
    for i in range(4):
        dry = fade(peak_normalize(slice_samples(near, near_rate, near_hits[i], .012, .62), .72), near_rate)
        world = fade(peak_normalize(slice_samples(near, near_rate, near_hits[i], .012, 1.05), .64), near_rate)
        distant = fade(peak_normalize(slice_samples(far, far_rate, far_hits[i], .018, 1.35), .60), far_rate, .14)
        tail_body = slice_samples(far, far_rate, far_hits[i] + int(.055 * far_rate), 0.0, 1.15)
        silence = array("h", [0]) * int(.055 * far_rate)
        tail = fade(peak_normalize(silence + tail_body, .30), far_rate, .20)
        write(output / f"near_{i}.wav", dry, near_rate)
        write(output / f"world_{i}.wav", world, near_rate)
        write(output / f"distant_{i}.wav", distant, far_rate)
        write(output / f"tail_{i}.wav", tail, far_rate)
    duplicate_warning = len(set(near_hits)) < 4 or len(set(far_hits)) < 4
    print(f"prepared {profile}: near_hits={near_hits} distant_hits={far_hits}" + (" WARNING: source had <4 isolated transients" if duplicate_warning else ""))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, default=Path(".realistic_audio_sources"))
    parser.add_argument("--output", type=Path, default=Path("assets/audio/realistic_weapons"))
    args = parser.parse_args()
    for profile, (folder, near_name, distant_name) in PROFILES.items():
        prep_profile(profile, folder, near_name, distant_name, args.cache, args.output)

if __name__ == "__main__":
    main()
