# Polderrace — Godot-versie: plan en werkafspraken

Yip vroeg op 2 oktober 2026 om de echte pc-versie in Godot, met online spelen (LAN-lobby zonder codes).
De HTML-versie (`../polderrace-3d.html`) blijft de gepubliceerde browserversie en is het **naslagwerk**: de Godot-versie
is een getrouwe port ervan. Zelfde banen, auto's, rijgedrag, menu's, carrière, en waar het kan dezelfde getallen.

> **Fase 2 (vanaf 20 november 2026): zie `PLAN2.md`.** De Godot-versie is nu de hoofdversie; de portregels hieronder
> zijn richtlijnen en de golden-bestanden zijn de goedgekeurde stand van Godot zelf (`run.py --update`).

## Stand van zaken

| Onderdeel | Stand |
|---|---|
| G0 project, testrunner | klaar |
| G1 fundament (rng, CatmullRom, baanberekening, Geo, LMat, Canvas2D, World, Env) | klaar; baan exact gelijk (test `track`) |
| G2 alle 10 banen + terrein + dag/nacht/weer | klaar; decor exact gelijk (test `build`, 120/120), beeld gelijk (`tools/compare.py`) |
| G3 auto's (18 modellen, tuning, verkeer) | klaar; elke mesh gelijk (test `cars`), beeld gelijk (`tools/compare_car.py`) |
| G4 gameplay (rijden, botsingen, bots, verkeer, race, camera, HUD, audio, fx, spiegel, ghost, replay, invoer) | klaar; autopiloot-ronde gelijk (test `laps`), spelverloop (test `flow`), geluid (test `audio`) |
| G5 menu's (hoofdscherm, race-opzet, garage, carrière, kampioenschap, prestaties, records, instellingen, podium) | klaar: Menu (`scripts/ui/menu.gd` + `*_ui.gd`, look in `ui_kit.gd`), Champ, Career, Ach, GarageRoom, Podium; test `menus`, beeld gelijk (`tools/compare_menus.py`) |
| G6 online: LAN zonder codes (automatisch vinden), meedoen via IP, UPnP | klaar; `tests/test_net.py` (2 processen), `tests/test_net_more.py` (tot 9 spelers, LAN-scenario's) |
| G7 split screen | klaar (test `flow`) |
| G8 export (Windows .exe en Linux, GitHub Actions) | klaar; zie `README.md` en `.github/workflows/godot.yml` |
| G9 QA | klaar: vier onafhankelijke controles (doorspelen met echte toetsen en muis: test `play`; volledigheid tegen de JS: test `rules`; online met tot 9 spelers; geheugen en snelheid: tests `memory`, `perf`), gevonden bugs opgelost |

Mogelijke volgende stappen (nog niet gedaan): menu's meeschalen op hoge-DPI-schermen (Windows-schaal 125–200 %; nu
1 schermpixel = 1 CSS-pixel, zoals de browser op 100 %), botauto's samenvoegen tot minder meshes (±70 draw calls minder).

## Opzet

- Godot **4.7**, GDScript, renderer **Compatibility** (OpenGL 3): draait op oude laptops en in de cloud-container
  (software-OpenGL), zodat we hier screenshots kunnen maken.
- Autoloads: `G` (opslag, instellingen, garage), `Trk` (baanstatus), `Sfx` (geluid), `Game` (de race: speler, bots,
  verkeer, natuurkunde, camera, spelverloop, invoer), `Net` (online), `Hud` (race-HUD), `NetUi` (online-scherm),
  `Rep` (ghost en replay). In de spelscène (`scripts/main.gd`): `Env` (omgeving), `Fx` (remsporen, rook, koplamp,
  spiegel), de schermeffecten (`ui/fx_overlay.gd`) en `SplitView` (2 spelers).
- Mappen: `scripts/core` (rng, mathx, cr_curve, geo, mats, lmat, o3, canvas2d), `scripts/track` (track, track_defs,
  world, env, dress, common, loader, `builders/<baan>.gd`), `scripts/car`, `scripts/game`, `scripts/ui`, `scripts/net`.
- `tests/` (Godot-tests + golden data uit de HTML-versie), `tools/` (export van golden data, vergelijkingstool).

## Portregels (belangrijk)

1. **Zelfde namen en algoritmes als de JS.** `buildPolder` wordt `BuildPolder.build()`, `ribbon` blijft `World.ribbon`,
   `TRACK_LEN` blijft `Trk.TRACK_LEN`. Lees de JS en zet hem regel voor regel om; verzin niets nieuws.
