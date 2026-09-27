"""Memory leak check: 4 rounds of loading all 10 tracks (different weather), garage, podium and a short
race. GPU geometry/texture counts after round 2 and round 4 must be (nearly) the same, and the scene must
not collect extra objects.
"""
from lib import Session, Report, DEFAULT, TRACKS

rep = Report('geheugen (geen lekken)')
with Session(dict(DEFAULT, diff='easy'), w=400, h=260) as s:
    mem = []
    for rnd in range(4):
        for tr in TRACKS:
            s.ev(f"loadTrack('{tr}','fwd');applyEnv(['day','dusk','night','day'][{rnd}],['dry','rain','fog','dry'][{rnd}]);rebuildPlayerCar();menuScene();0")
            s.pg.wait_for_timeout(100)
        s.ev("homePanel('garage');0"); s.pg.wait_for_timeout(200); s.ev("homePanel('main');0")
        s.ev("enterPodium([{name:'A',carId:'gt',color:'#ff0000'},{name:'B',carId:'hyper',color:'#00ff00'},{name:'C',carId:'hatch',color:'#0000ff'}],'TEST');0")
        s.pg.wait_for_timeout(300); s.ev('leavePodium();0')
        s.ev('startRace();0'); s.step(5, False); s.ev('toMenu(-1);0')
        m = s.ev("({g:renderer.info.memory.geometries,t:renderer.info.memory.textures,c:scene.children.length})")
        mem.append(m); print(f'   ronde {rnd+1}: {m}')
    a, b = mem[1], mem[3]
    rep.check(b['g'] <= a['g'] * 1.05 + 5, 'geometrieën stabiel', f"{a['g']} -> {b['g']}")
    rep.check(b['t'] <= a['t'] * 1.05 + 3, 'texturen stabiel', f"{a['t']} -> {b['t']}")
    rep.check(b['c'] <= a['c'] + 2, 'aantal scene-objecten stabiel', f"{a['c']} -> {b['c']}")
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
