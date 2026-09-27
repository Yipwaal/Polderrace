"""Claude Code Stop hook: runs automatically when Claude wants to finish its turn.

1. Game file unchanged since the last approved review -> let Claude stop.
2. Game file changed -> run the quick check. If it fails -> block (exit 2) with the failures.
3. Quick check passes but the qa-reviewer agent has not approved this exact version -> block and ask
   Claude to run the qa-reviewer agent first.
Safety valve: after 4 blocks on the same version the hook lets Claude stop (and says so), so it can
never loop forever.

tests/reviewed.txt (committed) = hash of the version the reviewer approved; tests/.out/hook_state.json = hook bookkeeping.
"""
import json, subprocess, sys
from lib import game_hash, OUT, TESTS
REVIEWED = TESTS / 'reviewed.txt'

try:
    json.load(sys.stdin)
except Exception:
    pass

h = game_hash()
reviewed = REVIEWED.read_text().strip() if REVIEWED.exists() else ''
if h == reviewed:
    sys.exit(0)

state_f = OUT / 'hook_state.json'
try:
    state = json.loads(state_f.read_text())
except Exception:
    state = {}
if state.get('hash') != h:
    state = {'hash': h, 'blocks': 0, 'quick_ok': False}
if state['blocks'] >= 4:
    print('Stop-hook: 4x geblokkeerd op deze versie zonder goedkeuring; stoppen toegestaan. Meld de gebruiker dat de controle niet is afgerond.')
    sys.exit(0)


def block(msg):
    state['blocks'] += 1
    state_f.write_text(json.dumps(state))
    print(msg, file=sys.stderr)
    sys.exit(2)


if not state['quick_ok']:
    r = subprocess.run([sys.executable, str(TESTS / 'quick_check.py')], capture_output=True, text=True, timeout=600)
    if r.returncode:
        tail = '\n'.join((r.stdout + r.stderr).strip().splitlines()[-25:])
        block('Snelle controle van polderrace-3d.html is MISLUKT. Los dit op voordat je afrondt:\n' + tail)
    state['quick_ok'] = True
    state_f.write_text(json.dumps(state))

block('Snelle controle geslaagd, maar deze versie van polderrace-3d.html is nog niet goedgekeurd door de qa-reviewer. '
      'Start nu de qa-reviewer agent (Agent-tool, subagent_type "qa-reviewer") met een korte beschrijving van wat je hebt veranderd en waarom. '
      'Verwerk zijn bevindingen; pas als hij GOEDGEKEURD geeft (en tests/mark_reviewed.py heeft gedraaid) mag je afronden.')
