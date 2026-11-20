"""Before/after table of two handling measurements (tests/test_measure.gd):
    python godot/tools/handling_table.py [before] [now] [filter]
before/now: a tag (tests/.out/handling_<tag>.json) or a path; default: tests/golden/handling_before.json against now.
filter: only keys that contain this text (e.g. lap- or skid).
"""
import json, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent.parent / 'tests'


def load(tag):
    p = pathlib.Path(tag)
    if tag == 'before':
        p = HERE / 'golden' / 'handling_before.json'
    elif not p.exists():
        p = HERE / '.out' / ('handling_%s.json' % tag)
    return json.loads(p.read_text())


a = load(sys.argv[1] if len(sys.argv) > 1 else 'before')
b = load(sys.argv[2] if len(sys.argv) > 2 else 'now')
flt = sys.argv[3] if len(sys.argv) > 3 else ''
for k in sorted(set(a) | set(b)):
    if flt not in k:
        continue
    x, y = a.get(k, {}), b.get(k, {})
    cols = []
    for f in sorted(set(x) | set(y)):
        u, v = x.get(f), y.get(f)
        if isinstance(u, bool) or isinstance(v, bool) or u is None or v is None:
            if u != v:
                cols.append('%s %s->%s' % (f, u, v))
            continue
        if abs(u - v) < 1e-3:
            cols.append('%s %g' % (f, u))
        else:
            rel = (' (%+.1f%%)' % ((v / u - 1) * 100)) if abs(u) > 1e-6 else ''
            cols.append('%s %g->%g%s' % (f, u, v, rel))
    print('%-26s %s' % (k, '  '.join(cols)))
