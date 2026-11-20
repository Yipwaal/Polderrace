"""Contact sheets of the cars: every model on a piece of road in the real game light, from fixed angles, by day and by night
with the lamps on, stock and tuned (the turntable of tools/view_car.gd).

python godot/tools/view_car.py [cars] [sets] [--color=#d62a2a] [--out=dir] [--size=640x400] [--cols=5]
  cars  all (default), or ids separated by commas: gt,hatch,traffic:van (traffic:hatch|van|truck|tractor), or B / A / S / traffic
  sets  day,night,tune,duck (default); also dusk, rain, num, center, colors, finishes, look (see SETS in view_car.gd)
Output: tests/.out/cars/<car>.png (one sheet per car: a row of tiles per set) and the loose tiles in tests/.out/cars/tiles/.
Look at the sheets with the Read tool. Needs xvfb-run and PIL.
"""
import sys, subprocess, pathlib, shutil, os, re
from PIL import Image, ImageDraw
HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
GODOT = shutil.which('godot') or shutil.which('godot4') or 'godot'
CLS = {'B': 'hatch,rally,coupe,roadster,mini,retro', 'A': 'gt,muscle,fastback,sedan,wagon,evo', 'S': 'super,hyper,longtail,proto,v12,speedster',
       'traffic': 'traffic:hatch,traffic:van,traffic:truck,traffic:tractor'}
args = [a for a in sys.argv[1:] if not a.startswith('--')]
opt = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
cars = args[0] if args else 'all'
cars = ','.join(CLS.get(c, c) for c in cars.split(','))
if cars == 'all': cars = ','.join(CLS[k] for k in ('B', 'A', 'S', 'traffic'))
sets = args[1] if len(args) > 1 else 'day,night,tune,duck'
size = opt.get('size', '640x400')
W, H = map(int, size.split('x'))
cols = int(opt.get('cols', 5))
out = pathlib.Path(opt.get('out', PROJ / 'tests' / '.out' / 'cars')).resolve()
tiles = out / 'tiles'
tiles.mkdir(parents=True, exist_ok=True)
for c in cars.split(','):
    for f in tiles.glob(c.replace(':', '-') + '__*.png'): f.unlink()
cmd = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', GODOT, '--path', str(PROJ), '--rendering-driver', 'opengl3', '--resolution', size,
       'res://tools/view_car.tscn', '--', 'sheet=1', 'cars=' + cars, 'sets=' + sets, 'colors=' + opt.get('color', '#d62a2a'), 'out=' + str(tiles)]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=3000)
bad = [l for l in (r.stdout + r.stderr).splitlines() if ('ERROR' in l or 'Parse Error' in l) and 'leaked at exit' not in l and 'RID allocations' not in l]
for l in bad[:30]: print(l)
for c in cars.split(','):
    name = c.replace(':', '-')
    files = []
    for s in sets.split(','):
        fs = sorted(tiles.glob('%s__%s__*.png' % (name, s)), key=lambda p: p.stat().st_mtime)
        files += [(s, f) for f in fs]
    if not files: continue
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * W, rows * H), (30, 30, 34))
    d = ImageDraw.Draw(sheet)
    for i, (s, f) in enumerate(files):
        im = Image.open(f).convert('RGB')
        if im.size != (W, H): im = im.resize((W, H))
        x, y = (i % cols) * W, (i // cols) * H
        sheet.paste(im, (x, y))
        label = '%s  %s  %s' % (name, s, f.stem.split('__')[2])
        d.rectangle([x, y, x + 8 + 7 * len(label), y + 16], fill=(0, 0, 0))
        d.text((x + 4, y + 2), label, fill=(255, 255, 255))
    p = out / (name + '.png')
    sheet.save(p)
    print('sheet', p)
sys.exit(1 if bad else 0)