2. **Zelfde random-volgorde.** Baandecor gebruikt de geseede `World.rnd` (JS `rnd()`), in exact dezelfde volgorde als de JS,
   anders staat alles daarna ergens anders. `Math.random()` in de JS wordt `randf()`. `pick(a)` → `World.pick(a)`.
   `Canvas2D.tex(...)` voert de tekenfunctie direct uit (net als JS `canvasTex`), dus rnd() daarin telt mee.
3. **three.js → Godot:**
   - `new THREE.Mesh(geo, mat)` + position → `O3.mesh(Geo.box(...), mat, x, y, z, parent, cast)`; `castShadow` = `cast`.
   - `receiveShadow = true` → `O3.receive(mesh)` (zet `LMat.receive_shadow` op zijn materialen; zonder die vlag valt er, net als
     in three, geen schaduw op). `ribbon`, `vribbon`, `groundPlane`, `startLine`, `waterPlane` en `landPlane` doen dat al zelf.
   - `rotation.set(x,y,z)` (volgorde XYZ) → `O3.rot(node, x, y, z)`; `scale.set` → `node.scale = Vector3(...)`.
   - `M(c,o)` → `Mats.M(c,o)` (Lambert), de HTML-`PM(c,o)` → `Mats.PM(c,o)` (Phong, specular 0x3a3a3a/38),
     `new THREE.MeshPhongMaterial({...})` → `Mats.phong(c,o)` (three-defaults 0x111111/30),
     `MeshBasicMaterial` → `Mats.basic(c,o)`. Opties met three-namen: map, repeat, emissive, emissiveMap, transparent, opacity, side,
     depthWrite, depthTest, fog, alphaTest, vertexColors, flatShading, blending:"add".
   - Een texture die met `.clone()` + eigen `repeat` wordt gebruikt: geef `"repeat": Vector2(...)` aan de materiaal-opties.
   - Geometrie: `Geo.box/cylinder/cone/plane/sphere/torus/circle/ring/lathe/extrude/icosahedron` (zelfde parameters als three),
     plus `.translate/.rotate_x/y/z/.scale/.apply_transform/.clone`. Meerdere materialen per groep: `[m0, m1, ...]`
     (box: px nx py ny pz nz).
   - `tmpO`-matrices / `mtx(x,y,z,ry,sx,sy,sz)` → `World.mtx(...)` (sz volgt sx, niet sy, zoals in de JS).
     Andere rotaties: `Transform3D(O3.euler(rx,ry,rz).scaled_local(Vector3(sx,sy,sz)), Vector3(x,y,z))`.
     Rotatievolgorde 'YXZ': `Basis(Vector3.UP, ry) * Basis(Vector3.RIGHT, rx)`.
   - `new THREE.Line(...)` → `O3.line(points, color)`; wireframe → `O3.wire(geo, color)`.
   - `world.add(x)` → `World.add(x)`. Lijsten die Env bijwerkt: `World.lampMats, roadMats, winMats, reflMats, hillMats,
     beaconMats, trackLights, sailGroups`.
   - `m.userData.x` → `node.set_meta("x", ...)`.
4. **GDScript-valkuilen:** lambda-parameters zijn ongetypeerd, dus binnen een lambda `var x: float = ...` schrijven
   (niet `:=` op een Variant). `for i in n` geeft int; deel met `/ 12.0` voor floats. Een `const` mag geen klassen bevatten.
   Lokale variabelen in geneste blokken mogen niet dezelfde naam hebben als een buitenste.
5. **Licht en kleur:** gebruik altijd `Mats` (LMat-shader), nooit `StandardMaterial3D` voor de wereld. LMat rekent zoals
   three.js r128 (gamma-ruimte, hemisfeer + zon, Lambert per vertex, lineaire mist). Uitleg in `scripts/core/lmat.gd`.
6. **Geen testcode in spelscripts**; tests en tools in `tests/` en `tools/`.

## Testen

- `python godot/tests/run.py track build laps cars flow audio menus rules perf memory` — alle Godot-tests headless (±11 min). Elke test
  speelt op een eigen savebestand (`G.use_store`, in runner.gd) met een garage die alle auto's bezit, nooit op die van de speler.
  `python godot/tests/test_net.py` — online: host en speler als twee processen; `test_net_more.py` — tot 9 spelers (zie Online).
  `python godot/tests/run.py play` (±11 min, apart draaien) — doorspeeltest: de echte spelscène met echte toetsen en
  muisklikken (`tests/play_driver.gd`), van nieuwe speler tot alles in bezit, elke modus, een heel kampioenschap,
  vensterformaten; faalt ook op elke foutmelding in de uitvoer. Alleen delen: `PLAY_ONLY=home,garage`; schermafdrukken
  met `PLAY_SHOTS=/map` onder xvfb (zie de kop van `tests/test_play.gd`).
