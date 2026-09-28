# Polderrace 3D — projectgids voor Claude Code

Arcade-racegame in de browser, Nederlands thema. Eén HTML-bestand, Three.js r128.
Eigenaar: Yip. **Spreek Nederlands met Yip**; code-commentaar mag Engels blijven (zoals nu).

> **Fase: HTML-prototype.** Tot Yip zelf zegt dat hij de definitieve versie als echt spel wil, blijft Polderrace
> een HTML-spel: elke wijziging is een nieuwe versie van `polderrace-3d.html`, net zoals tot nu toe in de chat.
> Begin niet op eigen initiatief aan een Godot-/Unity-/desktopversie, geen andere engine of framework, geen
> opsplitsing in modules of build-stap, geen TypeScript/React. Ook niet "alvast een beetje voorbereiden".
> `tests/test_static.py` bewaakt dit: extra spelbestanden (.js/.css/.ts/extra .html, Godot-/Unity-bestanden) laten hem falen.
> Die controle pas je pas aan als Yip expliciet de overstap naar het echte spel vraagt.

## Werkafspraken (altijd)

1. **Alles zit in `polderrace-3d.html`.** Houd het één zelfstandig bestand dat direct in de browser en als claude.ai-artifact
   werkt: geen bundler, geen extra scripts behalve three.js r128 van cdnjs, geen externe assets (texturen worden met
   canvas getekend), geen extra .js/.css/.html-bestanden voor het spel. Het eindproduct van elke opdracht is dit ene
   bijgewerkte bestand, klaar om te publiceren.
2. **Zet nooit testcode in het spelbestand.** De tests injecteren hun hooks zelf in een kopie (`tests/.build/`).
   `tests/test_static.py` faalt op `__ev`, `__step`, `__zfight`, `mockroom`, `__clog`.
3. **De init-regel moet precies één keer bestaan en ongewijzigd blijven**, anders werken de tests niet:
   `loadTrack(settings.track);applyEnv(settings.time,settings.weather);rebuildPlayerCar();`
4. **Na elke wijziging:** `python tests/quick_check.py` (±1 min) plus de gerichte tests uit de tabel hieronder.
   Voor je afrondt, draait de Stop-hook automatisch de snelle controle en vraagt hij om de **qa-reviewer**-agent.
   Rond pas af als die GOEDGEKEURD geeft.
5. **Niets stukmaken wat werkt.** Los alleen op wat gevraagd is. Zie je onderweg andere bugs, meld ze in je
   eindverslag (en los ze op als Yip om "zoek en fix bugs" vroeg).
6. **Visuele fix = kijken.** Maak een screenshot (`tests/screenshots.py` of een eigen standpunt) en bekijk hem
   met de Read-tool vóór en na de fix. Een test die groen is, betekent niet dat het er goed uitziet.
7. Kleine, gerichte commits met een Nederlandse commitboodschap ("Grachten: kademuur niet meer door de weg").

## Publiceren

Het spel draait als **claude.ai-artifact**: https://claude.ai/artifact/Pe2uUr4oTeTjyDygDkzUgx
- Capabilities: `{"downloads": true, "room": {}}` — `room` is nodig voor de lobby met open games, `downloads` voor replay opslaan.
- Titel "Polderrace 3D", icoon 🌷.
- Online spelen kan op twee manieren:
  - **Lobby met open games** (`window.claude.use('room')`): alleen als artifact op claude.ai.
  - **Spelen via host (met code)**: werkt overal, ook lokaal en op GitHub Pages. Rechtstreeks tussen de browsers
    via WebRTC, zonder server. De host maakt per speler een uitnodigingscode, de speler stuurt een antwoordcode terug.
    Op hetzelfde wifi werkt dat altijd, via internet meestal (STUN van Google). Strenge netwerken (hotspot, school,
    werk) kunnen verbinden blokkeren: er is geen TURN-server.
  Buiten claude.ai toont het online-scherm alleen "Spelen via host".
