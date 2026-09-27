"""Run the full test suite (about 20-35 minutes, depending on the PC). Tests run in parallel in groups.

usage: python tests/run_all.py            -> everything
       python tests/run_all.py --fast     -> static, road clearance, z-fighting, layout, collisions, regression on 3 tracks
Exit code 0 only when everything passed. Summary at the end; full logs in tests/.out/logs/.
"""
import subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor
from lib import TESTS, OUT

LOGS = OUT / 'logs'; LOGS.mkdir(exist_ok=True)
FAST = '--fast' in sys.argv
JOBS = [
    ['test_static.py'],
    ['test_road_clear.py', 'polder,dorp,circuit,afsluitdijk,haven'],
    ['test_road_clear.py', 'veluwe,grachten,limburg,rotterdam,zeeland'],
    ['test_zfight.py'],
    ['test_layout.py'],
    ['test_collisions.py'],
]
if FAST:
    JOBS.append(['test_regression.py', 'polder,grachten,zeeland', 'race,time'])
else:
    JOBS += [
        ['test_road_clear.py', 'polder,dorp,circuit,afsluitdijk,haven,veluwe,grachten,limburg,rotterdam,zeeland', '--rev'],
        ['test_regression.py', 'polder,dorp,circuit,afsluitdijk,haven'],
        ['test_regression.py', 'veluwe,grachten,limburg,rotterdam,zeeland'],
        ['test_regression.py', 'polder,dorp,circuit,afsluitdijk,haven,veluwe,grachten,limburg,rotterdam,zeeland', 'race', 'rev'],
        ['test_camera_terrain.py'],
        ['test_championship.py'],
        ['test_multiplayer.py'],
        ['test_memory.py'],
    ]


def run(job):
    t = time.time(); name = '_'.join(a.replace(',', '-')[:40] for a in job).replace('.py', '')
    r = subprocess.run([sys.executable, str(TESTS / job[0])] + job[1:], capture_output=True, text=True, cwd=str(TESTS))
    (LOGS / f'{name}.log').write_text(r.stdout + '\n' + r.stderr, encoding='utf-8')
    fails = [l for l in r.stdout.splitlines() if l.startswith('FOUT')]
    last = [l for l in r.stdout.splitlines() if l.startswith('--')]
    if r.returncode and not fails:
        fails = (r.stderr.strip().splitlines() or ['onbekende fout'])[-3:]
    return job, r.returncode, time.time() - t, fails, last


workers = 3
with ThreadPoolExecutor(workers) as ex:
    results = list(ex.map(run, JOBS))
bad = 0
print('\n==== SAMENVATTING ====')
for job, rc, dt, fails, last in results:
    bad += rc != 0
    print(f"{'OK  ' if rc == 0 else 'FOUT'} {' '.join(job)}  ({dt:.0f} s)  {last[-1] if last else ''}")
    for f in fails[:6]:
        print('       ' + f)
print(f"==== {'ALLES GESLAAGD' if not bad else str(bad) + ' testbestand(en) mislukt'} — logs in {LOGS}")
sys.exit(1 if bad else 0)
