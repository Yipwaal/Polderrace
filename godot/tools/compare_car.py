"""Side-by-side picture of one car in the HTML game (left) and the Godot version (right): same model, colour, looks,
camera and light, the car alone (the track's world hidden, its sky and light kept).

python godot/tools/compare_car.py <spec>[,<spec>...] [time] [weather]
  spec = <car>:<variant>:<view>[:<colour>]
    car     a model id (gt, hatch, ...) or traffic-hatch / traffic-van / traffic-truck / traffic-tractor
    variant base, or a looks/tuning set from VARIANTS (num, tune, duck, center)
    view    f3q (front three-quarter), r3q, side, front, rear, top, wheel (front wheel close up), or ex/ey/ez/lx/ly/lz
Output: tests/.out/compare/car_<car>_<variant>_<view>_<time>.png (left HTML, right Godot). Look at it with the Read tool.
Note: the HTML game aims its sun every frame (updateCamera); here it is aimed once at the car, so a night or dusk view gets
that time's sun direction and not the one of the last frame drawn.
"""
import sys, subprocess, pathlib, shutil, json, base64
HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
ROOT = PROJ.parent
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT, OUT
from PIL import Image

VARIANTS = {
    'num': {'num': 7},
    'tune': {'wing': 'gt', 'exhaust': 'sport', 'rimStyle': 'spoke', 'rim': 'gold', 'stripe': 'white'},
    'duck': {'wing': 'duck', 'exhaust': 'dual', 'rimStyle': 'dish', 'rim': 'black', 'stripe': 'none', 'num': 12},
    'center': {'exhaust': 'center', 'stripe': 'yellow', 'num': 3},
}
# camera [ex,ey,ez,lx,ly,lz] from the car's length L, width W and front axle z A (JS expressions)
# (k = L/4.6 for long vehicles, so a truck fits the picture too)
VIEWS = {
    'f3q': "[3.4*k,1.7*k,L/2+3.2*k,0,0.55*k,0.2]",
    'r3q': "[-3.4*k,1.7*k,-(L/2+3.2*k),0,0.55*k,-0.2]",
    'side': "[6.8*k,0.9*k,0,0,0.6*k,0]",
    'front': "[0,1.0*k,L/2+4.6*k,0,0.6*k,0]",
    'rear': "[0,1.0*k,-(L/2+4.6*k),0,0.6*k,0]",
    'top': "[0.001,9*k,0.02,0,0,0]",
    'wheel': "[W/2+1.7,0.7,A+1.5,W/2-0.2,0.35,A]",
}
W, H = 900, 560
OUTD = OUT / 'compare'; OUTD.mkdir(exist_ok=True)
DEFAULT_UP = {'eng': 0, 'turbo': 0, 'tyre': 0, 'brake': 0, 'body': 0, 'rim': 'silver', 'stripe': 'std', 'num': 0, 'wing': 'std', 'rimStyle': 'std', 'exhaust': 'std'}


def main():
    specs = sys.argv[1].split(',') if len(sys.argv) > 1 else ['gt:base:f3q']
    tm = sys.argv[2] if len(sys.argv) > 2 else 'day'
    we = sys.argv[3] if len(sys.argv) > 3 else 'dry'
    jobs = []
    with Session(dict(DEFAULT, bots=0), w=W, h=H, prefs={'quality': 'high'}) as s:
        s.ev(f"toMenu(-1);loadTrack('polder','fwd');applyEnv('{tm}','{we}');0")
        for spec in specs:
            p = spec.split(':')
            car, var, view = p[0], p[1] if len(p) > 1 else 'base', p[2] if len(p) > 2 else 'f3q'
            col = p[3] if len(p) > 3 else ('#d62a2a' if var == 'base' else '#1d4f9e')
            up = VARIANTS.get(var)
            vjs = VIEWS.get(view, '[' + view.replace('/', ',') + ']')
            if car.startswith('traffic-'):
                kind = car.split('-')[1]
                make = {'hatch': f"buildHatchTraffic(new THREE.Color('{col}'))", 'van': 'makeVan()', 'truck': 'makeTruck()', 'tractor': 'makeTractor()'}[kind]
                build = f"const keep=rnd;rnd=seeded(5);const m={make};rnd=keep;"
            else:
                build = f"const m=buildCar('{car}',new THREE.Color('{col}'));"
                if up:
                    u = dict(DEFAULT_UP, **up)
                    build += (f"const kg=garage.cars['{car}'];garage.cars['{car}']={json.dumps(u)};styleCar(m,'{car}');"
                              f"if(kg)garage.cars['{car}']=kg;else delete garage.cars['{car}'];")
            res = s.ev(f"""(()=>{{{build}const c=renderer.domElement;world.visible=false;if(car)car.g.visible=false;
              const L=m.len,W=m.wid,A=m.kit?m.kit.S.wz[0]:L/2-1,k=Math.max(1,L/4.6);const v={vjs};scene.add(m.g);
              camera.fov=40;camera.near=0.1;camera.clearViewOffset();camera.aspect=c.width/c.height;camera.position.set(v[0],v[1],v[2]);camera.lookAt(v[3],v[4],v[5]);camera.updateProjectionMatrix();
              sun.position.set(0,0,0).addScaledVector(SUN_DIR,160);sun.target.position.set(0,0,0);sun.target.updateMatrixWorld();updateEnv(0);skyDome.position.copy(camera.position);renderer.render(scene,camera);const url=c.toDataURL('image/png');
              scene.remove(m.g);camera.near=0.5;camera.updateProjectionMatrix();world.visible=true;return JSON.stringify({{url,v}});}})()""")
            r = json.loads(res)
            name = f"car_{car}_{var}_{view if view in VIEWS else 'custom'}_{tm}"
            hp = OUTD / f'{name}_html.png'
            hp.write_bytes(base64.b64decode(r['url'].split(',', 1)[1]))
            gcar = car.replace('traffic-', 'traffic:')
            jobs.append((name, hp, gcar, col, json.dumps(dict(DEFAULT_UP, **up)) if up else '', r['v']))
    godot = shutil.which('godot') or 'godot'
    for name, hp, gcar, col, up, v in jobs:
        gp = OUTD / f'{name}_godot.png'
        args = [f'car={gcar}', f'color={col}', f'time={tm}', f'weather={we}', 'view=' + ','.join(str(x) for x in v), f'out={gp}', 'fov=40']
        if up:
            args.append('up=' + up)
        r = subprocess.run(['xvfb-run', '-a', '-s', f'-screen 0 {W}x{H}x24', godot, '--path', str(PROJ), '--rendering-driver', 'opengl3',
                            '--resolution', f'{W}x{H}', 'res://tools/view_car.tscn', '--', *args], capture_output=True, text=True, timeout=900,
                           stdin=subprocess.DEVNULL)
        for line in (r.stdout + r.stderr).splitlines():
            if any(k in line for k in ('ERROR', 'Parse', 'SCRIPT')):
                print(line)
        a = Image.open(hp).convert('RGB').resize((W, H))
        b = Image.open(gp).convert('RGB').resize((W, H)) if gp.exists() else Image.new('RGB', (W, H), 'magenta')
        out = Image.new('RGB', (W * 2 + 6, H), 'black'); out.paste(a, (0, 0)); out.paste(b, (W + 6, 0))
        p = OUTD / f'{name}.png'; out.save(p); print(p)


main()