- Heb je zelf geen Artifact-tool: zeg Yip dat de nieuwe versie klaarstaat. Hij publiceert `polderrace-3d.html`
  via een claude.ai-chat naar dezelfde URL, met dezelfde capabilities.
- Publiceer alleen een versie die de qa-reviewer heeft goedgekeurd (`tests/reviewed.txt` = hash van het bestand).

## Tests

Eenmalig installeren: `pip install -r requirements-dev.txt`, `python -m playwright install chromium`,
`npm install` (three.js r128 lokaal, zodat de tests geen internet nodig hebben).
Alle tests draaien headless met software-WebGL (SwiftShader), dus zonder videokaart. Gebruik `python`
(of `python3` op macOS/Linux). Uitvoer: `OK`/`FOUT`-regels; exitcode 1 bij een fout.

| Wat je veranderd hebt | Draai minimaal |
|---|---|
| alles | `tests/quick_check.py` |
| baan, decor, objecten langs de weg | `test_road_clear.py <baan> --rev`, `test_zfight.py <baan> --no-cars`, `screenshots.py <baan>` |
| automodellen, tuning, spoilers | `test_zfight.py none` |
| menu's, CSS, HUD | `test_layout.py` + screenshots |
| rijgedrag, botsingen, bots | `test_collisions.py`, `test_regression.py` |
| camera, terrein (Veluwe/Limburg) | `test_camera_terrain.py` |
| spelverloop, kampioenschap, carrière, geld | `test_championship.py`, `test_regression.py` |
| online, 2 spelers | `test_multiplayer.py`, `test_p2p.py`, `test_camera_terrain.py` (bevat split screen) |
| laden/opruimen van banen of scènes | `test_memory.py` |
| voor publicatie | `tests/run_all.py` (volledig, ±30 min) of minimaal `run_all.py --fast` |

Handig: `python tests/test_regression.py grachten,zeeland race,time fwd,rev`.
Screenshots komen in `tests/.out/screens/`; bekijk ze met Read.
Een andere kopie testen (bijvoorbeeld de oude versie om een bug te reproduceren): zet `POLDERRACE_GAME=<pad>` voor het commando.
Vind je een nieuw soort bug, voeg dan waar mogelijk een test toe (of breid een bestaande uit) zodat hij niet terugkomt.
Wil je iets in de spelstatus onderzoeken, gebruik dan `tests/lib.py`: `Session(...)`, dan `s.ev("js in de spel-closure")`
en `s.step(seconden)`. Voorbeeld: `s.ev("loadTrack('zeeland','fwd');0")`.

## Architectuur (volgorde in het bestand; zoek op de `/* ===== naam ===== */`-markeringen)

HTML/CSS bovenaan (design tokens in `:root`, responsive blok onder `/* ---------- responsive ---------- */`),
daarna één `(async function(){ ... })()`. Alle globals leven in die closure.

- **renderer & scene** — `logarithmicDepthBuffer:true`, schaduwen, `canvasTex(w,h,fn,repeat)`, sky dome, `M(color,opts)` = Lambert-materiaal.
- **track definitions** — `TRACKS{id:{name,desc,banner,ctrl:[[x,z,hoogte]...],ver,roadHalf,shoulder,lanes,embK,edge,edgeAt,cpM,startTime,traffic,fog,seed,...}}`.
  Verhoog `ver` als je de vorm van een baan verandert: ronderecords en ghosts horen bij (baan+ver+richting).
- **track state** — `computeTrack(def,dir)` maakt per 2 m een sample: `P[i]` positie, `T[i]` richting, `R[i]` rechts,
  `HT[i]` weghoogte, `EMB[i]` dijktalud-breedte, `EDGE[i]` muur/sloot, `CURV`, `LINE` (ideale lijn), `cps` (checkpoints).
  `NS` samples, `SPC` afstand, `TRACK_LEN`. Richting 'rev' draait de ctrl-punten om.
  Helpers: `onTrack(i,lat)`→[x,z], `hAt(i,lat)` hoogte, `distToTrack(x,z)` (**min EMB!**), `randPos(minD)`, `clearSpot(minD)`.
