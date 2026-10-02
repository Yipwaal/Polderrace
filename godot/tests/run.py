"""Run the Godot tests: python godot/tests/run.py [test ...]   (default: all logic tests, headless)

Logic tests run headless (no window). Visual tests (screenshots) need a display: they run under xvfb-run with OpenGL
(software Mesa in the cloud), see tests/shots.py.
"""
import subprocess, sys, pathlib, shutil
HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
GODOT = shutil.which('godot') or shutil.which('godot4') or 'godot'
DEFAULT = ['track']
names = sys.argv[1:] or DEFAULT
# (re)import first: new scripts with class_name are only known after an import, and an unknown class makes the runner hang
subprocess.run([GODOT, '--headless', '--path', str(PROJ), '--import'], capture_output=True, text=True, timeout=600)
r = subprocess.run([GODOT, '--headless', '--path', str(PROJ), 'res://tests/runner.tscn', '--', *names], capture_output=True, text=True, timeout=7200)
out = r.stdout + r.stderr
for line in out.splitlines():
    if line.startswith(('OK', 'FOUT', '--', '==')) or 'SCRIPT ERROR' in line or line.startswith('ERROR') or 'Parse Error' in line:
        print(line)
sys.exit(r.returncode)
