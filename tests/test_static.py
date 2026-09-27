"""Static checks on the game file (no browser, a few seconds).

- no test hooks left in the game file
- the init line (ANCHOR) exists exactly once
- only the allowed external script (three.js r128 from cdnjs)
- the artifact capabilities the game relies on are still used (room, downloads)
- JavaScript syntax check of the inline script with `node --check` (skipped when node is missing)
- HTML phase: no extra game files next to polderrace-3d.html (.js/.css/.ts/extra .html, Godot/Unity project files)
"""
import re, shutil, subprocess, tempfile, pathlib
from lib import GAME, ANCHOR, TEST_MARKERS, Report, ROOT

rep = Report('statische controle')
s = GAME.read_text(encoding='utf-8')

found = [m for m in TEST_MARKERS if m in s]
rep.check(not found, 'geen testhooks in het spelbestand', 'gevonden: ' + ', '.join(found) if found else '')
rep.check(s.count(ANCHOR) == 1, 'init-regel precies 1x aanwezig', f'{s.count(ANCHOR)}x')
rep.check(s.lstrip().lower().startswith('<!doctype html>'), 'begint met <!doctype html>')
rep.check(s.count('<!doctype html>') + s.count('<!DOCTYPE html>') == 1, 'maar 1 doctype (geen dubbele publicatie-wrapper)')

srcs = re.findall(r'<script[^>]*\bsrc="([^"]+)"', s)
rep.check(srcs == ['https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js'], 'alleen three.js r128 van cdnjs als extern script', str(srcs))
rep.check("use('room')" in s, "online spelen gebruikt claude.use('room')")
rep.check("use('downloads')" in s, "replay opslaan gebruikt claude.use('downloads')")
rep.check('localStorage' in s and 'try{' in s, 'localStorage alleen via try/catch (store-helper)')
rep.check(len(s.encode('utf-8')) < 15_000_000, 'bestand kleiner dan 15 MB', f'{len(s.encode("utf-8"))//1024} kB')

scripts = re.findall(r'<script>(.*?)</script>', s, re.S)
node = shutil.which('node')
if node and scripts:
    with tempfile.TemporaryDirectory() as d:
        ok = True
        for k, js in enumerate(scripts):
            p = pathlib.Path(d) / f's{k}.js'
            p.write_text(js, encoding='utf-8')
            r = subprocess.run([node, '--check', str(p)], capture_output=True, text=True)
            if r.returncode:
                ok = False
                rep.check(False, f'JS-syntax script {k}', r.stderr.strip().splitlines()[-1] if r.stderr else '')
        if ok:
            rep.check(True, f'JS-syntax ({len(scripts)} inline script(s))')
else:
    print('--   JS-syntaxcheck overgeslagen (node niet gevonden)')
# HTML phase (see CLAUDE.md): the game stays one self-contained file until Yip asks for the "real" game
SKIP = {'tests', 'node_modules', '.claude', '.git', 'docs'}
extra = []
for p in ROOT.rglob('*'):
    rel = p.relative_to(ROOT)
    if rel.parts[0] in SKIP or p.is_dir():
        continue
    name = p.name.lower()
    if (p.suffix.lower() in {'.js', '.mjs', '.css', '.ts', '.tsx', '.jsx', '.gd', '.tscn', '.godot', '.unity', '.cs'} or
            (p.suffix.lower() == '.html' and p.resolve() != GAME.resolve()) or name in {'project.godot', 'vite.config.js', 'webpack.config.js', 'tsconfig.json'}):
        extra.append(str(rel))
rep.check(not extra, 'HTML-fase: geen extra spelbestanden naast polderrace-3d.html', ', '.join(extra[:8]))
rep.finish()