- **world building helpers** — `ribbon(latA,latB,mat,vRep,yOff)` strook langs de baan (weg yOff 0.07; berm < 0.07 wordt 3 cm verlaagd;
  kerbs 0.07–0.1 worden 2 cm verhoogd), `vribbon` verticale strook (muren, relingen), `place(obj,i,lat,y)`, `box(w,h,d,mat,x,y,z,parent,cast)`,
  `inst(geo,mat,matrices,colors,cast)` = InstancedMesh in cellen van 150 m. **Let op:** `inst` zet een world-space boundingSphere
  op de geometry (voor culling). Daardoor werkt de standaard three-raycast op instanced objecten niet; gebruik de aanpak uit `test_road_clear.py`.
- **per baan een builder** — `buildPolder, buildDorp, buildCircuit, buildAfsluitdijk, buildHaven, buildVeluwe, buildGrachten, buildLimburg,
  buildRotterdam, buildZeeland` + `DETAILS[id]` extra details + `dressTrack(id)` (bloemen, riet, hekken, borden... per baan).
  `loadTrack(id,dir)` ruimt de wereld op (`clearWorld`), bouwt opnieuw met vaste seed (`rnd`), zet mist en minimap.
- **terreinbanen** — Veluwe en Limburg: `terrainFn()` geeft `veluweTF(x,z)→{h,d}`; `groundY(x,z)` gebruik je om objecten op de heuvels te zetten.
- **cars** — `CARS{id:{name,cls:'B'|'A'|'S',vmax,acc,grip,brake,mass}}`, `buildCar(type,color)` (boxen + `trim()` voor bumpers, spiegels, uitlaten),
  `stockWing`, `wingY/wingZ`. Tuning/uiterlijk: `styleCar(m,id)` + `styleExtras`. Gedeelde materialen/geometrie staan in `SHARED`: nooit disposen.
  Verkeer: `buildHatchTraffic`, `makeVan`, `makeTruck`, `makeTractor`.
- **settings / prefs** — `settings` (car,color,track,dir,bots,diff,laps,grid,mode,time,weather,p2car,p2color) en `prefs` (sound,fx,cam,gearbox,quality,mirror,nick).
  Opslag via `store.get/set` (localStorage met try/catch). Sleutels beginnen met `polderrace3d-` (settings, prefs, garage, champ, career-run, binds, best-, lap-, lapcar-, ghost-).
- **player / traffic / bots** — `player{pos,heading,speed,steer,idx,lat,s,y,lap,slide,spin,gear,...}`; bots hebben `s`(afstand langs baan), `lat`, `speed`, AI in `updateBots`.
- **input** — toetsen via `binds` (instelbaar, P1/P2), gamepad `readPad`, touch-knoppen.
- **game flow** — `state`: menu → countdown → racing → finished → over (en replay). `mode`: race, elim, time, ghost, champ (+split = race met 2 spelers).
  `startRace()`, `finishPlayer`, `showResults()` → `enterPodium`. `toMenu(step)`.
- **ghost, championship (`CHAMP_ALL`, punten `CHAMP_PTS`), garage & credits (`UPG`, `garage`), podium (`PPOS`, ver weg in de wereld),
  garage-ruimte (`GPOS`), carrière (`CUPS`), prestaties (`ACH`).**
- **split screen** — speler 2 draait door globals te wisselen: `asP2(fn)` → `swapCtx(p2)`. **Elke nieuwe per-speler global
  (zoals `camLift`) moet in `swapCtx` en in `newP2` erbij**, anders lekt de toestand tussen de spelers.
