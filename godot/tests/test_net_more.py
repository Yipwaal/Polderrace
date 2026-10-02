"""Online scenarios with more players (each a Godot process on this PC, driven like a player: tests/net_ctl.gd):
  1. host + 3 spelers: lobby, auto en naam wisselen, start tegelijk zonder overlap, bots vloeiend, botsen met een bot,
     iemand stopt / hapert / sluit af / wordt gekilld, uitslag overal gelijk, nieuwe race met andere baan, laatkomer,
     host sluit midden in de race en op de uitslag, nieuwe game.
  2. vol: host + 8 spelers (de 9e krijgt "vol"), Esc en focus, verkeerd IP-adres, host verlaat de lobby.
  3. auto kiezen in de lobby (de speler in een venster, met xvfb-run).
  4. LAN met losse pc's (Linux als root: netwerk-namespaces): twee hosts in de lijst, /16-netwerk, VirtualBox-kaart,
     een speler via een slechte verbinding (net_lossy.py: 5% verlies, vertraging, volgorde door elkaar).
usage: python godot/tests/test_net_more.py [1] [2] [3] [4]   (about 4 minutes)"""
import sys, os, time, math, itertools, shutil, subprocess, pathlib
import net_players
net_players.isolate()
from net_players import Player, kill_all

bad = []
def check(c, label, detail=''):
    print(('OK   ' if c else 'FOUT ') + label + (('  ' + str(detail)[:300]) if detail else ''))
    if not c: bad.append(label)

def names(r, nick):
    """the results of one player, with "Jij" as that player's nick (to compare between PCs)"""
    return [nick if x['name'] == 'Jij' else x['name'] for x in r.get('results', [])]

def remote(r, name):
    for x in r.get('remotes', []):
        if x['name'] == name: return x
    return None

def steps(track):
    """per-frame distance a car moved on screen (from bot_track: x, z, game clock, ...)"""
    pts = list(zip(track[0::3], track[1::3]))
    return [math.dist(a, b) for a, b in zip(pts, pts[1:])]

def speeds(track):
    """how fast the car moved on screen from frame to frame (m/s of game time): a jump shows as an impossible speed"""
    pts = list(zip(track[0::3], track[1::3], track[2::3]))
    return [math.dist(a[:2], b[:2]) / (b[2] - a[2]) for a, b in zip(pts, pts[1:]) if b[2] > a[2]]

def no_errors(ps):
    for p in ps:
        e = p.errors()
        check(not e, f'{p.name}: geen scriptfouten', e[:3])

