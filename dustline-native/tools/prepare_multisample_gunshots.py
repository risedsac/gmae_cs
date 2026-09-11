#!/usr/bin/env python3
"""Prepare four real single-shot variants per weapon and role.

The inputs are unmodified multi-shot field recordings from The Free Firearm
Sound Library mirrored by fps-asset-kit.  We detect separated transients rather
than cloning one take with pitch shifts.  Runtime outputs keep the dry report
and environmental tail as separate files so the game can mix them according to
space instead of baking one fixed echo into every shot.
"""
from __future__ import annotations

import argparse
import audioop
import math
from pathlib import Path
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


def read_mono16(path: Path) -> tuple[int, bytes]:
    with wave.open(str(path), "rb") as reader:
        channels = reader.getnchannels()
        width = reader.getsampwidth()
        rate = reader.getframerate()
        raw = reader.readframes(reader.getnframes())
    if channels == 2:
        raw = audioop.tomono(raw, width, 0.5, 0.5)
        channels = 1
    if channels != 1:
        raise RuntimeError(f"unsupported channel count {channels}: {path}")
    if width != 2:
        raw = audioop.lin2lin(raw, width, 2)
    if rate != 44100:
        raw, _ = audioop.ratecv(raw, 2, 1, rate, 44100, None)
        rate = 44100
    return rate, raw


def sample_at(raw: bytes, index: int) -> int:
    off = index * 2
    return int.from_bytes(raw[off:off + 2], "little", signed=True)


def detect_transients(raw: bytes, rate: int, count: int = 4) -> list[int]:
    frames = len(raw) // 2
    hop = max(1, int(rate * 0.004))
    window = max(hop, int(rate * 0.012))
    envelope: list[tuple[float, int]] = []
    for start in range(0, max(1, frames - window), hop):
        peak = 0
        for i in range(start, min(frames, start + window), max(1, hop // 6)):
            peak = max(peak, abs(sample_at(raw, i)))
        envelope.append((float(peak), start))
    if not envelope:
        return [0]
    maximum = max(v for v, _ in envelope)
    candidates = sorted((item for item in envelope if item[0] >= maximum * 0.30), reverse=True)
    chosen: list[int] = []
    minimum_gap = int(rate * 0.34)
    for _, frame in candidates:
        if all(abs(frame - old) >= minimum_gap for old in chosen):
            chosen.append(frame)
            if len(chosen) >= count:
                break
    chosen.sort()
    if len(chosen) < count:
        # The prepared source sometimes contains only a few strong peaks. Add
        # the next strongest independent windows instead of duplicating a take.
        for _, frame in sorted(envelope, reverse=True):
            if all(abs(frame - old) >= int(rate * 0.20) for old in chosen):
                chosen.append(frame)
                if len(chosen) >= count:
                    break
        chosen.sort()
    if not chosen:
        chosen=[0]
    while len(chosen) < count:
        chosen.append(chosen[-1])
    return chosen[:count]


def slice_pcm(raw: bytes, rate: int, center: int, pre: float, post: float) -> bytes:
    start = max(0, center - int(pre * rate))
    end = min(len(raw)//2, center + int(post * rate))
    return raw[start*2:end*2]


def peak_normalize(raw: bytes, target_peak: float) -> bytes:
    peak = audioop.max(raw, 2) if raw else 0
    if peak <= 0:
        return raw
    return audioop.mul(raw, 2, min(8.0, target_peak * 32767.0 / peak))


def fade(raw: bytes, rate: int, fade_out: float = 0.08) -> bytes:
    samples = bytearray(raw)
    frames = len(samples)//2
    fade_frames = min(frames, int(rate * fade_out))
    for n in range(fade_frames):
        gain = 1.0 - n / max(1, fade_frames - 1)
        idx = frames - fade_frames + n
        value = sample_at(samples, idx)
        samples[idx*2:idx*2+2] = int(value*gain).to_bytes(2,"little",signed=True)
    return bytes(samples)


def write(path: Path, raw: bytes, rate: int = 44100) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(1);writer.setsampwidth(2);writer.setframerate(rate);writer.writeframes(raw)


def prep_profile(profile: str, folder: str, near_name: str, distant_name: str, cache: Path, out_root: Path) -> None:
    folder_url = quote_folder(folder)
    near_src = cache / profile / near_name
    distant_src = cache / profile / distant_name
    download(f"{BASE}/{folder_url}/{near_name}", near_src)
    download(f"{BASE}/{folder_url}/{distant_name}", distant_src)
    near_rate, near_raw = read_mono16(near_src)
    far_rate, far_raw = read_mono16(distant_src)
    near_hits = detect_transients(near_raw, near_rate, 4)
    far_hits = detect_transients(far_raw, far_rate, 4)
    output = out_root / profile
    for i in range(4):
        dry = fade(peak_normalize(slice_pcm(near_raw, near_rate, near_hits[i], .012, .62), .72), near_rate)
        world = fade(peak_normalize(slice_pcm(near_raw, near_rate, near_hits[i], .012, 1.05), .64), near_rate)
        distant = fade(peak_normalize(slice_pcm(far_raw, far_rate, far_hits[i], .018, 1.35), .60), far_rate, .14)
        # Tail is a separate distant-mic ambience layer. Prepend silence so its
        # timing stays physical while runtime is free to change its gain/filter.
        tail_body = slice_pcm(far_raw, far_rate, far_hits[i] + int(.055*far_rate), 0.0, 1.15)
        silence = b"\x00\x00" * int(.055 * far_rate)
        tail = fade(peak_normalize(silence + tail_body, .30), far_rate, .20)
        write(output / f"near_{i}.wav", dry, near_rate)
        write(output / f"world_{i}.wav", world, near_rate)
        write(output / f"distant_{i}.wav", distant, far_rate)
        write(output / f"tail_{i}.wav", tail, far_rate)
    print(f"prepared {profile}: near_hits={near_hits} distant_hits={far_hits}")


def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument("--cache",type=Path,default=Path(".realistic_audio_sources"))
    parser.add_argument("--output",type=Path,default=Path("assets/audio/realistic_weapons"))
    args=parser.parse_args()
    for profile,(folder,near_name,distant_name) in PROFILES.items():
        prep_profile(profile,folder,near_name,distant_name,args.cache,args.output)

if __name__=="__main__":
    main()
