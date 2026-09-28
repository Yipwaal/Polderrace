"""Full flow through the menus with real clicks: a complete quick championship (6 races) and chapter 1 of the story
career (a race, an elimination, a duel with rival Daan, then the Polder Cup of 3 races). Every race must end in results
(+ podium), standings must advance, the championship must be marked done, credits must be paid, each career event shows
its story line and opens the next one; after a career race the quick-race settings are back. An old save still counts.
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
    # career: a fresh career starts at chapter 1, event 1 (a race); every event has a story, a goal and prize money
    s.ev("garage.career={cups:{},bonus:{}};saveGarage();toMenu(-1);0"); s.pg.wait_for_timeout(500)
    s.ev("homePanel('career');0"); s.pg.wait_for_timeout(500)
    rep.check(s.ev("careerSel") == 'b1' and s.ev("!!document.getElementById('careerEvInfo')") and s.ev("$('careerChs').querySelector('[data-v=c2]').disabled"),
              'carrière begint bij hoofdstuk 1, evenement 1 (hoofdstuk 2 op slot)', s.ev("careerSel"))
    keep = s.ev("JSON.stringify([settings.mode,settings.track,settings.laps,settings.bots,settings.diff])")

    def event(eid, label, kind):
        s.ev(f"careerSel='{eid}';careerCh=chapterOf(CAREER_EVS.find(e=>e.id==='{eid}')).id;openCareer();0"); s.pg.wait_for_timeout(300)
        cr = s.ev('garage.credits'); s.pg.click('#careerGo'); s.pg.wait_for_timeout(600)
        info = s.ev("JSON.stringify({ev:careerEv&&careerEv.ev.id,mode,bots:bots.map(b=>b.name+(b.rival?'*':'')),track:TRACK_ID})")
        ok = run(s)
        res = s.ev("JSON.stringify({story:!$('storyBox').hidden&&$('storyBox').textContent.length>20,again:$('againBtn').textContent,res:garage.career.cups['%s']})" % eid)
        rep.check(ok and kind in info and '"story":true' in res and 'Verder' in res and s.ev('garage.credits') > cr, label, info + ' ' + res)
        s.pg.click('#againBtn'); s.pg.wait_for_timeout(900)
        return s.ev("homeView+' '+careerSel")
    after = event('b1', 'race b1: rivaal Daan rijdt mee, verhaal + prijzengeld na de race', 'Daan*')
    rep.check(after == 'career b2', 'Verder: terug in de carrière, volgende evenement gekozen', after)
    rep.check(s.ev("JSON.stringify([settings.mode,settings.track,settings.laps,settings.bots,settings.diff])") == keep
              and s.ev("localStorage.getItem('polderrace3d-settings')").find('"mode":"' + s.ev('settings.mode')) >= 0,
              'snel-race-instellingen terug na een carrière-race', keep)
    s.ev("garage.career.cups.b2={best:1,won:true};saveGarage();0")
    event('b3', 'eliminatie b3 in de carrière', '"mode":"elim"')
    after = event('b4', 'duel b4: één tegenstander, Daan in zijn Rallyhatch', '"bots":["Daan*"]')
    rep.check(after == 'career B', 'na het duel staat de Polder Cup klaar', after)
    cr0 = s.ev('garage.credits')
    s.pg.click('#careerGo'); s.pg.wait_for_timeout(600)
    n = s.ev('CR().length')
    rep.check(s.ev('champ&&champ.career') == 'B' and s.ev("champ.bots.some(b=>b.name==='Daan'&&b.rival)"), 'Polder Cup gestart, met Daan', str(n) + ' races')
    for r in range(n):
        s.ev("bots.forEach(b=>{b.vmax*=0.85;});0")
        ok = run(s)
        s.pg.click('#againBtn'); s.pg.wait_for_timeout(900)
        rep.check(ok, f'cup race {r+1}/{n} ({s.ev("TRACK_ID")})', s.ev("$('overTitle').textContent"))
        if r < n - 1:
            s.pg.click('#againBtn'); s.pg.wait_for_timeout(700)
    rep.check(s.ev("!$('storyBox').hidden") and s.ev("$('againBtn').textContent") == 'Verder', 'cup-eindstand met verhaal', s.ev("$('storyBox').textContent")[:80])
    rep.check(s.ev('garage.credits') > cr0 and s.ev('garage.career.bonus.c1') is True, 'geld verdiend in de cup + bonus hoofdstuk 1', f"{cr0} -> {s.ev('garage.credits')}")
    rep.check(bool(s.ev("garage.career.cups.B")) and s.ev("chUnlocked(CHAPTERS[1])") is True, 'cup-resultaat opgeslagen, hoofdstuk 2 open', str(s.ev("JSON.stringify(garage.career.cups)")))
    s.pg.click('#againBtn'); s.pg.wait_for_timeout(900)
    rep.check(s.ev("homeView+' '+careerSel") == 'career a1', 'na de cup: hoofdstuk 2, evenement 1', s.ev("homeView+' '+careerSel"))
    rep.check(not s.errs, 'geen JS-fouten', str(s.errs[:3]))
# an old save (before the story career) that already passed the Polder Cup: chapter 2 is open and so is all of chapter 1
with Session(DEFAULT, w=640, h=400, extra_init="localStorage.setItem('polderrace3d-garage',JSON.stringify({owned:{hatch:true,gt:true},career:{cups:{B:{best:2}}}}));") as s:
    r = s.ev("JSON.stringify({c2:chUnlocked(CHAPTERS[1]),c3:chUnlocked(CHAPTERS[2]),ch1:CHAPTERS[0].events.map(evUnlocked),a:CHAPTERS[1].events.map(evUnlocked),next:careerNext().id})")
    rep.check(r == '{"c2":true,"c3":false,"ch1":[true,true,true,true,true],"a":[true,false,false,false,false],"next":"a1"}', 'oude save: Polder Cup gehaald -> hoofdstuk 2 open, daar ga je verder', r)
    rep.check(not s.errs, 'geen JS-fouten (oude save)', str(s.errs[:3]))
# an old save in the middle of its first Delta Trofee: the cup stays open (Ga verder works), though the events before it were never raced
RUN = "{career:'A',rounds:[{track:'haven',time:'dusk',weather:'dry',laps:2},{track:'afsluitdijk',time:'day',weather:'rain',laps:2}],nRounds:2,active:false,car:'gt',color:'#d62a2a',cls:'A',diff:'hard',round:1,bots:[{name:'Henk',type:'gt',color:'#1d4f9e'}],pts:{Jij:10,Henk:8},history:[['Jij','Henk']]}"
with Session(DEFAULT, w=900, h=560, extra_init="localStorage.setItem('polderrace3d-garage',JSON.stringify({owned:{hatch:true,gt:true},career:{cups:{B:{best:2}}}}));localStorage.setItem('polderrace3d-career-run',JSON.stringify(%s));" % RUN) as s:
    s.ev("homePanel('career');0"); s.pg.wait_for_timeout(400)
    r = s.ev("JSON.stringify({sel:careerSel,go:!$('careerGo').disabled,txt:$('careerGo').textContent,open:!!document.getElementById('careerEvInfo')})")
    rep.check(r == '{"sel":"A","go":true,"txt":"Ga verder: race 2","open":true}', 'oude save midden in een cup: Ga verder werkt', r)
    s.pg.click('#careerGo'); s.pg.wait_for_timeout(600)
    rep.check(s.ev("mode==='champ'&&champ.career==='A'&&champ.round===1&&TRACK_ID==='afsluitdijk'") is True, 'de lopende cup gaat verder bij race 2', s.ev("mode+' '+TRACK_ID"))
    rep.check(not s.errs, 'geen JS-fouten (oude save met lopende cup)', str(s.errs[:3]))

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
