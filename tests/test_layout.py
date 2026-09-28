"""Menu layout: on 6 screen sizes, open every panel/tab and check that
- no box with overflow hidden cuts off its content (scrolling boxes are fine),
- no panel/list collapsed to ~0 px height, and no rows in a column drawn over each other,
- the primary buttons (Volgende / Terug / Start) are reachable (inside the viewport after scrolling into view).
Screenshots of the garage look-tab per size go to tests/.out/.
Then, once: Terug (button and Esc) goes one level up, and the focus ring of a chosen option stays inside its bar.
"""
from lib import Session, Report, DEFAULT, NEW_GARAGE

SIZES = [(1280, 720), (1366, 768), (812, 854), (1920, 1080), (390, 844), (844, 390)]
TOL = 24  # px: the sticky button bar on phones deliberately overhangs 22 px
DET = """(tol)=>{const out=[];const roots=[...document.querySelectorAll('#home .board,#menu .board,#over .board,#pause .board')].filter(e=>e.offsetParent);
 const nm=el=>(el.id||String(el.className)||el.tagName).slice(0,40);
 for(const r of roots)for(const el of r.querySelectorAll('*')){if(!el.offsetParent||!el.children.length)continue;const cs=getComputedStyle(el);
  /* scrolling boxes (auto/scroll) may be taller than their window; clipped boxes (hidden/clip) may not */
  if((cs.overflowY==='hidden'||cs.overflowY==='clip')&&el.scrollHeight>el.clientHeight+tol)out.push('afgeknipt: '+nm(el)+' '+el.clientHeight+'/'+el.scrollHeight);}
 for(const r of roots)for(const el of r.querySelectorAll('.panel,.step,.opts,.cups,.ccards,.achs,.upgs,.togs,.bindlist')){if(!el.offsetParent)continue;
  if(el.children.length&&el.getBoundingClientRect().height<4)out.push('ingeklapt: '+nm(el));
  /* children of a column that overlap each other = rows drawn over each other */
  const cs=getComputedStyle(el);if(cs.display!=='flex'||!cs.flexDirection.startsWith('column'))continue;
  const kids=[...el.children].filter(k=>k.offsetParent&&getComputedStyle(k).position!=='sticky'&&getComputedStyle(k).position!=='absolute').map(k=>[k,k.getBoundingClientRect()]);
  for(let i=1;i<kids.length;i++){const [pa,ra]=kids[i-1],[pb,rb]=kids[i];if(rb.top<ra.bottom-4&&rb.height>0&&ra.height>0)out.push('overlapt: '+nm(pa)+' / '+nm(pb)+' ('+Math.round(ra.bottom-rb.top)+' px)');}}
 return [...new Set(out)].slice(0,8);}"""
VIEWS = [("home:play", "homePanel('play')"), ("home:career", "homePanel('career')"), ("home:net", "homePanel('net')"), ("home:ach", "homePanel('ach')"),
         ("garage:perf", "homePanel('garage');garTab('perf')"), ("garage:look", "homePanel('garage');garTab('look')"), ("home:records", "homePanel('records')"),
         ("instellingen:algemeen", "homePanel('settings')"), ("instellingen:toetsen", "homePanel('settings');document.querySelector('#setTabs [data-v=keys]').click()"),
         ("instellingen:controller", "homePanel('settings');document.querySelector('#setTabs [data-v=pad]').click()"),
         ("menu:modus", "document.querySelector('#setTabs [data-v=general]').click();homePanel('main');menuFlow='quick';showMenu(2)"),
         ("menu:auto", "showMenu(0)"), ("menu:baan", "showMenu(1)"), ("menu:kampioenschap", "menuFlow='champ';showMenu(3)"),
         # online via host: the host's game panel with the invite card, then the guest's join box
         ("online:host", "menuFlow='quick';homePanel('net');p2pHostGame()"), ("online:meedoen", "netLeave();homePanel('net');if(!p2pJoinOpen)$('p2pJoin').click()")]
