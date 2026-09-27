"""Quick check (about 1 minute): static checks + the game loads without errors + one race to the podium
+ every menu screen opens without errors. Run after every change.

usage: python tests/quick_check.py
"""
import subprocess, sys
from lib import Session, Report, DEFAULT, TESTS

r = subprocess.run([sys.executable, str(TESTS / 'test_static.py')], capture_output=True, text=True)
print(r.stdout.strip())
if r.returncode:
    print(r.stderr.strip()); sys.exit(1)

rep = Report('snelle speltest')
with Session(dict(DEFAULT, track='haven', bots=3), w=900, h=560) as s:
    rep.check(s.ev("$('loading').hidden===true&&state==='menu'"), 'spel laadt en toont het hoofdmenu')
    for js, name in [("homePanel('play')", 'spelen'), ("homePanel('garage');garTab('look')", 'garage'), ("homePanel('career')", 'carrière'),
                     ("homePanel('records')", 'records'), ("homePanel('settings')", 'instellingen'), ("homePanel('ach')", 'prestaties'),
                     ("homePanel('main');menuFlow='quick';showMenu(2)", 'menu modus'), ("showMenu(0)", 'menu auto'), ("showMenu(1)", 'menu baan')]:
        e0 = len(s.errs); s.ev(f"toMenu(-1);{js};0"); s.pg.wait_for_timeout(200)
        rep.check(len(s.errs) == e0, f'scherm {name} opent', str(s.errs[e0:e0+2]))
    s.ev("toMenu(-1);startRace();0")
    ok = s.race_until_over(25)
    rep.check(ok and s.ev('inPodium'), 'race Haven van start tot podium', s.ev("$('overTitle').textContent"))
    s.shot('quick_podium.png')
    for tr in ['grachten', 'limburg', 'zeeland']:
        e0 = len(s.errs); s.ev(f"toMenu(-1);settings.track='{tr}';loadTrack('{tr}','rev');startRace();0"); s.step(4.5, False); s.step(6)
        rep.check(len(s.errs) == e0 and s.ev("state") == 'racing', f'{tr} omgekeerd laadt en rijdt', str(s.errs[e0:e0+2]))
    rep.check(not s.errs, 'geen JS-fouten in de hele sessie', str(s.errs[:3]))
rep.finish()
