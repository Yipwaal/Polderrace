"""Every track x every mode must run from start to the results screen without JS errors.

usage: python tests/test_regression.py [tracks] [modes] [dirs]
  e.g. python tests/test_regression.py grachten,zeeland race,time fwd,rev
defaults: all 10 tracks, modes race/elim/ghost/time, direction fwd
"""
import sys
from lib import Session, Report, DEFAULT, TRACKS

tracks = sys.argv[1].split(',') if len(sys.argv) > 1 else TRACKS
modes = sys.argv[2].split(',') if len(sys.argv) > 2 else ['race', 'elim', 'ghost', 'time']
dirs = sys.argv[3].split(',') if len(sys.argv) > 3 else ['fwd']

rep = Report('regressie: elke baan x modus tot de uitslag')
with Session(dict(DEFAULT, bots=4), w=500, h=320) as s:
    for tr in tracks:
        for d in dirs:
            for m in modes:
                e0 = len(s.errs)
                s.ev(f"toMenu(-1);settings.track='{tr}';settings.dir='{d}';settings.mode='{m}';settings.bots={3 if m == 'elim' else 4};"
                     f"settings.laps=1;saveSettings();loadTrack('{tr}','{d}');0")
                s.ev('startRace();0')
                if m == 'time':
                    s.step(4.5, False); s.step(12); s.ev('timeLeft=0.01;0'); s.step(1)
                else:
                    s.race_until_over(45 if m == 'elim' else 25)
                st = s.ev('state'); title = s.ev("$('overTitle')?$('overTitle').textContent:''")
                new_errs = s.errs[e0:]
                rep.check(st == 'over' and not new_errs, f'{tr}/{d}/{m}', f"{st} '{title}'" + (f' ERR {new_errs[:2]}' if new_errs else ''))
rep.finish()
