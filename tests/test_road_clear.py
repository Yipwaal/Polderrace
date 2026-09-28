"""Road clearance: nothing may stick out of the asphalt or hang low over the driving lanes.

For every track (both directions) rays are cast straight down over the whole road width, from
CLEAR metres above the road surface. Anything a ray hits that is higher than 12 cm above the road
(the road ribbon, kerbs, start line and grime sit below that) is an obstruction: a quay wall through
the road, a dune on the asphalt, a bridge leg in a lane, a beam across the road, ...
Structures higher than CLEAR (gantries, checkpoint banners, bridge decks overhead) are allowed.
The downward rays probe the lanes every 2nd track sample (4 m), with --dicht every sample (2 m, slower, finds thinner things).
A second ray goes straight UP from just above the asphalt at every sample (2 m): when the road surface lies inside a closed
solid (a pylon leg or pillar taller than CLEAR, where the downward ray starts inside the object and sees nothing), that ray
crosses the object an odd number of times, and that is an obstruction too.
The first 1.5 m of verge next to the asphalt is checked too (cars run wide there), but only for big
things: anything at least 3 m across that rises more than 0.6 m (a dune, a wall, a building). Posts,
bollards, benches, planters and flowers there are fine.
On Dorp the cafe terraces are checked as well: tables at least 2.9 m apart, parasols not over the road; and the pavement:
bikes, lamp posts, planters and benches may not stand in each other.

usage: python tests/test_road_clear.py [track,track,...] [--rev] [--dicht]
"""
import sys
from lib import Session, Report, DEFAULT, TRACKS

CLEAR = 4.6   # free height a car needs above the road
tracks = [a for a in sys.argv[1:] if not a.startswith('--')]
tracks = tracks[0].split(',') if tracks else TRACKS
dirs = ['fwd', 'rev'] if '--rev' in sys.argv else ['fwd']
DSTEP = 1 if '--dicht' in sys.argv else 2

