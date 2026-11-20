"""Online test: a host and a guest Godot process on this PC. The guest must find the host's game by LAN discovery
(no codes), join, start the same race when the host starts, and both must see each other's car and the same bots;
when the host leaves, the guest takes the game over.
usage: python godot/tests/test_net.py"""
import subprocess, sys, json, pathlib, shutil, time
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import net_players
net_players.isolate()      # Linux as root: a network of its own, so other games on this PC cannot mix in
PROJ = pathlib.Path(__file__).resolve().parent.parent
GODOT = shutil.which('godot') or 'godot'
bad = []
def check(c, label, detail=''):
    print(('OK   ' if c else 'FOUT ') + label + (('  ' + str(detail)) if detail else ''))
    if not c: bad.append(label)
def run(role, nick):
    return subprocess.Popen([GODOT, '--headless', '--path', str(PROJ), 'res://tests/net_role.tscn', '--', f'role={role}', f'nick={nick}', 'secs=12'],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
def parse(out):
    d = {}
    for line in out.splitlines():
        if line.startswith('NET '):
            _, k, v = line.split(' ', 2); d[k] = json.loads(v)
    return d
# first what can be checked without a network (tests/test_netunit.gd)
u = subprocess.run([GODOT, '--headless', '--path', str(PROJ), 'res://tests/runner.tscn', '--', 'netunit'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
for line in u.stdout.splitlines():
    if line.startswith(('OK', 'FOUT', '--', '==', 'SCRIPT ERROR')): print(line[:200])
check(u.returncode == 0 and 'SCRIPT ERROR' not in u.stdout, 'online zonder netwerk (test_netunit.gd)')
print('== online: host en speler via LAN')
h = run('host', 'Yip'); time.sleep(4); g = run('guest', 'Gast')
oh, _ = h.communicate(timeout=240); og, _ = g.communicate(timeout=240)
H, Gd = parse(oh), parse(og)
for name, out in (('host', oh), ('guest', og)):
    errs = [l for l in out.splitlines() if 'SCRIPT ERROR' in l]
    check(not errs, f'{name}: geen scriptfouten', errs[:3])
check(H.get('hosting'), 'host maakt een game')
check(len(Gd.get('lobbies', [])) >= 1, 'speler ziet de game in de lijst (zonder code)', Gd.get('lobbies'))
check(H.get('guest_seen', 0) == 1, 'host ziet de speler binnenkomen')
check(H.get('in_race') and Gd.get('in_race'), 'beiden zitten in de race')
check(H.get('track') == Gd.get('track') == 'polder', 'zelfde baan', (H.get('track'), Gd.get('track')))
check(H.get('bots') == Gd.get('bots') and len(H.get('bots', [])) == 2, 'zelfde bots', (H.get('bots'), Gd.get('bots')))
hr, gr = H.get('remotes', []), Gd.get('remotes', [])
check(len(hr) == 1 and hr[0]['has_st'] and hr[0]['visible'] and hr[0]['car'] == 'hatch', 'host ziet de auto van de speler', hr)
check(len(gr) == 1 and gr[0]['has_st'] and gr[0]['visible'] and gr[0]['car'] == 'gt', 'speler ziet de auto van de host', gr)
if hr and gr:
    check(abs(hr[0]['s'] - Gd.get('me_s', -99)) < 60, 'positie van de speler komt aan bij de host', (hr[0]['s'], Gd.get('me_s')))
hb, gb = H.get('bot_rel', []), Gd.get('bot_rel', [])
check(hb and gb and all(abs(a - b) < 15 for a, b in zip(hb, gb)), 'bots staan bij beiden op dezelfde plek (t.o.v. de auto van de host)', (hb, gb))
check(Gd.get('took_over') and 'Jij bent nu de host' in Gd.get('status', ''), 'de host stopt: de speler neemt de game over', Gd.get('status'))
print(f'-- online: {14 - len(bad)}/14 geslaagd' + ('' if not bad else '  | mislukt: ' + ', '.join(bad)))
sys.exit(1 if bad else 0)
