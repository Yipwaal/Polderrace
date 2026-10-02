"""Menu screens of the HTML version (left) and the Godot version (right) side by side.

python godot/tools/compare_menus.py [WxH] [screen,screen,...] [--html]
  --html  also make the HTML screenshots again (tools/menus_html.py; otherwise the ones already there are used)
Output: tests/.out/menus/compare_<W>x<H>/<screen>.png (and godot_<W>x<H>/<screen>.png). Look at them with the Read tool.
Screens: home play career ach records settings settings_keys settings_pad garage garage_look menu_modus menu_auto menu_baan
menu_champ pause pause_settings results champ_results standings timetrial
"""
import sys, subprocess, pathlib, shutil
HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
ROOT = PROJ.parent
OUT = ROOT / 'tests' / '.out' / 'menus'

args = [a for a in sys.argv[1:] if not a.startswith('--')]
size = args[0] if args and 'x' in args[0] else '1280x720'
only = args[1] if len(args) > 1 else (args[0] if args and 'x' not in args[0] else '')
W, H = (int(v) for v in size.split('x'))
if '--html' in sys.argv:
    subprocess.run([sys.executable, str(HERE / 'menus_html.py'), size] + ([only] if only else []), check=False)
gd = OUT / f'godot_{size}'
gd.mkdir(parents=True, exist_ok=True)
godot = shutil.which('godot') or 'godot'
cmd = ['xvfb-run', '-a', '-s', f'-screen 0 {W}x{H}x24', godot, '--path', str(PROJ), '--rendering-driver', 'opengl3',
       '--resolution', size, 'res://tools/shot_menus.tscn', '--', f'out={gd}'] + ([f'only={only}'] if only else [])
r = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
for line in (r.stdout + r.stderr).splitlines():
    if any(k in line for k in ('ERROR', 'SCRIPT', 'saved', 'at: ')):
        print(line)
from PIL import Image
cmp = OUT / f'compare_{size}'
cmp.mkdir(parents=True, exist_ok=True)
hd = OUT / f'html_{size}'
for p in sorted(gd.glob('*.png')):
    if only and p.stem not in only.split(','):
        continue
    a = Image.open(hd / p.name).convert('RGB') if (hd / p.name).exists() else Image.new('RGB', (W, H), 'magenta')
    b = Image.open(p).convert('RGB')
    o = Image.new('RGB', (W * 2 + 6, H), 'black')
    o.paste(a.resize((W, H)), (0, 0))
    o.paste(b.resize((W, H)), (W + 6, 0))
    o.save(cmp / p.name)
    print(cmp / p.name)
