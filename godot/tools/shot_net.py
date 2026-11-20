"""Screenshots of every online screen, from a small evening played by real games on this PC (tests/net_ctl.gd players).
One player at a time is in a window (xvfb, software OpenGL: more windows at once make everything crawl), the others
headless; the evening is played once per window.
    python godot/tools/shot_net.py [outdir] [1280x720] [host,guest,late]      (default: godot/tests/.out/net, all three)
host:  host_lobby, host_countdown, host_results, host_standings
guest: list_help (nothing found after 10 s), list, guest_lobby, countdown, race (name tags, minimap), pause, spectate
       (after the finish), results, standings, migrated (the host left: this guest took over)
late:  late_lobby (a race is on), watch (watching from the lobby), kicked
Each player plays on its own save file, never the player's. Look at the pictures with an image viewer."""
import sys, time, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / 'tests'))
import net_players
net_players.isolate()
from net_players import Player, kill_all

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent / 'tests' / '.out' / 'net').resolve()
res = sys.argv[2] if len(sys.argv) > 2 else '1280x720'
wins = (sys.argv[3] if len(sys.argv) > 3 else 'host,guest,late').split(',')
out.mkdir(parents=True, exist_ok=True)

def evening(win):
    def shot(p, name):
        if not p.window: return
        r = p.cmd(f'shot {out / (name + ".png")}', timeout=60)
        print('saved' if r else 'FOUT', out / (name + '.png'), flush=True)
    def mk(name, role, **kw):
        p = Player(name, window=role == win, res=res if role == win else None, **kw)
        p.window = role == win
        return p
    TS = 3
    h = mk('host', 'host', nick='Yip', car='gt', ts=TS, look={"rim": "gold", "stripe": "white", "num": 7, "wing": "gt", "rimStyle": "spoke"})
    g = mk('g1', 'guest', nick='Fenna', car='hatch', color='#2f8f5b', ts=TS, look={"rim": "black", "stripe": "yellow", "num": 23})
    b1 = mk('g2', '-', nick='Bram', car='evo', color='#d62a2a', ts=TS)
    b2 = mk('g3', '-', nick='Lotte', car='super', color='#1d4f9e', ts=TS)
    late = mk('g4', 'late', nick='Teun', car='hatch', ts=TS)
    assert all(p.ready(180) for p in (h, g, b1, b2, late)), 'spellen starten niet'
    g.cmd('open')
    if g.window:
        g.wait(lambda r: r['help'], 14)
        shot(g, 'list_help')
    h.cmd('open'); h.cmd('press Nieuwe game maken')
    h.cmd('set laps 2'); h.cmd('set bots 3'); h.cmd('set track dorp', timeout=60); h.cmd('set next vote')
    g.wait(lambda r: r['lobbies'], 10); time.sleep(0.5)
    shot(g, 'list')
    for p in (g, b1, b2): p.cmd('open'); p.cmd('join 0')
    h.wait(lambda r: len(r.get('remotes', [])) == 3, 15)
    b1.cmd('ready'); b2.cmd('say 0'); g.cmd('say Even mijn auto kiezen')
    time.sleep(1.5)
    shot(h, 'host_lobby'); shot(g, 'guest_lobby')
    g.cmd('ready'); b2.cmd('ready')
    h.cmd('start'); time.sleep(1.0)
    shot(g, 'countdown'); shot(h, 'host_countdown')
    for p in (h, g, b1, b2): p.wait(lambda r: r['state'] == 'racing', 30)
    b2.cmd('drive off')        # Lotte dawdles: the others can watch her after their finish
    time.sleep(5)
    shot(g, 'race')
    if g.window:
        g.cmd('ex get_node("/root/Game").setPaused(true)'); time.sleep(0.4)
        shot(g, 'pause')
        g.cmd('ex get_node("/root/Game").setPaused(false)')
        # (a window under software OpenGL runs in slow motion: for the pictures after the finish, end her race here)
        g.cmd('ex get_node("/root/Game").finishPlayer()')
    time.sleep(3)
    b2.cmd('drive on')
    # Teun comes late: he watches from the lobby
    late.cmd('open'); late.cmd('join 0')
    late.wait(lambda r: r.get('canWatch'), 10)
    shot(late, 'late_lobby')
    late.cmd('press Meekijken'); time.sleep(3)
    shot(late, 'watch')
    g.wait(lambda r: r['state'] == 'over', 150); time.sleep(1.2)
    if 'Meekijken' in g.rep().get('over_btns', []):
        g.cmd('press Meekijken'); time.sleep(2.5)
        shot(g, 'spectate')
        g.cmd('key Escape')
    g.wait(lambda r: r.get('res') and r['res'].get('final'), 150); time.sleep(1.5)
    shot(g, 'results'); shot(h, 'host_results')
    for p in (g, h): p.cmd('press Stand van de avond')
    time.sleep(0.6)
    shot(g, 'standings'); shot(h, 'host_standings')
    # the host kicks Teun, then leaves: Fenna takes over
    for p in (h, g, b1, b2): p.cmd('press Lobby')
    time.sleep(1.5)
    h.cmd('kick Teun'); time.sleep(1.5)
    shot(late, 'kicked')
    h.cmd('press Game verlaten')
    g.wait(lambda r: r.get('host'), 15); time.sleep(2)
    shot(g, 'migrated')

for w in wins:
    print('== venster:', w, flush=True)
    try:
        evening(w)
    finally:
        kill_all()
        time.sleep(1)
