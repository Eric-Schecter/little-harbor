from pathlib import Path
import wave, math, random, array, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[2]/'assets/audio/harbor'
RATE=44100
random.seed(81)
def save(name, samples, peak=.8):
    gain=peak/max(.001,max(abs(x) for x in samples))
    data=array.array('h',(int(max(-1,min(1,x*gain))*32767) for x in samples))
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data.tobytes())
def wood(t,offset=0):
    t-=offset
    if t<0:return 0
    return sum(a*math.sin(2*math.pi*hz*t)*math.exp(-t/decay) for hz,a,decay in [(185,.7,.045),(431,.4,.025),(918,.25,.015)])
def weapon(name,duration):
    values=[];low=0
    # A damped plucked string gives a bow release a pitched body, not a gunshot.
    delay=[random.uniform(-1,1) for _ in range(int(RATE/155))]
    for i in range(int(duration*RATE)):
        t=i/RATE;idx=i%len(delay);pluck=delay[idx]
        delay[idx]=.496*(pluck+delay[(idx+1)%len(delay)])
        low=.87*low+.13*random.uniform(-1,1)
        if name=='ballista':v=.65*wood(t)+.28*pluck*math.exp(-t*11)+.18*low*math.sin(min(1,t/.13)*math.pi)*math.exp(-t*18)
        elif name=='catapult':v=.55*wood(t)+.45*wood(t,.09)+.15*math.sin(2*math.pi*(105*t-36*t*t))*math.exp(-t*7)+.15*low*math.exp(-((t-.12)/.07)**2)
        elif name=='firepot':v=.5*wood(t)+.3*math.sin(2*math.pi*330*t)*math.exp(-t*22)+.25*low*math.exp(-((t-.09)/.06)**2)
        else:v=.8*wood(t)+.3*wood(t,.022)+.25*low*math.exp(-t*40)
        v*=min(1,t/.002)*min(1,(duration-t)/.025)
        values.append(v)
    save(name,values)
for n,d in [('ballista',.32),('catapult',.48),('firepot',.38),('hull_hit',.25)]:weapon(n,d)
with tempfile.TemporaryDirectory() as temp:
    decoded=Path(temp)/'water.wav'
    subprocess.run(['ffmpeg','-v','error','-i',str(ROOT/'water-source.mp3'),'-ar',str(RATE),'-ac','1',str(decoded)],check=True)
    with wave.open(str(decoded),'rb') as f:water=array.array('h',f.readframes(f.getnframes()))
source=[x/32768 for x in water[int(1.2*RATE):int(8.8*RATE)]]
overlap=int(.35*RATE)
loop=[source[-overlap+i]*(1-i/overlap)+source[i]*i/overlap for i in range(overlap)]+source[overlap:-overlap]
save('sailing_loop',loop,.65)
splash=[x/32768 for x in water[int(4.6*RATE):int(5.25*RATE)]]
splash=[v*min(1,i/(RATE*.015))*min(1,(len(splash)-i)/(RATE*.18)) for i,v in enumerate(splash)]
save('water_hit',splash,.75)
print('Built 4 weapon/impact clips and natural sailing loop + water impact')
