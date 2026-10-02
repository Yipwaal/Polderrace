"""Players for the online scenarios: each Player is one Godot process (tests/net_ctl.tscn) on this PC, driven by commands
like a player at the keyboard. Used by test_net_more.py.

    p = Player('host', nick='Yip', car='gt')
    p.cmd('open'); p.cmd('press Nieuwe game maken')
    r = p.wait(lambda r: r['net'], 10)     # poll the player's state until the condition holds
"""
import subprocess, threading, json, pathlib, shutil, time, tempfile, os, atexit, signal

def isolate():
    """Linux as root (the cloud container): run this test script in a network of its own (only 127.0.0.1), so games of
    other tests or players on this PC cannot mix with ours. Elsewhere (Windows, CI without root) it runs as it is."""
    import sys
    if os.environ.get('POLDERRACE_NETNS') or not hasattr(os, 'geteuid') or os.geteuid() != 0:
        return
    if not (shutil.which('unshare') and shutil.which('ip')):
        return
    os.environ['POLDERRACE_NETNS'] = '1'
    r = subprocess.run(['unshare', '-n', 'sh', '-c', 'ip link set lo up && exec "$0" "$@"', sys.executable, *sys.argv])
    sys.exit(r.returncode)


PROJ = pathlib.Path(__file__).resolve().parent.parent
GODOT = shutil.which('godot') or 'godot'
TMP = pathlib.Path(tempfile.mkdtemp(prefix='polderrace-net-'))
ALL = []


class Player:
    def __init__(self, name, nick=None, car='hatch', ts=1, color=None, env=None, window=False, extra=(), wrap=()):
        self.name = name
        self.ctl = TMP / f'{name}.cmd'
        self.ctl.write_text('')
        self.seq = 0
        self.ans = {}
        self.out = []
        self.cv = threading.Condition()
        # window=True: a real window with OpenGL (under xvfb-run in the cloud) instead of headless
        args = (['xvfb-run', '-a', GODOT, '--rendering-driver', 'opengl3'] if window else [GODOT, '--headless']) + list(extra) + ['--path', str(PROJ), 'res://tests/net_ctl.tscn', '--', f'name={name}', f'ctl={self.ctl}',
                f'nick={nick or name}', f'car={car}', f'ts={ts}'] + ([f'color={color}'] if color else [])
        if shutil.which('stdbuf'):
            args = ['stdbuf', '-oL'] + args      # Godot's print is buffered in a pipe: line by line, please
        args = list(wrap) + args                 # e.g. ip netns exec <pc>: this player on another "PC" of a test LAN
        # own process group: kill() also stops Godot under xvfb-run
        self.proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, start_new_session=True)
        ALL.append(self)
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.proc.stdout:
            line = line.rstrip('\n')
            with self.cv:
                self.out.append(line)
                if line.startswith('NET '):
                    _, k, v = line.split(' ', 2)
                    try:
                        self.ans[k] = json.loads(v)
                    except ValueError:
                        self.ans[k] = v
                self.cv.notify_all()

    def ready(self, timeout=60):
        with self.cv:
            ok = self.cv.wait_for(lambda: '0' in self.ans or self.proc.poll() is not None, timeout)
        return ok and self.ans.get('0') == 'ready'

    def cmd(self, c, timeout=30):
        """send a command, wait for its answer (None when the player does not answer in time)"""
        self.seq += 1
        k = str(self.seq)
        with open(self.ctl, 'a') as f:
            f.write(f'{k} {c}\n')
        with self.cv:
            self.cv.wait_for(lambda: k in self.ans or self.proc.poll() is not None, timeout)
            return self.ans.get(k)

    def rep(self):
        return self.cmd('report') or {}

    def wait(self, cond, timeout=20, every=0.25):
        """poll the state until cond(report) holds; returns the last report (check cond again for the result)"""
        t0 = time.time()
        r = {}
        while time.time() - t0 < timeout:
            if self.proc.poll() is not None:
                return r
            r = self.rep()
            try:
                if cond(r):
                    return r
            except (KeyError, IndexError, TypeError):
                pass
            time.sleep(every)
        return r

    def errors(self):
        with self.cv:
            return [l for l in self.out if 'SCRIPT ERROR' in l or 'Parse Error' in l or
                    (l.startswith('ERROR') and 'leaked at exit' not in l and 'still in use at exit' not in l
                     and 'ERR_CANT_OPEN' not in l)]      # (no sound card under xvfb)

    def kill(self):
        try:
            os.killpg(self.proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        self.proc.wait()

    def quit(self, timeout=10):
        if self.proc.poll() is None:
            self.cmd('quit', timeout=5)
            try:
                self.proc.wait(timeout)
            except subprocess.TimeoutExpired:
                self.kill()


def kill_all():
    for p in ALL:
        try:
            p.kill()
        except Exception:
            pass


atexit.register(kill_all)
