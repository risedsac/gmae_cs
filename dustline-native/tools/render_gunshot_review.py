#!/usr/bin/env python3
"""Render same-RMS single/burst comparisons for firearm audio review.

Outputs three treatments when sources exist:
  dry     - new close-mic transient only
  layered - new dry report plus the separately controlled recorded tail
  legacy  - previous single prepared player-near file
The tool never changes runtime files; it creates review WAVs under --output.
"""
from __future__ import annotations
from array import array
from pathlib import Path
import argparse, math, sys, wave

PROFILES={"ak74":.105,"p226":.22,"m4a1":.089,"awm":1.4}


def read(path: Path):
    with wave.open(str(path),"rb") as r:
        if r.getsampwidth()!=2 or r.getnchannels()!=1:raise RuntimeError(f"expected mono 16-bit PCM: {path}")
        rate=r.getframerate();data=array("h");data.frombytes(r.readframes(r.getnframes()))
    if sys.byteorder!="little":data.byteswap()
    return rate,data


def write(path: Path,rate:int,data:array):
    path.parent.mkdir(parents=True,exist_ok=True);out=array("h",data)
    if sys.byteorder!="little":out.byteswap()
    with wave.open(str(path),"wb") as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(out.tobytes())


def rms(data:array)->float:
    if not data:return 0.
    return math.sqrt(sum(int(v)*int(v) for v in data)/len(data))


def normalize_rms(data:array,target=5200.)->array:
    level=rms(data)
    if level<=1:return array("h",data)
    gain=min(8.,target/level)
    return array("h",(max(-32768,min(32767,round(int(v)*gain))) for v in data))


def mix(a:array,b:array,b_gain=.18)->array:
    n=max(len(a),len(b));out=array("h",[0])*n
    for i in range(n):
        value=(int(a[i]) if i<len(a) else 0)+(int(b[i])*b_gain if i<len(b) else 0)
        out[i]=max(-32768,min(32767,round(value)))
    return out


def burst(single:array,rate:int,interval:float,count=6)->array:
    starts=[int(i*interval*rate) for i in range(count)];out=array("h",[0])*(starts[-1]+len(single)+1)
    for start in starts:
        for i,v in enumerate(single):
            j=start+i
            if j>=len(out):break
            out[j]=max(-32768,min(32767,int(out[j])+int(v)))
    return out


def main():
    p=argparse.ArgumentParser();p.add_argument("--audio-root",type=Path,default=Path("assets/audio/realistic_weapons"));p.add_argument("--output",type=Path,default=Path("audio_review"));args=p.parse_args()
    for profile,interval in PROFILES.items():
        folder=args.audio_root/profile;near=folder/"near_0.wav";tail=folder/"tail_0.wav";legacy=folder/f"{profile}_player_near.wav"
        if not near.exists():print(f"skip {profile}: {near} missing");continue
        rate,dry=read(near);treatments={"dry":dry}
        if tail.exists():
            tail_rate,tail_data=read(tail)
            if tail_rate==rate:treatments["layered"]=mix(dry,tail_data)
        if legacy.exists():
            legacy_rate,legacy_data=read(legacy)
            if legacy_rate==rate:treatments["legacy"]=legacy_data
        for name,data in treatments.items():
            matched=normalize_rms(data)
            write(args.output/profile/f"single_{name}.wav",rate,matched)
            write(args.output/profile/f"burst_{name}.wav",rate,normalize_rms(burst(matched,rate,interval)))
        print(f"review {profile}: treatments={list(treatments)} RMS matched")

if __name__=="__main__":main()