- **online** — twee transports met dezelfde room-interface (`presence(patch)`, `peers()`, `onPeers(cb)`, `leave()`), zodat
  `netEnter`/`netTick`/`netSyncRemotes`/`netHostStart`/`netBegin` voor allebei werken; `net.p2p` zegt welke het is.
  (1) claude.ai-room (`roomNS`): lobby (`lobby:{id,name,track,n,max,open}`) en per game een room `'pr-'+id`.
  (2) Spelen via host: WebRTC (`p2pHostRoom`/`p2pGuestRoom`), stertopologie: de host heeft per gast een RTCPeerConnection +
  DataChannel, houdt de presence van iedereen bij en stuurt elke wijziging door; ids `'h'` en `'g1','g2',…`. Signalering met
  codes (`p2pEncode`/`p2pDecode`: `PR1` + I/A + Z/B + base64url, niet-trickle ICE met timeout); de gast is DTLS-server
  (`a=setup:passive`), zodat een trage antwoordcode (minutenlang via WhatsApp) nog werkt. `roomNS` wordt voor p2p nooit aangeraakt.
  Presence per game: `nick,car,color,host,st,b,k,race`. De host is de baas over de bots (`b`) en de start (`race`, met
  `order`: alleen wie daarin staat, start mee); gasten sturen hun positie (`st`) en tikken tegen bots (`k`).
- **menu** — `homePanel(v)` (hoofdscherm-panelen), `showMenu(step)` (0 auto, 1 baan, 2 modus, 3 kampioenschap), `menuFlow` quick/champ/net.
- **physics** — `drive(dt,inp)` (versnellingsbak `GEARS`), `edges()` (muren/sloot), botsingen: `pairContact` + `pairImpulse` + `yawKick`,
  `spinStep` voor uitspinnen. Afgestemd zodat een licht tikje niets doet en een PIT-manoeuvre wél draait (`test_collisions.py` bewaakt dit).
- **camera** — `updateCamera(dt)`: `placeCam`, `camLift` houdt de camera boven heuvels.
- **fx, damage** (schade is verwijderd, lege API blijft), **environment** (`applyEnv(time,weather)`), **mirror, replay, minimap, gauge, main loop** (`frame` → `update` → `hud`).

## Valkuilen (hier gingen eerder dingen mis)

- **Z-fighting (flikkeren):** twee vlakken in hetzelfde vlak flikkeren. Door de logaritmische dieptebuffer werkt `polygonOffset` niet;
  houd **≥ 2 cm** afstand, of laat een vlak 1–2 cm voorbij het andere uitsteken. Check met `test_zfight.py`.
- **Objecten op of naast de weg:** `distToTrack` trekt het dijktalud (EMB) er al af. Houd bij plaatsing rekening met de **straal/lengte**
  van het object, niet alleen met het middelpunt (grote duinen, lange muren, schepen). Lange objecten (kademuren, balken) die
  de baan kruisen, moeten onderbroken worden waar de weg ligt of onder het wegdek blijven. Check met `test_road_clear.py`.
- **Grote CSS-panelen:** op desktop zijn de menu's in hoogte begrensd en scrollt het paneel. Sub-panelen mogen daarin niet krimpen
  (`flex:0 0 auto; min-height:auto`), anders klappen ze in tot 0 px hoog en schuift de inhoud over elkaar. Check met `test_layout.py` op alle formaten.
- **Richting 'rev':** alles moet ook in omgekeerde richting kloppen (startlijn, checkpoints, borden). Test altijd `--rev`/`fwd,rev`.
- **Geheugen:** alles wat je aan `world` hangt, wordt opgeruimd door `clearWorld`. Voeg je iets toe aan `scene` zelf, ruim het dan ook zelf op.
- **Performance:** veel losse meshes = traag. Herhaalde objecten via `inst(...)`.

## Openstaande wensen / backlog

- Yip test visueel door te spelen en stuurt screenshots; neem die serieus, ook als tests groen zijn.
- Pas als Yip daar expliciet om vraagt, wordt er een echt PC-spel van gemaakt (waarschijnlijk in Godot). Tot die tijd is dat
  géén taak: blijf in `polderrace-3d.html` werken (zie "Fase" bovenaan).