JS = r"""(()=>{world.updateMatrixWorld(true);const meshes=[],inst=[];
  world.traverse(o=>{if(!(o.isMesh||o.isInstancedMesh)||!o.visible)return;let v=true;o.traverseAncestors(a=>{if(!a.visible)v=false;});if(!v)return;
    const m=Array.isArray(o.material)?o.material[0]:o.material;if(m&&(m.transparent&&m.opacity<0.3))return;(o.isInstancedMesh?inst:meshes).push(o);});
  /* instanced meshes: the game gives their geometry a world-space bounding sphere (for culling), which breaks three's own
     per-instance raycast. Put every instance in a 20 m grid with its own world sphere and raycast those one by one. */
  const G=20,grid=new Map(),im4=new THREE.Matrix4(),w4=new THREE.Matrix4(),sp=new THREE.Sphere(),saved=[];
  for(const o of inst){const g=o.geometry;saved.push([g,g.boundingSphere]);new THREE.Box3().setFromBufferAttribute(g.attributes.position).getBoundingSphere(sp);g.boundingSphere=sp.clone();
    for(let k=0;k<o.count;k++){o.getMatrixAt(k,im4);w4.multiplyMatrices(o.matrixWorld,im4);const c=g.boundingSphere.center.clone().applyMatrix4(w4),r=g.boundingSphere.radius*w4.getMaxScaleOnAxis();
      const it={o,k,m:w4.clone(),c,r};for(let gx=Math.floor((c.x-r)/G);gx<=Math.floor((c.x+r)/G);gx++)for(let gz=Math.floor((c.z-r)/G);gz<=Math.floor((c.z+r)/G);gz++){const key=gx+','+gz;if(!grid.has(key))grid.set(key,[]);grid.get(key).push(it);}}}
  const tmp=new THREE.Mesh();tmp.matrixAutoUpdate=false;
  const castInst=(rc,x,z,out)=>{const l=grid.get(Math.floor(x/G)+','+Math.floor(z/G));if(!l)return;for(const it of l){const dx=x-it.c.x,dz=z-it.c.z;if(dx*dx+dz*dz>it.r*it.r)continue;
      tmp.geometry=it.o.geometry;tmp.material=it.o.material;tmp.matrixWorld.copy(it.m);const hs=[];tmp.raycast(rc,hs);for(const h of hs){h.object=it.o;h.instanceId=it.k;h.mat=it.m;out.push(h);}}};
  const rc=new THREE.Raycaster(),dn=new THREE.Vector3(0,-1,0),o=new THREE.Vector3(),hits=[];const CLEAR=%CLEAR%;
  const bs=new THREE.Vector3();
  const foot=(q)=>{const ob=q.object,g=ob.geometry;if(!g.boundingBox)g.computeBoundingBox();g.boundingBox.getSize(bs);const w=q.mat?q.mat:ob.matrixWorld;
    const e=w.elements,sx=Math.hypot(e[0],e[1],e[2]),sz=Math.hypot(e[8],e[9],e[10]);return Math.max(bs.x*sx,bs.z*sz);};
  const lats=[];{const lim=ROAD_HALF-0.4;for(let lat=-lim;lat<=lim+1e-6;lat+=lim/3)lats.push([lat,'rijbaan']);
    for(const sg of [-1,1])for(const d of [0.4,0.9,1.4])if(ROAD_HALF+d<SHOULDER)lats.push([sg*(ROAD_HALF+d),'berm']);}
  for(let i=0;i<NS;i+=%DSTEP%){for(const [lat,zone] of lats){if(zone==='berm'&&i%4)continue;const [x,z]=onTrack(i,lat),h=hAt(i,lat);
      o.set(x,h+CLEAR,z);rc.set(o,dn);rc.far=CLEAR+0.5;const hs=rc.intersectObjects(meshes,false);castInst(rc,x,z,hs);hs.sort((a,b)=>a.distance-b.distance);
      for(const q of hs){const up=q.point.y-h;if(up<=0.12)break;if(zone==='berm'&&(up<0.6||foot(q)<3))continue;const ob=q.object,p=ob.geometry.parameters||{};
        const col=ob.material&&!Array.isArray(ob.material)&&ob.material.color?ob.material.color.getHexString():'';
        hits.push({i,lat:+lat.toFixed(1),up:+up.toFixed(2),what:zone+': '+(ob.isInstancedMesh?'inst ':'')+ob.geometry.type.replace('Geometry','')+(p.width?' '+[p.width,p.height,p.depth].map(v=>v===undefined?'':+(+v).toFixed(2)).join('x'):'')+' #'+col,x:+x.toFixed(0),z:+z.toFixed(0)});break;}}}
  /* blind spot of the rays above: a ray that STARTS inside a solid (a pylon leg, a pillar, a thick wall taller than CLEAR) sees
     only back faces and hits nothing. So also cast a ray straight UP from just above the asphalt through all closed solids,
     both faces counted: an odd number of crossings of one object means the road surface lies inside that object. */
  /* a solid is any watertight mesh: after merging equal positions every edge belongs to exactly two triangles. That also
     covers instanced meshes, whose geometry is a clone (in three r128 a plain BufferGeometry without type or parameters),
     and it leaves out planes, ribbons and open-ended cylinders. */
  const wt=new Map();
  const closed=o=>{const g=o.geometry;if(wt.has(g))return wt.get(g);const pa=g.attributes.position;let ok=false;
    if(pa&&pa.count<=20000){const id=new Map(),vid=[];for(let i=0;i<pa.count;i++){const k=Math.round(pa.getX(i)*1e4)+','+Math.round(pa.getY(i)*1e4)+','+Math.round(pa.getZ(i)*1e4);if(!id.has(k))id.set(k,id.size);vid.push(id.get(k));}
      const ix=g.index?g.index.array:null,n=ix?ix.length:pa.count,ec=new Map();let tri=0;
      for(let t=0;t+2<n;t+=3){const A=vid[ix?ix[t]:t],B=vid[ix?ix[t+1]:t+1],C=vid[ix?ix[t+2]:t+2];if(A===B||B===C||A===C)continue;tri++;
        for(const [u,v] of [[A,B],[B,C],[C,A]]){const k=u<v?u*1e6+v:v*1e6+u;ec.set(k,(ec.get(k)||0)+1);}}
      ok=tri>0;for(const c of ec.values())if(c!==2){ok=false;break;}}
    wt.set(g,ok);return ok;};
  const sides=new Map();for(const o of meshes.concat(inst))for(const m of (Array.isArray(o.material)?o.material:[o.material]))if(m&&!sides.has(m)){sides.set(m,m.side);m.side=THREE.DoubleSide;}
  const solidM=meshes.filter(closed),upV=new THREE.Vector3(0,1,0);
  for(let i=0;i<NS;i++){for(const [lat,zone] of lats){if(zone!=='rijbaan')continue;const [x,z]=onTrack(i,lat),h=hAt(i,lat);
      o.set(x,h+0.13,z);rc.set(o,upV);rc.far=400;const hs=rc.intersectObjects(solidM,false);castInst(rc,x,z,hs);const cnt=new Map();
      for(const q of hs){if(!closed(q.object))continue;const k=q.object.id+':'+(q.instanceId===undefined?'':q.instanceId),l=cnt.get(k)||[];
        if(!l.some(d=>Math.abs(d-q.distance)<1e-3))l.push(q.distance);cnt.set(k,l);}
      for(const [k,l] of cnt){if(l.length%2===0)continue;const q=hs.find(q=>q.object.id+':'+(q.instanceId===undefined?'':q.instanceId)===k),ob=q.object,p=ob.geometry.parameters||{};
        const col=ob.material&&!Array.isArray(ob.material)&&ob.material.color?ob.material.color.getHexString():'';
        hits.push({i,lat:+lat.toFixed(1),up:+(Math.min(...l)+0.13).toFixed(2),what:zone+' (weg ligt binnenin): '+(ob.isInstancedMesh?'inst ':'')+ob.geometry.type.replace('Geometry','')+(p.width?' '+[p.width,p.height,p.depth].map(v=>v===undefined?'':+(+v).toFixed(2)).join('x'):'')+' #'+col,x:+x.toFixed(0),z:+z.toFixed(0)});break;}}}
  for(const [m,sd] of sides)m.side=sd;
  for(const [g,b] of saved)g.boundingSphere=b;
  const groups={};for(const h of hits){const k=h.what;(groups[k]=groups[k]||[]).push(h);}
  return {n:hits.length,groups:Object.entries(groups).map(([k,l])=>({what:k,n:l.length,iFrom:Math.min(...l.map(h=>h.i)),iTo:Math.max(...l.map(h=>h.i)),maxUp:Math.max(...l.map(h=>h.up)),at:[l[0].x,l[0].z]})).sort((a,b)=>b.n-a.n)};})()""".replace('%CLEAR%', str(CLEAR)).replace('%DSTEP%', str(DSTEP))