def scenario_four():
    print('== online: host + 3 spelers')
    TS = 4
    h = Player('host', nick='Yip', car='gt', ts=TS)
    g1 = Player('g1', nick='Bram', car='hatch', ts=TS)
    g2 = Player('g2', nick='Lotte', car='evo', ts=TS)
    g3 = Player('g3', nick='Mira', car='super', ts=TS)
    g4 = Player('g4', nick='Teun', car='hatch', ts=TS)       # comes later
    P = [h, g1, g2, g3]
    check(all(p.ready() for p in P + [g4]), 'vijf spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken'); h.cmd('set laps 1'); h.cmd('set bots 2')
    for g in (g1, g2, g3): g.cmd('open')
    rs = [g.wait(lambda r: len(r['lobbies']) >= 1, 10) for g in (g1, g2, g3)]
    check(all(len(r.get('lobbies', [])) == 1 and r['lobbies'][0]['name'] == 'Yips game' for r in rs), 'iedereen ziet "Yips game" in de lijst', rs[0].get('cards'))
    for g in (g1, g2, g3): g.cmd('join 0')
    r = g1.wait(lambda r: r.get('net') and 'game van' in r['status'], 8)
    check('NetUi' in r.get('focus', ''), 'na Meedoen staat de focus op een knop van het online-scherm', r.get('focus'))
    r = h.wait(lambda r: len(r['remotes']) == 3, 15)
    check(sorted((x['name'], x['car']) for x in r.get('remotes', [])) == [('Bram', 'hatch'), ('Lotte', 'evo'), ('Mira', 'super')],
          'host ziet de drie spelers met hun auto', r.get('remotes'))
    check(r.get('players_ui', [None])[0] == 'Yip (jij)' and len(r.get('players_ui', [])) == 4, 'spelerslijst bij de host', r.get('players_ui'))
    for g, me in ((g1, 'Bram'), (g2, 'Lotte'), (g3, 'Mira')):
        r = g.wait(lambda r: len(r.get('remotes', [])) == 3, 10)
        hostr = remote(r, 'Yip')
        check(hostr is not None and hostr['host'] and hostr['car'] == 'gt' and len(r['remotes']) == 3 and 'game van Yip' in r['status'],
              f'{me} ziet de host en de anderen', (r.get('remotes'), r.get('status')))
    g3.cmd('nick Mira B')
    r = h.wait(lambda r: remote(r, 'Mira B') is not None, 5)
    check(remote(r, 'Mira B') is not None, 'naam wijzigen komt bij de host aan', [x['name'] for x in r.get('remotes', [])])

    # ---- race 1
    check(h.cmd('press Start race'), 'host start de race')
    rs = [p.wait(lambda r: r['state'] in ('countdown', 'racing') and r['grid'], 15) for p in P]
    check(all(r.get('state') in ('countdown', 'racing') for r in rs), 'iedereen in de race', [r.get('state') for r in rs])
    check(len({str(r.get('bots')) for r in rs}) == 1 and len(rs[0].get('bots', [])) == 2, 'zelfde bots bij iedereen', rs[0].get('bots'))
    check(len({str(r.get('order')) for r in rs}) == 1 and len({r.get('goDelay') for r in rs}) == 1 and len({int(r.get('raceId', 0)) for r in rs}) == 1,
          'zelfde startvolgorde, race-id en wachttijd voor groen', [(r.get('order'), r.get('goDelay')) for r in rs])
    pts = [tuple(r['grid']) for r in rs] + [tuple(b) for b in rs[0]['grid_bots']]
    md = min(math.dist(a, b) for a, b in itertools.combinations(pts, 2))
    check(md > 3, 'startopstelling zonder overlap (auto\'s en bots)', round(md, 2))
    rs = [p.wait(lambda r: r['go_at'] > 0, 15) for p in P]
    gos = [r.get('go_at', 0) for r in rs]
    check(max(gos) - min(gos) < 0.25, 'groen licht op elke pc tegelijk', round(max(gos) - min(gos), 3))
    time.sleep(2)
    rh = h.rep(); r2 = g2.rep()
    st = steps(r2.get('bot_track', []))
    moving = [s for s in st if s > 0.0005]
    check(len(st) > 60 and len(moving) > 0.8 * len(st), 'bots rijden vloeiend bij een speler (elk beeld een stukje)', (len(moving), len(st)))
    for g, nm in ((g1, 'Bram'), (g2, 'Lotte')):
        rg = g.rep(); rh = h.rep()
        x = remote(rh, nm)
        check(x and x['visible'] and abs(x['s'] - rg['me_s']) < 80, f'host ziet {nm} waar {nm} rijdt', (x and x['s'], rg['me_s']))
    # Lotte rams bot 0 of the host: the host applies her kick, the bot does not jump
    seen0 = h.rep().get('seen', {}).get('g2', 0)
    h.cmd('track')
    g2.cmd('ram')
    r = h.wait(lambda r: r.get('seen', {}).get('g2', 0) > seen0, 4)
    check(r.get('seen', {}).get('g2', 0) > seen0, 'host krijgt de botsing van Lotte met zijn bot', (seen0, r.get('seen')))
    time.sleep(1.5)
    sp = speeds(h.rep().get('bot_track', []))
    check(sp and max(sp) < 110, 'bot springt niet bij de host na de botsing (snelheid van beeld tot beeld)', round(max(sp), 1) if sp else sp)
    # Mira stops (pause, Naar menu): her car goes, she stays in the game
    check(g3.cmd('quitrace'), 'Mira stopt met de race (pauze, Naar menu)')
    r = g3.wait(lambda r: r['state'] == 'menu' and r['ui'], 5)
    check(r.get('state') == 'menu' and r.get('ui') and not r.get('lobbyView') and r.get('net'), 'Mira staat in het online-scherm, nog in de game', (r.get('state'), r.get('ui')))
    for p in (h, g1):
        r = p.wait(lambda r: remote(r, 'Mira B') and not remote(r, 'Mira B')['visible'], 3)
        check(remote(r, 'Mira B') and not remote(r, 'Mira B')['visible'], f'{p.name}: auto van Mira weg van de baan', remote(r, 'Mira B'))
    # Bram hangs 2,5 s: the host keeps him, his car is back after it
    g1.cmd('hitch 2500')
    r = h.wait(lambda r: remote(r, 'Bram') and remote(r, 'Bram')['visible'], 4)
    check(remote(r, 'Bram') and remote(r, 'Bram')['visible'], 'Bram hapert 2,5 s en rijdt daarna gewoon verder bij de host', remote(r, 'Bram'))
    rs = [p.wait(lambda r: r['state'] == 'over' and r.get('results'), 90) for p in (h, g1, g2)]
    time.sleep(1.5)
    rs = [p.rep() for p in (h, g1, g2)]
    res = [names(r, n) for r, n in zip(rs, ('Yip', 'Bram', 'Lotte'))]
    check(res[0] and res[0] == res[1] == res[2], 'uitslag op elke pc in dezelfde volgorde', res)
    check('Mira B' not in res[0], 'wie stopte staat niet in de uitslag', res[0])
    check(rs[0].get('again') and not rs[1].get('again'), 'alleen de host heeft "Nieuwe race"', (rs[0].get('again'), rs[1].get('again')))

    # ---- race 2: the host picks another track and fewer bots in the online screen
    check(h.cmd('press Hoofdmenu'), 'host terug naar het online-scherm')
    r = h.wait(lambda r: r['state'] == 'menu' and r['ui'], 5)
    check(r.get('ui') and not r.get('lobbyView'), 'host in het online-scherm na de uitslag', (r.get('state'), r.get('ui')))
    check(h.cmd('set track grachten', timeout=60) and h.cmd('set bots 1'), 'host kiest Grachten en 1 bot')
    h.cmd('press Start race')
    P2 = [h, g1, g2, g3]
    rs = [p.wait(lambda r: r['state'] == 'countdown' and r['track'] == 'grachten', 20) for p in P2]
    check(all(r.get('track') == 'grachten' and r.get('state') == 'countdown' and len(r.get('bots', [])) == 1 for r in rs),
          'nieuwe race op Grachten met 1 bot voor iedereen (ook wie op de uitslag of in het menu stond)', [(r.get('state'), r.get('track'), len(r.get('bots', []))) for r in rs])
    check(len({int(r.get('raceId', 0)) for r in rs}) == 1, 'zelfde race-id')
    check(not any(x['done'] for r in rs for x in r.get('remotes', [])), 'niemand staat al gefinisht aan de start (geen oude pakketjes)',
          [[(x['name'], x['done']) for x in r.get('remotes', [])] for r in rs])
    rs = [p.wait(lambda r: r['go_at'] > 0 and r['state'] == 'racing', 20) for p in P2]
    gos = [r.get('go_at', 0) for r in rs]
    check(max(gos) - min(gos) < 0.25, 'ook na het laden van een andere baan tegelijk groen', (round(max(gos) - min(gos), 3), gos))
    # Teun comes in during the race: he waits for the next one
    g4.cmd('open')
    r = g4.wait(lambda r: len(r['lobbies']) >= 1 and r['lobbies'][0].get('race'), 10)
    check(r.get('lobbies') and r['lobbies'][0].get('race') and any('race bezig' in t for c in r.get('cards', []) for t in c),
          'de lijst zegt dat er een race bezig is', r.get('cards'))
    g4.cmd('join 0')
    r = g4.wait(lambda r: r.get('net') and 'race bezig' in r['status'], 8)
    check(r.get('state') == 'menu' and 'race bezig' in r.get('status', ''), 'laatkomer wacht op de volgende race', (r.get('state'), r.get('status')))
    r = h.wait(lambda r: remote(r, 'Teun') is not None, 5)
    check(r.get('state') == 'racing' and remote(r, 'Teun') and not remote(r, 'Teun')['visible'] and 'g4' not in r.get('order', []),
          'host racet gewoon door, Teun staat in de game maar niet op de baan', (r.get('state'), remote(r, 'Teun')))
    # Lotte stops and leaves the game: gone at once everywhere
    g2.cmd('quitrace'); g2.wait(lambda r: r['ui'], 5)
    check(g2.cmd('press Game verlaten'), 'Lotte verlaat de game')
    r = g2.rep()
    check(not r['net'] and r['lobbyView'], 'Lotte terug in de lijst met games', (r['net'], r['lobbyView']))
    for p in (h, g1):
        r = p.wait(lambda r: remote(r, 'Lotte') is None, 3)
        check(remote(r, 'Lotte') is None, f'{p.name}: Lotte is meteen weg', [x['name'] for x in r.get('remotes', [])])
    check('Lotte heeft de game verlaten' in h.rep()['status'], 'host ziet wie er wegging', h.rep()['status'])
    # Bram' game is killed (crash, task manager): his car goes at once, he leaves the game after the time-out
    g1.kill()
    t0 = time.time()
    r = h.wait(lambda r: remote(r, 'Bram') is None or not remote(r, 'Bram')['visible'], 4)
    check(remote(r, 'Bram') is None or not remote(r, 'Bram')['visible'], 'gekilde speler meteen van de baan', remote(r, 'Bram'))
    r = h.wait(lambda r: 'remotes' in r and remote(r, 'Bram') is None, 30, every=0.5)
    check('remotes' in r and remote(r, 'Bram') is None, 'gekilde speler na de time-out uit de game', round(time.time() - t0, 1))
    r = h.wait(lambda r: r['state'] == 'over' and r.get('results') and 'Bram' not in names(r, 'Yip'), 90)
    check(r.get('state') == 'over' and 'Bram' not in names(r, 'Yip'), 'host haalt de finish, uitslag zonder de weggevallen speler', names(r, 'Yip'))
    # the replay of this race: Lotte left and Bram fell away halfway; every car of it can still be followed
    time.sleep(1)
    check(h.cmd('press Bekijk replay'), 'host bekijkt de replay')
    for _ in range(6):
        h.cmd('ex get_node("/root/Rep").next_btn.emit_signal("pressed")'); time.sleep(0.3)
    r = h.rep()
    check(r['state'] == 'replay' and not h.errors(), 'replay met spelers die halverwege weggingen: alle auto\'s te volgen, geen fouten', (r['state'], h.errors()[:2]))
    h.cmd('press Terug naar uitslag')

    # ---- race 3 (Nieuwe race): Teun races now; the host closes his window halfway
    check(h.cmd('again'), 'host klikt Nieuwe race')
    rs = [p.wait(lambda r: r['state'] == 'racing', 20) for p in (g3, g4)]
    check(all(r.get('state') == 'racing' for r in rs), 'Mira en laatkomer Teun rijden de nieuwe race', [r.get('state') for r in rs])
    time.sleep(1)
    h.cmd('close')
    for g in (g3, g4):
        r = g.wait(lambda r: not r['net'] and r['state'] == 'menu' and r['ui'], 6)
        check(not r.get('net') and r.get('state') == 'menu' and r.get('ui') and r.get('lobbyView') and 'host heeft de game gesloten' in r.get('status', ''),
              f'{g.name}: host sluit midden in de race, melding en terug in de lijst', (r.get('state'), r.get('ui'), r.get('status')))
    # ---- Mira hosts a new game, Teun joins; Mira closes the game on the results screen
    h.proc.wait(15)      # (on one PC the port is free once the old host's game has really quit)
    g3.cmd('press Nieuwe game maken'); g3.cmd('set laps 1'); g3.cmd('set track dorp', timeout=60)
    r = g4.wait(lambda r: any(l['name'] == 'Mira Bs game' for l in r['lobbies']) and not any(l['name'] == 'Yips game' for l in r['lobbies']), 10)
    check([l['name'] for l in r.get('lobbies', [])] == ['Mira Bs game'], 'nieuwe game in de lijst, de gesloten game is weg', r.get('lobbies'))
    g4.cmd('join 0')
    r = g3.wait(lambda r: remote(r, 'Teun') is not None, 8)
    check(remote(r, 'Teun') is not None, 'Teun doet mee in de nieuwe game')
    g3.cmd('press Start race')
    r = g4.wait(lambda r: r['state'] == 'over', 90)
    r3 = g3.wait(lambda r: r['state'] == 'over', 60)
    check(r.get('state') == 'over' and r3.get('state') == 'over', 'tweede game: race gereden')
    time.sleep(1)
    g3.cmd('close')
    r = g4.wait(lambda r: not r['net'] and r['state'] == 'menu', 6)
    check(not r.get('net') and r.get('ui') and 'host heeft de game gesloten' in r.get('status', ''), 'host sluit op de uitslag: melding en terug in de lijst', (r.get('state'), r.get('status')))
    no_errors([h, g1, g2, g3, g4])
    kill_all()

