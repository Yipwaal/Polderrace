"""Chase camera must never dip into the hills on the terrain tracks (Veluwe, Limburg), for player 1
and for player 2 in split screen. Sampled over 90 frames of driving; margin camera-above-ground >= 0.5 m.
"""
from lib import Session, Report, DEFAULT

rep = Report('camera blijft boven het terrein')
for tr in ['limburg', 'veluwe']:
    with Session(dict(DEFAULT, track=tr, bots=5, laps=3), w=500, h=300) as s:
        s.ev('startRace();0'); s.step(4.5, False); s.step(9)
        worst = 99; bad = 0
        for k in range(90):
            s.step(0.25)
            m = s.ev("(()=>{updateCamera(1/60);return camera.position.y-veluweTF(camera.position.x,camera.position.z).h;})()")
            worst = min(worst, m); bad += m < 0.5
        rep.check(bad == 0, f'{tr} speler 1', f'{bad} van 90 frames te laag, laagste marge {worst:.2f} m')
    with Session(dict(DEFAULT, track=tr, bots=3, mode='split'), w=800, h=600) as s:
        s.ev("settings.mode='split';startRace();0"); s.step(4.5, False)
        bad = 0; worst = 99
        for k in range(40):
            s.step(0.4)
            r = s.ev("(()=>{const o=[];updateCamera(1/60);o.push(camera.position.y-veluweTF(camera.position.x,camera.position.z).h);"
                     "asP2(()=>{updateCamera(1/60);o.push(camera.position.y-veluweTF(camera.position.x,camera.position.z).h);});return o;})()")
            worst = min(worst, *r); bad += min(r) < 0.5
        rep.check(bad == 0 and not s.errs, f'{tr} 2 spelers', f'{bad} van 40 te laag, laagste {worst:.2f} m' + (f' ERR {s.errs[:2]}' if s.errs else ''))
rep.finish()
