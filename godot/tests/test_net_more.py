"""Online scenarios with more players (each a Godot process on this PC, driven like a player: tests/net_ctl.gd):
  1. een avond: host + 3 spelers + een laatkomer. Lobby (instellingen van de host live bij iedereen, klaar, chat,
     aftellen en afbreken), drie races (start tegelijk, bots vloeiend, botsen met een bot, meekijken na de finish en vanuit
     de lobby, uitslag en punten door de host en overal gelijk, stand van de avond, volgende baan om de beurt en met
     stemmen, startvolgorde naar de stand), iemand stopt / hapert / verlaat de game / crasht en komt terug op zijn plek,
     de host sluit midden in de race af en een speler neemt het over (bots rijden door, stand blijft).
  2. vol: host + 8 spelers (de 9e krijgt "vol"), Esc en focus, verkeerd IP-adres, kick, gesloten game, kapotte en
     vijandige pakketjes, race met 8 spelers en 5 bots (bandbreedte gemeten), host verlaat de lobby (overname).
  3. auto kiezen in de lobby (de speler in een venster, met xvfb-run), uiterlijk van de auto bij de anderen.
  4. LAN met losse pc's (Linux als root: netwerk-namespaces): twee hosts in de lijst, /16-netwerk, VirtualBox-kaart,
     broadcast geblokkeerd (gevonden via de sweep), firewall van een host dicht (de lijst zegt het), een speler via een
     slechte verbinding (net_lossy.py: 5% verlies, 150 ms heen en terug, door elkaar): hoe vloeiend en hoe waar zijn auto
     bij de host rijdt, 5 s en 12 s geen verbinding (blijft / komt vanzelf terug), host crasht (overname op een andere pc).
  5. de host stapt uit de race (Naar lobby) terwijl de anderen nog rijden: de bots rijden door, de race krijgt toch een
     uitslag en punten; de host start een nieuwe race voor iedereen binnen is: de lopende race telt mee.
usage: python godot/tests/test_net_more.py [1] [2] [3] [4] [5]   (about 8 minutes: 1 ±2, 2 ±1-3, 3 ±0,5, 4 ±4, 5 ±1; 4 only as root on Linux)"""
import sys, os, time, math, itertools, shutil, subprocess, pathlib, json, socket, random, statistics, threading
import net_players
net_players.isolate()
from net_players import Player, kill_all, TMP

bad = []
def check(c, label, detail=''):
    print(('OK   ' if c else 'FOUT ') + label + (('  ' + str(detail)[:300 if c else 3000]) if detail else ''), flush=True)
    if not c: bad.append(label)

def names(r, nick):
    """the results list of one player as on its screen, with "Jij" as that player's nick (to compare between PCs)"""
    return [nick if x[1] == 'Jij' else x[1] for x in r.get('rows_ui', [])]

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
        ctx = ''
        if e:
            # what the game said just before the first one (where it came from)
            with p.cv:
                i = p.out.index(e[0])
                ctx = ' | '.join(l for l in p.out[max(0, i - 12):i + 3] if not l.startswith('NET '))
        check(not e, f'{p.name}: geen scriptfouten', (e[:3], ctx) if e else '')

def pts_of(r):
    return sorted((x['name'], x['pts'], x['races']) for x in r.get('pts', []))

def final(r):
    return bool(r.get('res') and r['res'].get('final') and int(r['res'].get('id', 0)) == int(r.get('raceId', -1)))

def wait_all(ps, cond, timeout=20):
    return [p.wait(cond, timeout) for p in ps]

