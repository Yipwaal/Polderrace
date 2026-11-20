#!/usr/bin/env python3
"""Contact sheets of tools/shot_beeld.gd pictures: per track one sheet, rows = time x weather, columns = points.
   python godot/tools/sheet_beeld.py <dir> [<dir2> ...] [--w=480]
   (two dirs: before | after side by side per picture) -> <last dir>/sheet_<track>.jpg"""
import sys, os, re, glob
from PIL import Image, ImageDraw


def main():
    dirs = [d for d in sys.argv[1:] if not d.startswith('--')]
    tw = 480
    for a in sys.argv[1:]:
        if a.startswith('--w='):
            tw = int(a[4:])
    names = sorted(os.path.basename(p) for p in glob.glob(os.path.join(dirs[-1], '*_*_*_*.png')))
    tracks = {}
    for n in names:
        m = re.match(r'(\w+?)_(day|dusk|night)_(dry|rain|fog)_(\d+)\.png', n)
        if m:
            tracks.setdefault(m.group(1), []).append((m.group(2), m.group(3), int(m.group(4)), n))
    order_t = ['day', 'dusk', 'night']
    order_w = ['dry', 'rain', 'fog']
    for tr, lst in tracks.items():
        rows = sorted({(t, w) for t, w, _, _ in lst}, key=lambda r: (order_t.index(r[0]), order_w.index(r[1])))
        cols = sorted({p for _, _, p, _ in lst})
        th = tw * 9 // 16
        cw = tw * len(dirs)
        sheet = Image.new('RGB', (cw * len(cols), th * len(rows)), (20, 20, 20))
        dr = ImageDraw.Draw(sheet)
        for t, w, p, n in lst:
            x = cols.index(p) * cw
            y = rows.index((t, w)) * th
            for k, d in enumerate(dirs):
                f = os.path.join(d, n)
                if os.path.exists(f):
                    im = Image.open(f).convert('RGB').resize((tw, th), Image.LANCZOS)
                    sheet.paste(im, (x + k * tw, y))
            dr.text((x + 4, y + th - 14), '%s %s %s %d' % (tr, t, w, p), fill=(255, 255, 0))
        out = os.path.join(dirs[-1], 'sheet_%s.jpg' % tr)
        sheet.save(out, quality=88)
        print(out)


main()