- `rules`: de spelregels gelijk aan de HTML (golden/rules.json): credits per modus/plaats/ronden/niveau, kampioenschapspunten
  en stand (ook bij gelijke punten), de carrière (resultaat, bonus, wat opengaat, prestaties), prestaties na een race,
  meetunen van de tegenstanders, uitslagvolgorde, eliminatie, ronde- en checkpointmeldingen met de records die ze opslaan,
  opslagsleutels, getalnotatie (`G.toFixed` rondt af als JS `toFixed`), upgradeprijzen.
- `memory`: drie rondes van alle banen heen en terug laden (dag/avond/nacht, droog/regen/mist), race met 7 bots tot podium en
  replay, ghost, split screen, tijdrit met verkeer, garage en menu's in de echte spelscène; nodes, objecten, wezen
  (orphans), SubViewports, shaders en geheugen moeten na ronde 2 en 3 gelijk zijn (met renderer ook video-/textuurgeheugen).
- `perf`: laadtijd van elke baan, simulatie en frame met 7 bots, HUD (budgetten ruim). Met een renderer ook tekenaanroepen
  en driehoeken per baan (beeld en spiegel): `xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver
  opengl3 --resolution 1280x720 res://tests/runner.tscn -- perf memory`. Meer meten (kwaliteit, nacht, regen, split screen,
  verkeer): `res://tools/perf_render.tscn` (zie de kop van `tools/perf_render.gd`).
- Godot-eigen versnelling (beeld blijft gelijk): `World.batch()` voegt na het bouwen de onderdelen van één decorobject
  (boerderij, molen met wieken, schip, geparkeerde auto) per materiaal samen; `World.inst` gebruikt cellen van 300 m.
  `build` telt de meshes vóór het samenvoegen (zoals de HTML).
- `python godot/tests/run.py track build` — headless. `track`: baanberekening gelijk aan de HTML (golden/tracks.json).
  `build`: per geporte baan (fwd en rev) het aantal rnd()-aanroepen per fase, elk `inst()`-object (aantal, eerste en
  laatste positie) en het aantal meshes gelijk aan de HTML (golden/build.json). **Een builder is pas af als `build` groen is.**
  Alleen bepaalde banen: `TRACKS=dorp,circuit python godot/tests/run.py build`.
- `python godot/tools/compare.py <baan> <view> [tijd] [weer]` — zelfde camerastandpunt in de HTML-versie (links) en Godot
  (rechts) naast elkaar: `tests/.out/compare/<baan>_<view>_<tijd>_<weer>.png`. Views: `start`, `lap`, `side`, `top` of een
  JS-expressie `[ex,ey,ez,lx,ly,lz]`. Bekijk het plaatje met Read. Wolken, vogels en sterren zijn willekeurig; de rest
  hoort gelijk te zijn.
- Golden data opnieuw maken (alleen als de HTML-versie verandert): `python godot/tools/export_golden.py`,
  `python godot/tools/export_build.py`, `python godot/tools/export_rules.py`.
- Screenshots in de container: `xvfb-run -a godot --path godot --rendering-driver opengl3 ...`.
- `python godot/tools/compare_menus.py [BxH] [scherm,...] [--html]` — elk menuscherm in de HTML-versie (links) en Godot
  (rechts): `tests/.out/menus/compare_<BxH>/<scherm>.png`. Beide met dezelfde save (`tools/menus_state.json`);
  `--html` maakt de HTML-kant opnieuw (`tools/menus_html.py`, met de echte lettertypen).

## Online (G6) — ontwerp (fase 2: LAN-avond met 8 spelers, protocol 4)

