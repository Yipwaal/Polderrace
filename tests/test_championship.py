"""Full flow through the menus with real clicks: a complete quick championship (6 races) and the
career Polder Cup (3 races). Every race must end in results + podium, standings must advance, the
championship must be marked done, and credits must be paid.
First: you can only race cars you own (car step, player 2, class buttons, keys, garage browsing, quick race).
Last: balance. Fully upgraded, your car used to be ~8 % faster than the bots (13 s in 3 laps: every race a walkover); the rivals now
tune along (RIVAL_TUNE), so a bot with your upgraded car's stats wins by only a small margin.
"""
from lib import Session, Report, DEFAULT, NEW_GARAGE

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


VISIBLE = "[...$('cars').querySelectorAll('.card')].filter(b=>!b.hidden).map(b=>b.dataset.v).join()"
# a new player: only the hot hatch is owned, the saved settings still point at the (default) GT and a Supercar for player 2
with Session(dict(DEFAULT, car='gt', p2car='super', mode='split'), w=900, h=560,
             extra_init=NEW_GARAGE.replace('{owned:', '{credits:3000,owned:')) as s:
    rep.check(s.ev("settings.car+'/'+settings.p2car") == 'hatch/hatch', 'niet-gekochte auto in de opslag wordt een eigen auto', s.ev("settings.car+'/'+settings.p2car"))
    s.ev("homePanel('play');0"); s.pg.click('#hStart'); s.pg.wait_for_timeout(300); s.pg.click('#nextBtn'); s.pg.wait_for_timeout(400)
    rep.check(s.ev('menuStep') == 0 and s.ev(VISIBLE) == 'hatch', 'autokeuze toont alleen auto\'s in bezit', s.ev(VISIBLE))
    rep.check(s.ev("[...$('classSeg').querySelectorAll('button')].map(b=>b.disabled).join()") == 'false,true,true' and not s.ev("$('carsNote').hidden"),
              'klassen zonder eigen auto uit, met uitleg')
    s.ev("$('classSeg').querySelector('[data-v=S]').click();menuCycle(1);classCycle(1);classCycle(-1);0")
    rep.check(s.ev('settings.car') == 'hatch', 'klik op uitgeschakelde klasse en pijltjes kiezen geen niet-gekochte auto', s.ev('settings.car'))
    s.ev("setEditP(2);menuCycle(1);classCycle(1);0")
    rep.check(s.ev(VISIBLE) == 'hatch' and s.ev('settings.p2car') == 'hatch', 'speler 2: ook alleen eigen auto\'s', s.ev(VISIBLE))
    s.ev("setEditP(1);toMenu(-1);homePanel('garage');pickCar('coupe');openGarage();0"); s.pg.click('#garUpg .buy'); s.pg.wait_for_timeout(200)
    s.ev("pickCar('super');openGarage();0"); s.pg.click('#homeGarage [data-homeback]'); s.pg.wait_for_timeout(200)
    rep.check(s.ev('settings.car') == 'coupe' and s.ev('car.type') == 'coupe', 'garage: rondkijken bij een niet-gekochte auto laat je in je eigen (net gekochte) auto', s.ev('settings.car'))
    s.ev("homePanel('play');0"); s.pg.click('#hStart'); s.pg.wait_for_timeout(300); s.pg.click('#nextBtn'); s.pg.wait_for_timeout(400)
    rep.check(s.ev(VISIBLE) == 'coupe,hatch' or s.ev(VISIBLE) == 'hatch,coupe', 'gekochte auto staat erbij', s.ev(VISIBLE))
    s.ev("toMenu(-1);settings.mode='race';settings.car='hyper';settings.p2car='proto';startRace();0"); s.step(1, False)
    rep.check(s.ev("owns(settings.car)&&owns(car.type)&&owns(settings.p2car)") is True, 'snel racen start nooit met een niet-gekochte auto', s.ev('car.type'))
    rep.check(not s.errs, 'geen JS-fouten (auto\'s in bezit)', str(s.errs[:3]))

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
# balance: a bot-only race (3 laps, compare best laps: one incident does not count) in which one bot drives with the stats of your fully upgraded GT; the other five are rivals as the game sets them up
BAL = """(k=>{toMenu(-1);const u=carUp('gt');u.eng=u.turbo=u.tyre=u.brake=3;settings.car='gt';settings.diff='hard';settings.laps=3;loadTrack('circuit','fwd');applyEnv('day','dry');startRace();
  setupBots(0,Array.from({length:6},(_,i)=>({name:BOT_NAMES[i],type:'gt',color:COLORS[i]})));placeGrid();
  const me=bots[k],c=CARS.gt,e=effStats('gt'),rb=typeof rivalBoost==='function'?rivalBoost():{vmax:1,acc:1,grip:1,brake:1};me.vmax*=e.vmax/c.vmax/rb.vmax;me.acc*=e.acc/c.acc/rb.acc;me.aLat*=e.grip/c.grip/rb.grip;me.brk*=e.brake/c.brake/rb.brake;
  for(let i=0;i<120*400&&!bots.every(b=>b.finished);i++){player.lat=80;update(1/120);}
  const oth=bots.filter(b=>b!==me).map(b=>b.bestLap).sort((a,b)=>a-b);return (oth[0]-me.bestLap)/me.bestLap*100;})"""
with Session(dict(DEFAULT, car='gt', track='circuit', bots=6, diff='hard', laps=3), w=640, h=400) as s:
    edge = [round(s.ev(BAL + f"({k})"), 1) for k in range(3)]
    avg = sum(edge) / len(edge)
    rep.check(avg < 3 and max(edge) < 4.5, 'volle upgrades: kleine voorsprong op de rivalen, geen wandelrace (gem < 3 %)', f'voorsprong snelste ronde in %: {edge}')
    rep.check(not s.errs, 'geen JS-fouten (balans)', str(s.errs[:3]))
rep.finish()
