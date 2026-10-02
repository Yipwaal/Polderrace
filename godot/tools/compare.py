"""Side-by-side picture of one view in the HTML game (left) and the Godot version (right).

python godot/tools/compare.py <track> <view> [time] [weather]
  view = a name from VIEWS below, or a JS expression giving [ex,ey,ez,lx,ly,lz] (it can use P, T, R, HT, NS, START_I)
Output: tests/.out/compare/<track>_<view>.png (and the two halves). Look at it with the Read tool.
"""
import sys, subprocess, pathlib, shutil, json
HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
ROOT = PROJ.parent
sys.path.insert(0, str(ROOT / 'tests'))
from lib import Session, DEFAULT, OUT
from PIL import Image

VIEWS = {
    # chase-like view a bit after the start, looking along the road
    'start': "(()=>{const i=(START_I+20)%NS,j=(i+14)%NS,p=P[i],t=T[i];return [p.x-t.x*9,HT[i]+3.4,p.z-t.z*9,P[j].x,HT[j]+1,P[j].z];})()",
    # same, further round the lap
    'lap': "(()=>{const i=Math.floor(NS*0.4),j=(i+14)%NS,p=P[i],t=T[i];return [p.x-t.x*9,HT[i]+3.4,p.z-t.z*9,P[j].x,HT[j]+1,P[j].z];})()",
    # from the side, above the verge
    'side': "(()=>{const i=Math.floor(NS*0.7),p=P[i],r=R[i],t=T[i];return [p.x+r.x*40-t.x*20,HT[i]+14,p.z+r.z*40-t.z*20,p.x+t.x*20,HT[i],p.z+t.z*20];})()",
    # high overview of the whole track
    'top': "[(BX0+BX1)/2-500,420,(BZ0+BZ1)/2+700,(BX0+BX1)/2,0,(BZ0+BZ1)/2]",
}
W, H = 900, 560
OUTD = OUT / 'compare'; OUTD.mkdir(exist_ok=True)


def main():
    tr = sys.argv[1] if len(sys.argv) > 1 else 'polder'
    vn = sys.argv[2] if len(sys.argv) > 2 else 'start'
    tm = sys.argv[3] if len(sys.argv) > 3 else 'day'
    we = sys.argv[4] if len(sys.argv) > 4 else 'dry'
    js = VIEWS.get(vn, vn)
    name = f"{tr}_{vn if vn in VIEWS else 'custom'}_{tm}_{we}"
    hp, gp = OUTD / f'{name}_html.png', OUTD / f'{name}_godot.png'
    with Session(dict(DEFAULT, bots=0), w=W, h=H, prefs={'quality': 'high'}) as s:
        s.ev(f"toMenu(-1);settings.track='{tr}';settings.dir='fwd';loadTrack('{tr}','fwd');applyEnv('{tm}','{we}');0")
        v = s.ev(js)
        data = s.ev(f"(()=>{{const v={json.dumps(v)};const c=renderer.domElement;"
                    "for(const o of [player&&player.mesh,...(typeof bots!=='undefined'?bots:[]).map(b=>b.mesh),...(typeof traffic!=='undefined'?traffic:[]).map(t=>t.mesh)])if(o)o.visible=false;"
                    "camera.fov=62;camera.clearViewOffset();camera.aspect=c.width/c.height;camera.position.set(v[0],v[1],v[2]);camera.lookAt(v[3],v[4],v[5]);camera.updateProjectionMatrix();"
                    "updateEnv(0);skyDome.position.copy(camera.position);sun.position.copy(camera.position).addScaledVector(SUN_DIR,160);sun.target.position.copy(camera.position);sun.target.updateMatrixWorld();"
                    "renderer.render(scene,camera);return c.toDataURL('image/png');})()")
        import base64
        hp.write_bytes(base64.b64decode(data.split(',', 1)[1]))
    godot = shutil.which('godot') or 'godot'
    r = subprocess.run(['xvfb-run', '-a', '-s', f'-screen 0 {W}x{H}x24', godot, '--path', str(PROJ), '--rendering-driver', 'opengl3',
                        '--resolution', f'{W}x{H}', 'res://tools/view.tscn', '--', f'track={tr}', f'time={tm}', f'weather={we}',
                        'view=' + ','.join(str(x) for x in v), f'out={gp}'], capture_output=True, text=True, timeout=900)
    for line in (r.stdout + r.stderr).splitlines():
        if any(k in line for k in ('ERROR', 'ms ', 'saved', 'Parse', 'SCRIPT', 'amb ')):
            print(line)
    a = Image.open(hp).convert('RGB').resize((W, H))
    b = Image.open(gp).convert('RGB').resize((W, H)) if gp.exists() else Image.new('RGB', (W, H), 'magenta')
    out = Image.new('RGB', (W * 2 + 6, H), 'black'); out.paste(a, (0, 0)); out.paste(b, (W + 6, 0))
    p = OUTD / f'{name}.png'; out.save(p); print(p)


main()
