"""Original UI motifs and a compact toy cannon, generated from oscillators only."""
from pathlib import Path
from array import array
import math,random,wave
ROOT=Path(__file__).resolve().parents[2]/'assets/audio/harbor/ui'
ROOT.mkdir(exist_ok=True); SR=22050
melodies={'ui_buy':[76,81],'ui_merge':[72,76,79],'ui_upgrade':[72,76,79,84], 'ui_invalid':[48,46], 'wave_start':[67,72,76], 'wave_clear':[72,76,79,84], 'defeat':[67,64,60,55], 'ui_discover':[60,67,72], 'explosion_small':[43]}
for name,notes in melodies.items():
 duration=len(notes)*.095+.26; values=[0.0]*int(SR*duration)
 for n,note in enumerate(notes):
  start=int(n*.095*SR); hz=440*2**((note-69)/12)
  for i in range(int(.26*SR)):
   t=i/SR; env=min(1,t/.008)*math.exp(-t*18)*min(1,(.26-t)/.025)
   value=(math.sin(2*math.pi*hz*t)+.18*math.sin(4*math.pi*hz*t))*env
   values[start+i]+=value*.45
 peak=max(map(abs,values)); pcm=array('h',(round(v/max(1,peak)*.65*32767) for v in values))
 with wave.open(str(ROOT/(name+'.wav')),'wb') as f: f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
rng=random.Random(81);values=[];low=0
for i in range(int(.58*SR)):
 t=i/SR; low=.92*low+.08*rng.uniform(-1,1)
 env=min(1,t/.003)*math.exp(-t*10)*min(1,(.58-t)/.06)
 value=(math.sin(2*math.pi*(85*t-30*t*t))*.70+low*.65+math.sin(2*math.pi*210*t)*math.exp(-t*27)*.20)*env
 values.append(value)
peak=max(map(abs,values))
with wave.open(str(ROOT/'ship_cannon.wav'),'wb') as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(array('h',(round(v/peak*.7*32767) for v in values)).tobytes())
print('Built 10 original UI/cannon clips')
