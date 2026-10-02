"""Golden data from the HTML game (polderrace-3d.html) for the Godot port's tests.

Writes godot/tests/golden/tracks.json: per track and direction NS, TRACK_LEN, the checkpoints and every 20th sample
(P, T, R, HT, EMB, EDGE, CURV, LINE). The Godot test (tests/test_track.gd) checks its own computeTrack against it.
usage: python godot/tools/export_golden.py   (needs the HTML test setup: pip -r requirements-dev.txt, playwright)
"""
import json, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT, TRACKS

out = {}
with Session(DEFAULT, w=320, h=200) as s:
    for tr in TRACKS:
        for d in ['fwd', 'rev']:
            r = s.ev(f"""(()=>{{computeTrack(TRACKS['{tr}'],'{d}');const f=v=>+v.toFixed(5),S=[];
              for(let i=0;i<NS;i+=20)S.push([i,f(P[i].x),f(P[i].y),f(P[i].z),f(T[i].x),f(T[i].z),f(R[i].x),f(R[i].z),f(HT[i]),f(EMB[i]),f(EDGE[i]),f(CURV[i]),f(LINE[i])]);
              return JSON.stringify({{NS,LEN:TRACK_LEN,cps,S,BX:[BX0,BX1,BZ0,BZ1]}});}})()""")
            out[f'{tr}/{d}'] = json.loads(r)
            print(tr, d, out[f'{tr}/{d}']['NS'])
(ROOT / 'godot/tests/golden/tracks.json').write_text(json.dumps(out, separators=(',', ':')))
print('ok')
