"""Per-shot variants from CC0 near/mid field microphones, preserving the gun report.
Do not sum decorrelated/phase-shifted field microphones into mono.
"""
from pathlib import Path
import numpy as np, subprocess, wave, json, math
P=Path(__file__).resolve().parents[2];ROOT=P.parents[1];S=ROOT/'work/downloads/firearms/Prepared SFX Library';OUT=P/'assets/audio';RATE=48000
sets=[('rifle_shot','AK-47/C_28P.wav','AK-47/C_31P.wav',1.05),('m4_shot','AR-15/D_32P.wav','AR-15/D_24P.wav',.95),('pistol_shot','1911/A_42P.wav','1911/A_34P.wav',.85),('sniper_shot','Tikka/W_29P.wav','Tikka/W_24P.wav',1.65)]
report=[];preview=[]
def decode(p):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','2','-ar',str(RATE),'-']),dtype='<f4').reshape(-1,2)
def write(name,x):
 a=np.int16(np.clip(x,-.98,.98)*32767)
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setparams((1,2,RATE,0,'NONE','not compressed'));w.writeframes(a.tobytes())
def filter_(x,kind):
 chain='highpass=f=45,lowpass=f=14500' if kind=='near' else ('highpass=f=55,lowpass=f=7000' if kind=='far' else 'highpass=f=60,lowpass=f=1250')
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-f','f32le','-ar',str(RATE),'-ac','1','-i','-','-af',chain,'-f','f32le','-'],input=x.astype('<f4').tobytes()),dtype='<f4').copy()
for name,near,far,duration in sets:
 variants=[]
 for kind,file in [('near',near),('far',far)]:
  x=decode(S/file);env=np.max(np.abs(x),axis=1);starts=[]
  for i in np.where(env>env.max()*.32)[0]:
   if not starts or i-starts[-1]>RATE*1.9:starts.append(int(i))
  for v in range(4):
   onset=starts[(v//2)%len(starts)];channel=v%2
   # Find the onset of this microphone, preserving its full transient without phase cancellation.
   begin=max(0,onset-int(.035*RATE));window=x[begin:onset+int(.065*RATE),channel];peak=np.max(np.abs(window))
   first=int(np.where(np.abs(window)>peak*.025)[0][0])+begin
   begin=max(0,first-96);end=begin+int(duration*RATE)
   a=x[begin:end,channel].copy();a=np.pad(a,(0,max(0,int(duration*RATE)-len(a))))
   a=filter_(a,kind)
   # Only fade the final tail. No transient compressor or high-frequency exciter.
   fade_len=min(len(a),int(.30*RATE));a[-fade_len:]*=np.linspace(1,0,fade_len)**1.4
   a[:48]*=np.linspace(0,1,48);a-=np.mean(a)
   a*=.79/max(.001,np.max(np.abs(a)))
   stem=name+('' if kind=='near' else '_far')+f'_{v}'
   write(stem,a)
   if kind=='near':
    variants.append(a);write(name,a) if v==0 else None
    blocked=filter_(a,'occluded');blocked*=.68/max(.001,np.max(np.abs(blocked)));write(name+'_occluded_'+str(v),blocked)
   report.append({'name':stem,'source':file,'microphone':channel,'onset_seconds':round(begin/RATE,4),'duration':len(a)/RATE,'peak_dbfs':round(20*math.log10(np.max(np.abs(a))),2),'clipped_samples':int(np.sum(np.abs(a)>=1))})
 # Two singles, then a four-shot burst. Uses the exact files loaded by Godot.
 segment=np.zeros(RATE*5)
 interval=.105 if name=='rifle_shot' else (.089 if name=='m4_shot' else (.23 if name=='pistol_shot' else 1.4))
 times=[.1,1.4]+([2.7+i*interval for i in range(4)] if name!='sniper_shot' else [2.9])
 for n,t in enumerate(times):
  a=variants[n%4];j=int(t*RATE);count=min(len(a),len(segment)-j);segment[j:j+count]+=a[:count]*.55
 preview.append(segment)
mix=np.concatenate(preview);mix*=.88/max(.88,np.max(np.abs(mix)))
with wave.open(str(ROOT/'outputs/Dustline-v3-枪声试听.wav'),'wb') as w:w.setparams((1,2,RATE,0,'NONE','not compressed'));w.writeframes(np.int16(mix*32767).tobytes())
(OUT/'audio-analysis-v3.json').write_text(json.dumps(report,indent=2));print('EXPORTED',len(report),'near/far variants + 16 occluded; four weapons, no phase-cancelling mono fold-down')
