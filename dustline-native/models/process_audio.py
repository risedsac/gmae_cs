"""Reproducible crisp gun mix from the credited CC0 field recordings; no game rips."""
from pathlib import Path
import subprocess,array,wave,math,random,json
root=Path(__file__).resolve().parents[2]
source=root/'downloads/firearms/Prepared SFX Library'
out=Path(__file__).resolve().parents[1]/'assets/audio'
report=[]
for name,file,duration in [('rifle_shot','AK-47/C_28P.wav',.52),('pistol_shot','1911/A_34P.wav',.40),('m4_shot','AR-15/D_32P.wav',.43),('sniper_shot','Tikka/W_29P.wav',.82)]:
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(source/file),'-f','s16le','-ac','1','-ar','48000','-'])
 a=array.array('h',raw);peak=max(abs(x) for x in a)
 onset=next(i for i,v in enumerate(a) if abs(v)>peak*.08)
 start=max(0,onset-48);a=a[start:start+int(48000*duration)]
 # Keep a punchy transient and shorten the distant outdoor wash between automatic shots.
 samples=array.array('h')
 for i,v in enumerate(a):
  t=i/48000
  env=1 if t<.045 else math.exp(-(t-.045)*(6.0 if name!='sniper_shot' else 3.5))
  fade=min(1,(len(a)-i)/240)
  samples.append(int(v*env*fade))
 filters='highpass=f=115,equalizer=f=320:t=q:w=0.8:g=-4,equalizer=f=2800:t=q:w=0.9:g=4,equalizer=f=6000:t=q:w=0.8:g=2,acompressor=threshold=0.18:ratio=2:attack=0.3:release=35:makeup=1.6,alimiter=limit=0.89:level=false:latency=true'
 processed=subprocess.check_output(['ffmpeg','-v','error','-f','s16le','-ar','48000','-ac','1','-i','-','-af',filters,'-f','s16le','-'],input=samples.tobytes())
 a=array.array('h',processed);peak=max(abs(x) for x in a);gain=28500/max(peak,1)
 a=array.array('h',(int(v*gain) for v in a))
 with wave.open(str(out/(name+'.wav')),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(a.tobytes())
 report.append({'name':name,'source':file,'trim_seconds':start/48000,'duration':len(a)/48000,'peak_dbfs':20*math.log10(max(abs(v) for v in a)/32768),'clipped_samples':sum(abs(v)>=32767 for v in a)})
rng=random.Random(579)
def write(name,values):
 peak=max(max(abs(x) for x in values),.001)
 a=array.array('h',(int(x/peak*24000) for x in values))
 with wave.open(str(out/(name+'.wav')),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(a.tobytes())
for name,hz,duration in [('bomb_beep',1800,.09),('buy',1300,.075),('pin',3400,.065),('planted',880,.40),('round_win',660,.65)]:
 vals=[]
 for i in range(int(48000*duration)):
  t=i/48000;freq=hz*(1 if t<duration*.5 else 1.25)
  vals.append(math.sin(t*math.tau*freq)*min(1,t/.003)*math.exp(-t*(25 if duration<.1 else 5)))
 write(name,vals)
vals=[];low=0
for i in range(48000):
 t=i/48000;noise=rng.uniform(-1,1);low=.91*low+.09*noise
 vals.append((low*2+noise*.22)*math.exp(-t*7)*min(1,t/.002)+math.sin(t*math.tau*(65-t*22))*math.exp(-t*12)*.3)
write('explosion',vals)
vals=[];low=0
for i in range(48000*3):
 t=i/48000;noise=rng.uniform(-1,1);low=.7*low+.3*noise;vals.append((noise-low)*min(1,t/.06)*math.exp(-t*.9))
write('smoke_hiss',vals)
(out/'audio-analysis.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