# ---------------------------------------------------------------------------------------------------------------- 1
def scenario_evening():
    print('== online: een avond (host + 3 spelers + laatkomer, drie races, crash en overname)')
    TS = 4
    h = Player('host', nick='Yip', car='gt', ts=TS, look={"rim": "gold", "stripe": "center", "sc": "#ff8800", "finish": "metallic", "num": 7, "wing": "gt", "rimStyle": "spoke", "exhaust": "dual", "eng": 3})
    g1 = Player('g1', nick='Bram', car='hatch', ts=TS)
    g2 = Player('g2', nick='Lotte', car='evo', ts=TS)
    g3 = Player('g3', nick='Mira', car='super', ts=TS)
    g4 = Player('g4', nick='Teun', car='hatch', ts=TS)       # comes later
    P = [h, g1, g2, g3]
    check(all(p.ready() for p in P + [g4]), 'vijf spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken')
    check(h.cmd('set laps 1') and h.cmd('set bots 2') and h.cmd('set time dusk') and h.cmd('set weather rain') and h.cmd('set dir rev', timeout=60)
          and h.cmd('set next rot') and h.cmd('set grid rev'), 'host stelt de race in (ronden, bots, avond, regen, omgekeerd, banen om de beurt)')
    for g in (g1, g2, g3): g.cmd('open')
    rs = [g.wait(lambda r: len(r['lobbies']) >= 1, 10) for g in (g1, g2, g3)]
    check(all(len(r.get('lobbies', [])) == 1 and r['lobbies'][0]['name'] == 'Yips game' for r in rs), 'iedereen ziet "Yips game" in de lijst', rs[0].get('cards'))
    r = h.wait(lambda r: r['searching'] >= 1, 5)
    check(r.get('searching', 0) >= 1 and 'zien de jouwe' in r.get('diag', '') or 'ziet de jouwe' in r.get('diag', ''), 'de host ziet dat spelers zijn game vinden', (r.get('searching'), r.get('diag')))
    for g in (g1, g2, g3):
        # one after the other: the seats (and with them who takes over from the host later) are then Bram, Lotte, Mira
        g.cmd('join 0'); g.wait(lambda r: r.get('me'), 8)
    r = g1.wait(lambda r: r.get('net') and 'game van' in r['status'], 8)
    check('NetUi' in r.get('focus', ''), 'na Meedoen staat de focus op een knop van het online-scherm', r.get('focus'))
    r = h.wait(lambda r: len(r['remotes']) == 3, 15)
    seat = {x['name']: x['peer'] for x in r.get('remotes', [])}      # (the three joined at once: seats by who came in first)
    check(sorted((x['name'], x['car']) for x in r.get('remotes', [])) == [('Bram', 'hatch'), ('Lotte', 'evo'), ('Mira', 'super')],
          'host ziet de drie spelers met hun auto', r.get('remotes'))
    check(r.get('players_ui', [None])[0] == 'Yip (jij) | host' and len(r.get('players_ui', [])) == 4, 'spelerslijst bij de host', r.get('players_ui'))
    for g, me in ((g1, 'Bram'), (g2, 'Lotte'), (g3, 'Mira')):
        r = g.wait(lambda r: len(r.get('remotes', [])) == 3 and r.get('cfg', {}).get('dir') == 'rev', 10)
        hostr = remote(r, 'Yip')
        check(hostr is not None and hostr['host'] and hostr['car'] == 'gt' and len(r['remotes']) == 3 and 'game van Yip' in r['status'],
              f'{me} ziet de host en de anderen', (r.get('remotes'), r.get('status')))
    ui = r.get('race_ui', ['', ''])
    check(ui[0] == 'Dorp (omgekeerd)' and '1 ronde' in ui[1] and '2 bots' in ui[1] and 'avond, regen' in ui[1] and 'om de beurt' in ui[1],
          'spelers zien de instellingen van de host (baan, richting, ronden, bots, tijd, weer)', ui)
    lk = remote(r, 'Yip')['look']
    cl = remote(r, 'Yip')['carlook']
    check(lk.get('rim') == 'gold' and lk.get('stripe') == 'center' and lk.get('sc') == '#ff8800' and lk.get('finish') == 'metallic' and int(lk.get('num', 0)) == 7
          and lk.get('wing') == 'gt' and lk.get('paint') == remote(r, 'Yip')['color'] and 'eng' not in lk and len(json.dumps(lk)) < 600
          and cl.get('finish') == 'metallic' and cl.get('stripe') == 'center' and cl.get('rimStyle') == 'spoke',
          'de auto van de host ziet er bij de anderen uit als bij hemzelf (lak, afwerking, velgen, strepen, nummer, vleugel; geen tuning mee)', (lk, cl))
    h.cmd('set laps 2')
    r = g2.wait(lambda r: r.get('cfg', {}).get('laps') == 2, 4)
    check(r.get('cfg', {}).get('laps') == 2 and '2 ronden' in r.get('race_ui', ['', ''])[1], 'een wijziging van de host staat meteen bij de spelers', r.get('race_ui'))
    h.cmd('set laps 1')
    g3.cmd('nick Mira B')
    r = h.wait(lambda r: remote(r, 'Mira B') is not None, 5)
    check(remote(r, 'Mira B') is not None, 'naam wijzigen komt bij de host aan', [x['name'] for x in r.get('remotes', [])])
    # ready, chat, connection quality
    check(g1.cmd('ready') and g2.cmd('ready'), 'Bram en Lotte melden zich klaar')
    r = h.wait(lambda r: remote(r, 'Bram')['rdy'] and remote(r, 'Lotte')['rdy'], 4)
    check(remote(r, 'Bram')['rdy'] and not remote(r, 'Mira B')['rdy'] and r.get('start_ui') == 'Start toch (Mira B niet klaar)',
          'de host ziet wie klaar is, en kan toch starten', (r.get('players_ui'), r.get('start_ui')))
    g2.cmd('say Hoi allemaal'); g3.cmd('say 1')
    rs = [p.wait(lambda r: len(r.get('chat', [])) >= 2, 4) for p in P]
    check(all(['Lotte', 'Hoi allemaal'] in r.get('chat', []) and ['Mira B', 'Klaar?'] in r.get('chat', []) for r in rs), 'chat en vaste zinnen komen bij iedereen aan', rs[0].get('chat'))
    time.sleep(1.2)
    r = h.rep(); rg = g1.rep()
    check(all(x['q']['ping'] >= 0 for x in r['remotes']) and rg.get('ping', -1) >= 0 and all(x['q']['ping'] >= 0 for x in rg['remotes']),
          'ping van elke speler bij de host en bij de spelers', ([x['q'] for x in r['remotes']], rg.get('ping')))
    # countdown: everyone sees it, the host can cancel
    check(h.cmd('start'), 'host klikt Start')
    rs = wait_all(P, lambda r: r.get('countdown', 0) > 0 and r['banner'], 4)
    check(all(r.get('countdown', 0) > 0 and 'Race start over' in r.get('banner', '') for r in rs) and 'Annuleren' in rs[0].get('start_ui', ''),
          'iedereen ziet het aftellen, de host kan nog annuleren', [(r.get('countdown'), r.get('banner')) for r in rs])
    h.cmd('start')
    rs = wait_all(P, lambda r: r.get('countdown', 1) == 0, 3)
    time.sleep(3.3)
    rs = [p.rep() for p in P]
    check(all(r.get('countdown') == 0 and r['state'] == 'menu' for r in rs), 'afgebroken: niemand start', [(r.get('countdown'), r['state']) for r in rs])
    g3.cmd('ready')

    # ---- race 1
    check(h.cmd('start'), 'host start de race')
    rs = [p.wait(lambda r: r['state'] in ('countdown', 'racing') and r['grid'], 15) for p in P]
    check(all(r.get('state') in ('countdown', 'racing') for r in rs), 'iedereen in de race', [r.get('state') for r in rs])
    check(all(r.get('track') == 'dorp' and r.get('dir') == 'rev' and r['settings']['time'] == 'dusk' and r['settings']['weather'] == 'rain' and r['laps'] == 1 for r in rs),
          'zelfde baan, richting, tijd en weer bij iedereen', [(r.get('track'), r.get('dir'), r['settings']) for r in rs][:2])
    check(len({str(r.get('bots')) for r in rs}) == 1 and len(rs[0].get('bots', [])) == 2, 'zelfde bots bij iedereen', rs[0].get('bots'))
    check(len({str(r.get('order')) for r in rs}) == 1 and len({r.get('goDelay') for r in rs}) == 1 and len({int(r.get('raceId', 0)) for r in rs}) == 1,
          'zelfde startvolgorde, race-id en wachttijd voor groen', [(r.get('order'), r.get('goDelay')) for r in rs])
    pts = [tuple(r['grid']) for r in rs if len(r.get('grid', [])) == 2] + [tuple(b) for b in rs[0].get('grid_bots', [])]
    md = min(math.dist(a, b) for a, b in itertools.combinations(pts, 2))
    check(md > 3, 'startopstelling zonder overlap (auto\'s en bots)', round(md, 2))
    rs = [p.wait(lambda r: r['go_at'] > 0, 15) for p in P]
    gos = [r.get('go_at', 0) for r in rs]
    check(max(gos) - min(gos) < 0.25, 'groen licht op elke pc tegelijk', round(max(gos) - min(gos), 3))
    # name tags show within 110 m of the camera: look right after green, while everyone is still near the grid (two
    # seconds later a fast host can be more than 110 m ahead of the others)
    rt = h.rep()
    g2.cmd('drive off')          # Lotte waits a moment: she is last, the others can watch her after their finish
    time.sleep(2)
    g2.cmd('drive on')
    rh = h.rep(); r2 = g2.rep()
    st = steps(r2.get('bot_track', []))
    moving = [s for s in st if s > 0.0005]
    check(len(st) > 60 and len(moving) > 0.8 * len(st), 'bots rijden vloeiend bij een speler (elk beeld een stukje)', (len(moving), len(st)))
    check(rh.get('mapdots') == 3 and sum(1 for x in rt['remotes'] if x['tag']) >= 2, 'de andere spelers staan op de minimap, met hun naam boven de auto (dichtbij)', (rh.get('mapdots'), [x['tag'] for x in rt['remotes']]))
    for g, nm in ((g1, 'Bram'), (g2, 'Lotte')):
        rg = g.rep(); rh = h.rep()
        x = remote(rh, nm)
        check(x and x['visible'] and abs(x['s'] - rg['me_s']) < 80, f'host ziet {nm} waar {nm} rijdt', (x and x['s'], rg['me_s']))
    # Bram rams bot 0 of the host: the host applies his kick, the bot does not jump (at real speed: a faster game
    # time makes every correction between two network updates bigger)
    for p in (h, g1): p.cmd('ts 1')
    bram = seat.get('Bram', 'g1')
    seen0 = h.rep().get('seen', {}).get(bram, 0)
    for _ in range(3):      # (a bot that just changed lanes can be missed: try again)
        h.cmd('track')
        g1.cmd('ram')
        r = h.wait(lambda r: r.get('seen', {}).get(bram, 0) > seen0, 3)
        if r.get('seen', {}).get(bram, 0) > seen0: break
    check(r.get('seen', {}).get(bram, 0) > seen0, 'host krijgt de botsing van Bram met zijn bot', (seen0, r.get('seen')))
    time.sleep(1.5)
    sp = speeds(h.rep().get('bot_track', []))
    check(sp and max(sp) < 110, 'bot springt niet bij de host na de botsing (snelheid van beeld tot beeld)', [round(x) for x in sp])
    sp = speeds(g1.rep().get('bot_track', []))
    check(sp and max(sp) < 110, 'en ook niet bij Bram zelf (zijn botsing en daarna de positie van de host)', [round(x) for x in sp])
    for p in (h, g1): p.cmd(f'ts {TS}')
    # pause online: the world goes on (the host drives the bots for everyone)
    h.cmd('ex get_node("/root/Game").setPaused(true)')
    b0 = g2.rep()['bot_s']; time.sleep(1.0); b1 = g2.rep()['bot_s']; rh = h.rep()
    check(rh['paused'] and abs(b1[0] - b0[0]) > 5, 'de host pauzeert: de bots rijden bij de anderen gewoon door', (rh['paused'], b0, b1))
    h.cmd('ex get_node("/root/Game").setPaused(false)')
    # Mira stops (pause, Naar lobby): her car goes, she stays in the game and can watch the race from the lobby
    check(g3.cmd('quitrace'), 'Mira stopt met de race (pauze, Naar lobby)')
    r = g3.wait(lambda r: r['state'] == 'menu' and r['ui'] and r.get('canWatch'), 5)
    check(r.get('state') == 'menu' and r.get('ui') and not r.get('lobbyView') and r.get('net'), 'Mira staat in het online-scherm, nog in de game', (r.get('state'), r.get('ui')))
    for p in (h, g1):
        r = p.wait(lambda r: remote(r, 'Mira B') and not remote(r, 'Mira B')['visible'], 3)
        check(remote(r, 'Mira B') and not remote(r, 'Mira B')['visible'], f'{p.name}: auto van Mira weg van de baan', remote(r, 'Mira B'))
    check(g3.cmd('press Meekijken', timeout=60), 'Mira klikt Meekijken')
    r = g3.wait(lambda r: r.get('watch') and r.get('spec') in ('Yip', 'Bram', 'Lotte'), 8)
    first = r.get('spec')
    check(r.get('watch') and r.get('specbar', '').startswith('Je kijkt mee met') and first in ('Yip', 'Bram', 'Lotte') and len(r['bots']) == 2 and
          sum(1 for x in r['remotes'] if x['visible']) == 3, 'Mira kijkt mee vanuit de lobby: de race van de anderen, met de bots', (r.get('specbar'), [x['visible'] for x in r.get('remotes', [])]))
    g3.cmd('key Right')
    r = g3.rep()
    check(r.get('spec') and r.get('spec') != first, 'pijltje: een andere auto volgen', (first, r.get('spec')))
    g3.cmd('key Escape')
    r = g3.wait(lambda r: r['ui'] and not r.get('watch'), 4)
    check(r.get('ui') and not r.get('watch') and not r.get('specbar') and r.get('net') and len(r['bots']) == 0, 'Esc: terug in de lobby', (r.get('ui'), r.get('watch')))
    # Bram hangs 2,5 s: the host keeps him, his car is back after it
    g1.cmd('hitch 2500')
    r = h.wait(lambda r: remote(r, 'Bram') and remote(r, 'Bram')['visible'], 4)
    check(remote(r, 'Bram') and remote(r, 'Bram')['visible'], 'Bram hapert 2,5 s en rijdt daarna gewoon verder bij de host', remote(r, 'Bram'))
    # after the finish: watch who is still racing
    r = h.wait(lambda r: r['state'] == 'over' and r.get('over_btns'), 90)
    if 'Meekijken' in r.get('over_btns', []) and not final(r):
        h.cmd('press Meekijken')
        r = h.wait(lambda r: r['specbar'], 3)
        check(r.get('spec') in ('Bram', 'Lotte') and not r['over'], 'na de finish meekijken met wie nog rijdt', (r.get('spec'), r.get('over')))
        h.cmd('key Escape')
        r = h.wait(lambda r: r['over'], 3)
        check(r.get('over') and not r.get('specbar'), 'Esc: de uitslag is terug', r.get('over'))
    else:
        print('     (meekijken na de finish niet gecontroleerd: de anderen waren al binnen)')
    rs = [p.wait(lambda r: r['state'] == 'over' and final(r), 90) for p in (h, g1, g2)]
    time.sleep(1.5)
    rs = [p.rep() for p in (h, g1, g2)]
    res = [names(r, n) for r, n in zip(rs, ('Yip', 'Bram', 'Lotte'))]
    check(res[0] and res[0] == res[1] == res[2], 'uitslag op elke pc in dezelfde volgorde', res)
    check(len({json.dumps(r.get('res'), sort_keys=True).replace('.0', '') for r in rs}) == 1 and len({str([x[3:] for x in r['rows_ui']]) for r in rs}) == 1,
          'en met dezelfde tijden en punten (de host bepaalt de uitslag)', ([json.dumps(r.get('res'), sort_keys=True).replace('.0', '') for r in rs], [str([x[3:] for x in r['rows_ui']]) for r in rs]))
    check('Mira B' not in res[0], 'wie stopte staat niet in de uitslag', res[0])
    check(rs[0].get('again') and not rs[1].get('again'), 'alleen de host heeft "Nieuwe race"', (rs[0].get('again'), rs[1].get('again')))
    ps = [pts_of(p.rep()) for p in P]
    check(ps[0] == ps[1] == ps[2] == ps[3] and sorted(x[1] for x in ps[0]) == [6, 8, 10] and all(x[2] == 1 for x in ps[0]),
          'stand van de avond na race 1: 10, 8 en 6 punten, bij iedereen gelijk (ook bij Mira in de lobby)', ps[0])
    nxt = rs[1].get('cfg', {}).get('nt')
    check(nxt and nxt != 'dorp' and 'Volgende baan' in rs[1].get('over_ui', ''), 'de uitslag zegt welke baan er komt (banen om de beurt)', (nxt, rs[1].get('over_ui')))
    g1.cmd('press Stand van de avond')
    r = g1.rep()
    check(len(r['rows_ui']) == 3 and all('pt' in x[-1] for x in r['rows_ui']) and r['rows_ui'][0][-1] == '10 pt', 'knop Stand van de avond op de uitslag', r.get('rows_ui'))
    g1.cmd('press Uitslag van de race')
    leader = [x['name'] for x in h.rep()['pts']][0]

    # ---- race 2 (Nieuwe race): the next track of the rotation, the leader of the standings starts last
    # Bram's game is busy for 4.5 s just as the host starts (a slow laptop that loads the next track takes longer than
    # the countdown): the host waits for him, so he still gets the start lights with the others
    stall = threading.Thread(target=g1.cmd, args=('ex OS.delay_msec(4500)', 20), daemon=True)
    stall.start()
    time.sleep(0.2)
    check(h.cmd('again'), 'host klikt Nieuwe race')
    rest = [p for p in P if p is not g1]
    rs = wait_all(rest, lambda r: r.get('countdown', 0) > 0, 4)
    check(all(r.get('countdown', 0) > 0 and r.get('banner') for r in rs), 'aftellen op elk scherm (uitslag en lobby)', [(r['state'], r.get('banner')) for r in rs])
    stall.join(15)
    rs = [p.wait(lambda r: r['state'] == 'countdown' and r['track'] == nxt, 25) for p in P]
    check(all(r.get('track') == nxt and r.get('state') == 'countdown' and len(r.get('bots', [])) == 2 for r in rs),
          'nieuwe race op de volgende baan voor iedereen (ook wie in de lobby stond)', [(r.get('state'), r.get('track'), len(r.get('bots', []))) for r in rs])
    check(len({int(r.get('raceId', 0)) for r in rs}) == 1, 'zelfde race-id')
    order = rs[0].get('order', [])
    ids = {'Yip': 'h', 'Bram': seat.get('Bram'), 'Lotte': seat.get('Lotte'), 'Mira B': seat.get('Mira')}
    check(len(order) == 4 and order[-1] == ids[leader] and order[0] == ids['Mira B'], 'startvolgorde naar de stand: de leider achteraan, wie nog geen punten heeft vooraan', (leader, order, h.cmd('ex [get_node("/root/Net").onl().get("grid"), get_node("/root/Net").net.pts, get_node("/root/Net").net.seats]')))
    check(not any(x['done'] for r in rs for x in r.get('remotes', [])), 'niemand staat al gefinisht aan de start (geen oude pakketjes)',
          [[(x['name'], x['done']) for x in r.get('remotes', [])] for r in rs])
    rs = [p.wait(lambda r: r['go_at'] > 0 and r['state'] == 'racing', 20) for p in P]
    gos = [r.get('go_at', 0) for r in rs]
    check(max(gos) - min(gos) < 0.25, 'ook op een andere baan tegelijk groen (de baan was al geladen tijdens het aftellen)', (round(max(gos) - min(gos), 3), gos))
    gi = rs[P.index(g1)].get('go_info', {})
    check(gi.get('cd_at', 0) > 2.0, 'wie de baan langzaam laadde, kreeg toch de hele startprocedure (de host wachtte op hem)', gi)
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
    r = g4.wait(lambda r: r.get('canWatch'), 4)
    check(r.get('canWatch') and len(r.get('pts', [])) == 3, 'de laatkomer kan meekijken en ziet de stand van de avond', (r.get('canWatch'), r.get('pts')))
    # Lotte stops and leaves the game: gone at once everywhere
    g2.cmd('quitrace'); g2.wait(lambda r: r['ui'], 5)
    check(g2.cmd('press Game verlaten'), 'Lotte verlaat de game')
    r = g2.wait(lambda r: not r['net'] and r['lobbyView'], 3)
    check(not r['net'] and r['lobbyView'], 'Lotte terug in de lijst met games', (r['net'], r['lobbyView']))
    check(r['settings']['time'] == 'day' and r['settings']['weather'] == 'dry' and r['settings']['laps'] == 1 and r['settings']['track'] == 'dorp' and r['settings']['dir'] == 'fwd',
          'en haar eigen race-instellingen zijn terug (niet die van de host)', r['settings'])
    for p in (h, g1):
        r = p.wait(lambda r: remote(r, 'Lotte') is None, 3)
        check(remote(r, 'Lotte') is None, f'{p.name}: Lotte is meteen weg', [x['name'] for x in r.get('remotes', [])])
    check('Lotte heeft de game verlaten' in h.rep()['status'], 'host ziet wie er wegging', h.rep()['status'])
    # Bram's game is killed (crash, task manager): his car goes at once, his seat waits for him
    g1.kill()
    t0 = time.time()
    r = h.wait(lambda r: remote(r, 'Bram') is None or not remote(r, 'Bram')['visible'], 4)
    check(remote(r, 'Bram') is None or not remote(r, 'Bram')['visible'], 'gecrashte speler meteen van de baan', remote(r, 'Bram'))
    r = h.wait(lambda r: remote(r, 'Bram') and remote(r, 'Bram')['off'], 20, every=0.5)
    check(remote(r, 'Bram') and remote(r, 'Bram')['off'] and remote(r, 'Bram')['q']['warn'], 'en staat als "verbinding kwijt" in de spelerslijst (zijn plek blijft even vrij)', (round(time.time() - t0, 1), remote(r, 'Bram')))
    g1 = Player('g1', nick='Bram', car='hatch', ts=TS)        # he starts the game again
    check(g1.ready(), 'Bram start het spel opnieuw')
    g1.cmd('open'); g1.cmd('join 0')
    r = g1.wait(lambda r: r.get('net') and r.get('me'), 10)
    rh = h.wait(lambda r: remote(r, 'Bram') and not remote(r, 'Bram')['off'], 6)
    check(r.get('me') == seat.get('Bram') and remote(rh, 'Bram') and remote(rh, 'Bram')['peer'] == seat.get('Bram') and not remote(rh, 'Bram')['off'] and
          any(x['name'] == 'Bram' and x['me'] and x['pts'] > 0 for x in r.get('pts', [])), 'hij komt terug op zijn eigen plek, met zijn punten', (r.get('me'), remote(rh, 'Bram'), r.get('pts')))
    rs = [p.wait(lambda r: r['state'] == 'over' and final(r), 120) for p in (h, g3)]
    time.sleep(1)
    rs = [p.rep() for p in (h, g3, g4)]
    check(final(rs[0]) and names(rs[0], 'Yip') == names(rs[1], 'Mira B') and 'Lotte' not in names(rs[0], 'Yip'), 'race 2: uitslag overal gelijk, zonder wie wegging', (names(rs[0], 'Yip'), names(rs[1], 'Mira B')))
    ps = [p.rep().get('pts', []) for p in (h, g3, g4)]
    check(pts_of({'pts': ps[0]}) == pts_of({'pts': ps[1]}) == pts_of({'pts': ps[2]}) and len(ps[0]) == 4 and any(x['name'] == 'Lotte' and not x['here'] for x in ps[0]),
          'stand na race 2 bij iedereen gelijk; Lotte staat er nog in, als "weg"', pts_of({'pts': ps[0]}))
    tot1 = sum(x['pts'] for x in ps[0])
    # the replay of this race: Lotte left and Bram fell away halfway; every car of it can still be followed
    check(h.cmd('press Bekijk replay'), 'host bekijkt de replay')
    for _ in range(6):
        h.cmd('ex get_node("/root/Rep").next_btn.emit_signal("pressed")'); time.sleep(0.3)
    r = h.rep()
    check(r['state'] == 'replay' and not h.errors(), 'replay met spelers die halverwege weggingen: alle auto\'s te volgen, geen fouten', (r['state'], h.errors()[:2]))
    h.cmd('press Terug naar uitslag')

    # ---- race 3: the players vote for the track; the host closes his window halfway and Bram takes over
    P3 = [h, g1, g3, g4]
    for p in P3: p.cmd('press Lobby')
    h.wait(lambda r: r['ui'] and r['state'] == 'menu', 5)
    check(h.cmd('set next vote') and h.cmd('set laps 1') and h.cmd('set bots 2'), 'host zet de volgende baan op stemmen')
    r = g3.wait(lambda r: len(r.get('cfg', {}).get('cands', [])) == 3, 4)
    cands = r.get('cfg', {}).get('cands', [])
    check(len(cands) == 3 and r['cfg']['track'] not in cands, 'drie banen om uit te kiezen, bij de spelers bekend', cands)
    for p in (g3, g4):
        p.cmd(f'ex get_node("/root/Net").vote("{cands[1]}")')
    r = h.wait(lambda r: sum(1 for x in r['remotes'] if x['vote'] == cands[1]) == 2, 4)
    check(sum(1 for x in r['remotes'] if x['vote'] == cands[1]) == 2, 'de stemmen komen bij de host aan', [(x['name'], x['vote']) for x in r['remotes']])
    for p in (g1, g3, g4): p.cmd('ready')
    h.cmd('start')
    rs = [p.wait(lambda r: r['state'] == 'racing', 30) for p in P3]
    check(all(r.get('state') == 'racing' and r.get('track') == cands[1] for r in rs) and len(rs[0]['order']) == 4, 'race 3 op de baan met de meeste stemmen, nu ook met Teun', [(r.get('state'), r.get('track')) for r in rs])
    time.sleep(2)
    b_before = g3.rep()['bot_s']
    h.cmd('close')
    rs = [p.wait(lambda r: r.get('net') and not r.get('mig') and (r.get('host') or (remote(r, 'Bram') and remote(r, 'Bram')['host'])), 12) for p in (g1, g3, g4)]
    check(rs[0].get('host') and all(r.get('net') and r['state'] in ('racing', 'finished', 'over') for r in rs) and all(remote(r, 'Bram') and remote(r, 'Bram')['host'] for r in rs[1:]),
          'de host sluit midden in de race af: Bram neemt het over, iedereen racet door', [(r.get('host'), r.get('state'), r.get('status')) for r in rs])
    check(all(remote(r, 'Yip') is None for r in rs) and 'Jij bent nu de host' in rs[0].get('status', '') and 'Bram is nu de host' in rs[1].get('status', ''),
          'met een duidelijke melding', [(r.get('status'), r.get('me'), [(x['name'], x['peer']) for x in r.get('remotes', [])]) for r in rs])
    g3.cmd('track'); time.sleep(1.5)
    r = g3.rep()
    st = steps(r.get('bot_track', []))
    moving = [s for s in st if s > 0.0005]
    check(len(st) > 30 and len(moving) > 0.8 * len(st) and r['bot_s'] != b_before, 'de bots rijden door bij de anderen (de nieuwe host bestuurt ze)', (len(moving), len(st)))
    rs = [p.wait(lambda r: r['state'] == 'over' and final(r), 120) for p in (g1, g3, g4)]
    time.sleep(1.2)
    rs = [p.rep() for p in (g1, g3, g4)]
    res = [names(r, n) for r, n in zip(rs, ('Bram', 'Mira B', 'Teun'))]
    check(res[0] and res[0] == res[1] == res[2] and 'Yip' not in res[0] and len(res[0]) == 5, 'de race wordt uitgereden; uitslag overal gelijk', (res, rs[0].get('res'), [(x['peer'], x['name'], x['off'], x['has_st'], x['done']) for x in rs[0].get('remotes', [])], rs[1].get('me')))
    ps = [pts_of(r) for r in rs]
    tot3 = sum(x[1] for x in ps[0])
    check(ps[0] == ps[1] == ps[2] and len(ps[0]) == 5 and tot3 == tot1 + 24 and any(x[0] == 'Yip' for x in ps[0]),
          'de stand van de avond is mee overgenomen en telt door (ook de punten van de oude host staan er nog)', ps[0])
    check(rs[0].get('again') and not rs[1].get('again'), 'de nieuwe host heeft nu "Nieuwe race"', (rs[0].get('again'), rs[1].get('again')))
    check(g1.cmd('again'), 'de nieuwe host start de volgende race')
    rs = [p.wait(lambda r: r['state'] in ('countdown', 'racing') and len(r.get('order', [])) == 3, 25) for p in (g1, g3, g4)]
    check(all(r.get('state') in ('countdown', 'racing') for r in rs) and len({int(r.get('raceId', 0)) for r in rs}) == 1, 'en die start bij iedereen', [r.get('state') for r in rs])
    # the old host comes back: he finds the game (now Bram's) and joins as a player, his points are still his
    h.proc.wait(15)
    h = Player('host', nick='Yip', car='gt', ts=TS)
    check(h.ready(), 'de oude host start het spel opnieuw')
    h.cmd('open')
    r = h.wait(lambda r: any(l['name'] == 'Brams game' for l in r['lobbies']), 10)
    check([l['name'] for l in r.get('lobbies', [])] == ['Brams game'], 'hij ziet de game onder de naam van de nieuwe host', r.get('lobbies'))
    h.cmd('join 0')
    r = h.wait(lambda r: r.get('net') and len(r.get('pts', [])) == 5, 8)
    check(not r.get('host') and any(x['name'] == 'Yip' and x['me'] and x['pts'] > 0 for x in r.get('pts', [])), 'en doet weer mee als speler, met zijn punten', r.get('pts'))
    no_errors([h, g1, g2, g3, g4])
    kill_all()

