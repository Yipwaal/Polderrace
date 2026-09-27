"""Screenshots for a visual review (no pass/fail): tests/.out/screens/

  track_<id>_a/b.png   every track, 2 moments in a race (day)
  spot_<name>.png      fixed viewpoints of known tricky spots (bridges, barrier, canals, dunes), plus free-camera
                       overviews: zeeland_kering_boven, rotterdam_pyloon_zij/_dek, grachten_gevels
  podium.png, garage.png, menu_*.png

usage: python tests/screenshots.py [tracks|none]
Look at them with the Read tool (images are shown to you) and compare with what the scene should look like.
"""
import sys
from lib import Session, DEFAULT, TRACKS, OUT

SC = OUT / 'screens'; SC.mkdir(exist_ok=True)
tracks = [] if len(sys.argv) > 1 and sys.argv[1] == 'none' else (sys.argv[1].split(',') if len(sys.argv) > 1 else TRACKS)


def shot(s, name):
    s.pg.screenshot(path=str(SC / name)); print('  ', SC / name)


with Session(dict(DEFAULT, bots=5), w=900, h=560, prefs={'quality': 'high'}) as s:
    for tr in tracks:
        s.ev(f"toMenu(-1);settings.track='{tr}';settings.dir='fwd';settings.time='day';settings.weather='dry';settings.mode='race';loadTrack('{tr}','fwd');applyEnv('day','dry');startRace();0")
        s.step(4.5, False); s.step(9); s.pg.wait_for_timeout(1200); shot(s, f'track_{tr}_a.png')
        s.step(14); s.pg.wait_for_timeout(1200); shot(s, f'track_{tr}_b.png')
    # fixed viewpoints: drive the player to a track index and look from behind the car
    SPOTS = [('rotterdam_brug', 'rotterdam', "(()=>{let b=0;for(let i=0;i<NS;i++)if(HT[i]>HT[b])b=i;return b-45;})()", -2),
             ('zeeland_kering', 'zeeland', "(()=>{for(let i=0;i<NS;i+=5)if(P[i].x>400&&P[i].z<60)return i;return 0;})()", -3),
             ('zeeland_duinen', 'zeeland', "(()=>{let b=0,bd=1e9;for(let i=0;i<NS;i++){const d=Math.hypot(P[i].x-421,P[i].z-355);if(d<bd){bd=d;b=i;}}return (b-30+NS)%NS;})()", -3),
             ('grachten_brug', 'grachten', "(()=>{let b=0,bd=1e9;for(let i=0;i<NS;i++){const d=Math.hypot(P[i].x-313,P[i].z+299);if(d<bd){bd=d;b=i;}}return (b-15+NS)%NS;})()", 0),
             ('afsluitdijk_sluis', 'afsluitdijk', "(()=>{let b=0;for(let i=0;i<NS;i++)if(HT[i]>HT[b])b=i;return b-40;})()", 0),
             ('haven_viaduct', 'haven', "(()=>{let b=0;for(let i=0;i<NS;i++)if(HT[i]>HT[b])b=i;return b-40;})()", 0)]
    for name, tr, idx, lat in SPOTS:
        if tracks and tr not in tracks:
            continue
        s.ev(f"toMenu(-1);settings.track='{tr}';settings.mode='time';loadTrack('{tr}','fwd');applyEnv('day','dry');startRace();0"); s.step(4.5, False)
        i = s.ev(idx)
        s.ev(f"state='racing';resetPlayer((({i})%NS+NS)%NS,{lat});snapCamera();0"); s.step(1.6)
        s.ev("$('lights').hidden=true;$('count').hidden=true;$('msg').hidden=true;0"); s.pg.wait_for_timeout(1200); shot(s, f'spot_{name}.png')
    # free-camera overviews for structures you cannot judge from behind the car: js returns [eye x,y,z, look-at x,y,z]
    PYLON = "(()=>{let b=0;for(let i=0;i<NS;i++)if(HT[i]>HT[b])b=i;return b;})()"
    VIEWS = [('zeeland_kering_boven', 'zeeland', "[760,160,120,760,10,-110]"),
             ('rotterdam_pyloon_zij', 'rotterdam', f"(()=>{{const i={PYLON},p=P[i],r=R[i],t=T[i],h=HT[i];return [p.x+r.x*75-t.x*50,h+10,p.z+r.z*75-t.z*50,p.x,h+30,p.z];}})()"),
             ('rotterdam_pyloon_dek', 'rotterdam', f"(()=>{{const i={PYLON},p=P[i],t=T[i],h=HT[i];return [p.x-t.x*55,h+3,p.z-t.z*55,p.x,h+14,p.z];}})()"),
             ('grachten_gevels', 'grachten', "(()=>{const i=140,p=P[i],t=T[i],r=R[i];return [p.x-r.x*30-t.x*10,45,p.z-r.z*30-t.z*10,p.x+r.x*14+t.x*25,10,p.z+r.z*14+t.z*25];})()")]
    for name, tr, js in VIEWS:
        if tracks and tr not in tracks:
            continue
        s.ev(f"toMenu(-1);settings.track='{tr}';settings.mode='time';loadTrack('{tr}','fwd');applyEnv('day','dry');startRace();0"); s.step(4.5, False)
        s.ev(f"state='racing';window.__v=({js});window.__pc=window.__pc||placeCam;placeCam=function(){{camPos.set(__v[0],__v[1],__v[2]);camLook.set(__v[3],__v[4],__v[5]);}};"
             "$('lights').hidden=true;$('count').hidden=true;$('msg').hidden=true;updateCamera(0);renderer.render(scene,camera);0")
        s.pg.wait_for_timeout(1500); shot(s, f'spot_{name}.png'); s.ev("placeCam=window.__pc;0")
    s.ev("toMenu(-1);enterPodium([{name:'Henk',sub:'0:53,4',carId:'muscle',color:'#f36f21'},{name:'Jij',sub:'+0,9 s',carId:'gt',color:'#d62a2a',me:true},{name:'Daan',sub:'+1,1 s',carId:'sedan',color:'#1d4f9e'}],'HAVENRACE');0")
    s.pg.wait_for_timeout(2500); shot(s, 'podium.png'); s.ev('leavePodium();toMenu(-1);0')
    s.ev("homePanel('garage');0"); s.pg.wait_for_timeout(1500); shot(s, 'garage.png')
    s.ev("garTab('look');0"); s.pg.wait_for_timeout(500); shot(s, 'garage_uiterlijk.png')
    for st, nm in [(2, 'modus'), (0, 'auto'), (1, 'baan')]:
        s.ev(f"homePanel('main');menuFlow='quick';showMenu({st});0"); s.pg.wait_for_timeout(700); shot(s, f'menu_{nm}.png')
    print('JS-fouten:', s.errs[:5] or 'geen')