- **Games vinden** (`net/lan.gd`): elke seconde "wie host?" (UDP `POLDERRACE?1`, poort 47811) naar 255.255.255.255,
  127.0.0.1, per netwerkkaart het broadcastadres van /24, /23, /22, /16 (10.x ook /8) en rechtstreeks naar onthouden
  IP-adressen; vindt dat na een paar seconden niets, dan vraagt hij alle adressen van de eigen /24 één voor één (sweep).
  De host antwoordt `{pr, v, id, name, track, n, max, open, race}` en roept zelf elke 2 s een baken (poort 47812): wie
  het baken hoort maar geen antwoord krijgt, ziet de game met "firewall van de host dicht". De host telt wie zijn game
  ziet (`searching()`), test zichzelf (eigen vraag komt terug) en kan op Windows de firewall openzetten (netsh via
  PowerShell met UAC; niet op Windows getest). Na 10 s zonder games: hulptekst met concrete stappen.
- **Verbinding** (`net/net_room.gd`): ENet (poort 47810, range coder), host = server, ster. Bij binnenkomst `hi` met
  token → vaste stoel (uid = hash van het token): wie wegvalt houdt 45 s zijn stoel, id en punten; de gast verbindt
  15 s lang zelf opnieuw. Kick (ban op uid), open/dicht, vol (9e speler hoort "vol"), andere versie ("andere versie").
  Alles van de lijn gaat door `clean()` (types, lengtes, getallen eindig, looks ≤ 1000 tekens), kapotte JSON wordt stil
  weggegooid (`parse_json`), per gast een rate limit (token bucket). Positiepakketjes van iedereen per frame gebundeld
  (`{t:"f"}`); bytes/s gemeten (`up_bps`/`down_bps`).
- **Presence** (wat elke speler deelt): `nick, car, color, look (G.lookOf: lak, afwerking, strepen, velgen, …),
  rdy, vote, e (chat), st (positie), k (tik tegen bot)`; de host daarnaast `cfg` (instellingen live in de lobby),
  `cd` (aftellen), `race` (met `order` = startvolgorde), `b` (bots), `res` (officiële uitslag), `pts` (stand van de
  avond, per uid), `q` (ping/verlies per speler), `seats` (uid + IP per stoel, voor een hostwissel).
- **Race** (`net/net.gd`): aftellen 3 s met baan voorladen, start op de klok van de host (`st[10]`); auto's van anderen
  met tijdstempels en dead reckoning op de echte beweging (ook als hij driftet; op 150 ms ± 30 ms en 5% verlies: 95% binnen 0,5-1,5 m van de echte plek, geen sprongen; teruggezet op de baan = meteen daar); de host
  beslist uitslag en punten (afstand gecontroleerd: een finish die niet kan, telt niet), meekijken na de finish of als
  laatkomer, naamlabels boven auto's (instelbaar), pauze online bevriest niets. Startvolgorde: leider achteraan /
  vooraan / willekeurig / vast; volgende baan: host / om de beurt / willekeurig / stemmen.
- **Hostwissel**: stopt of crasht de host, dan kiezen de anderen zonder overleg dezelfde nieuwe host (wie in de race zit
  eerst, dan op stoel); die opent de game met alles wat hij weet (stand, instellingen, race), de rest verbindt met zijn
  IP-adres (uit `seats`) en houdt zijn stoel. Een eenzame host blijft 2 min bij de oude adressen vragen of de game daar
  nog is (zijn eigen netwerk viel weg) en gaat dan zelf terug.
- **Dubbele namen**: elke pc toont de tweede "Bram" als "Bram (2)" (op stoelvolgorde, dus overal gelijk).
- **Bandbreedte** (8 spelers + 5 bots, gemeten): host ±60 kB/s omhoog, speler ±1,4 kB/s omhoog en ±9 kB/s omlaag.
- **Tests**: `tests/test_net.py` (2 processen, ±20 s, in CI) en `tests/test_net_more.py` (±6 min, in CI zonder
  scenario 4): 1 een avond (lobby, klaar, chat, aftellen, drie races, meekijken, crash en terugkomen, overname midden
  in de race), 2 vol met 9 spelers (kick, gesloten, vijandige pakketjes, race met 8, bandbreedte, overname in de lobby),
  3 auto en uiterlijk in de lobby (venster, xvfb), dubbele namen, 4 LAN met losse pc's (alleen Linux als root:
  netwerk-namespaces; /16, VirtualBox-kaart, broadcast dicht, firewall dicht, slechte verbinding via `net_lossy.py`,
  wifi 5 s en 12 s weg, host crasht). Spelers zijn `tests/net_ctl.gd` (commando's als aan het toetsenbord), gestart
  door `tests/net_players.py`. Schermafdrukken van alle online-schermen: `python godot/tools/shot_net.py`.

## Export (G8)

- Windows (.exe) en Linux via export-presets; GitHub Actions-workflow bouwt ze bij een push (Godot headless export).
