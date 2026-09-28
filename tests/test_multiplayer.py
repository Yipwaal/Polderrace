"""Online multiplayer with 3 browser pages in one context. The artifact `room` capability only exists on
claude.ai, so tests/mockroom.js replaces window.claude.use('room') with a BroadcastChannel copy that has
the same API (presence, peers, onPeers, join, leave).

Checks: lobby visible to guests, joining, host sees both guests with their cars, race start on a reversed
track reaches every page, all pages race, remote positions arrive, bots are in sync, HUD counts everyone.
"""
from lib import Session, Report, DEFAULT, TESTS, build_test_page

rep = Report('online multiplayer (3 spelers, gesimuleerde room)')
mock = (TESTS / 'mockroom.js').read_text(encoding='utf-8')
with Session(DEFAULT, w=240, h=150, extra_init=mock) as s:
    page = build_test_page()
    H = s.pg; G = s.new_page(page, name='gast: '); G2 = s.new_page(page, name='gast2: ')
    ev = s.ev
    for pg, n in [(H, 'Host Henk'), (G, 'Gast Gijs'), (G2, 'Gast Greet')]:
        ev(f"prefs.nick='{n}';0", pg)
    ev("settings.car='muscle';settings.color='#2f8f5b';rebuildPlayerCar();0", G)
    ev("settings.car='hatch';settings.color='#f2c200';rebuildPlayerCar();0", G2)
    ev("homePanel('net');0", H); H.click('#netCreate'); H.wait_for_timeout(1500)
    ev("homePanel('net');0", G); G.wait_for_timeout(800)
    rep.check(ev('lobbies().length', G) >= 1, 'gast ziet de game in de lobby', ev("JSON.stringify(lobbies().map(l=>l.name))", G))
    G.click('#netList .cupcard'); ev("homePanel('net');0", G2); G2.wait_for_timeout(600); G2.click('#netList .cupcard'); H.wait_for_timeout(1500)
    rem = ev("[...net.remotes.values()].map(r=>r.name+':'+r.carId).sort().join(', ')", H)
    rep.check(rem == 'Gast Gijs:muscle, Gast Greet:hatch', 'host ziet beide gasten met hun auto', rem)
    ev("settings.track='rotterdam';settings.dir='rev';settings.laps=1;settings.bots=2;0", H); H.click('#netStart'); H.wait_for_timeout(2500)
    for pg, n in [(G, 'gast'), (G2, 'gast2')]:
        got = ''
        for _ in range(30):  # the guest picks up the host's race start on its next network tick
            got = ev("TRACK_ID+'/'+TRACK_DIR", pg)
            if got == 'rotterdam/rev':
                break
            pg.wait_for_timeout(500)
        rep.check(got == 'rotterdam/rev', f'{n} krijgt baan en richting van de host', got)
    # the game clamps a frame to 0.1 s, so below 10 fps (three software-rendered pages while other tests run) game time runs slower than
    # the clock and the countdown can take much longer than its 4 s: wait up to 60 s, and say where each page is when it fails
    for _ in range(120):
        H.wait_for_timeout(500)
        if all(ev('state', pg) == 'racing' for pg in [H, G, G2]):
            break
    rep.check(all(ev('state', pg) == 'racing' for pg in [H, G, G2]), 'alle drie racen',
              ' / '.join(ev("state+' '+TRACK_ID+' cd '+(typeof cd==='number'?cd.toFixed(1):'')", pg) for pg in [H, G, G2]))
    for pg in [H, G, G2]:
        ev('kb.up=true;0', pg)
    H.wait_for_timeout(6000)
    seen = ev("[...net.remotes.values()].filter(r=>r.st&&r.st[5]>0).length", H)
    rep.check(seen == 2, 'host ontvangt posities van beide gasten', str(seen))
    bh = ev("bots.map(b=>b.s.toFixed(0)).join(',')", H); bg = ev("bots.map(b=>b.s.toFixed(0)).join(',')", G)
    close = all(abs(float(a) - float(b)) < 40 for a, b in zip(bh.split(','), bg.split(','))) and bh.count(',') == bg.count(',')
    rep.check(close, 'bots lopen synchroon bij host en gast', f'{bh} / {bg}')
    rep.check(ev("$('t').textContent", G).endswith('/5'), 'HUD van de gast telt 3 spelers + 2 bots', ev("$('t').textContent", G))
    rep.check(not s.errs, 'geen JS-fouten op alle pagina\'s', str(s.errs[:3]))
rep.finish()
