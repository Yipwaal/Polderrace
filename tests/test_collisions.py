"""Collision physics self-test (circuit, 2 bots, fixed random seed).

- a light side tap at equal speed must NOT spin the bot or the player (bot yaw < 6 deg, player spin < 0.3)
- a PIT manoeuvre on the rear corner MUST spin the bot (bot yaw > 60 deg)
- 30 random light taps: none may be violent (bot yaw < 10 deg, player spin < 0.6)
"""
import json, random
from lib import Session, Report, DEFAULT

rep = Report('botsingen')
with Session(dict(DEFAULT, track='circuit', bots=2, laps=5), w=300, h=200) as s:
    s.ev("startRace();0"); s.step(4.5, False)
    s.ev("setupBots(0,[{name:'A',type:'gt',color:'#ffffff'},{name:'B',type:'gt',color:'#222222'}]);bots.forEach(b=>{b.acc=15;b.aLat=10;b.brk=20;});0")
    s.ev(r"""window.__scn=(o)=>{paused=true;state='racing';$('lights').hidden=true;{let x=12345;Math.random=()=>{x=(x*1103515245+12345)%2147483648;return x/2147483648;};}
     const i0=40,A=bots[0],B=bots[1];
     const setBot=(b,s,lat,v)=>{b.s=s;b.lat=lat;b.gridLat=lat;b.lap=0;b.speed=v;b.cur=v;b.vmax=v;b.lp=0;b.latV=0;b.spin=0;b.yawOff=0;b.spun=false;b.yawK=0;b.slideT=0;b.passT=0;b.slowT=0;b.mistT=1e9;b.contactT=0;b.noAvoid=true;poseOnTrack(b.m.g,b.s,b.lat,0);};
     setBot(A,i0*SPC,o.botLat,o.botV);setBot(B,(i0*SPC+900)%TRACK_LEN,0,o.botV);
     const a=trackAt(i0*SPC+o.pDs);player.pos.set(a.px+a.rx*o.pLat,0,a.pz+a.rz*o.pLat);player.idx=i0;player.heading=Math.atan2(a.tx,a.tz)+o.pAng;player.speed=o.pV;player.spin=0;player.slide.x=player.slide.z=0;player.steer=0;locatePlayer();
     while(player.gear<6&&player.speed>gearTop(player.gear)*0.9)player.gear++;
     const m={botYaw:0,botLp:0,pSpin:0,pSlide:0,botDLat:0},lat0=A.lat;
     for(let k=0;k<120*o.T;k++){const th=headingOf(T[player.idx]);const want=th+(k<o.steerFrames?o.pAng:clamp((player.lat-o.pLat)*0.12,-0.12,0.12));const df=((want-player.heading+Math.PI)%(2*Math.PI)+2*Math.PI)%(2*Math.PI)-Math.PI;
       pad.steer=clamp(-df*4,-1,1);kb.up=player.speed<o.pV;update(1/120);
       m.botYaw=Math.max(m.botYaw,Math.abs(A.yawOff||0));m.botLp=Math.max(m.botLp,Math.abs(A.lp));m.pSpin=Math.max(m.pSpin,Math.abs(player.spin||0));m.pSlide=Math.max(m.pSlide,Math.hypot(player.slide.x,player.slide.z));m.botDLat=Math.max(m.botDLat,Math.abs(A.lat-lat0));}
     kb.up=false;pad.steer=0;m.botYaw=+(m.botYaw*57.3).toFixed(0);for(const k in m)m[k]=+(+m[k]).toFixed(2);return JSON.stringify(m);};0""")

    def sc(prm):
        return json.loads(s.pg.evaluate("o=>__ev('__scn')(o)", prm))

    m = sc(dict(botLat=1.9, botV=30, pDs=0, pLat=-0.35, pV=30, pAng=-0.035, steerFrames=90, T=3))
    rep.check(m['botYaw'] < 6 and m['pSpin'] < 0.3 and m['botLp'] < 2, 'lichte zijtik: niemand spint', json.dumps(m))
    m = sc(dict(botLat=1.9, botV=30, pDs=-3.6, pLat=-1.9, pV=33, pAng=-0.3, steerFrames=24, T=6))
    rep.check(m['botYaw'] > 60, 'PIT op achterhoek: bot spint', json.dumps(m))
    random.seed(7); bad = []
    for n in range(30):
        side = random.choice([-1, 1]); ds = random.uniform(-4.2, 4.2); close = random.uniform(0.3, 1.5); v = random.uniform(18, 40)
        m = sc(dict(botLat=side*1.9, botV=v, pDs=ds, pLat=side*(1.9-2.3), pV=v, pAng=-side*close/v, steerFrames=int(random.uniform(30, 70)), T=2.5))
        if m['botYaw'] >= 10 or m['pSpin'] >= 0.6:
            bad.append((n, m))
    rep.check(not bad, '30 willekeurige lichte tikjes, geen te heftige reactie', str(bad[:3]))
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