# ---------------------------------------------------------------------------------------------------------------- 2
def scenario_full():
    print('== online: volle game (host + 8 spelers), Esc, verkeerd IP, kick, gesloten, vijandige pakketjes, race met 8, overname in de lobby')
    TS = 4
    h = Player('host', nick='Yip', car='gt', ts=TS)
    gs = [Player(f'v{i}', nick=f'Speler {i}', ts=TS) for i in range(1, 9)]
    check(all(p.ready(120) for p in [h] + gs), 'negen spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken'); h.cmd('set laps 1'); h.cmd('set bots 5'); h.cmd('set track polder', timeout=60); h.cmd('set time day'); h.cmd('set weather dry')
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
    # leaving and coming back a few times: nothing piles up (players, ENet rooms)
    w = gs[2]
    n0 = (h.rep()['nodes'], w.rep()['nodes'])
    for _ in range(4):
        w.cmd('press Game verlaten'); h.wait(lambda r: len(r['remotes']) == 6, 5)
        w.wait(lambda r: r['lobbies'] and r['lobbies'][0]['open'], 6); w.cmd('join 0')
        h.wait(lambda r: len(r['remotes']) == 7, 8)
    time.sleep(1.5)
    r, rw = h.rep(), w.rep()
    check(len(r['remotes']) == 7 and 'game van Yip' in rw['status'], 'vier keer weggaan en terugkomen werkt', (len(r['remotes']), rw['status']))
    check(r['nodes'] <= n0[0] + 5 and rw['nodes'] <= n0[1] + 5, 'en er blijft niets achter (aantal nodes bij host en speler)', (n0, (r['nodes'], rw['nodes'])))
    # kick: out with a message, and not back in
    k = gs[3]
    check(h.cmd('kick Speler 4'), 'de host zet Speler 4 uit de game (Eruit, Zeker?)')
    r = k.wait(lambda r: not r['net'], 5)
    check(not r.get('net') and 'uit de game gezet' in r.get('status', '') and r.get('lobbyView'), 'die krijgt een duidelijke melding en de lijst', r.get('status'))
    rh = h.wait(lambda r: len(r['remotes']) == 6, 4)
    check(len(rh['remotes']) == 6 and 'uit de game gezet' in rh['status'], 'en is weg bij de host', rh['status'])
    k.wait(lambda r: r['lobbies'], 6); k.cmd('join 0')
    r = k.wait(lambda r: not r['net'] and 'uit de game gezet' in r['status'], 6)
    time.sleep(0.5)
    check(not k.rep().get('net') and len(h.rep()['remotes']) == 6, 'opnieuw meedoen lukt hem niet', k.rep().get('status'))
    # closed for new players
    check(h.cmd('set open 0'), 'de host sluit de game voor nieuwe spelers')
    r = v.wait(lambda r: r['lobbies'] and not r['lobbies'][0]['open'], 6)
    check(any('gesloten' in t for c in r.get('cards', []) for t in c) and not v.cmd('join 0', timeout=3), 'de lijst zegt "gesloten", Meedoen kan niet', r.get('cards'))
    v.cmd('joinip 127.0.0.1')
    r = v.wait(lambda r: not r['net'] and 'gesloten' in r['status'], 6)
    check('gesloten voor nieuwe spelers' in r.get('status', ''), 'via het IP-adres: melding dat de game gesloten is', r.get('status'))
    h.cmd('set open 1')
    v.wait(lambda r: r['lobbies'] and r['lobbies'][0]['open'], 6); v.cmd('join 0')
    r = h.wait(lambda r: len(r['remotes']) == 7, 8)
    check(len(r['remotes']) == 7, 'weer open: de speler doet mee', len(r['remotes']))
    # broken and hostile packets from a guest, and rubbish on the ports: the host stays up and keeps its own state
    hz = gs[4]
    before = h.rep()
    hz.cmd('hostile')
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    for port in (47810, 47811):
        for _ in range(150):
            s.sendto(bytes(random.getrandbits(8) for _ in range(random.randint(1, 1400))), ('127.0.0.1', port))
        s.sendto(b'POLDERRACE?1' + b'x' * 2000, ('127.0.0.1', port)); s.sendto(b'{"pr":1,"id":"x","name":' + b'[' * 3000, ('127.0.0.1', port))
    time.sleep(1.5)
    r = h.rep()
    hostile = remote(r, 'Flood 39') or next((x for x in r['remotes'] if x['peer'] == 'g5'), None)
    check(r.get('net') and r.get('host') and len(r['remotes']) == 7 and not h.errors(), 'kapotte en vijandige pakketjes: de host blijft overeind', (len(r.get('remotes', [])), h.errors()[:2]))
    check(r['dropped'] > 100 and r['cfg'] == before['cfg'] and r['state'] == 'menu' and r['pts'] == before['pts'] and hostile is not None and not hostile['host'] and hostile['uid'] != 'h4x' and not hostile['off'],
          'wat niet klopt of te veel is wordt weggegooid; een speler kan zich geen host maken en geen race, stand of instellingen sturen', (r['dropped'], hostile))
    rs = [p.rep() for p in gs[5:7]]
    check(all(p_.get('net') and remote(p_, 'Yip') and remote(p_, 'Yip')['host'] and sum(1 for x in p_['remotes'] if x['host']) == 1 for p_ in rs) and not gs[5].errors(),
          'de andere spelers merken er niets van (Yip is nog steeds de host)', [[(x['name'], x['host']) for x in p_.get('remotes', [])] for p_ in rs][:1])
    k.wait(lambda r: r['lobbies'] and r['lobbies'][0]['name'] == 'Yips game', 5)
    check(k.rep()['lobbies'] and k.rep()['lobbies'][0]['name'] == 'Yips game', 'en de game staat nog gewoon in de lijst', k.rep().get('lobbies'))
    # a race with 8 players and 5 bots
    P = [h] + [p for p in gs if p is not k]
    h.cmd('set grid rand')
    h.cmd('start')
    rs = [p.wait(lambda r: r['go_at'] > 0 and r['state'] == 'racing', 40) for p in P]
    gos = [r.get('go_at', 0) for r in rs]
    # nine games on one machine: a process the CPU starved can only show green on its first frame after the stall, so a
    # late green counts as in time when the frame gap before it covers the moment the others went green
    ref = statistics.median(gos)
    late = [(round(r.get('go_at', 0) - ref, 3), r.get('go_gap', 0)) for r in rs if abs(r.get('go_at', 0) - ref) >= 0.3]
    ok = all(d > 0 and d - gap < 0.3 for d, gap in late)
    check(all(r.get('state') == 'racing' for r in rs) and ok, 'race met 8 spelers en 5 bots: iedereen start tegelijk', (round(max(gos) - min(gos), 3), late, [r.get('state') for r in rs]))
    if not ok or os.environ.get('NET_DIAG'):
        for r in rs: print('     ', round(r.get('go_at', 0) - ref, 3), r.get('go_info'), flush=True)
    pts = [tuple(r['grid']) for r in rs] + [tuple(b) for b in rs[0]['grid_bots']]
    md = min(math.dist(a, b) for a, b in itertools.combinations(pts, 2))
    check(len(pts) == 13 and md > 3 and rs[0]['order'] != ['h'] + sorted(x for x in rs[0]['order'] if x != 'h'), '13 auto\'s op de grid zonder overlap, in willekeurige volgorde', (round(md, 2), rs[0]['order']))
    time.sleep(4)
    ups = []
    for _ in range(4):
        time.sleep(1.05)
        ups.append((h.rep(), P[1].rep()))
    hu = statistics.mean(a['up'] for a, b in ups); hd = statistics.mean(a['down'] for a, b in ups)
    gu = statistics.mean(b['up'] for a, b in ups); gd = statistics.mean(b['down'] for a, b in ups)
    print(f'     bandbreedte met 8 spelers + 5 bots: host {hu / 1000:.1f} kB/s omhoog, {hd / 1000:.1f} kB/s omlaag; speler {gu / 1000:.1f} kB/s omhoog, {gd / 1000:.1f} kB/s omlaag', flush=True)
    check(hu < 120000 and gu < 6000 and gd < 30000, 'bandbreedte blijft klein (host < 120 kB/s, speler < 6 kB/s omhoog)', (round(hu), round(gu), round(gd)))
    r = P[3].wait(lambda r: sum(1 for x in r['remotes'] if x['visible']) == 7 and r['mapdots'] == 7, 5)
    check(sum(1 for x in r['remotes'] if x['visible']) == 7 and r['mapdots'] == 7, 'elke speler ziet de 7 anderen op de baan en op de minimap', [x['visible'] for x in r['remotes']])
    rs = [p.wait(lambda r: r['state'] == 'over' and final(r), 150) for p in P]
    time.sleep(1.5)
    rs = [p.rep() for p in P]
    # (the hostile game renamed itself "Flood …" behind its own back: on its own screen it is "Jij" = its nick)
    res = [names(r, r['nick'] if p is not hz else next((x['name'] for x in rs[0]['remotes'] if x['peer'] == r.get('me')), '?')) for p, r in zip(P, rs)]
    check(len(res[0]) == 13 and all(x == res[0] for x in res), 'uitslag met 13 auto\'s op alle 8 pc\'s gelijk', res)
    ps = [pts_of(r) for r in rs]
    check(all(x == ps[0] for x in ps) and sorted((x[1] for x in ps[0]), reverse=True) == [10, 8, 6, 5, 4, 3, 2, 1], 'punten 10-8-6-5-4-3-2-1, overal gelijk', ps[0])
    # the host leaves the lobby: the first player takes over, everyone stays together
    for p in P: p.cmd('press Lobby')
    h.wait(lambda r: r['ui'] and r['state'] == 'menu', 5); time.sleep(1)
    h.cmd('press Game verlaten')
    G = P[1:]
    rs = [p.wait(lambda r: r.get('net') and not r.get('mig') and len(r.get('remotes', [])) == 6 and sum(1 for x in r['remotes'] if x['host']) + (1 if r['host'] else 0) == 1, 15) for p in G]
    hosts = [r['nick'] for r in rs if r.get('host')]
    check(len(hosts) == 1 and all(r.get('net') and len(r.get('remotes', [])) == 6 and r.get('ui') for r in rs), 'host verlaat de lobby: een speler neemt over, de andere 6 blijven bij elkaar',
          (hosts, [(len(r.get('remotes', [])), r.get('status')) for r in rs][:3]))
    check(all(pts_of(r) == ps[0] for r in rs), 'met de stand van de avond', pts_of(rs[0]))
    gname = (f"{hosts[0]}'s game" if hosts[0][-1:] in 'aiouy0123456789' else f'{hosts[0]}s game') if hosts else '?'
    r = k.wait(lambda r: [l['name'] for l in r['lobbies']] == [gname], 8)
    check([l['name'] for l in r.get('lobbies', [])] == [gname] and r['lobbies'][0]['n'] == 7, 'in de lijst staat de game nu onder de naam van de nieuwe host', r.get('lobbies'))
    no_errors([h] + gs)
    kill_all()

