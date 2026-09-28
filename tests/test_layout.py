"""Menu layout: on 6 screen sizes, open every panel/tab and check that
- no box with overflow hidden cuts off its content (scrolling boxes are fine),
- no panel/list collapsed to ~0 px height, and no rows in a column drawn over each other,
- the primary buttons (Volgende / Terug / Start) are reachable (inside the viewport after scrolling into view).
Screenshots of the garage look-tab per size go to tests/.out/.
"""
from lib import Session, Report, DEFAULT

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
    with Session(DEFAULT, w=w, h=h) as s:
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
rep.finish()
