"""Golden data of the HTML game's track BUILD (decor) for the Godot port: godot/tests/golden/build.json

Per track and direction:
  rnd   number of rnd() calls in each stage (build, details, veluwe, dress): the Godot builders must draw the seeded
        random numbers in exactly the same order, or every later object lands somewhere else
  inst  every inst() call in order: [count, x, y, z of the first instance, x, y, z of the last]
  meshes number of Mesh/Line objects in the world (instanced meshes not counted)
The Godot test tests/test_build.gd compares against it.
usage: python godot/tools/export_build.py [track,...]
"""
import json, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT, TRACKS

tracks = sys.argv[1].split(',') if len(sys.argv) > 1 else TRACKS
path = ROOT / 'godot/tests/golden/build.json'
out = json.loads(path.read_text()) if path.exists() else {}
with Session(dict(DEFAULT, bots=0), w=320, h=200) as s:
    for tr in tracks:
        for d in ['fwd', 'rev']:
            r = s.ev(f"""(()=>{{const id='{tr}';clearWorld();TRACK_ID=id;TRACK_DIR='{d}';TRK=TRACKS[id];trackLights=[];lampMats=[];hillMats=[];roadMats=[];winMats=[];reflMats=[];beaconMats=[];
              computeTrack(TRK,'{d}');const base=seeded(TRK.seed);let n=0;rnd=()=>{{n++;return base();}};
              const log=[],_inst=inst,f=v=>+v.toFixed(3),v=new THREE.Vector3();
              inst=(geo,mat,mats,colors,cast)=>{{if(mats.length){{v.setFromMatrixPosition(mats[0]);const a=[mats.length,f(v.x),f(v.y),f(v.z)];v.setFromMatrixPosition(mats[mats.length-1]);a.push(f(v.x),f(v.y),f(v.z));log.push(a);}}return _inst(geo,mat,mats,colors,cast);}};
              const R={{}},st=(k,fn)=>{{const a=n;fn();R[k]=n-a;}};
              veluweSheep=[];veluwePicnic=[];veluweGround=[];veluweTF=null;pavTaken=[];
              try{{st('build',BUILDERS[id]);st('details',()=>{{if(DETAILS[id])DETAILS[id]();}});st('veluwe',finishVeluweDetails);st('dress',()=>dressTrack(id));}}
              finally{{inst=_inst;rnd=Math.random;}}
              let meshes=0;world.traverse(o=>{{if((o.isMesh&&!o.isInstancedMesh)||o.isLine)meshes++;}});
              return JSON.stringify({{rnd:R,inst:log,meshes}});}})()""")
            out[f'{tr}/{d}'] = json.loads(r)
            o = out[f'{tr}/{d}']
            print(tr, d, o['rnd'], len(o['inst']), 'inst-calls', o['meshes'], 'meshes')
        s.ev("loadTrack(settings.track);0")
path.write_text(json.dumps(out, separators=(',', ':')))
print('ok')
