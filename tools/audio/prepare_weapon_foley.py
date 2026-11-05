from pathlib import Path
import subprocess,wave,array,math,json
root=Path(__file__).resolve().parents[2]/'assets/audio/harbor/foley-v2'
report=[]
for src,dst,length in [('arrow_release','ballista',.38),('arrow_impact','arrow_hit',.43),('stone_release','catapult',.57),('stone_impact','stone_hit',.72)]:
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
