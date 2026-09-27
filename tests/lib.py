"""Shared test harness for Polderrace 3D.

Builds tests/.build/test.html = the game + test hooks (never touch the real game file),
opens it in headless Chromium (software WebGL) and gives every test the same helpers.

Hooks injected into the game's closure (right before the init line, see ANCHOR):
  window.__ev(code)        -> eval inside the game closure (all game globals reachable)
  window.__step(sec,steer) -> run the simulation `sec` seconds at 120 Hz with gas held;
                              steer=false keeps the wheel straight, otherwise a simple autopilot steers
  window.__zfight(root,o)  -> coplanar-face (z-fighting) detector, see zf.js
"""
import json, os, sys, pathlib, hashlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = pathlib.Path(os.environ.get('POLDERRACE_GAME', ROOT / 'polderrace-3d.html'))  # override to test another copy
TESTS = ROOT / 'tests'
BUILD = TESTS / '.build'
OUT = TESTS / '.out'
BUILD.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)

# The init line of the game. Test hooks are inserted right before it, so it must stay unique and unchanged.
ANCHOR = "loadTrack(settings.track);applyEnv(settings.time,settings.weather);rebuildPlayerCar();"
TRACKS = ['polder', 'dorp', 'circuit', 'afsluitdijk', 'haven', 'veluwe', 'grachten', 'limburg', 'rotterdam', 'zeeland']
TEST_MARKERS = ['__ev', '__clog', 'mockroom', '__zfight', '__step']

STEP_JS = ("window.__ev=(c)=>eval(c);window.__step=(sec,steer)=>{kb.up=true;for(let i=0;i<Math.round(sec*120);i++){"
           "if(steer!==false){const th=headingOf(T[player.idx]);const df=((th-player.heading+Math.PI)%(2*Math.PI)+2*Math.PI)%(2*Math.PI)-Math.PI;"
           "pad.steer=clamp(-df*3-player.lat*0.15,-1,1);}update(1/120);}kb.up=false;pad.steer=0;};\n")


def game_hash():
    # line endings normalised, so a Windows checkout (CRLF) gives the same hash as Linux/macOS
    return hashlib.sha256(GAME.read_bytes().replace(b'\r\n', b'\n')).hexdigest()[:16]


def build_test_page():
    s = GAME.read_text(encoding='utf-8')
    if s.count(ANCHOR) != 1:
        raise SystemExit(f'FOUT: de init-regel (ANCHOR) komt {s.count(ANCHOR)}x voor in {GAME.name}; hij moet precies 1x bestaan.')
    hook = (TESTS / 'zf.js').read_text(encoding='utf-8') + '\n' + STEP_JS
    page = BUILD / f'test_{os.getpid()}.html'  # one per process: parallel tests never overwrite each other
    page.write_text(s.replace(ANCHOR, hook + ANCHOR), encoding='utf-8')
    return page


def _three_source():
    """Local three.js r128 if installed (npm i), otherwise None -> the CDN is used."""
    for p in [ROOT / 'node_modules' / 'three' / 'build' / 'three.min.js']:
        if p.exists():
            return p.read_bytes()
    return None


class Session:
    """One headless browser page with the game loaded. Use as a context manager."""

    def __init__(self, settings=None, prefs=None, w=1000, h=600, extra_init='', wait=9000):
        from playwright.sync_api import sync_playwright
        page = build_test_page()
        self.p = sync_playwright().start()
        self.b = self.p.chromium.launch(args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
        self.ctx = self.b.new_context(viewport={'width': w, 'height': h})
        init = extra_init
        if settings:
            init += "localStorage.setItem('polderrace3d-settings',JSON.stringify(%s));" % json.dumps(settings)
        prefs = dict({'quality': 'low'}, **(prefs or {}))
        init += "localStorage.setItem('polderrace3d-prefs',JSON.stringify(%s));" % json.dumps(prefs)
        self.ctx.add_init_script(init)
        self.errs = []
        self.pg = self.new_page(page, wait)

    def new_page(self, page, wait=9000, name=''):
        pg = self.ctx.new_page()
        pg.set_default_timeout(180000)  # software rendering on a busy PC can be slow
        three = _three_source()
        if three:
            pg.route('**/three.min.js', lambda r: r.fulfill(body=three, content_type='application/javascript'))
        pg.route('**fonts.googleapis.com/**', lambda r: r.abort())
        pg.route('**fonts.gstatic.com/**', lambda r: r.abort())
        pg.on('pageerror', lambda e: self.errs.append(f'{name}PAGEERR {e}'))
        pg.on('console', lambda m: self.errs.append(f'{name}CONSOLE {m.text}') if m.type == 'error' and 'ERR_FAILED' not in m.text and 'fonts.g' not in m.text else None)
        pg.goto(page.as_uri(), wait_until='commit')
        pg.wait_for_timeout(wait)
        return pg

    def ev(self, code, pg=None):
        return (pg or self.pg).evaluate('c=>__ev(c)', code)

    def step(self, sec, steer=True, pg=None):
        (pg or self.pg).evaluate('([s,st])=>__step(s,st)', [sec, steer])

    def race_until_over(self, max_chunks=30, chunk=10):
        for _ in range(max_chunks):
            self.step(chunk)
            if self.ev("state==='over'"):
                return True
        return False

    def shot(self, name):
        path = OUT / name
        self.pg.screenshot(path=str(path))
        return path

    def close(self):
        try:
            self.b.close()
        finally:
            self.p.stop()

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()


DEFAULT = {'car': 'gt', 'color': '#d62a2a', 'track': 'polder', 'bots': 3, 'diff': 'normal', 'laps': 1, 'mode': 'race'}


class Report:
    """Collects OK/FOUT lines; exit code 1 when anything failed."""

    def __init__(self, title):
        self.title, self.ok, self.bad = title, 0, []
        print(f'== {title}')

    def check(self, cond, label, detail=''):
        if cond:
            self.ok += 1
            print(f'OK   {label}' + (f'  {detail}' if detail else ''))
        else:
            self.bad.append(label)
            print(f'FOUT {label}' + (f'  {detail}' if detail else ''))
        return cond

    def finish(self):
        n = self.ok + len(self.bad)
        print(f'-- {self.title}: {self.ok}/{n} geslaagd' + ('' if not self.bad else '  | mislukt: ' + ', '.join(self.bad[:10])))
        sys.exit(1 if self.bad else 0)
