"""Collision physics self-test (circuit, 2 bots, fixed random seed).

- a light side tap at equal speed must NOT spin the bot or the player (bot yaw < 6 deg, player spin < 0.3)
- a PIT manoeuvre on the rear corner MUST spin the bot (bot yaw > 60 deg)
- 30 random light taps: none may be violent (bot yaw < 10 deg, player spin < 0.6)
- a tap is not a brake: grazing a bot while overtaking or tapping it from behind costs only a few km/h (the old model treated a graze
  as a rear-end crash and the pushed bot braked hard against you: -21 km/h and 17 hits in a row)
- the hitbox is the car: per model the rounded hitbox stays within 9 cm of the body's footprint (convex hull of the body skin), and for
  400 random placements of two cars it reports contact exactly when the bodies touch (8 cm tolerance; the old box: 37 false hits)
"""
import json, random

HITBOX_JS = r'''window.__hb=(()=>{
 /* plan-view footprint of a car model: convex hull (x,z) of the body and cabin skin, mirrors and spoilers left out */
 const hull=pts=>{pts=pts.slice().sort((a,b)=>a[0]-b[0]||a[1]-b[1]);const cr=(o,a,b)=>(a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0]);const lo=[],up=[];
   for(const p of pts){while(lo.length>=2&&cr(lo[lo.length-2],lo[lo.length-1],p)<=0)lo.pop();lo.push(p);}
   for(let i=pts.length-1;i>=0;i--){const p=pts[i];while(up.length>=2&&cr(up[up.length-2],up[up.length-1],p)<=0)up.pop();up.push(p);}up.pop();lo.pop();return lo.concat(up);};
 const foot=id=>{const K=carKit(id),P=[];for(const g of [K.body,K.cab])if(g){const a=g.attributes.position;for(let i=0;i<a.count;i++)P.push([a.getX(i),a.getZ(i)]);}return hull(P);};
 const segD=(p,a,b)=>{const ex=b[0]-a[0],ez=b[1]-a[1],t=clamp(((p[0]-a[0])*ex+(p[1]-a[1])*ez)/(ex*ex+ez*ez||1),0,1);return Math.hypot(p[0]-a[0]-ex*t,p[1]-a[1]-ez*t);};
 const inside=(p,H)=>{let c=false;for(let i=0,j=H.length-1;i<H.length;j=i++){const [xi,zi]=H[i],[xj,zj]=H[j];if((zi>p[1])!==(zj>p[1])&&p[0]<(xj-xi)*(p[1]-zi)/(zj-zi)+xi)c=!c;}return c;};
 const sdist=(p,H)=>{let d=1e9;for(let i=0;i<H.length;i++)d=Math.min(d,segD(p,H[i],H[(i+1)%H.length]));return inside(p,H)?-d:d;}; /* signed: >0 outside */
 /* outline of a hitbox (rounded rectangle, rc=0 is the old sharp box) in the car's own frame */
 const outline=(len,wid,rc,off)=>{const O=[],a=len/2-rc,b=wid/2-rc;for(const [cx,cz,a0] of [[b,a,0],[-b,a,Math.PI/2],[-b,-a,Math.PI],[b,-a,Math.PI*1.5]])for(let k=0;k<=8;k++){const t=a0+k/8*Math.PI/2;O.push([cx+Math.cos(t)*rc,cz+Math.sin(t)*rc+(off||0)]);}return O;};
 /* how well a hitbox fits the body: how far it sticks out of the footprint, and how far the footprint sticks out of it */
 const fit=(id,rc)=>{const m=buildCar(id,new THREE.Color('#fff')),H=foot(id),O=outline(m.len,m.wid,rc===undefined?(m.rc||0):rc,m.off),out=Math.max(...O.map(p=>sdist(p,H))),Hb=hull(O),miss=Math.max(...H.map(p=>sdist(p,Hb)));disposeObj(m.g);return {out:+out.toFixed(3),miss:+miss.toFixed(3)};};
 /* separation of two convex polygons: >0 gap, <0 overlap depth (separating axis) */
 const polyGap=(A,B)=>{let best=-1e9;for(const P of [A,B])for(let i=0;i<P.length;i++){const a=P[i],b=P[(i+1)%P.length],nx=b[1]-a[1],nz=a[0]-b[0],l=Math.hypot(nx,nz)||1;
     let a0=1e9,a1=-1e9,b0=1e9,b1=-1e9;for(const q of A){const d=(q[0]*nx+q[1]*nz)/l;a0=Math.min(a0,d);a1=Math.max(a1,d);}for(const q of B){const d=(q[0]*nx+q[1]*nz)/l;b0=Math.min(b0,d);b1=Math.max(b1,d);}
     best=Math.max(best,Math.max(b0-a1,a0-b1));}
   if(best<=0)return best;let d=1e9;for(const q of A)for(let i=0;i<B.length;i++)d=Math.min(d,segD(q,B[i],B[(i+1)%B.length]));for(const q of B)for(let i=0;i<A.length;i++)d=Math.min(d,segD(q,A[i],A[(i+1)%A.length]));return d;};
 const place=(H,x,z,h)=>H.map(([px,pz])=>[x+px*Math.cos(h)+pz*Math.sin(h),z-px*Math.sin(h)+pz*Math.cos(h)]);
 /* random pairs of cars: the hitbox says contact exactly when the bodies touch (within tol) */
 const pairs=(n,tol)=>{let x=777;const rnd=()=>{x=(x*1103515245+12345)%2147483648;return x/2147483648;};const ids=Object.keys(CARS),F={},M={};for(const id of ids){F[id]=foot(id);const m=buildCar(id,new THREE.Color('#fff'));M[id]={len:m.len,wid:m.wid,rc:m.rc||0,off:m.off||0};disposeObj(m.g);}
   let fp=0,fn=0,ex=[];for(let k=0;k<n;k++){const ia=ids[rnd()*ids.length|0],ib=ids[rnd()*ids.length|0],ha=(rnd()-0.5)*Math.PI*2,hb=(rnd()-0.5)*Math.PI*2,ang=rnd()*Math.PI*2,r=2+rnd()*3.5,xa=Math.sin(ang)*r,za=Math.cos(ang)*r;
     const gap=polyGap(place(F[ia],xa,za,ha),place(F[ib],0,0,hb)),mk=(D,x,z,h)=>({x:x+Math.sin(h)*D.off,z:z+Math.cos(h)*D.off,h,len:D.len,wid:D.wid,rc:D.rc}),ct=pairContact(mk(M[ia],xa,za,ha),mk(M[ib],0,0,hb));
     if(ct&&gap>tol){fp++;if(ex.length<3)ex.push('vals '+ia+'/'+ib+' gat '+gap.toFixed(2));}if(!ct&&gap<-tol){fn++;if(ex.length<3)ex.push('mis '+ia+'/'+ib+' overlap '+(-gap).toFixed(2));}}
   return {fp,fn,ex};};
 return {fit,pairs};})();0'''
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
    # speed before the first contact and 0.5 s after it (gas held all the time), in km/h
    s.ev(r"""window.__tap=(o)=>{const r=JSON.parse(__scn(Object.assign({},o,{T:0.01})));paused=true;state='racing';const A=bots[0];let first=-1,v0=0,b0=0,n=0,prev=false,out=null;
     const i0=40;A.s=i0*SPC;A.lat=o.botLat;A.gridLat=o.botLat;A.speed=A.cur=A.vmax=o.botV;A.lp=A.latV=A.spin=A.yawOff=A.yawK=0;A.spun=false;A.pushDv=0;poseOnTrack(A.m.g,A.s,A.lat,0);
     const a=trackAt(i0*SPC+o.pDs); /* after poseOnTrack: trackAt returns one shared object */
     player.pos.set(a.px+a.rx*o.pLat,0,a.pz+a.rz*o.pLat);player.idx=i0;player.heading=Math.atan2(a.tx,a.tz)+o.pAng;player.speed=o.pV;player.spin=0;player.slide.x=player.slide.z=0;player.steer=0;drift=0;locatePlayer();
     for(let k=0;k<360&&!out;k++){const th=headingOf(T[player.idx]),want=th+(k<o.steerFrames?o.pAng:clamp((player.lat-o.pLat)*0.12,-0.12,0.12)),df=((want-player.heading+Math.PI)%(2*Math.PI)+2*Math.PI)%(2*Math.PI)-Math.PI;
       pad.steer=clamp(-df*4,-1,1);kb.up=true;const pv=player.speed,bv=A.speed;update(1/120);const c=!!pairContact(playerBody(),bodyOf(A));if(c&&!prev)n++;prev=c;
       if(c&&first<0){first=k;v0=pv;b0=bv;}if(first>=0&&k-first===60)out={loss:+((v0-player.speed)*3.6).toFixed(1),bot:+((A.speed-b0)*3.6).toFixed(1),hits:n};}
     kb.up=false;pad.steer=0;return JSON.stringify(out||{loss:99,hits:n});};0""")
    tap = lambda prm: json.loads(s.pg.evaluate("o=>__ev('__tap')(o)", prm))
    m = tap(dict(botLat=1.9, botV=33, pDs=-6, pLat=-0.2, pV=40, pAng=-0.03, steerFrames=80))
    rep.check(m['loss'] < 8 and m['hits'] <= 3, 'schampen bij inhalen remt je niet af', json.dumps(m))
    m = tap(dict(botLat=0, botV=35, pDs=-6, pLat=0, pV=38, pAng=0, steerFrames=0))
    rep.check(m['loss'] < 8 and m['bot'] > 5, 'tikje van achteren: bot gaat mee, jij houdt je snelheid grotendeels', json.dumps(m))
    s.ev(HITBOX_JS)
    fits = {c: s.ev(f"JSON.stringify(__hb.fit('{c}'))") for c in ['hatch', 'rally', 'coupe', 'roadster', 'gt', 'muscle', 'fastback', 'sedan', 'super', 'hyper', 'longtail', 'proto']}
    badfit = {c: f for c, f in fits.items() if json.loads(f)['out'] > 0.09 or json.loads(f)['miss'] > 0.09}
    rep.check(not badfit, 'hitbox valt op de carrosserie (max 9 cm eruit of erin)', str(badfit or fits['gt']))
    pr = json.loads(s.ev("JSON.stringify(__hb.pairs(400,0.08))"))
    rep.check(pr['fp'] == 0 and pr['fn'] == 0, '400 willekeurige plaatsingen: botsing precies als de auto\'s elkaar raken', json.dumps(pr))
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
