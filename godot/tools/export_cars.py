"""Golden data of the HTML game's CARS for the Godot port: godot/tests/golden/cars.json

For every model (and the traffic hatchback, van, truck and tractor) built by the HTML game itself, plus a few looks/tuning
variants (styleCar with a garage entry), every mesh of the car in traversal order:
  [triangle corners, xmin, ymin, zmin, xmax, ymax, zmax (car space, all vertices), [material colour per used group], kind, visible]
  kind = L (Lambert) / P (Phong) / B (Basic)
and the object's fields (len, wid, rc, off, wingY, wingZ, wheel radii).
The Godot test tests/test_cars.gd builds the same cars and compares.
usage: python godot/tools/export_cars.py
"""
import json, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT, CAR_IDS

# looks/tuning variants (garage entries for styleCar); the same table is in tests/test_cars.gd
VARIANTS = {
    'num': {'num': 7},
    'tune': {'wing': 'gt', 'exhaust': 'sport', 'rimStyle': 'spoke', 'rim': 'gold', 'stripe': 'white'},
    'duck': {'wing': 'duck', 'exhaust': 'dual', 'rimStyle': 'dish', 'rim': 'black', 'stripe': 'none', 'num': 12},
    'center': {'exhaust': 'center', 'stripe': 'yellow', 'num': 3},
}

DUMP = r"""(m)=>{const out=[],g=m.g;g.updateMatrixWorld(true);const v=new THREE.Vector3(),r=x=>+x.toFixed(4);
  const kind=t=>t==='MeshLambertMaterial'?'L':t==='MeshPhongMaterial'?'P':'B';
  g.traverse(o=>{if(!o.isMesh)return;const geo=o.geometry,pa=geo.attributes.position;let mn=[1e9,1e9,1e9],mx=[-1e9,-1e9,-1e9];
    for(let i=0;i<pa.count;i++){v.fromBufferAttribute(pa,i).applyMatrix4(o.matrixWorld);const a=[v.x,v.y,v.z];for(let k=0;k<3;k++){mn[k]=Math.min(mn[k],a[k]);mx[k]=Math.max(mx[k],a[k]);}}
    const tri=geo.index?geo.index.count:pa.count,mats=Array.isArray(o.material)?o.material:[o.material];
    let used=[0];if(Array.isArray(o.material)){used=[...new Set(geo.groups.map(q=>q.materialIndex))].sort((a,b)=>a-b);}
    out.push([tri,...mn.map(r),...mx.map(r),used.map(i=>mats[i].color.getHex()),kind(mats[used[0]].type),o.visible]);});
  return {meshes:out,len:m.len,wid:m.wid,rc:m.rc,off:m.off||0,wingY:m.wingY===undefined?null:r(m.wingY),wingZ:m.wingZ===undefined?null:m.wingZ,wheels:m.wheels.map(w=>w.r)};}"""

out = {}
with Session(dict(DEFAULT, bots=0), w=320, h=200) as s:
    s.ev(f"window.__dump={DUMP};0")
    for t in CAR_IDS:
        out[f'{t}/base'] = s.ev(f"(()=>{{const m=buildCar('{t}',new THREE.Color('#d62a2a'));return __dump(m);}})()")
        for vn, u in VARIANTS.items():
            out[f'{t}/{vn}'] = s.ev(f"""(()=>{{const keep=garage.cars['{t}'];garage.cars['{t}']=Object.assign({{eng:0,turbo:0,tyre:0,brake:0,body:0,rim:'silver',stripe:'std',num:0,wing:'std',rimStyle:'std',exhaust:'std'}},{json.dumps(u)});
              const m=buildCar('{t}',new THREE.Color('#1d4f9e'));styleCar(m,'{t}');if(keep)garage.cars['{t}']=keep;else delete garage.cars['{t}'];return __dump(m);}})()""")
        print(t, len(out[f'{t}/base']['meshes']), 'meshes')
    out['traffic/hatch'] = s.ev("__dump(buildHatchTraffic(0x2f6db3))")
    out['traffic/van'] = s.ev("__dump(makeVan())")
    out['traffic/truck'] = s.ev("(()=>{const keep=rnd;rnd=seeded(5);try{return __dump(makeTruck());}finally{rnd=keep;}})()")
    out['traffic/tractor'] = s.ev("__dump(makeTractor())")
path = ROOT / 'godot/tests/golden/cars.json'
path.write_text(json.dumps(out, separators=(',', ':')))
print('ok', len(out), 'cars')