def scenario_full():
    print('== online: volle game (host + 8 spelers), Esc, verkeerd IP-adres, host verlaat de lobby')
    h = Player('host', nick='Yip', car='gt')
    gs = [Player(f'v{i}', nick=f'Speler {i}') for i in range(1, 9)]
    check(all(p.ready(90) for p in [h] + gs), 'negen spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken')
    for g in gs[:7]:
        g.cmd('open'); g.cmd('join 0')
    r = h.wait(lambda r: len(r['remotes']) == 7, 20)
    check(len(r.get('remotes', [])) == 7, 'zeven spelers in de game (8 met de host)', len(r.get('remotes', [])))
    g = gs[7]
    g.cmd('open')
    r = g.wait(lambda r: r['lobbies'] and r['lobbies'][0]['n'] == 8, 8)
    check(r.get('lobbies') and not r['lobbies'][0]['open'] and any('vol' in t for c in r.get('cards', []) for t in c), 'de lijst zegt "vol"', r.get('cards'))
    check(not g.cmd('join 0', timeout=20), 'Meedoen kan niet bij een volle game')
    g.cmd('joinip 127.0.0.1')
    r = g.wait(lambda r: not r['net'] and 'vol' in r['status'], 8)
    check(not r.get('net') and 'zit vol' in r.get('status', '') and r.get('lobbyView'), 'de 9e speler hoort dat de game vol is', r.get('status'))
    r = h.rep()
    check(len(r.get('remotes', [])) == 7, 'de game blijft heel', len(r.get('remotes', [])))
    gs[0].cmd('press Game verlaten')
    h.wait(lambda r: len(r['remotes']) == 6, 5)
    g.wait(lambda r: r['lobbies'] and r['lobbies'][0]['open'], 6)
    check(g.cmd('join 0'), 'plek vrij: Meedoen kan weer')
    r = g.wait(lambda r: r.get('net') and 'game van Yip' in r['status'], 8)
    check('game van Yip' in r.get('status', ''), 'de 9e speler doet nu mee', r.get('status'))
    # Esc and focus on the online screen
    v = gs[0]
    r = v.rep()
    check(r['ui'] and 'NetUi' in r['focus'], 'online-scherm open, focus op een knop', r['focus'])
    v.cmd('esc')
    r = v.rep()
    check(not r['ui'], 'Esc sluit het online-scherm', r['ui'])
    v.cmd('open')
    # a wrong address: a clear message, not a hang, and the list is back
    v.cmd('joinip 10.255.255.1')
    t0 = time.time()
    r = v.wait(lambda r: not r['net'] and 'Geen verbinding' in r['status'], 10)
    check('Geen verbinding' in r.get('status', '') and time.time() - t0 < 9, 'verkeerd IP-adres: melding na een paar seconden', (round(time.time() - t0, 1), r.get('status')))
    r = v.wait(lambda r: r['lobbies'], 5)
    check(r.get('lobbyView') and r.get('lobbies'), 'en de lijst met games is er weer', r.get('lobbies'))
    v.cmd('joinip 192.168.1')
    r = v.rep()
    check(not r['net'] and 'geen IP-adres' in r['status'], 'onzin als adres: meteen een melding', r['status'])
    # the host leaves the lobby: everyone gets a message and the list
    h.cmd('press Game verlaten')
    rs = [p.wait(lambda r: not r['net'], 5) for p in gs[1:]]
    check(all(not r.get('net') and r.get('lobbyView') and 'host heeft de game gesloten' in r.get('status', '') for r in rs), 'host verlaat de lobby: iedereen een melding en de lijst',
          [r.get('status') for r in rs][:2])
    r = gs[1].wait(lambda r: not r['lobbies'], 8)
    check(not r.get('lobbies'), 'de gesloten game verdwijnt uit de lijst', r.get('lobbies'))
    no_errors([h] + gs)
    kill_all()

