"""Original casual theme: Pebble Picnic; sampled harp/marimba (VSCO 2 CE, CC0)."""
from array import array
from pathlib import Path
import math, wave, random
ROOT=Path(__file__).resolve().parents[2]
SR=22050; BEAT=60/104; N=round(32*4*BEAT*SR)
L=array('f',[0])*N; R=array('f',[0])*N
rng=random.Random(431)
def read(name):
    with wave.open(str(ROOT/'assets/audio/harbor/bgm-samples'/name),'rb') as f:
        ch=f.getnchannels(); rate=f.getframerate(); width=f.getsampwidth()
        raw=f.readframes(f.getnframes())
    if width not in (2,3,4): raise ValueError(f'Unsupported PCM width: {width}')
    scale=float(1 << (width*8-1)); stride=width*ch
    mono=array('f')
    for offset in range(0,len(raw),stride):
        value=sum(int.from_bytes(raw[offset+c*width:offset+(c+1)*width],'little',signed=True) for c in range(ch))
        mono.append(value/ch/scale)
    return mono,rate
harp,hr=read('KSHarp_D4_mf.wav'); high,hi=read('KSHarp_C5_mf.wav'); marimba,mr=read('Marimba_hit_Outrigger_F5_loud_01.wav')
flute,fr=read('flute-long.wav'); short,sr=read('flute-short.wav'); violin,vr=read('violin-short.wav')
def add_note(beat,midi,duration,gain,pan,instrument='harp'):
    src,rate,root=(marimba,mr,77) if instrument=='marimba' else (high,hi,72) if midi>=69 else (harp,hr,62)
    if instrument=='flute': src,rate,root=(flute,fr,72) if duration>1.2 else (short,sr,72)
    elif instrument=='violin': src,rate,root=violin,vr,72
    step=rate/SR*2**((midi-root)/12); length=min(int(duration*BEAT*SR),int((len(src)-2)/step))
    start=round(beat*BEAT*SR); a=math.sqrt((1-pan)/2)*gain; b=math.sqrt((1+pan)/2)*gain
    for i in range(length):
        x=i*step; j=int(x); value=(src[j]*(1-x+j)+src[j+1]*(x-j))*min(1,i/90,(length-i)/700)
        k=(start+i)%N; L[k]+=value*a; R[k]+=value*b
        # Wrapped short room reflections make the loop tail continuous.
        for delay,decay in [(0.13,0.10),(0.23,0.065)]:
            d=(k+int(delay*SR))%N; L[d]+=value*b*decay; R[d]+=value*a*decay
# A relaxed, syncopated toy-box groove. Short motifs leave room for gameplay.
chords=[(48,64,67,69),(45,60,64,67),(53,60,65,69),(43,59,62,69),
        (50,60,65,69),(43,59,64,69),(48,64,67,71),(43,59,62,65)]
a=[[(0,76),(.75,79),(1.5,76),(2.75,74)],[(.5,72),(1,76),(2.5,79),(3.25,76)],
   [(0,77),(1.25,76),(2,72)],[(.5,74),(1.25,71),(2.75,69)],
   [(0,74),(.75,77),(2,81),(3.25,77)],[(.5,79),(1.5,76),(2.75,74)],
   [(0,76),(1,79),(2.5,72)],[(.5,74),(1.25,71),(3,72)]]
b=[[(0,79),(.5,81),(1.75,84),(3,81)],[(.25,79),(1.5,76),(2.75,72)],
   [(0,81),(.75,79),(1.5,77),(3.25,76)],[(.5,74),(2,79),(3,74)],
   [(0,77),(1.5,81),(2.25,79),(3,77)],[(.75,76),(1.5,74),(3,71)],
   [(0,72),(.75,76),(1.5,79),(2.5,76)],[(0,74),(1,71),(2.75,72)]]
for bar in range(32):
    section=bar//8; local=bar%8; root,*tones=chords[local]; start=bar*4
    # Soft bass steps and lightly staggered offbeat harp chords.
    for off,pitch in [(0,root),(2,root+7)]: add_note(start+off,pitch,1.65,.30,0)
    for off in [.75,2.5]:
        for j,pitch in enumerate(tones): add_note(start+off+j*.035,pitch,1.1,.21,-.28)
    phrase=(b if section in [1,3] else a)[local]
    for j,(off,pitch) in enumerate(phrase):
        if section==2 and j==1: continue
        add_note(start+off,pitch,.85 if j<len(phrase)-1 else 1.1,.48 if section!=2 else .36,.18,'marimba')
    if section in [1,3] and local%2==0:
        for off,pitch in [(2.15,tones[0]+12),(3.55,tones[1]+12)]: add_note(start+off,pitch,.55,.19,-.35)
    if section==3 and local in [1,5]:
        add_note(start+3.65,phrase[-1][1]+2,.28,.28,.18,'marimba')
    for j in range(8):
        if section==2 and j%2==0: continue
        at=round((start+j*.5+(.04 if j%2 else 0))*BEAT*SR)
        for i in range(int(.045*SR)):
            t=i/SR; v=rng.uniform(-1,1)*math.exp(-t*90)*(.010 if j%2 else .006)
            k=(at+i)%N; L[k]+=v*.7; R[k]+=v
    # Gentle wooden taps, with a small turnaround every four bars.
    for off in ([1,3,3.5,3.75] if local%4==3 else [1,3]):
        at=round((start+off)*BEAT*SR)
        for i in range(int(.06*SR)):
            t=i/SR; v=(math.sin(2*math.pi*670*t)+.25*math.sin(2*math.pi*1073*t))*math.exp(-t*110)*.026
            k=(at+i)%N; L[k]+=v; R[k]+=v*.8
peak=max(max(abs(x) for x in L),max(abs(x) for x in R)); gain=.70/peak
pcm=array('h')
for l,r in zip(L,R): pcm.extend((round(l*gain*32767),round(r*gain*32767)))
out=ROOT/'assets/audio/harbor/little-harbor-bgm.wav'
with wave.open(str(out),'wb') as f: f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())
print(f'Pebble Picnic: {N/SR:.2f}s, 104 BPM, 32 bars, four variations')
