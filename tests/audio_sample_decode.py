"""Compare composer PCM decoding against ffmpeg's independent decoder."""
import ast, wave, subprocess
from array import array
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ast.parse((ROOT/'tools/audio/compose_harbor_bgm.py').read_text())
fn=next(n for n in source.body if isinstance(n,ast.FunctionDef) and n.name=='read')
env={'wave':wave,'array':array,'ROOT':ROOT}
exec(compile(ast.Module(body=[fn],type_ignores=[]),'decoder','exec'),env)
for name in ['KSHarp_D4_mf.wav','Marimba_hit_Outrigger_F5_loud_01.wav']:
    actual,rate=env['read'](name)
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/'assets/audio/harbor/bgm-samples'/name),'-af','pan=mono|c0=0.5*c0+0.5*c1','-f','f32le','-'])
    expected=array('f',raw)
    assert len(actual)==len(expected),(name,len(actual),len(expected))
    error=max(abs(a-b) for a,b in zip(actual,expected))
    assert error<0.00004,(name,error)
    print(name,'PASS: ffmpeg agreement; max error=',error)
