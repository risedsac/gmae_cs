from pathlib import Path
import subprocess,numpy as np,wave
P=Path(__file__).resolve().parents[2];S=P.parents[1]/'work/downloads/footsteps/Fantozzi-footsteps/flac'
for i,file in enumerate(sorted(S.glob('*Sand*.flac'))):
 x=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(file),'-f','f32le','-ac','1','-ar','48000','-']),dtype='<f4').copy()
 x*=.66/max(.001,np.max(np.abs(x)))
 with wave.open(str(P/'assets/audio'/f'step{i}.wav'),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(np.int16(x*32767).tobytes())
 print(file.name,'->',f'step{i}.wav')
