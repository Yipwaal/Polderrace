"""Camera tour of a track as contact sheets (see tools/tour.gd for the views).

  python godot/tools/tour.py <track> [fwd|rev] [day|dusk|night] [dry|rain|fog] [options]

  --step N         metres between stops (default 150)
  --from A --to B  only this part of the lap (metres from sample 0; the start line is at 12 m)
  --views a,b,..   drive,high,left,right,back,over (default drive,high,left,right,over)
  --lat X          camera X metres right of the centre line
  --cam ex,ey,ez,lx,ly,lz[;...]   free camera positions instead of the tour (world coordinates)
  --spot s,lat[;...]              two looks at a point the tests report (distance along the lap, metres right of the centre)
  --car hatch      a car on the road 22 m past every stop, for scale
  --fov F          field of view of --cam / --spot (default 62)
  --res WxH        render size (default 960x540); --tile WxH size of a tile on the sheet (default 384x216)
  --rows N         stops per sheet (default 7; with one view: tiles per sheet = 4 x N)
  --out DIR        default godot/tests/.out/tour/<track>_<dir>_<time>_<weather>[_<from>-<to>]

Writes the PNGs of every view plus sheet_NN.png (one row per stop, one column per view, the distance on every tile) and
over.png (the overviews); prints the paths of the sheets. Look at them with the Read tool.
Needs xvfb-run and Pillow. Set XDG_DATA_HOME first when several agents share the machine (see PLAN2.md).
"""
import subprocess, sys, pathlib, shutil, re, os
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    # this Python has no working Pillow (the cloud container's `python` is one without): use the system Python
    alt = '/usr/bin/python3'
    if os.path.exists(alt) and not os.environ.get('TOUR_REEXEC'):
        os.environ['TOUR_REEXEC'] = '1'
        os.execv(alt, [alt] + sys.argv)
    raise

HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
GODOT = shutil.which('godot') or shutil.which('godot4') or 'godot'


def opt(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        v = sys.argv[i + 1]
        del sys.argv[i:i + 2]
        return v
    return default


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def label(d, xy, text, f):
    x, y = xy
    w = d.textlength(text, font=f)
    d.rectangle([x, y, x + w + 8, y + 21], fill=(0, 0, 0))
    d.text((x + 4, y + 2), text, font=f, fill=(255, 255, 255))


def main():
    step = opt('--step', '150'); a = opt('--from', '0'); b = opt('--to', '-1')
    views = opt('--views', 'drive,high,left,right,over'); lat = opt('--lat', '0')
    cam = opt('--cam', ''); spot = opt('--spot', ''); car = opt('--car', ''); fov = opt('--fov', '62')
    res = opt('--res', '960x540'); tile = opt('--tile', '384x216'); rows = int(opt('--rows', '7')); out = opt('--out')
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    if not args:
        print(__doc__); sys.exit(2)
    track = args[0]
    d = next((x for x in args[1:] if x in ('fwd', 'rev')), 'fwd')
    time = next((x for x in args[1:] if x in ('day', 'dusk', 'night')), 'day')
    weather = next((x for x in args[1:] if x in ('dry', 'rain', 'fog')), 'dry')
    name = f'{track}_{d}_{time}_{weather}'
    if a != '0' or b != '-1':
        name += f'_{a}-{b}'
    if cam or spot:
        name += '_cam'
    outdir = pathlib.Path(out).resolve() if out else PROJ / 'tests' / '.out' / 'tour' / name
    if outdir.exists():
        for p in outdir.glob('*.png'):
            p.unlink()
    outdir.mkdir(parents=True, exist_ok=True)
    cmd = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', GODOT, '--path', str(PROJ), '--rendering-driver', 'opengl3', '--resolution', res,
           'res://tools/tour.tscn', '--', f'track={track}', f'dir={d}', f'time={time}', f'weather={weather}', f'step={step}', f'from={a}', f'to={b}',
           f'views={views}', f'lat={lat}', f'cam={cam}', f'spot={spot}', f'car={car}', f'fov={fov}', f'out={outdir}']
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=3400)
    txt = r.stdout + r.stderr
    for line in txt.splitlines():
        if line.startswith(('TOUR', 'ERROR tour', 'SCRIPT ERROR')) or 'Parse Error' in line:
            print(line)
    tw, th = (int(x) for x in tile.split('x'))
    f = font(15)
    head = f'{track} {d} {time} {weather}'
    sheets = []
    vlist = [v for v in views.split(',') if v != 'over']
    stops = sorted({int(m.group(1)) for p in outdir.glob('*.png') for m in [re.match(r'(?:drive|high|left|right|back)_(\d+)\.png', p.name)] if m})
    cells = []   # rows of (path, label)
    if len(vlist) == 1:
        row = []
        for s in stops:
            row.append((outdir / f'{vlist[0]}_{s:05d}.png', f'{s} m'))
            if len(row) == 4:
                cells.append(row); row = []
        if row:
            cells.append(row)
    else:
        for s in stops:
            cells.append([(outdir / f'{v}_{s:05d}.png', f'{s} m {v}') for v in vlist])
    for k in range(0, len(cells), rows):
        part = cells[k:k + rows]
        cols = max(len(r_) for r_ in part)
        sheet = Image.new('RGB', (cols * tw, len(part) * th + 22), (20, 20, 20))
        dr = ImageDraw.Draw(sheet)
        dr.text((4, 2), f'{head}   views: {", ".join(vlist)}   ({part[0][0][1]} .. {part[-1][-1][1]})', font=f, fill=(255, 255, 255))
        for y, r_ in enumerate(part):
            for x, (p, lab) in enumerate(r_):
                if p.exists():
                    sheet.paste(Image.open(p).convert('RGB').resize((tw, th), Image.LANCZOS), (x * tw, 22 + y * th))
                label(dr, (x * tw + 2, 22 + y * th + 2), lab, f)
        p = outdir / f'sheet_{k // rows + 1:02d}.png'
        sheet.save(p); sheets.append(p)
    singles = sorted(outdir.glob('over_*.png')) + sorted(outdir.glob('cam_*.png')) + sorted(outdir.glob('spot_*.png'))
    if singles:
        big = len(singles) <= 4
        w2, h2 = (tw * 2, th * 2) if big else (tw * 4 // 3, th * 4 // 3)
        cols = 2 if big else 3
        n = (len(singles) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * w2, n * h2 + 22), (20, 20, 20))
        dr = ImageDraw.Draw(sheet)
        dr.text((4, 2), head, font=f, fill=(255, 255, 255))
        for i, p in enumerate(singles):
            x, y = (i % cols) * w2, 22 + (i // cols) * h2
            sheet.paste(Image.open(p).convert('RGB').resize((w2, h2), Image.LANCZOS), (x, y))
            label(dr, (x + 2, y + 2), p.stem, f)
        p = outdir / ('over.png' if not (cam or spot) else 'cams.png')
        sheet.save(p); sheets.append(p)
    for p in sheets:
        print(p)
    if not sheets:
        print('geen beelden gemaakt'); print(txt[-2000:]); sys.exit(1)


main()
