import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const key=process.env.ELEVENLABS_API_KEY;
if(!key)throw new Error('Configured audio generation key unavailable');
const output=resolve('assets/audio/harbor/foley-v2');await mkdir(output,{recursive:true});
const logPath=resolve(output,'generation.json');
let ledger;try{ledger=JSON.parse(await readFile(logPath,'utf8'));}catch{ledger={attempts:[]};}
const jobs=[
 ['arrow_release','One isolated small medieval wooden crossbow firing. Immediate tight dry bowstring snap, a short warm wooden mechanism clack, quick airy arrow release, subtle string tension decay. Close clean foley, charming light game sound, crisp but not sharp or metallic. One shot only, no reload sequence, no impact, no music, voices, ambience or reverb.',1.2],
 ['arrow_impact','One isolated arrow embedding deeply into a wooden boat hull. Immediate compact woody THUNK with a crisp fibrous puncture and very short quiet shaft quiver. Satisfying solid wood penetration, warm dry close foley, light cute medieval game. No metallic ringing, gunshot, explosion, water, ambience, music, voice or long reverb. Single impact.',1.2],
 ['stone_release','One isolated small medieval wooden catapult launching a stone. Short rope tension creak immediately releasing into a solid wooden arm clack and a brief low airy stone whoosh. Warm chunky playful but physically grounded foley. Single launch only, no impact, explosion, gunshot, metal ringing, music, voices or background.',1.5],
 ['stone_impact','One isolated heavy stone striking a hollow wooden ship hull. Immediate deep rounded wooden THUD, sharp short plank crack, followed by two or three small wood fragments settling. Weighty warm resonant wood, dry close game foley, compact decay, no harsh high hiss. No explosion, gunshot, metallic ringing, water, ambience, voices or music.',1.5]
];
for(const [id,text,duration] of jobs){
 if(ledger.attempts.some(a=>a.id===id)){console.log(id+': previously attempted');continue;}
 const attempt={id,text,duration,date:new Date().toISOString(),status:'started'};ledger.attempts.push(attempt);await writeFile(logPath,JSON.stringify(ledger,null,2));
 try{
 const res=await fetch('https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',{method:'POST',headers:{'xi-api-key':key,'Content-Type':'application/json'},body:JSON.stringify({text,duration_seconds:duration,model_id:'eleven_text_to_sound_v2',prompt_influence:.45,loop:false}),signal:AbortSignal.timeout(120000),redirect:'error'});
 attempt.httpStatus=res.status;
 if(!res.ok){attempt.status='failed';console.log(id+': HTTP '+res.status);}
 else{const b=Buffer.from(await res.arrayBuffer());await writeFile(resolve(output,id+'.mp3'),b);attempt.status='complete';console.log(id+': saved '+b.length+' bytes');}
 }catch(e){attempt.status='uncertain';console.log(id+': '+String(e.message).replaceAll(key,'[redacted]'));}
 await writeFile(logPath,JSON.stringify(ledger,null,2));
}
