"""Full flow through the menus with real clicks: a complete quick championship (6 races) and the
career Polder Cup (3 races). Every race must end in results + podium, standings must advance, the
championship must be marked done, and credits must be paid.
"""
from lib import Session, Report, DEFAULT

rep = Report('kampioenschap en carrière')


def run(s):
    s.ev("bots.forEach(b=>{b.vmax*=0.7;});0")
    ok = s.race_until_over(40)
    s.pg.wait_for_timeout(1200)
    for _ in range(10):
        if s.ev('overReady'):
            break
        s.pg.wait_for_timeout(300)
    return ok


with Session(dict(DEFAULT, car='hatch', diff='easy'), w=640, h=400) as s:
    s.ev("champ=null;homePanel('play');0"); s.pg.click('#hChamp'); s.pg.wait_for_timeout(400)
    s.pg.click('#nextBtn'); s.pg.wait_for_timeout(400); s.pg.click('#nextBtn'); s.pg.wait_for_timeout(400)
    n = s.ev('CR().length')
    for r in range(n):
        ok = run(s); pod = s.ev('inPodium')
        s.pg.click('#againBtn'); s.pg.wait_for_timeout(900)
        title = s.ev("$('overTitle').textContent")
        rep.check(ok and pod and ('Tussenstand' in title or 'Kampioen' in title or 'Eindstand' in title), f'kampioenschap race {r+1}/{n} ({s.ev("TRACK_ID")})', title)
        if r < n - 1:
            s.pg.click('#againBtn'); s.pg.wait_for_timeout(700)
    rep.check(s.ev('champ&&champ.done') is True, 'kampioenschap afgerond')
    cr0 = s.ev('garage.credits')
    s.ev('toMenu(-1);0'); s.pg.wait_for_timeout(500)
    s.ev("homePanel('career');0"); s.pg.wait_for_timeout(500); s.pg.click('#careerGo'); s.pg.wait_for_timeout(600)
    n = s.ev('CR().length')
    rep.check(s.ev('champ&&champ.career') == 'B', 'Polder Cup gestart', str(n) + ' races')
    for r in range(n):
        s.ev("bots.forEach(b=>{b.vmax*=0.85;});0")
        ok = run(s)
        s.pg.click('#againBtn'); s.pg.wait_for_timeout(900)
        rep.check(ok, f'cup race {r+1}/{n} ({s.ev("TRACK_ID")})', s.ev("$('overTitle').textContent"))
        if r < n - 1:
            s.pg.click('#againBtn'); s.pg.wait_for_timeout(700)
    rep.check(s.ev('garage.credits') > cr0, 'geld verdiend in de cup', f"{cr0} -> {s.ev('garage.credits')}")
    rep.check(bool(s.ev("garage.career.cups.B")), 'cup-resultaat opgeslagen', str(s.ev("JSON.stringify(garage.career.cups)")))
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
rep.finish()
