# Polderrace — Godot-versie: plan en werkafspraken

Yip vroeg op 2 oktober 2026 om de echte pc-versie in Godot, met online spelen (LAN-lobby zonder codes).
De HTML-versie (`../polderrace-3d.html`) blijft de gepubliceerde browserversie en is het **naslagwerk**: de Godot-versie
is een getrouwe port ervan. Zelfde banen, auto's, rijgedrag, menu's, carrière, en waar het kan dezelfde getallen.

## Stand van zaken

| Onderdeel | Stand |
|---|---|
| G0 project, testrunner | klaar |
| G1 fundament (rng, CatmullRom, baanberekening, Geo, LMat, Canvas2D, World, Env) | klaar; baan exact gelijk (test `track`) |
| G2 banen | polder klaar (decor exact gelijk, test `build`; beeld gelijk, zie `tools/compare.py`); overige 9 in bewerking |
| G3 auto's (modellen, tuning, verkeer) | open |
| G4 gameplay (rijden, botsingen, bots, verkeer, race, camera, HUD, audio, fx, invoer) | open |
| G5 menu's | open |
| G6 online: LAN-lobby (automatisch vinden), join via IP, internet | open |
| G7 split screen | open |
| G8 export (Windows/Linux, GitHub Actions) | open |
| G9 QA | open |

## Opzet

- Godot **4.7**, GDScript, renderer **Compatibility** (OpenGL 3): draait op oude laptops en in de cloud-container
  (software-OpenGL), zodat we hier screenshots kunnen maken.
- Autoloads: `G` (globals), `Trk` (baanstatus, `scripts/track/track.gd`). Later: `Net`, `Audio`.
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
   - `rotation.set(x,y,z)` (volgorde XYZ) → `O3.rot(node, x, y, z)`; `scale.set` → `node.scale = Vector3(...)`.
   - `M(c,o)` → `Mats.M(c,o)` (Lambert), de HTML-`PM(c,o)` → `Mats.PM(c,o)` (Phong, specular 0x3a3a3a/38),
     `new THREE.MeshPhongMaterial({...})` → `Mats.phong(c,o)` (three-defaults 0x111111/30),
     `MeshBasicMaterial` → `Mats.basic(c,o)`. Opties met three-namen: map, repeat, emissive, transparent, opacity, side,
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

- `python godot/tests/run.py track build` — headless. `track`: baanberekening gelijk aan de HTML (golden/tracks.json).
  `build`: per geporte baan (fwd en rev) het aantal rnd()-aanroepen per fase, elk `inst()`-object (aantal, eerste en
  laatste positie) en het aantal meshes gelijk aan de HTML (golden/build.json). **Een builder is pas af als `build` groen is.**
  Alleen bepaalde banen: `TRACKS=dorp,circuit python godot/tests/run.py build`.
- `python godot/tools/compare.py <baan> <view> [tijd] [weer]` — zelfde camerastandpunt in de HTML-versie (links) en Godot
  (rechts) naast elkaar: `tests/.out/compare/<baan>_<view>_<tijd>_<weer>.png`. Views: `start`, `lap`, `side`, `top` of een
  JS-expressie `[ex,ey,ez,lx,ly,lz]`. Bekijk het plaatje met Read. Wolken, vogels en sterren zijn willekeurig; de rest
  hoort gelijk te zijn.
- Golden data opnieuw maken (alleen als de HTML-versie verandert): `python godot/tools/export_golden.py`,
  `python godot/tools/export_build.py`.
- Screenshots in de container: `xvfb-run -a godot --path godot --rendering-driver opengl3 ...`.

## Online (G6) — ontwerp

- **LAN-lobby zonder codes:** de host start een lobby en roept zich elke seconde om via UDP-broadcast (poort 47811,
  bericht `POLDERRACE1 {naam, baan, spelers, max, poort}`); spelers zien open games in een lijst en klikken op Meedoen.
- Spel zelf: Godot **ENet** (`ENetMultiplayerPeer`, poort 47810), host = server. Zelfde rolverdeling als de HTML:
  de host bepaalt start, bots en volgorde; spelers sturen hun positie; botsingen tussen spelers lokaal per speler.
- Ook: meedoen via IP-adres (internet, met port forwarding of UPnP via `UPNP`-klasse).

## Export (G8)

- Windows (.exe) en Linux via export-presets; GitHub Actions-workflow bouwt ze bij een push (Godot headless export).