# Dorp cafe terraces (4 tables with parasols of 2.8 m across): tables at least 2.9 m apart (closer and the parasols overlap
# and the chairs stick into the next table) and the parasol rim at least 0.3 m past the edge of the road.
STOEP = r"""(()=>{world.updateMatrixWorld(true);const out=[],m=new THREE.Matrix4(),P=new THREE.Vector3(),Q=new THREE.Quaternion(),S=new THREE.Vector3(),E=new THREE.Euler();
  /* footprints on the pavement as rectangles: [kind,x,z,yaw,half length (local x),half width (local z)] */
  world.traverse(o=>{if(!o.isInstancedMesh)return;const c=o.material.color&&o.material.color.getHex(),cyl=o.geometry.attributes.position.count>24;
    for(let k=0;k<o.count;k++){o.getMatrixAt(k,m);m.premultiply(o.matrixWorld);m.decompose(P,Q,S);E.setFromQuaternion(Q,'YXZ');let r=null;
      if(c===0x2b2f36&&!cyl&&Math.abs(S.x-1.1)<0.01&&Math.abs(S.y-0.08)<0.01)r=['fiets',0.86,0.06];
      else if(c===0x6b4a2e&&!cyl&&Math.abs(S.x-1.4)<0.01)r=['plantenbak',0.7,0.35];
      else if(c===0x7a5a3a&&!cyl&&Math.abs(S.z-1.8)<0.01&&Math.abs(S.y-0.08)<0.01)r=['bankje',0.25,0.9];
      else if(c===0x23382c&&cyl&&P.y>2)r=['lantaarnpaal',0.1,0.1];
      if(r)out.push([r[0],P.x,P.z,E.y,r[1],r[2]]);}});
  const ax=a=>[[Math.cos(a[3]),-Math.sin(a[3])],[Math.sin(a[3]),Math.cos(a[3])]];
  const hit=(a,b)=>{if((a[1]-b[1])**2+(a[2]-b[2])**2>9)return false;const A=ax(a),B=ax(b),dx=b[1]-a[1],dz=b[2]-a[2];
    return A.concat(B).every(([ux,uz])=>{const pa=a[4]*Math.abs(A[0][0]*ux+A[0][1]*uz)+a[5]*Math.abs(A[1][0]*ux+A[1][1]*uz),pb=b[4]*Math.abs(B[0][0]*ux+B[0][1]*uz)+b[5]*Math.abs(B[1][0]*ux+B[1][1]*uz);return Math.abs(dx*ux+dz*uz)<pa+pb-0.01;});};
  const n={},bad=[];for(const q of out)n[q[0]]=(n[q[0]]||0)+1;
  for(let i=0;i<out.length;i++)for(let j=i+1;j<out.length;j++){const a=out[i],b=out[j];if(a[0]===b[0])continue;if(hit(a,b))bad.push(a[0]+'/'+b[0]+' bij '+a[1].toFixed(0)+','+a[2].toFixed(0));}
  return {n,bad};})()"""


