# LAN-agent: werknotities (tijdelijk; verdwijnt voor het eindverslag)

Notities zodat het werk een onderbreking overleeft. Scratchpad-screenshots "voor": `/tmp/claude-0/-home-user-Polderrace/59a095fe-1fa3-5f6d-8af6-8bdf8b8a4610/scratchpad/before/` (net_host/net_guest/net_lobby.png).
Machine: `iproute2` geinstalleerd met apt (ip/tc), zodat netwerk-namespaces werken (test_net isoleert zich nu echt).
Screenshots maken: `sh <scratchpad>/shots.sh <outdir>` (host + gast in eigen netns onder xvfb).

## Avond doorlopen — wrijving VOOR (stand f530f27)
Host:
1. Game maken: geen terugkoppeling of anderen je kunnen vinden; firewallvraag kan achter het spel staan.
2. Instellingen: alleen baan/ronden/bots (geen richting, tijd, weer, niveau).
3. Start gooit iedereen meteen in de race (geen klaar, geen aftellen); iemand in de autokeuze wordt overvallen.
4. Geen kick, niet sluiten voor nieuwe spelers.
5. Host weg = avond voorbij ("De host heeft de game gesloten").
6. Geen stand over meerdere races; uitslag per pc zelf berekend.
7. Pauze (ook alt-tab!) van de host bevriest de bots bij iedereen; "Herstart" in pauze herstart alleen lokaal.
8. Minimap toont andere spelers niet.
9. 0 bots online => Game maakt er een tijdrit van (mode time) — bug.
10. Wie na een race binnenkomt ziet "Er is een race bezig" ook als die allang klaar is (host wist `race` nooit).
Gast:
1. Lege lijst: geen hulp, geen onthouden IP-adressen.
2. Lobby toont niets van de instellingen van de host; geen ping.
3. Na finish: stilstaand uitslagscherm; laatkomer wacht op een menu.
4. Verbinding kwijt (12-20 s) = uit de game, geen terugkeer naar dezelfde plek.
5. Auto van een ander heeft fabrieksuiterlijk (geen velgen/strepen/nummer).
6. Auto's van anderen: lineair tussen de laatste twee pakketjes op aankomsttijd (50 ms achter, schokt bij jitter/verlies).
7. Race-instellingen van de gast worden overschreven door die van de host en zo opgeslagen.

## Ontwerp (PROTO 3) — zie koppen van net_room.gd / lan.gd / net.gd
- NetRoom: hi+token (uid = hash), stoelen blijven 45 s, auto-reconnect 15 s, kick, open/dicht, ping (q), validatie van elk veld,
  rate limit, positiepakketjes per frame gebundeld ({t:"f"}), ENet range coder, bytes/s meten.
- LanDiscovery: broadcast + direct naar onthouden IP's + sweep /24 + beacon (host roept zelf, poort 47812) => "deaf" (firewall host dicht),
  host telt zoekers (searching()) en zelftest.
- Net: cfg live, rdy, cd (aftellen 3 s + baan voorladen), look, e (chat/emotes), res (officiele uitslag host), pts (stand, [naam,pt,races,winst,laatste]),
  grid-volgorde, volgende baan (host/rot/rand/vote), meekijken (spec/watch), dead reckoning met st[10], naamlabels, host-migratie (ook midden in race),
  Windows-firewall check/openzetten (PowerShell, NIET getest op Windows).

## Stand van het werk (opvolger, 20 nov avond)
- [x] net_room/lan/net herschreven, net_ui, haken in game/menu/hud, tests, shot-tool (commits f8841a9..87f4cfe)
- [x] overname: _close vertelt eerst (closed) en ruimt dan op, anders was de presence van de anderen weg (valse "verlaten")
- [x] JSON van de lijn stil parsen (NetRoom.parse_json): JSON.parse_string gaf ERROR-regels bij elk kapot pakketje
- [x] test hostile: "bye" uit de rommel (een bye is gewoon weggaan)
- [ ] scenario 2, 3, 4 groen; docs PLAN.md/README.md; CI (test_net_more?)
- [ ] merge claude/new-session-vj6qwu, alle tests, eindverslag (LAN_NOTES.md verwijderen)

## Gemeten / bekeken (aanvullen)
- test_net.py: 13/13, 17 s. Scenario 1: 103 s.