def scenario_car():
    # the car step opens in a real window (OpenGL, xvfb-run): headless Godot crashes on that menu screen (see report)
    if not shutil.which('xvfb-run'):
        print('-- auto kiezen overgeslagen (geen xvfb-run)'); return
    print('== online: auto kiezen in de lobby (speler in een venster)')
    h = Player('host', nick='Yip', car='gt')
    g = Player('g1', nick='Bram', car='hatch', window=True)
    o = Player('g2', nick='Lotte', car='evo')
    check(all(p.ready(120) for p in (h, g, o)), 'drie spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken')
    for p in (g, o): p.cmd('open'); p.cmd('join 0')
    h.wait(lambda r: len(r['remotes']) == 2, 15)
    check(g.cmd('car gt #2f8f5b', timeout=30), 'Bram kiest een andere auto (Auto kiezen, Klaar)')
    r = g.rep()
    check(r.get('car') == 'gt' and r.get('color') == '#2f8f5b' and r.get('ui') and not r.get('lobbyView'), 'Bram terug in het online-scherm met zijn nieuwe auto',
          (r.get('car'), r.get('color'), r.get('ui')))
    for p in (h, o):
        r = p.wait(lambda r: remote(r, 'Bram') and remote(r, 'Bram')['car'] == 'gt' and remote(r, 'Bram')['color'] == '#2f8f5b', 5)
        check(remote(r, 'Bram') and remote(r, 'Bram')['car'] == 'gt' and remote(r, 'Bram')['color'] == '#2f8f5b', f'{p.name} ziet de nieuwe auto van Bram', remote(r, 'Bram'))
    no_errors([h, g, o])
    kill_all()