BTN = {"online:host": "#netStart", "online:meedoen": "#p2pAnswerMake", "menu:modus": "#nextBtn", "menu:auto": "#nextBtn", "menu:baan": "#nextBtn", "menu:kampioenschap": "#nextBtn", "home:career": "#careerGo",
       "garage:look": "#homeGarage [data-homeback]", "instellingen:toetsen": "#homeSettings [data-homeback]"}

rep = Report('menu-layout op 6 schermformaten')
for w, h in SIZES:
    with Session(DEFAULT, w=w, h=h, extra_init=NEW_GARAGE) as s:  # a new player: garage and career show cars to buy
        bad = []
        for name, js in VIEWS:
            s.ev(f"toMenu(-1);{js};0"); s.pg.wait_for_timeout(250)
            r = s.pg.evaluate(f"({DET})({TOL})")
            if r:
                bad.append(f"{name}: {r}")
            if name in BTN:
                ok = s.pg.evaluate("""s=>{const e=document.querySelector(s);if(!e||!e.offsetParent)return false;e.scrollIntoView({block:'nearest'});
                    const r=e.getBoundingClientRect();return r.top>=0&&r.bottom<=innerHeight+1&&r.width>0;}""", BTN[name])
                if not ok:
                    bad.append(f"{name}: knop {BTN[name]} niet bereikbaar")
            if name == 'garage:look':
                s.shot(f'layout_garage_look_{w}x{h}.png')
        rep.check(not bad and not s.errs, f'{w}x{h}', ' | '.join(bad[:4]) + (f' ERR {s.errs[:2]}' if s.errs else ''))
NAV = [("Spelen > Race > Terug", "#hPlay,#hStart,#backBtn", "play"), ("Spelen > Race > Esc", "#hPlay,#hStart,ESC", "play"),
       ("Spelen > Carriere > Terug", "#hPlay,#hCareer,#homeCareer [data-homeback]", "play"), ("Spelen > Online > Terug", "#hPlay,#hNet,#homeNet [data-homeback]", "play"),
       ("Spelen > Kampioenschap > Terug", "#hPlay,#hChamp,#backBtn", "play"), ("Spelen > Terug", "#hPlay,#homePlay [data-homeback]", "main"),
       ("Carriere > auto kopen > Garage > Terug", "#hPlay,#hCareer,#careerCars .ccard:has(.lock),#homeGarage [data-homeback]", "career"),
       ("Garage > Terug", "#hGarage,#homeGarage [data-homeback]", "main")]
with Session(DEFAULT, w=1280, h=720, extra_init=NEW_GARAGE) as s:
    for name, clicks, want in NAV:
        s.ev("toMenu(-1);homePanel('main');0"); s.pg.wait_for_timeout(200)
        for c in clicks.split(','):
            if c == 'ESC':
                s.pg.keyboard.press('Escape')
            else:
                s.pg.click(c)
            s.pg.wait_for_timeout(250)
        got = s.ev("(menuStep<0&&!$('home').hidden)?homeView:'menu '+menuStep")
        rep.check(got == want, f'terug: {name}', f'kwam op {got}, verwacht {want}')
    s.ev("toMenu(-1);homePanel('main');0"); s.pg.click('#hPlay'); s.pg.click('#hStart'); s.pg.wait_for_timeout(300)
    s.pg.keyboard.press('Tab')  # keyboard modality, so the focused option shows its ring (:focus-visible) as it does for Yip
    ring = s.pg.evaluate("""()=>{const b=document.querySelector('#modeSeg [aria-checked="true"]');b.focus();const bar=b.closest('.seg'),cs=getComputedStyle(b),pad=parseFloat(getComputedStyle(bar).paddingTop);
        const reach=parseFloat(cs.outlineOffset)+parseFloat(cs.outlineWidth);return {fv:b.matches(':focus-visible'),reach,pad};}""")
    rep.check(ring['fv'] and ring['reach'] <= ring['pad'], 'focusring van de gekozen optie blijft binnen de balk', str(ring))
    rep.check(not s.errs, 'geen JS-fouten (navigatie)', str(s.errs[:2]))
rep.finish()
