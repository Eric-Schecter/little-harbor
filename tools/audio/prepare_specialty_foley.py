from pathlib import Path
import subprocess,wave,array,math,json
root=Path(__file__).resolve().parents[2]/'assets/audio/harbor/specialties-v1'
report=[]
for src,dst,length in [('rapid_release', 'rapid_release', 0.46), ('rapid_hit', 'rapid_hit', 0.46), ('heavy_release', 'heavy_release', 0.68), ('heavy_hit', 'heavy_hit', 0.8), ('scatter_release', 'scatter_release', 0.68), ('scatter_hit', 'scatter_hit', 0.8), ('siege_release', 'siege_release', 0.68), ('siege_hit', 'siege_hit', 0.8), ('flame_release', 'flame_release', 0.68), ('flame_hit', 'flame_hit', 0.8), ('oil_release', 'oil_release', 0.68), ('oil_hit', 'oil_hit', 0.8)]:
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/(src+'.mp3')),'-f','s16le','-ar','44100','-ac','1','-'])
    data=array.array('h',raw);rate=44100;win=220
    rms=[math.sqrt(sum(x*x for x in data[i:i+win])/max(1,len(data[i:i+win]))) for i in range(0,len(data),win)]
    onset=next(i for i,x in enumerate(rms) if x>max(rms)*.07)*win
    start=max(0,onset-int(.008*rate));end=min(len(data),start+int(length*rate));part=list(data[start:end])
    mean=sum(part)/len(part);part=[x-mean for x in part]
    part=[v*min(1,i/(rate*.002))*min(1,(len(part)-i)/(rate*.055)) for i,v in enumerate(part)]
    gain=.78*32767/max(abs(x) for x in part)
    pcm=array.array('h',(round(x*gain) for x in part))
    with wave.open(str(root/(dst+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(pcm.tobytes())
    report.append({'source':src+'.mp3','output':dst+'.wav','start_seconds':start/rate,'duration':len(part)/rate,'peak_dbfs':20*math.log10(.78)})
(root/'edits.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
