"""Online via host (WebRTC peer-to-peer, copy/paste codes) with 3 browser pages in one context. No claude.ai room here:
this is the path for the game as local file or on GitHub Pages. The code exchange goes through the real menu:
host makes an invite -> guest pastes it and gets an answer code -> host pastes the answer. The same for guest 2.

Checks: host option visible without claude.ai, friendly errors for wrong codes, plain-base64 fallback, both guests connect,
host sees both guests with their cars, race start on a reversed track reaches every page, all pages race, remote positions
arrive, bots are in sync, HUD counts everyone, a guest who leaves disappears on the host, a guest who joins after a race
does not start the old race, and the guests leave the game with a message when the host closes it.
There is no internet in the test environment: the STUN server is unreachable, so the ICE-gathering timeout path is used.
"""
import time
from lib import Session, Report, DEFAULT, build_test_page

# WebRTC between pages of headless Chromium: plain local IPs instead of mDNS names, loopback allowed
ARGS = ['--disable-features=WebRtcHideLocalIpsWithMdns', '--allow-loopback-in-peer-connection']


def wait(fn, sec=20, pg=None):
    """poll fn() until it is truthy (or the time is up); returns the last value"""
    t = time.time(); v = fn()
    while not v and time.time() - t < sec:
        (pg or H).wait_for_timeout(250); v = fn()
    return v