TERRAS = r"""(()=>{world.updateMatrixWorld(true);const all=(w,h,d)=>{const r=[],m=new THREE.Matrix4(),s=new THREE.Vector3();world.traverse(o=>{if(!o.isInstancedMesh)return;
    new THREE.Box3().setFromBufferAttribute(o.geometry.attributes.position).getSize(s);if(Math.abs(s.x-w)>0.03||Math.abs(s.y-h)>0.03||Math.abs(s.z-d)>0.03)return;
    for(let k=0;k<o.count;k++){o.getMatrixAt(k,m);r.push([m.elements[12],m.elements[14]]);}});return r;};
  const tb=all(1.046,0.06,1.1),um=all(2.8,0.7,2.8);if(tb.length<4||um.length!==tb.length)return {n:Math.min(tb.length,um.length)};
  const gap=Math.min(...tb.map((p,a)=>Math.min(...tb.filter((_,b)=>b!==a).map(q=>Math.hypot(p[0]-q[0],p[1]-q[1])))));
  const rim=Math.min(...um.map(([x,z])=>{let b=1e9;for(let i=0;i<NS;i++)b=Math.min(b,Math.hypot(P[i].x-x,P[i].z-z));return b-1.4;}));
  return {n:tb.length,gap:+gap.toFixed(2),rim:+rim.toFixed(2),need:ROAD_HALF+0.3};})()"""

rep = Report('rijbaan vrij (niets op of laag boven de weg)')
with Session(DEFAULT, w=400, h=260) as s:
    for tr in tracks:
        for d in dirs:
            s.ev(f"loadTrack('{tr}','{d}');0")
            r = s.ev(JS)
            detail = '' if not r['n'] else ' | '.join(f"{g['n']}x {g['what']} tot {g['maxUp']} m hoog, index {g['iFrom']}-{g['iTo']} (bij x={g['at'][0]} z={g['at'][1]})" for g in r['groups'][:5])
            rep.check(r['n'] == 0, f'{tr}/{d}', detail)
            if tr == 'dorp':
                t = s.ev(TERRAS)
                rep.check(t['n'] >= 4 and t['gap'] >= 2.9 and t['rim'] >= t['need'] - 0.01, f'{tr}/{d} terrassen',
                          f"{t['n']} tafels" + (f", kleinste afstand {t['gap']} m (min 2.9), parasolrand {t['rim']} m van het midden (min {t['need']})" if t['n'] >= 4 else ''))
                q = s.ev(STOEP)
                rep.check(not q['bad'] and q['n'].get('fiets', 0) > 20, f'{tr}/{d} stoep: fietsen, palen, plantenbakken en bankjes los van elkaar',
                          '; '.join(q['bad'][:4]) or str(q['n']))
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
