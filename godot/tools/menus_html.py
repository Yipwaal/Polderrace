"""Reference screenshots of the HTML game's menus (to compare with the Godot port, see tools/compare_menus.py).

python godot/tools/menus_html.py [WxH] [screen,screen,...]
Output: tests/.out/menus/html_<W>x<H>/<screen>.png
The page gets the real fonts (Nunito, Barlow Condensed from godot/assets/fonts) instead of the Google Fonts CDN, and the
same save data as tools/shot_menus.gd (tools/menus_state.json), so both versions show the same garage, records and career.
"""
import sys, json, pathlib
HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
ROOT = PROJ.parent
sys.path.insert(0, str(ROOT / 'tests'))
from lib import build_test_page, _three_source, OUT

W, H = 1280, 720
if len(sys.argv) > 1 and 'x' in sys.argv[1]:
    W, H = (int(v) for v in sys.argv[1].split('x'))
ONLY = sys.argv[2].split(',') if len(sys.argv) > 2 else None
OUTD = OUT / 'menus' / f'html_{W}x{H}'
OUTD.mkdir(parents=True, exist_ok=True)
STATE = json.loads((HERE / 'menus_state.json').read_text(encoding='utf-8'))
FONTS = PROJ / 'assets' / 'fonts'
CSS = ("@font-face{font-family:'Nunito';font-style:normal;font-weight:200 1000;src:url(https://fonts.gstatic.com/nunito.ttf)}"
       "@font-face{font-family:'Barlow Condensed';font-style:normal;font-weight:700;src:url(https://fonts.gstatic.com/barlow-b.ttf)}"
       "@font-face{font-family:'Barlow Condensed';font-style:italic;font-weight:800;src:url(https://fonts.gstatic.com/barlow-ebi.ttf)}"
       "@font-face{font-family:'Barlow Condensed';font-style:normal;font-weight:800;src:url(https://fonts.gstatic.com/barlow-ebi.ttf)}")
FONT_FILES = {'nunito.ttf': 'Nunito-Variable.ttf', 'barlow-b.ttf': 'BarlowCondensed-Bold.ttf', 'barlow-ebi.ttf': 'BarlowCondensed-ExtraBoldItalic.ttf'}


def main():
    from playwright.sync_api import sync_playwright
    page = build_test_page()
    init = ''.join("localStorage.setItem(%s,%s);" % (json.dumps(k), json.dumps(v if isinstance(v, str) else json.dumps(v))) for k, v in STATE.items())
    with sync_playwright() as p:
        b = p.chromium.launch(args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
        ctx = b.new_context(viewport={'width': W, 'height': H})
        ctx.add_init_script("if(!sessionStorage.getItem('seeded')){localStorage.clear();" + init + "sessionStorage.setItem('seeded','1');}")
        pg = ctx.new_page()
        pg.set_default_timeout(240000)
        three = _three_source()
        if three:
            pg.route('**/three.min.js', lambda r: r.fulfill(body=three, content_type='application/javascript'))
        pg.route('**fonts.googleapis.com/**', lambda r: r.fulfill(body=CSS, content_type='text/css'))
        pg.route('**fonts.gstatic.com/**', lambda r: r.fulfill(body=(FONTS / FONT_FILES[r.request.url.rsplit('/', 1)[1]]).read_bytes(), content_type='font/ttf'))
        errs = []
        pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.goto(page.as_uri(), wait_until='commit')
        pg.wait_for_timeout(9000)
        ev = lambda c: pg.evaluate('c=>__ev(c)', c)

        def shot(name, js=None, wait=900):
            if ONLY and name not in ONLY:
                return
            if js:
                ev(js + ';0')
            pg.wait_for_timeout(wait)
            pg.screenshot(path=str(OUTD / f'{name}.png'))
            print('  ', OUTD / f'{name}.png')

        shot('home', "toMenu(-1)", 1500)
        shot('play', "homePanel('play')")
        shot('career', "homePanel('career')")
        shot('ach', "homePanel('ach')")
        shot('records', "homePanel('records')")
        shot('settings', "homePanel('settings')")
        shot('settings_keys', "$('setTabs').querySelector('[data-v=keys]').click()")
        shot('settings_pad', "$('setTabs').querySelector('[data-v=pad]').click()")
        ev("$('setTabs').querySelector('[data-v=general]').click();0")
        shot('garage', "homePanel('main');homePanel('garage');orb.a=0.5;orb.idle=-1e9;orb.vel=0", 1500)
        shot('garage_look', "garTab('look')")
        ev("garTab('perf');homePanel('main');0")
        shot('menu_modus', "menuFlow='quick';showMenu(2)")
        shot('menu_auto', "showMenu(0)")
        shot('menu_baan', "showMenu(1)")
        shot('menu_champ', "toMenu(-1);homePanel('play');$('hChamp').click();showMenu(3)")
        shot('podium', "toMenu(-1);enterPodium([{name:'Henk',sub:'0:53,4',carId:'muscle',color:'#f36f21'},{name:'Jij',sub:'+0,9 s',carId:'gt',color:'#d62a2a',me:true},"
             "{name:'Daan',sub:'+1,1 s',carId:'sedan',color:'#1d4f9e'}],'HAVENRACE');$('home').hidden=true;podiumT=0", 2500)
        ev("leavePodium();toMenu(-1);0")
        if not ONLY or any(n in ONLY for n in ('pause', 'pause_settings', 'results', 'champ_results', 'standings', 'timetrial')):
            ev("toMenu(-1);menuFlow='quick';leaveChampMode();settings.mode='race';settings.bots=3;settings.laps=1;startRace();0")
            pg.evaluate('([s,st])=>__step(s,st)', [6, True])
            shot('pause', "setPaused(true)")
            shot('pause_settings', "openPauseSettings()")
            ev("closePauseSettings();setPaused(false);0")
            for _ in range(30):
                pg.evaluate('([s,st])=>__step(s,st)', [10, True])
                if ev("state==='over'"):
                    break
            pg.evaluate('([s,st])=>__step(s,st)', [1, True])
            shot('results', None, 2500)
            # championship standings after one round
            ev("toMenu(-1);champ=loadQuickChamp();menuFlow='champ';if(!champInProgress())newChamp();champ.active=true;saveChamp();loadChampRound();champ.rounds=null;startRace();0")
            for _ in range(40):
                pg.evaluate('([s,st])=>__step(s,st)', [10, True])
                if ev("state==='over'"):
                    break
            pg.evaluate('([s,st])=>__step(s,st)', [1, True])
            shot('champ_results', None, 2500)
            shot('standings', "overReady=true;onAgain()", 1500)
            ev("toMenu(-1);champ=null;store.set('polderrace3d-champ','null');0")
            ev("menuFlow='quick';settings.mode='time';startRace();0")
            pg.evaluate('([s,st])=>__step(s,st)', [5, True])
            ev("timeLeft=0.01;0")
            pg.evaluate('([s,st])=>__step(s,st)', [0.5, True])
            shot('timetrial', None, 1500)
        b.close()
    print('JS-fouten:', errs[:5] or 'geen')


main()