class Lan:
    """a small test LAN (Linux, root): every PC its own network namespace, all on one bridge"""
    def __init__(self):
        self.tag = f'prqa{os.getpid() % 100000}'
        self.made = []
        self.k = 0
        self.ok = all(shutil.which(t) for t in ('ip',)) and self.sh(f'ip netns add {self.tag}-lan')
        if self.ok:
            self.made.append(f'{self.tag}-lan')
            self.ok = self.sh(f'ip -n {self.tag}-lan link add br0 type bridge') and self.sh(f'ip -n {self.tag}-lan link set br0 up')
    @staticmethod
    def sh(c):
        return subprocess.run(c.split(), capture_output=True).returncode == 0
    def pc(self, name, addr, vbox=False):
        """a PC with one network card on the LAN (addr like 10.99.1.1/16); vbox: also a VirtualBox-like card that has
        the default route, so 255.255.255.255 goes out of the wrong card (as on many Windows PCs)"""
        ns = f'{self.tag}-{name}'
        self.k += 1
        v = f'pq{os.getpid() % 10000}v{self.k}'
        ok = self.sh(f'ip netns add {ns}')
        self.made.append(ns)
        for c in (f'ip link add {v} type veth peer name eth0 netns {ns}', f'ip link set {v} netns {self.tag}-lan',
                  f'ip -n {self.tag}-lan link set {v} master br0', f'ip -n {self.tag}-lan link set {v} up',
                  f'ip -n {ns} link set lo up', f'ip -n {ns} link set eth0 up', f'ip -n {ns} addr add {addr} dev eth0'):
            ok = ok and self.sh(c)
        if vbox:
            dead = f'{ns}-vb'
            self.sh(f'ip netns add {dead}')
            self.made.append(dead)
            for c in (f'ip link add {v}b type veth peer name vbox0 netns {ns}', f'ip link set {v}b netns {dead}', f'ip -n {dead} link set {v}b up',
                      f'ip -n {ns} link set vbox0 up', f'ip -n {ns} addr add 192.168.56.1/24 dev vbox0',
                      f'ip -n {ns} route add default via 192.168.56.2 dev vbox0'):
                ok = ok and self.sh(c)
        self.ok = self.ok and ok
        return ['ip', 'netns', 'exec', ns]
    def close(self):
        for ns in reversed(self.made):
            self.sh(f'ip netns del {ns}')