rep = Report('online via host (WebRTC, 3 spelers, uitnodigingscodes)')
with Session(DEFAULT, w=240, h=150, args=ARGS) as s:
    page = build_test_page()
    H = s.pg; G = s.new_page(page, name='gast: '); G2 = s.new_page(page, name='gast2: ')
    ev = s.ev
    for pg, n in [(H, 'Host Henk'), (G, 'Gast Gijs'), (G2, 'Gast Greet')]:
        ev(f"prefs.nick='{n}';0", pg)
    ev("settings.car='muscle';settings.color='#2f8f5b';rebuildPlayerCar();0", G)
    ev("settings.car='hatch';settings.color='#f2c200';rebuildPlayerCar();0", G2)
    for pg in [H, G, G2]:
        ev("homePanel('net');0", pg)
    rep.check(ev("roomNS===null&&!!$('p2pHost').offsetParent&&$('netRoomLobby').hidden", H), 'zonder claude.ai: optie "Game hosten" zichtbaar, geen room-lobby')

    # friendly errors instead of exceptions
    err = lambda code, kind, pg=G: ev(f"p2pDecode({code!r},'{kind}').then(()=>'geen fout',e=>e.message)", pg)
    rep.check('geen Polderrace-code' in err('hallo daar', 'I'), 'onzin geeft een nette melding', err('hallo daar', 'I'))
    rep.check('beschadigd' in err('PR1IZabcdef', 'I'), 'kapotte code geeft een nette melding', err('PR1IZabcdef', 'I'))
    rt = ev("(async()=>{const cs=window.CompressionStream;window.CompressionStream=undefined;const c=await p2pEncode('A',{id:'g7',s:p2pPack('v=0\\r\\nx')});"
            "window.CompressionStream=cs;const o=await p2pDecode('Mijn code:\\n'+c.slice(0,40)+'\\n'+c.slice(40),'A');return c.slice(0,5)+' '+o.id;})()", G)
    rep.check(rt == 'PR1AB g7', 'zonder CompressionStream: gewone base64, code met tekst en regelovergangen eromheen leesbaar', rt)
    rt = ev("(async()=>{const pc=new RTCPeerConnection();pc.createDataChannel('x');await pc.setLocalDescription(await pc.createOffer());const d=pc.localDescription.sdp;pc.close();"
            "const t=p2pPack(d);return (p2pUnpack(t)===d)+' '+d.length+' -> '+t.length;})()", G)
    rep.check(rt.startswith('true'), 'SDP inkorten is verliesvrij', rt)

    # host: 'Game hosten' makes the game and the first invite
    H.click('#p2pHost')
    inv = wait(lambda: (ev("$('p2pInviteOut').value", H) or '').startswith('PR1I') and ev("$('p2pInviteOut').value", H), 15)
    rep.check(bool(inv) and ev('!!(net&&net.p2p&&net.host)', H), 'host maakt game en uitnodiging', f'{len(inv or "")} tekens')

    def join(gp, invite, label):
        gp.click('#p2pJoin'); gp.fill('#p2pInviteIn', invite); gp.click('#p2pAnswerMake')
        ans = wait(lambda: (ev("$('p2pAnswerOut').value", gp) or '').startswith('PR1A') and ev("$('p2pAnswerOut').value", gp), 15, gp)
        rep.check(bool(ans), f'{label} krijgt een antwoordcode', f'{len(ans or "")} tekens')
        return ans or ''

    ans = join(G, inv, 'gast')
    # the guest must be the DTLS server: as client it gives up after ~3.5 min, before a slow chat round trip is back
    # (checked by hand: with setup:passive an answer pasted 12 minutes later still connects in 1 s)
    setup = ev(f"p2pDecode({ans!r},'A').then(o=>(o.s.match(/a=setup:\\w+/)||['?'])[0],e=>e.message)", H)
    rep.check(setup == 'a=setup:passive', 'gast is DTLS-server, zodat een trage antwoordcode nog werkt', setup)
    # wrong way round: the host pastes its own invite in the answer field
    H.fill('#p2pAnswerIn', inv); H.click('#p2pConnect'); H.wait_for_timeout(300)
    msg = ev("$('p2pInviteMsg').hidden?'':$('p2pInviteMsg').textContent", H)
    rep.check('uitnodiging' in msg, 'uitnodiging in het antwoordveld geeft een nette melding (in de kaart)', msg)
    H.fill('#p2pAnswerIn', ans); H.click('#p2pConnect')
    ok = wait(lambda: ev("!!net&&[...net.remotes.values()].some(r=>r.name==='Gast Gijs')", H) and ev('!!(net&&net.p2p)', G), 20)
    rep.check(ok, 'gast 1 verbonden (host en gast zitten in de game)', ev("$('netStatus').textContent", G))
    rep.check(ev("$('p2pInviteBox').hidden", H), 'gebruikte uitnodiging verdwijnt bij de host')
    rep.check(ev("homePanel('net');$('netHostCtl').hidden&&$('p2pInvite').hidden&&!$('netGame').hidden", G), 'gast ziet de game, zonder host-knoppen')

    H.click('#p2pInviteMake')
    inv2 = wait(lambda: (ev("$('p2pInviteOut').value", H) or '').startswith('PR1I') and ev("$('p2pInviteOut').value", H), 15)
    rep.check(bool(inv2) and inv2 != inv, 'host maakt een tweede uitnodiging')
    ans2 = join(G2, inv2, 'gast 2')
    H.fill('#p2pAnswerIn', ans2); H.click('#p2pConnect')
    wait(lambda: ev("net?net.remotes.size:0", H) == 2 and ev("net?[...net.remotes.values()].filter(r=>r.name).length:0", G) == 2, 20)
    rem = ev("[...net.remotes.values()].map(r=>r.name+':'+r.carId).sort().join(', ')", H)
    rep.check(rem == 'Gast Gijs:muscle, Gast Greet:hatch', 'host ziet beide gasten met hun auto', rem)
    seen = ev("[...net.remotes.values()].map(r=>r.name+(r.host?'*':'')).sort().join(', ')", G)
    rep.check(seen == 'Gast Greet, Host Henk*', 'gast ziet de host en de andere gast (via de host)', seen)
    rep.check(ev("$('netPlayers').children.length", H) == 3, 'spelerslijst van de host toont 3 spelers')

    ev("settings.track='rotterdam';settings.dir='rev';settings.laps=1;settings.bots=2;0", H); H.click('#netStart'); H.wait_for_timeout(2500)
    for pg, n in [(G, 'gast'), (G2, 'gast2')]:
        got = wait(lambda: ev("TRACK_ID+'/'+TRACK_DIR", pg) == 'rotterdam/rev' and 'rotterdam/rev', 15, pg)
        rep.check(got == 'rotterdam/rev', f'{n} krijgt baan en richting van de host', ev("TRACK_ID+'/'+TRACK_DIR", pg))
    wait(lambda: all(ev('state', pg) == 'racing' for pg in [H, G, G2]), 20)
    rep.check(all(ev('state', pg) == 'racing' for pg in [H, G, G2]), 'alle drie racen', str([ev('state', pg) for pg in [H, G, G2]]))
    for pg in [H, G, G2]:
        ev('kb.up=true;0', pg)
    H.wait_for_timeout(6000)
    n = ev("[...net.remotes.values()].filter(r=>r.st&&r.st[5]>0).length", H)
    rep.check(n == 2, 'host ontvangt posities van beide gasten', str(n))
    n = ev("[...net.remotes.values()].filter(r=>r.st&&r.st[5]>0).length", G2)
    rep.check(n == 2, 'gast 2 ontvangt posities van host en gast 1 (doorgestuurd)', str(n))
    bh = ev("bots.map(b=>b.s.toFixed(0)).join(',')", H); bg = ev("bots.map(b=>b.s.toFixed(0)).join(',')", G)
    close = all(abs(float(a) - float(b)) < 40 for a, b in zip(bh.split(','), bg.split(','))) and bh.count(',') == bg.count(',')
    rep.check(close, 'bots lopen synchroon bij host en gast', f'{bh} / {bg}')
    rep.check(ev("$('t').textContent", G).endswith('/5'), 'HUD van de gast telt 3 spelers + 2 bots', ev("$('t').textContent", G))

    # guest 2 leaves: gone on the host and on guest 1
    ev('kb.up=false;toMenu(-1);netLeave();0', G2)
    gone = wait(lambda: ev("[...net.remotes.values()].map(r=>r.name).join(',')", H) == 'Gast Gijs', 10)
    rep.check(bool(gone), 'gast die weggaat, verdwijnt bij de host', ev("[...net.remotes.values()].map(r=>r.name).join(',')", H))
    gone = wait(lambda: ev("net?[...net.remotes.values()].map(r=>r.name).sort().join(','):'-'", G) == 'Host Henk', 10)
    rep.check(bool(gone), 'en bij de andere gast', ev("net?[...net.remotes.values()].map(r=>r.name).sort().join(','):'-'", G))

    # after the race the host invites guest 2 again: the old race must not start for the newcomer
    ev('kb.up=false;toMenu(-1);0', H); ev('kb.up=false;toMenu(-1);0', G); ev("homePanel('net');0", H); ev("homePanel('net');0", G2)
    H.click('#p2pInviteMake')
    inv3 = wait(lambda: (ev("$('p2pInviteOut').value", H) or '').startswith('PR1I') and ev("$('p2pInviteOut').value", H), 15)
    ans3 = join(G2, inv3 or '', 'gast 2 (opnieuw)')
    H.fill('#p2pAnswerIn', ans3); H.click('#p2pConnect')
    back = wait(lambda: ev("!!(net&&net.p2p)", G2) and ev("net?net.remotes.size:0", H) == 2, 20)
    G2.wait_for_timeout(1500)
    rep.check(back and ev('state', G2) == 'menu', 'gast die na een race instapt, start de oude race niet', f"state {ev('state', G2)}")

    # host closes the game: guests are out, with a message
    ev('netLeave();0', H)
    out = wait(lambda: ev('net===null', G) and ev('net===null', G2), 10)
    msg = ev("$('netStatus').textContent", G)
    rep.check(out and 'host' in msg, 'host sluit de game: gasten zijn eruit met een melding', msg)
    rep.check(ev("!$('p2pLobby').hidden&&!$('netLobby').hidden", G), 'gast ziet daarna weer het beginscherm van online')
    rep.check(not s.errs, "geen JS-fouten op alle pagina's", str(s.errs[:3]))
rep.finish()
