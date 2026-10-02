"""Golden lap data from the HTML game for the physics port: godot/tests/golden/laps.json

Per track and car: the same autopilot as tests/lib.py's __step (full gas, steer -df*3 - lat*0.15, 120 Hz) drives a
ghost-mode race of 1 lap (no bots, no traffic, so no randomness except wind gusts) and we record raceFinishTime,
the lap time and the top speed. tests/test_laps.gd drives the same in Godot and compares.
usage: python godot/tools/export_laps.py [track,...]
"""
import json, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT, TRACKS

tracks = sys.argv[1].split(',') if len(sys.argv) > 1 else TRACKS
CARS = ['gt', 'hatch', 'super']
path = ROOT / 'godot/tests/golden/laps.json'
out = json.loads(path.read_text()) if path.exists() else {}
with Session(dict(DEFAULT, bots=0), w=320, h=200) as s:
    for tr in tracks:
        for car in CARS:
            s.ev(f"toMenu(-1);settings.track='{tr}';settings.dir='fwd';settings.mode='ghost';settings.laps=1;settings.car='{car}';settings.grid='back';"
                 f"loadTrack('{tr}','fwd');applyEnv('day','dry');rebuildPlayerCar();startRace();0")
            s.step(4.5, False)
            t = 0
            while t < 300 and not s.ev("raceDone"):
                s.step(2)
                t += 2
            r = s.ev("({ft:raceFinishTime,laps:lapTimes,top:raceTopSpeed,done:raceDone,resets:window.__resets||0})")
            out[f'{tr}/{car}'] = r
            print(tr, car, r)
            s.ev("window.__resets=0;0")
path.write_text(json.dumps(out, indent=1))
print('ok')
