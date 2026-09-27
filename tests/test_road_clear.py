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
  const CLOSED=['BoxGeometry','CylinderGeometry','SphereGeometry','ConeGeometry','TorusGeometry','OctahedronGeometry','IcosahedronGeometry','DodecahedronGeometry'];
  /* instanced meshes hold a clone of their geometry, and in three r128 a clone is a plain BufferGeometry: recognise boxes by shape */
  const boxLike=g=>{const pa=g.attributes.position;if(g.type!=='BufferGeometry'||!pa||pa.count!==24||!g.index||g.index.count!==36)return false;if(!g.boundingBox)g.computeBoundingBox();const b=g.boundingBox;
    for(let i=0;i<24;i++)for(const [c,lo,hi] of [[pa.getX(i),b.min.x,b.max.x],[pa.getY(i),b.min.y,b.max.y],[pa.getZ(i),b.min.z,b.max.z]])if(Math.abs(c-lo)>1e-5&&Math.abs(c-hi)>1e-5)return false;return true;};
  const closed=o=>{const g=o.geometry,p=g.parameters||{};if(boxLike(g))return true;if(!CLOSED.includes(g.type)||p.openEnded)return false;
    if(g.type==='SphereGeometry'&&((p.phiLength!==undefined&&p.phiLength<6.28)||(p.thetaLength!==undefined&&p.thetaLength<3.14)))return false;return true;};
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

rep = Report('rijbaan vrij (niets op of laag boven de weg)')
with Session(DEFAULT, w=400, h=260) as s:
    for tr in tracks:
        for d in dirs:
            s.ev(f"loadTrack('{tr}','{d}');0")
            r = s.ev(JS)
            detail = '' if not r['n'] else ' | '.join(f"{g['n']}x {g['what']} tot {g['maxUp']} m hoog, index {g['iFrom']}-{g['iTo']} (bij x={g['at'][0]} z={g['at'][1]})" for g in r['groups'][:5])
            rep.check(r['n'] == 0, f'{tr}/{d}', detail)
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
