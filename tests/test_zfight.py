"""Z-fighting (flicker) detector: two visible faces of boxes/planes in the same plane that overlap.

Checks every track in both directions (decoration differs per direction: signs, start/finish, seeded placement), the garage room, the podium, every car model and every tuning variant
(wing / rim style / start number / stripes). Pairs of the same mesh+material are ignored (invisible).
A hit list shows: count, area, the two colours, the two objects (size @ world position).
Fix a hit by moving one face >= 2 cm (the renderer uses a logarithmic depth buffer, polygonOffset does NOT work).
The repeated objects the game draws with inst() (houses, piers, fences, sheep, ...) are checked too: their geometry is a
clone, which three r128 turns into a plain BufferGeometry, so zf.js recognises boxes by their shape. --geen-inst skips them.
The cars are lofted skins plus merged detail sets (not boxes), so they are also checked triangle by triangle (__zfTris in zf.js).

usage: python tests/test_zfight.py [tracks|none] [--no-cars] [--geen-inst] [--fwd]   (--fwd: only the forward direction)
"""
import sys, collections
from lib import Session, Report, DEFAULT, TRACKS

args = [a for a in sys.argv[1:] if not a.startswith('--')]
tracks = [] if args and args[0] == 'none' else (args[0].split(',') if args else TRACKS)

DESC = ("window.__desc=(root,id)=>{let o=null;root.traverse(x=>{if(x.id===id)o=x;});if(!o)return '?';const p=o.geometry.parameters||{},v=new THREE.Vector3();"
        "o.getWorldPosition(v);return (o.isInstancedMesh?'INST x'+o.count+' ':'')+[p.width,p.height,p.depth].map(x=>x&&+x.toFixed(2)).join('x')+' @'+[v.x,v.y,v.z].map(x=>x.toFixed(1)).join(',');};0")


def summarize(s, root_expr, r):
    agg = collections.Counter(); area = collections.Counter(); ex = {}
    for h in r['top']:
        k = (h['a'].split('[')[0], h['b'].split('[')[0], h['ca'], h['cb']); agg[k] += 1; area[k] += h['area']; ex.setdefault(k, h['at'])
    lines = []
    for k, c in sorted(agg.items(), key=lambda kv: -area[kv[0]])[:5]:
        da = s.ev(f"__desc({root_expr},{int(k[0].split('#')[1])})"); db = s.ev(f"__desc({root_expr},{int(k[1].split('#')[1])})")
        lines.append(f"{c}x opp {area[k]:.2f} #{k[2]} {da} <-> #{k[3]} {db} bij {ex[k]}")
    return ' | '.join(lines)


rep = Report('z-fighting (flikkerende vlakken)')
with Session(DEFAULT, w=400, h=260) as s:
    s.ev(DESC)
    for tr in tracks:
        for d in (['fwd'] if '--fwd' in sys.argv else ['fwd', 'rev']):
            s.ev(f"loadTrack('{tr}','{d}');0")
            r = s.ev("__zfight(world,{top:100000,visibleOnly:true,inst:%s})" % ('false' if '--geen-inst' in sys.argv else 'true'))
            rep.check(r['hits'] == 0, f'baan {tr}/{d}', summarize(s, 'world', r) if r['hits'] else f"{r['boxes']} boxen")
    if tracks is not None:
        s.ev("homePanel('garage');0")
        r = s.ev("__zfight(garageRoom,{top:100000,visibleOnly:true,y0:0})")
        rep.check(r['hits'] == 0, 'garage', summarize(s, 'garageRoom', r) if r['hits'] else '')
        s.ev("homePanel('main');enterPodium([{name:'A',carId:'gt',color:'#ff0000'},{name:'B',carId:'hyper',color:'#00ff00'},{name:'C',carId:'hatch',color:'#0000ff'}],'TEST');0")
        r = s.ev("__zfight(podiumRoom,{top:100000,visibleOnly:true,y0:0})")
        rep.check(r['hits'] == 0, 'podium', summarize(s, 'podiumRoom', r) if r['hits'] else '')
        s.ev("leavePodium();0")
    if '--no-cars' not in sys.argv:
        r = s.ev("""(()=>{const out=[];const types=Object.keys(CARS).concat(['truck','van','tractor','traffic-hatch']);
          for(const t of types){const m=t==='truck'?makeTruck():t==='van'?makeVan():t==='tractor'?makeTractor():t==='traffic-hatch'?buildHatchTraffic(0x2f6db3):buildCar(t,new THREE.Color(0xd62a2a));
            const G=new THREE.Group();G.add(m.g);const z=__zfight(G,{top:5,visibleOnly:true});if(z.hits)out.push(t+': '+z.hits+' '+z.top.slice(0,2).map(h=>h.ca+'/'+h.cb+'@'+h.at.join(',')).join(' | '));
            const q=__zfTris(G,{top:2});if(q.hits)out.push(t+' (driehoeken): '+q.hits+' '+q.top.map(h=>h.ca+'/'+h.cb+'@'+h.at.join(',')).join(' | '));disposeObj(m.g);}
          return out;})()""")
        rep.check(not r, 'alle automodellen + verkeer', '; '.join(r))
        r = s.ev("""(()=>{const out=[];const wings=Object.keys(WINGS),rims=Object.keys(RIMSTYLES),ex=Object.keys(EXHAUSTS),st=Object.keys(STRIPES);
          for(const t of Object.keys(CARS))for(let v=0;v<5;v++){const u=carUp(t),keep=JSON.stringify(u);
            Object.assign(u,{wing:wings[v%wings.length],rimStyle:rims[v%rims.length],exhaust:ex[v%ex.length],stripe:st[(v+1)%st.length],num:v?27:0});
            const m=buildCar(t,new THREE.Color(settings.color));styleCar(m,t);const G=new THREE.Group();G.add(m.g);const z=__zfight(G,{top:3,visibleOnly:true});
            if(z.hits)out.push(t+'/'+u.wing+'/'+u.rimStyle+'/'+u.exhaust+': '+z.hits+' '+z.top.slice(0,2).map(h=>h.ca+'/'+h.cb+'@'+h.at.join(',')).join(' | '));
            const q=__zfTris(G,{top:2});if(q.hits)out.push(t+'/'+u.wing+'/'+u.rimStyle+'/'+u.stripe+' (driehoeken): '+q.hits+' '+q.top.map(h=>h.ca+'/'+h.cb+'@'+h.at.join(',')).join(' | '));
            Object.assign(u,JSON.parse(keep));disposeObj(m.g);}
          return out;})()""")
        rep.check(not r, 'alle getunede varianten (spoiler, velgen, uitlaat, striping, nummer)', '; '.join(r[:6]))
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