# ---------------------------------------------------------------------------------------------------------------- 3
def scenario_car():
    # the car step opens in a real window (OpenGL, xvfb-run): headless Godot crashes on that menu screen (see report)
    if not shutil.which('xvfb-run'):
        print('-- auto kiezen overgeslagen (geen xvfb-run)'); return
    print('== online: auto kiezen in de lobby (speler in een venster)')
    h = Player('host', nick='Yip', car='gt')
    g = Player('g1', nick='Bram', car='hatch', window=True, look={"rim": "black", "num": 23, "stripe": "center", "sc": "yellow"})
    o = Player('g2', nick='Lotte', car='evo')
    check(all(p.ready(120) for p in (h, g, o)), 'drie spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken')
    for p in (g, o): p.cmd('open'); p.cmd('join 0')
    r = h.wait(lambda r: len(r['remotes']) == 2, 15)
    lk = remote(r, 'Bram')['look']
    check(lk.get('rim') == 'black' and int(lk.get('num', 0)) == 23 and lk.get('stripe') == 'center' and lk.get('sc') == 'yellow', 'de host ziet de velgen, het nummer en de strepen van Bram', lk)
    g.cmd('ready')
    check(g.cmd('car gt #2f8f5b', timeout=30), 'Bram kiest een andere auto (Auto kiezen, Klaar)')
    r = g.rep()
    check(r.get('car') == 'gt' and r.get('color') == '#2f8f5b' and r.get('ui') and not r.get('lobbyView') and not r.get('ready'), 'Bram terug in het online-scherm met zijn nieuwe auto (en weer "niet klaar")',
          (r.get('car'), r.get('color'), r.get('ui'), r.get('ready')))
    for p in (h, o):
        r = p.wait(lambda r: remote(r, 'Bram') and remote(r, 'Bram')['car'] == 'gt' and remote(r, 'Bram')['color'] == '#2f8f5b', 5)
        check(remote(r, 'Bram') and remote(r, 'Bram')['car'] == 'gt' and remote(r, 'Bram')['color'] == '#2f8f5b', f'{p.name} ziet de nieuwe auto van Bram', remote(r, 'Bram'))
    # the arrows in the lobby: next car and colour without leaving the screen
    g.cmd('ex get_node("/root/NetUi").car_lbl.get_parent().get_child(2).pressed.emit()')
    g.cmd('ex get_node("/root/NetUi").col_swatch.get_parent().get_child(5).pressed.emit()')
    rg = g.rep()
    r = h.wait(lambda r: remote(r, 'Bram')['car'] == rg['car'] and remote(r, 'Bram')['color'] == rg['color'], 5)
    check(rg['car'] != 'gt' and rg['color'] != '#2f8f5b' and remote(r, 'Bram')['car'] == rg['car'] and remote(r, 'Bram')['color'] == rg['color'] and rg['ui'],
          'pijltjes in de lobby: volgende auto en kleur, meteen bij de anderen', (rg['car'], rg['color'], remote(r, 'Bram')))
    # Esc in the car step: back to the online screen, still in the game
    g.cmd('press Auto kiezen'); time.sleep(0.5)
    r = g.rep()
    check(not r.get('ui'), 'Auto kiezen opent de autostap', r.get('ui'))
    g.cmd('esc'); time.sleep(0.5)
    r = g.rep()
    check(r.get('ui') and r.get('net') and not r.get('lobbyView') and 'NetUi' in r.get('focus', ''), 'Esc in de autostap: terug in het online-scherm', (r.get('ui'), r.get('focus')))
    # two players with the same name: every screen calls the one with the later seat "Bram (2)"
    o.cmd('nick Bram')
    rh = h.wait(lambda r: sorted(x['name'] for x in r['remotes']) == ['Bram', 'Bram (2)'], 5)
    names_h = {x['peer']: x['name'] for x in rh.get('remotes', [])}
    rs = [p.wait(lambda r: all(names_h.get(x['peer'], x['name']) == x['name'] for x in r['remotes']), 5) for p in (g, o)]
    check(sorted(names_h.values()) == ['Bram', 'Bram (2)'] and all(len(r.get('remotes', [])) == 2 and all(names_h.get(x['peer'], x['name']) == x['name'] for x in r['remotes']) for r in rs),
          'twee spelers met dezelfde naam: overal dezelfde "Bram" en "Bram (2)"', (names_h, [[(x['peer'], x['name']) for x in r.get('remotes', [])] for r in rs]))
    o.cmd('nick Lotte')
    # the host starts while Bram is choosing a car: he is in the race with everyone
    g.cmd('press Auto kiezen'); time.sleep(0.3)
    h.cmd('set laps 1'); h.cmd('start')
    rs = [p.wait(lambda r: r['state'] in ('countdown', 'racing'), 30) for p in (h, g, o)]
    check(all(r.get('state') in ('countdown', 'racing') for r in rs) and len(rs[0].get('order', [])) == 3, 'de host start terwijl Bram een auto kiest: hij staat gewoon op de grid', [r.get('state') for r in rs])
    no_errors([h, g, o])
    kill_all()