def scenario_lan():
    """two hosts and players on separate (virtual) PCs; one player behind a bad connection"""
    if not (hasattr(os, 'geteuid') and os.geteuid() == 0 and sys.platform.startswith('linux')):
        print('-- LAN met meerdere pc\'s overgeslagen (alleen Linux als root)'); return
    print('== online: LAN met 5 pc\'s (/16-netwerk, VirtualBox-kaart, slechte verbinding: 5% verlies, 10-50 ms)')
    lan = Lan()
    px = None
    try:
        h1w = lan.pc('h1', '10.99.1.1/16'); h2w = lan.pc('h2', '10.99.1.2/16')
        gw = lan.pc('g', '10.99.2.1/16', vbox=True); g2w = lan.pc('g2', '10.99.2.2/16'); pxw = lan.pc('px', '10.99.3.1/16')
        if not lan.ok:
            print('-- LAN met meerdere pc\'s overgeslagen (netwerk maken lukte niet)'); return
        TS = 4
        h1 = Player('h1', nick='Yip', car='gt', ts=TS, wrap=h1w)
        h2 = Player('h2', nick='Kim', car='evo', ts=TS, wrap=h2w)
        g = Player('g', nick='Bram', car='hatch', ts=TS, wrap=gw)
        g2 = Player('g2', nick='Lotte', car='super', ts=TS, wrap=g2w)
        px = subprocess.Popen(pxw + [sys.executable, str(pathlib.Path(__file__).with_name('net_lossy.py')), '10.99.3.1', '47810', '10.99.1.1', '0.05', '0.03', '0.02'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        P = [h1, h2, g, g2]
        check(all(p.ready(90) for p in P), 'vier spellen op vier pc\'s gestart')
        for h in (h1, h2): h.cmd('open'); h.cmd('press Nieuwe game maken')
        h1.cmd('set laps 1'); h1.cmd('set bots 2')
        g.cmd('open')
        r = g.wait(lambda r: len(r['lobbies']) == 2, 10)
        check(sorted(l['ip'] for l in r.get('lobbies', [])) == ['10.99.1.1', '10.99.1.2'], 'twee hosts op het LAN staan allebei in de lijst (ook met een VirtualBox-kaart en een /16-netwerk)',
              r.get('lobbies'))
        h2.cmd('press Game verlaten')
        r = g.wait(lambda r: len(r['lobbies']) == 1, 8)
        check([l['name'] for l in r.get('lobbies', [])] == ['Yips game'], 'host die stopt verdwijnt uit de lijst', r.get('lobbies'))
        g.cmd('join 0')
        g2.cmd('open'); g2.cmd('joinip 10.99.3.1')
        r = h1.wait(lambda r: len(r['remotes']) == 2, 15)
        check(len(r.get('remotes', [])) == 2, 'speler via de slechte verbinding komt binnen', [x['name'] for x in r.get('remotes', [])])
        h1.cmd('press Start race')
        rs = [p.wait(lambda r: r['state'] == 'racing', 20) for p in (h1, g, g2)]
        gos = [r.get('go_at', 0) for r in rs]
        check(all(r.get('state') == 'racing' for r in rs) and max(gos) - min(gos) < 0.25, 'start tegelijk, ook met vertraging en verlies (de lampen volgen de klok van de host)', (round(max(gos) - min(gos), 3), [r.get('state') for r in rs]))
        seen = 0
        for _ in range(12):
            time.sleep(0.5)
            x = remote(h1.rep(), 'Lotte')
            seen += 1 if x and x['visible'] else 0
        check(seen >= 10, 'host ziet de speler met de slechte verbinding vrijwel steeds rijden', f'{seen}/12')
        rs = [p.wait(lambda r: r['state'] == 'over' and r.get('results'), 90) for p in (h1, g, g2)]
        time.sleep(2)
        rs = [p.rep() for p in (h1, g, g2)]
        res = [names(r, n) for r, n in zip(rs, ('Yip', 'Bram', 'Lotte'))]
        check(res[0] and res[0] == res[1] == res[2] and len(res[0]) == 5, 'uitslag overal gelijk, ook met pakketverlies', res)
        no_errors(P)
    finally:
        kill_all()
        if px is not None: px.kill()
        lan.close()

which = sys.argv[1:] or ['1', '2', '3', '4']
t0 = time.time()
try:
    if '1' in which: scenario_four()
    if '2' in which: scenario_full()
    if '3' in which: scenario_car()
    if '4' in which: scenario_lan()
finally:
    kill_all()
print(f'-- online (meer spelers): {"alles geslaagd" if not bad else str(len(bad)) + " mislukt: " + ", ".join(bad)}  ({round(time.time() - t0)} s)')
sys.exit(1 if bad else 0)