# ---------------------------------------------------------------------------------------------------------------- 4
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
    def firewall(self, name, rules):
        """a firewall on that PC (nft): rules like ('input', 'udp dport { 47810, 47811 } drop'); False when nft is missing"""
        if not shutil.which('nft'): return False
        ns = ['ip', 'netns', 'exec', f'{self.tag}-{name}']
        run = lambda *a: subprocess.run(ns + ['nft'] + list(a), capture_output=True).returncode == 0
        ok = run('add', 'table', 'inet', 'fw')
        for hook, rule in rules:
            ok = ok and run('add', 'chain', 'inet', 'fw', hook, '{ type filter hook ' + hook + ' priority 0; }') and run('add', 'rule', 'inet', 'fw', hook, *rule.split())
        return ok
    def close(self):
        for ns in reversed(self.made):
            self.sh(f'ip netns del {ns}')

def track_error(truth, shown):
    """how far the car shown on another PC is from where it really was at that moment: (median, 95%, worst) in m, and
    the worst jump from one frame to the next compared with what the car really drove in that time"""
    T = list(zip(truth[0::3], truth[1::3], truth[2::3]))
    S = list(zip(shown[0::3], shown[1::3], shown[2::3]))
    # moments the car really jumped (put back on the road): the other screens see that a ping later; leave out a second
    tele = [b[0] for a, b in zip(T, T[1:]) if math.dist(a[1:], b[1:]) > 4.0]
    S = [x for x in S if not any(0 <= x[0] - t < 1.0 for t in tele)]
    errs = []; jumps = []
    j = 0
    prev = None
    for t, x, z in S:
        while j + 1 < len(T) and T[j + 1][0] < t: j += 1
        if j + 1 >= len(T) or T[j][0] > t: continue
        a, b = T[j], T[j + 1]
        k = (t - a[0]) / max(1e-6, b[0] - a[0])
        tx, tz = a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k
        errs.append(math.dist((x, z), (tx, tz)))
        if prev is not None and t - prev[0] < 0.2:
            jumps.append(abs(math.dist((x, z), prev[1:3]) - math.dist((tx, tz), prev[3:5])))
        prev = (t, x, z, tx, tz)
    if len(errs) < 20: return None
    errs.sort()
    return (errs[len(errs) // 2], errs[int(len(errs) * 0.95)], errs[-1], max(jumps) if jumps else 0.0, len(errs), len(tele))

def scenario_lan():
    """two hosts and players on separate (virtual) PCs; one player behind a bad connection"""
    if not (hasattr(os, 'geteuid') and os.geteuid() == 0 and sys.platform.startswith('linux')):
        print('-- LAN met meerdere pc\'s overgeslagen (alleen Linux als root)'); return
    print('== online: LAN met 6 pc\'s (/16-netwerk, VirtualBox-kaart, broadcast dicht, firewall dicht, slechte verbinding, host crasht)')
    lan = Lan()
    px = None
    ctl = TMP / 'relay.ctl'
    ctl.write_text('')
    try:
        h1w = lan.pc('h1', '10.99.1.1/16'); h2w = lan.pc('h2', '10.99.1.2/16')
        gw = lan.pc('g', '10.99.2.1/16', vbox=True); g2w = lan.pc('g2', '10.99.2.2/16'); pxw = lan.pc('px', '10.99.3.1/16')
        sw = lan.pc('s', '10.99.1.50/16')
        if not lan.ok:
            print('-- LAN met meerdere pc\'s overgeslagen (netwerk maken lukte niet)'); return
        # PC s: its broadcasts do not get out and it hears no beacons (a switch or router that filters broadcast)
        sweep_fw = lan.firewall('s', [('output', 'udp dport 47811 ip daddr { 255.255.255.255, 10.255.255.255, 10.99.255.255, 10.99.3.255, 10.99.1.255 } drop'),
                                      ('input', 'udp dport 47812 drop')])
        TS = 1
        h1 = Player('h1', nick='Yip', car='gt', ts=TS, wrap=h1w)
        h2 = Player('h2', nick='Kim', car='evo', ts=TS, wrap=h2w)
        g = Player('g', nick='Bram', car='hatch', ts=TS, wrap=gw)
        g2 = Player('g2', nick='Lotte', car='super', ts=TS, wrap=g2w)
        s = Player('s', nick='Sem', car='evo', ts=TS, wrap=sw)
        # the bad connection: 75 ms each way (150 ms ping) ± 30 ms, 5% of the packets lost, some overtake each other
        px = subprocess.Popen(pxw + [sys.executable, str(pathlib.Path(__file__).with_name('net_lossy.py')), '10.99.3.1', '47810', '10.99.1.1', '0.05', '0.075', '0.03', str(ctl)],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        P = [h1, h2, g, g2, s]
        check(all(p.ready(90) for p in P), 'vijf spellen op vijf pc\'s gestart')
        for h in (h1, h2): h.cmd('open'); h.cmd('press Nieuwe game maken')
        h1.cmd('set laps 2'); h1.cmd('set bots 2'); h1.cmd('set track polder', timeout=60)
        r = h1.wait(lambda r: r['selftest'] in ('ok', 'fail'), 8)
        check(r.get('selftest') == 'ok', 'zelftest van de host: zijn eigen zoekbericht komt bij hem terug', r.get('selftest'))
        g.cmd('open')
        r = g.wait(lambda r: len(r['lobbies']) == 2, 10)
        check(sorted(l['ip'] for l in r.get('lobbies', [])) == ['10.99.1.1', '10.99.1.2'], 'twee hosts op het LAN staan allebei in de lijst (ook met een VirtualBox-kaart en een /16-netwerk)',
              r.get('lobbies'))
        # the firewall of Kim's PC closes: her game is still seen (her own beacon) but the list says what is wrong
        if lan.firewall('h2', [('input', 'udp dport { 47810, 47811 } drop')]):
            r = g.wait(lambda r: any(l['name'] == 'Kims game' and l['deaf'] for l in r['lobbies']), 12)
            check(any(l['name'] == 'Kims game' and l['deaf'] for l in r.get('lobbies', [])) and any('firewall' in t for c in r.get('cards', []) for t in c),
                  'firewall van een host dicht: zijn game staat in de lijst met de melding dat zijn firewall het spel tegenhoudt', r.get('cards'))
            # (the first seconds after making the game it just says the game is up)
            r = h2.wait(lambda r: r['searching'] == 0 and ('Nog niemand ziet je game' in r['diag'] or 'firewall' in r['diag']), 12)
            check(r.get('searching') == 0 and ('Nog niemand ziet je game' in r.get('diag', '') or 'firewall' in r.get('diag', '')), 'en die host leest zelf wat hij moet nalopen', (r.get('searching'), r.get('diag')))
        else:
            print('     (firewall-scenario overgeslagen: geen nft)')
        h2.cmd('press Game verlaten')
        r = g.wait(lambda r: len(r['lobbies']) == 1, 8)
        check([l['name'] for l in r.get('lobbies', [])] == ['Yips game'], 'host die stopt verdwijnt uit de lijst', r.get('lobbies'))
        # broadcast filtered: found by asking every address of the /24 one by one
        s.cmd('open')
        if sweep_fw:
            r = s.wait(lambda r: len(r['lobbies']) == 1, 14)
            check(len(r.get('lobbies', [])) == 1 and r['lobbies'][0]['ip'] == '10.99.1.1' and r.get('sweeps', 0) >= 1, 'broadcast geblokkeerd: de game wordt toch gevonden (alle adressen van het netwerk langs)',
                  (r.get('lobbies'), r.get('sweeps')))
        s.cmd('join 0') if s.rep().get('lobbies') else s.cmd('joinip 10.99.1.1')
        g.cmd('join 0')
        g2.cmd('open'); g2.cmd('joinip 10.99.3.1')
        r = h1.wait(lambda r: len(r['remotes']) == 3, 15)
        check(len(r.get('remotes', [])) == 3, 'speler via de slechte verbinding komt binnen', [x['name'] for x in r.get('remotes', [])])
        check(g2.rep().get('recent') == ['10.99.3.1'], 'het IP-adres waarmee hij meedeed is onthouden (één klik de volgende keer)', g2.rep().get('recent'))
        time.sleep(2.5)
        r = h1.rep()
        q = remote(r, 'Lotte')['q']
        check(q['ping'] > 100 and q['warn'] and not remote(r, 'Bram')['q']['warn'], 'de host ziet wie een slechte verbinding heeft (ping, waarschuwing)', (q, remote(r, 'Bram')['q']))
        h1.cmd('start')
        rs = [p.wait(lambda r: r['state'] == 'racing', 25) for p in (h1, g, g2, s)]
        gos = [r.get('go_at', 0) for r in rs]
        check(all(r.get('state') == 'racing' for r in rs) and max(gos) - min(gos) < 0.25, 'start tegelijk, ook met vertraging en verlies (de lampen volgen de klok van de host)', (round(max(gos) - min(gos), 3), gos, [r.get('state') for r in rs]))
        # how smooth and how true the car of the player with the bad connection drives on the host's screen, and the
        # host's car on his
        time.sleep(3)
        h1.cmd('follow Lotte'); g2.cmd('follow Yip'); g.cmd('follow Yip')
        time.sleep(9)
        th = h1.cmd('tracks', timeout=30); tg = g2.cmd('tracks', timeout=30); tb = g.cmd('tracks', timeout=30)
        for p in (h1, g2, g): p.cmd('follow off')
        e1 = track_error(tg['me'], th['rem'])
        e2 = track_error(th['me'], tg['rem'])
        e3 = track_error(th['me'], tb['rem'])
        if e1 and e2 and e3:
            print(f'     slechte verbinding (150 ms ping ± 30, 5% verlies), auto van de speler bij de host: mediaan {e1[0]:.2f} m, 95% {e1[1]:.2f} m, ergste {e1[2]:.2f} m naast de echte plek; grootste sprong per beeld {e1[3]:.2f} m ({e1[4]} beelden, {e1[5]}x teruggezet op de baan)', flush=True)
            print(f'     auto van de host bij die speler: mediaan {e2[0]:.2f} m, 95% {e2[1]:.2f} m, ergste {e2[2]:.2f} m; sprong {e2[3]:.2f} m', flush=True)
            print(f'     goede verbinding (LAN), auto van de host bij een speler: mediaan {e3[0]:.2f} m, 95% {e3[1]:.2f} m, ergste {e3[2]:.2f} m; sprong {e3[3]:.2f} m', flush=True)
        check(e1 and e1[1] < 3.0 and e1[3] < 1.5 and e2 and e2[1] < 3.0 and e2[3] < 1.5, 'slechte verbinding: de auto rijdt vloeiend en vrijwel op zijn echte plek (95% binnen 3 m, geen sprongen)', (e1, e2))
        # (the car is drawn a few hundredths of a second behind, at 30 m/s that is a metre; more on a busy test machine)
        check(e3 and e3[1] < 1.6 and e3[3] < 0.8, 'goede verbinding: vrijwel op de echte plek (95% binnen 1,6 m), geen sprongen', e3)
        # the Wi-Fi drops for 5 s: nobody is thrown out, the car is back by itself
        ctl.write_text('block'); time.sleep(5); ctl.write_text('')
        r = h1.wait(lambda r: remote(r, 'Lotte') and remote(r, 'Lotte')['visible'], 6)
        r2 = g2.rep()
        check(remote(r, 'Lotte') and remote(r, 'Lotte')['visible'] and r2.get('net') and r2['state'] == 'racing' and not r2.get('reconn'), '5 s geen verbinding: de speler blijft in de race, zijn auto is er vanzelf weer', (remote(r, 'Lotte'), r2.get('status')))
        # 12 s: the connection is gone for both sides; the player reconnects by itself into his own seat
        ctl.write_text('block')
        r2 = g2.wait(lambda r: r.get('reconn'), 14, every=0.5)
        check(r2.get('reconn') and r2.get('net') and 'Opnieuw verbinden' in r2.get('status', '') + r2.get('banner', ''), 'langer weg: "verbinding kwijt, opnieuw verbinden" in plaats van uit de game', (r2.get('status'), r2.get('banner')))
        time.sleep(2); ctl.write_text('')
        r2 = g2.wait(lambda r: r.get('net') and not r.get('reconn') and 'hersteld' in r.get('status', ''), 12)
        r = h1.wait(lambda r: remote(r, 'Lotte') and not remote(r, 'Lotte')['off'] and remote(r, 'Lotte')['visible'], 8)
        check(r2.get('me') == 'g3' or r2.get('me') in ('g1', 'g2', 'g3') and r2.get('net') and not r2.get('reconn') and remote(r, 'Lotte') and remote(r, 'Lotte')['peer'] == r2.get('me') and remote(r, 'Lotte')['visible'],
              'verbinding terug: vanzelf weer in de game, op dezelfde plek, en hij racet gewoon door', (r2.get('me'), r2.get('status'), remote(r, 'Lotte')))
        rs = [p.wait(lambda r: r['state'] == 'over' and final(r), 150) for p in (h1, g, g2, s)]
        time.sleep(2)
        rs = [p.rep() for p in (h1, g, g2, s)]
        res = [names(r, n) for r, n in zip(rs, ('Yip', 'Bram', 'Lotte', 'Sem'))]
        check(res[0] and res[0] == res[1] == res[2] == res[3] and len(res[0]) == 6, 'uitslag overal gelijk, ook met pakketverlies en een verbinding die wegviel', res)
        ps = pts_of(rs[1])
        # the host's PC crashes: after the time-outs a player on another PC takes over, the others find him there
        for p in (g, g2, s): p.cmd('press Lobby')
        time.sleep(1)
        h1.kill()
        t0 = time.time()
        G = [g, g2, s]
        rs = [p.wait(lambda r: r.get('net') and not r.get('mig') and not r.get('reconn') and len(r.get('remotes', [])) == 2 and not any(x['off'] for x in r['remotes'])
                      and sum(1 for x in r['remotes'] if x['host']) + (1 if r['host'] else 0) == 1, 60, every=0.5) for p in G]
        hosts = [r['nick'] for r in rs if r.get('host')]
        check(len(hosts) == 1 and all(len(r.get('remotes', [])) == 2 and not any(x['off'] for x in r['remotes']) for r in rs), 'de pc van de host valt uit: een speler op een andere pc neemt over, de anderen vinden hem daar',
              (hosts, round(time.time() - t0, 1), [r.get('status') for r in rs]))
        print(f'     overname na een crash van de host: {time.time() - t0:.0f} s', flush=True)
        check(all(pts_of(r) == ps for r in rs) and len(ps) == 4, 'de stand van de avond is er nog', pts_of(rs[0]))
        no_errors(P)
    finally:
        kill_all()
        if px is not None: px.kill()
        lan.close()

# ---------------------------------------------------------------------------------------------------------------- 5
def scenario_host_out():
    print('== online: de host stapt uit de race terwijl de anderen nog rijden')
    TS = 4
    h = Player('host', nick='Yip', car='gt', ts=TS)
    g1 = Player('g1', nick='Bram', car='hatch', ts=TS)
    g2 = Player('g2', nick='Lotte', car='evo', ts=TS)
    g3 = Player('g3', nick='Teun', car='super', ts=TS)     # comes later
    P = [h, g1, g2]
    check(all(p.ready() for p in P + [g3]), 'vier spellen gestart')
    h.cmd('open'); h.cmd('press Nieuwe game maken')
    h.cmd('set laps 2'); h.cmd('set bots 2')
    for g in (g1, g2): g.cmd('open')
    for g in (g1, g2):
        g.cmd('join 0'); g.wait(lambda r: r.get('me'), 8)     # (one after the other: Bram has the first seat)
    h.wait(lambda r: len(r['remotes']) == 2, 15)
    # keyboard / gamepad: the host's focus on Bram's "Eruit" button stays there while the list refreshes (every second)
    h.cmd('ex get_node("/root/NetUi").players.get_child(1).get_child(get_node("/root/NetUi").players.get_child(1).get_child_count() - 1).grab_focus()')
    time.sleep(2.5)
    f = h.cmd('ex [get_viewport().gui_get_focus_owner().get_parent().get_meta("nick", ""), get_viewport().gui_get_focus_owner().text]')
    check(f == '["Bram", "Eruit"]', 'de focus blijft op de knop Eruit van Bram terwijl de lijst ververst', f)
    # race 1: the host changes the track during the countdown (the countdown starts again with the new one); then he
    # stops at once (pause, Naar lobby) and the others race on
    h.cmd('start')
    g1.wait(lambda r: r.get('countdown', 0) > 0, 4)
    h.cmd('ex get_node("/root/NetUi").cyc.track.get_parent().get_child(3).pressed.emit()')
    newt = h.rep().get('settings', {}).get('track')
    nm = h.cmd('ex get_node("/root/Net").trackName("%s", "fwd")' % newt)
    r = g1.wait(lambda r: nm in r.get('banners', []), 8)
    check(newt != 'dorp' and nm in r.get('banners', []), 'de host kiest een andere baan tijdens het aftellen: het aftellen begint opnieuw met die baan', (newt, r.get('banners')))
    rs = [p.wait(lambda r: r['state'] == 'racing', 25) for p in P]
    check(all(r.get('state') == 'racing' for r in rs), 'iedereen in de race', [r.get('state') for r in rs])
    check(all(r.get('track') == newt for r in rs), 'op de nieuwe baan', [r.get('track') for r in rs])
    time.sleep(1.5)
    check(h.cmd('quitrace'), 'de host stopt met de race (pauze, Naar lobby)')
    time.sleep(3)
    b0 = g1.rep().get('bot_s', []); time.sleep(1.0); b1 = g1.rep().get('bot_s', [])
    check(len(b0) == 2 and all(abs(a - b) > 0.5 for a, b in zip(b0, b1)) and max(abs(a - b) for a, b in zip(b0, b1)) > 20, 'de bots blijven rijden bij de anderen (ze staan niet stil op de weg)', (b0, b1))
    rs = [p.wait(lambda r: r['state'] == 'over' and final(r), 90) for p in (g1, g2)]
    check(all(final(r) for r in rs), 'de race krijgt een officiele uitslag, ook al staat de host in de lobby', [(r.get('state'), r.get('res')) for r in rs])
    time.sleep(1)
    ps = [pts_of(p.rep()) for p in P]
    check(ps[0] == ps[1] == ps[2] and sorted(x[1] for x in ps[0]) == [8, 10], 'en punten voor wie de race uitreed, bij iedereen gelijk', ps)
    r = h.rep()
    check(r.get('state') == 'menu' and not h.errors(), 'de host stond al die tijd in de lobby', r.get('state'))
    # race 2: Lotte stands still; Yip and Bram finish, and Yip starts the next race before she is in
    for p in (g1, g2): p.cmd('press Lobby')
    h.cmd('set laps 1')
    h.cmd('start')
    rs = [p.wait(lambda r: r['state'] == 'racing', 25) for p in P]
    g2.cmd('drive off')
    rid = rs[0].get('raceId')
    g3.cmd('open'); g3.cmd('join 0'); g3.wait(lambda r: r.get('me'), 8)       # Teun comes in: he races from the next race on
    r = h.wait(lambda r: r['state'] == 'over' and r.get('again'), 90)
    g1.wait(lambda r: r['state'] in ('finished', 'over'), 60)
    check(h.cmd('again'), 'de host klikt Nieuwe race terwijl Lotte nog rijdt')
    rs = [p.wait(lambda r: r.get('countdown', 0) > 0 or r['state'] == 'countdown', 6) for p in P]
    ps = [pts_of(p.rep()) for p in P]
    check(ps[0] == ps[1] == ps[2] and all(x[2] == 2 for x in ps[0] if x[0] in ('Bram', 'Lotte')),
          'de race die nog liep telt mee in de stand (wie nog reed, krijgt de plek die hij had)', ps)
    P = [h, g1, g2, g3]
    rs = [p.wait(lambda r: r['state'] in ('countdown', 'racing') and r.get('raceId') != rid, 25) for p in P]
    check(all(r.get('state') in ('countdown', 'racing') for r in rs) and len({r.get('raceId') for r in rs}) == 1, 'en de volgende race start bij iedereen (ook bij wie later kwam)', [r.get('state') for r in rs])
    # race 3: Bram (first seat) stops and stands in the lobby; then the host closes his game. Bram and Lotte must pick the
    # same new host without talking: the one still racing (Lotte), not Bram for being first in line
    g2.cmd('drive on')
    for p in P: p.wait(lambda r: r['state'] == 'racing', 20)
    time.sleep(1)
    check(g1.cmd('quitrace'), 'Bram stopt en staat in de lobby')
    g1.wait(lambda r: r['state'] == 'menu', 5)
    h.cmd('close')
    t0 = time.time()
    one_host = lambda r: r.get('net') and not r.get('mig') and len(r.get('remotes', [])) == 2 and not any(x['off'] for x in r['remotes']) and (r.get('host') or any(x['host'] for x in r['remotes']))
    rs = [p.wait(one_host, 15) for p in (g1, g2, g3)]
    check(rs[1].get('host') and not rs[0].get('host') and not rs[2].get('host') and remote(rs[0], 'Lotte') and remote(rs[0], 'Lotte')['host'] and rs[1].get('state') == 'racing',
          'iedereen kiest dezelfde nieuwe host: wie nog racet (Lotte), ook al staat Bram eerder in de rij', ([(r.get('host'), r.get('state'), r.get('status')) for r in rs], round(time.time() - t0, 1)))
    # and when two players do pick themselves (here: Bram thinks Teun stopped too) on one PC, the second cannot open the
    # port: he goes to the other one instead of falling out of the game (and his screen never looks at a closed game)
    g1.cmd('ex get_node("/root/Net").net.remotes["%s"].merge({"out": true}, true)' % rs[2].get('me', 'g3'))
    g2.cmd('close')
    t0 = time.time()
    one = lambda r: r.get('net') and not r.get('mig') and len(r.get('remotes', [])) == 1 and not r['remotes'][0]['off'] and (r.get('host') or r['remotes'][0]['host'])
    rs = [p.wait(one, 25) for p in (g1, g3)]
    check(all(one(r) for r in rs) and sum(1 for r in rs if r.get('host')) == 1, 'twee spelers kiezen zichzelf: het eindigt toch met een host en iedereen erin',
          ([(r.get('host'), r.get('status')) for r in rs], round(time.time() - t0, 1)))
    P = [h, g1, g2, g3]
    no_errors(P)
    kill_all()

which = sys.argv[1:] or ['1', '2', '3', '4', '5']
t0 = time.time()
try:
    if '1' in which: scenario_evening()
    if '2' in which: scenario_full()
    if '3' in which: scenario_car()
    if '4' in which: scenario_lan()
    if '5' in which: scenario_host_out()
finally:
    kill_all()
print(f'-- online (meer spelers): {"alles geslaagd" if not bad else str(len(bad)) + " mislukt: " + ", ".join(bad)}  ({round(time.time() - t0)} s)')
sys.exit(1 if bad else 0)
