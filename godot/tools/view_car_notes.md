# Automodellen — werknotities (fase 2)

Notities van de Automodellen-agent: wat er per auto mis was, wat er veranderd is en wat nog open staat.
Contactvellen: `/usr/bin/python3 godot/tools/view_car.py [auto's] [sets]` → `godot/tests/.out/cars/<auto>.png` (zie de kop van
het script). (`python` = 3.11 zonder werkende PIL op deze machine; `/usr/bin/python3` heeft PIL wel.)
Uitgangssituatie staat in `godot/tests/.out/cars0/` (niet in git), nieuwe stand in `godot/tests/.out/cars/`.

## Uitgangssituatie (bekeken 20 nov, vellen cars0)

Algemeen (alle 18 + verkeer):
- Carrosserie is een gladde "zeep"-loft zonder lijnen: geen deurnaden, geen motorkap-/kofferlijn, geen taillelijn.
- Lak is vlak Phong: geen glans, geen spiegeling.
- Ruiten: één donkere massa, geen raamlijsten, geen interieur, niet doorzichtig.
- Koplampen: witte rechthoekige plakkers; **ontbraken helemaal** op gt en hatch (het vlak `hF` viel om de hoek van
  neus/motorkap en werd weggeklipt); supercars: witte vlakken plat op de kap.
- Achterlichten: platte rode rechthoeken; geen remlicht bij bots/verkeer/online-spelers, geen achteruitrijlicht.
- Grille: zwart vlak. Spiegels: bolletjes op een stokje. Wielen: 4 meshes per wiel.
- Kosten: 27-30 meshes (±33 tekenaanroepen) per auto; kit bouwen 35-100 ms.
- Verkeer: bus, vrachtwagen en trekker waren kale dozen.

## Wat er nu staat

- `car_paint.gd` (CarPaint extends LMat): lak met blanke-lak-glans, fresnel, nep-spiegeling van lucht/horizon/weg; afwerkingen
  gloss/metallic/matte/satin/pearl/chrome (`finish` in de looks, via styleCar); DETAIL-materiaal (vertexkleur + alpha = glans)
  voor al het overige; GLASS doorzichtig. Haakt in op LMat's shader via ankers; valt terug op LMat als die verdwijnen
  (`CarPaint.hooked`, test bewaakt het).
- `car_body.gd` v2: ring 22 punten (taillevouw `crease`/`cut`, wielkastverbreding `flare`), cabine met raamlijsten en
  gordellijst, carrosserie open onder de cabine met kuip/dashboard/stoelen/stuur/coureur (`interior`), paneellijnen als kaart
  in autoruimte (`lines_image`: deuren, motorkap, koffer, tankklep, bumpernaden), `proj()` voor lampen om een hoek.
- `car_lamps.gd`: canvas-atlas (koplampen, achterlichten, grilles) + emissiekaart; rem/achteruit = materiaal wisselen.
- `car_kit.gd`: één mesh per materiaal (lak, detail, glas, lampen, achterlichten, kenteken, coureur) + 1 mesh per wiel;
  `setLights`, `autoBrake`, `setPlate`, `setDriver`, `parkedCar`, contactschaduw (`blob`), `shell`-node.
- `vehicles.gd`: bestelbus is nu een kit (`van` in CAR_SPECS), vrachtwagen en trekker opnieuw opgebouwd.

## Per auto (vellen tests/.out/cars/<auto>.png)

| Auto | Was | Nu / gedaan | Nog open |
|---|---|---|---|
| hatch | geen koplampen, zwart vlak als grille | koplampen om de hoek, lamellengrille, gaasgrille onder, knipperlichten, achterlicht rood/oranje/wit, 4 deuren | lijkt nog veel op rally |
| rally | als hatch | lampenbalk met lenzen, bredere wielkasten (`flare`) | |
| coupe | plakkers | koplampen, breed achterlicht | |
| roadster | donker vlak als kuip, losse dozen als stoelen | echte open kuip met dashboard, stoelen, coureur; ronde lampen op de kap geprojecteerd | stoelen blokkerig |
| mini | ronde lampen | chroomring + lens uit atlas, staande achterlichten (ontbraken even: test ving het) | |
| retro | witte schijven | kikkerogen met chroomring, kortere chroomstrips (rafelden om de hoek) | |
| gt | **geen koplampen** | led-koplampen, ronde achterlichten, kieuwen/kapventilatie met lamellen | |
| muscle | ok | vier ronde lampen in lamellengrille, achterlichtbalk in vakken | |
| fastback | ok | gaasgrille, ronde lampen, drie-vaks achterlichten | |
| sedan | ok | dubbele niergrille, breed achterlicht | |
| wagon | ok | (nog bekijken na laatste ronde) | |
| evo | ok | mistlampen, kapventilatie | |
| super | witte vlakken op de kap | led-units op de spatborden (geprojecteerd), ronde achterlichten | |
| hyper | idem | smalle led-units, lichtbalk achter | (nog bekijken) |
| longtail | idem | led-units | (nog bekijken) |
| proto | idem | led-units; achterlicht ontbrak even (test ving het) | |
| v12 | idem | led-units, ronde achterlichten | (nog bekijken) |
| speedster | donker vlak als kuip | echte open kuip, coureur | (nog bekijken) |
| verkeer hatch | | als de auto's (lite) | |
| verkeer bus | doos | kit: schuine neus, cabine met ruiten, laadruimte dicht, staande achterlichten, streep | |
| verkeer vrachtwagen | dozen | cabine met schuine ruit, grille, spiegels, tanks, oplegger met ribben/deuren/markeerlichten, 8 wielen | |
| verkeer trekker | dozen | motorkap, grille, spatborden, cabine met glas en boer, noppenbanden, gele velgen, driehoek | |

## Buiten eigen bestanden (melden in eindverslag)

- `scripts/game/game.gd`: remlicht speler via `CarKit.setLights` (blok met eigen tail-materiaal weg, 3 regels in syncCar);
  `CarKit.autoBrake(...)` bij bots (2×) en verkeer (1×).
- `scripts/net/net.gd`: 1 regel `CarKit.autoBrake` bij de online-spelers. `scripts/game/replay.gd`: 1 regel idem.
- `scripts/track/dress.gd`: geparkeerde auto's via `CarKit.parkedCar` (geen coureur, geen lichtbundel).
- `tests/golden/build.json`: aantal meshes per baan verandert (geparkeerde auto's/vrachtwagens anders opgebouwd).

## Ronde 2 (Opus 5.5, 20 nov avond): alle vellen opnieuw bekeken (day, night, tune)

Gevonden en opgelost:
- **Achteruitrijlicht ontbrak** bij retro, longtail, proto, speedster (t_bar), hyper (t_full), muscle/fastback (t_slats),
  vrachtwagen en trekker (t_tri): wit vak in die atlascellen (alleen wit in de achteruit-emissiekaart), `t_slats3` voor de
  fastback, losse `rev`-lampjes naast het kenteken bij de muscle. Test: `CarLamps.REV_CELLS` + `cellAt(uv)`, elke auto moet
  een achteruitrijlicht-cel hebben.
- **Kofferlip was een plank** die over de achterkant en de flanken uitstak (coupe, roadster, gt, muscle, fastback, sedan,
  retro, v12): `lipSpoiler` is nu een paneel dat de klep volgt (2 cm aan de voorkant, ±7 cm aan de achterrand, nooit breder
  dan de klep, nooit voorbij de staart).
- **Dakspoiler breder dan het dak** met "oren" (hatch, mini, wagon): `postWingRoof` is nu een dun vleugelprofiel zo breed
  als het dak met kleine zijvinnen.
- **Diffuser als tanden** onder de bumper (super, hyper, longtail, v12, speedster): schuine bodemplaat met vinnen die de
  helling volgen.
- **Chroombumper fastback liep langs de flank terug** (paneel tot aan de wielkastverbreding, die ook naar voren wijst):
  `_cl` stopt nu waar de huid een sprong maakt (alleen de fastback veranderde).
- Roadster: koplampen waren witte vlakken op de kap, nu dubbele ronde lampen in een donker huis (`h_quad`).
- Spiegels vierkanter (afgeronde doos in plaats van bol) — wijziging van de voorganger, nu vastgelegd.

## Kosten (golden, zichtbare meshes per auto, incl. 4 wielen + 4 remklauwen + contactschaduw)

| | voor fase 2 (f697bff) | nu |
|---|---|---|
| auto's (base) | 26-29 meshes, 10-13k driehoeken | 17-19 meshes, 14-18k driehoeken |
| getuned | — | 18-19 meshes |
| verkeer hatch / bus / vrachtwagen / trekker | 21 / 18 / 26 / 23 | 13 / 13 / 14 / 11 |

Tekenaanroepen (perf met renderer, polder): beeld 408 (budget 750), spiegel 382 (budget 520); alle banen groen.

## Carrosserie-API voor onderdelen (Aanpassen)

`CarKit.anchors(type)` (zie de kop in car_kit.gd): lengte/breedte/hitbox, neus/staart, wielen, wielkastradius, functies
`top(z, x)`, `shoulderX(z)`, `sideX(z, y)`, `bot(z)`, `roof(z, x)`, `cabX(z, y)`, banden `sill`, `bumperR`, kentekenhoogtes,
spiegelpositie, `wing`/`tuneFit`, `seat`, en de oppervlakfuncties `on_front/on_rear/on_side/on_top/on_cab` → [punt, normaal].
Onderdeel op de huid: `CarKit.patch(A, f, u0, u1, v0, v1, nu, nv, out, mirror)` (paneel dat de huid volgt, `out` ≥ 0,02,
mag een Callable(u, v) zijn voor een vorm, zoals `lipSpoiler`) of `CarAcc.boxOn(w, h, d, p, n, out)`.
Getunede onderdelen in de rig: `m.shell` (Node3D) is de plek voor extra meshes; `m.stockWing` verbergen bij een eigen spoiler.

Hoofdmaten (car space: +z vooruit, +x links, meters):

| auto | len x wid (rc) | neus/staart z | W | wielen x / z voor, achter / r | wielkast r | dorpel y | kap y (z voor-as) | dak y (midden) | spiegel z,y | kenteken v/a y |
| hatch | 4.00 x 1.90 (0.32) | 2.00 / -2.00 | 0.94 | 0.80 / 1.30, -1.25 / 0.34 | 0.39 | 0.30-0.37 | 0.89 | 1.46 | [0.62, 0.98] | 0.575 / 0.57 |
| rally | 4.00 x 1.92 (0.32) | 2.00 / -2.00 | 0.95 | 0.79 / 1.30, -1.25 / 0.36 | 0.41 | 0.33-0.42 | 0.94 | 1.48 | [0.62, 1.04] | <null> / 0.62 |
| coupe | 3.95 x 1.85 (0.34) | 1.98 / -1.98 | 0.92 | 0.78 / 1.28, -1.28 / 0.33 | 0.38 | 0.28-0.35 | 0.80 | 1.28 | [0.48, 0.92] | 0.55 / 0.58 |
| roadster | 4.05 x 1.86 (0.34) | 2.02 / -2.02 | 0.93 | 0.78 / 1.30, -1.30 / 0.34 | 0.39 | 0.30-0.37 | 0.82 | open | [0.3, 0.95] | 0.47 / 0.57 |
| mini | 3.75 x 1.86 (0.30) | 1.88 / -1.88 | 0.93 | 0.79 / 1.24, -1.20 / 0.33 | 0.38 | 0.30-0.37 | 0.88 | 1.45 | [0.62, 0.98] | 0.55 / 0.55 |
| retro | 4.10 x 1.80 (0.40) | 2.05 / -2.05 | 0.90 | 0.76 / 1.22, -1.18 / 0.33 | 0.38 | 0.25-0.32 | 0.80 | 1.26 | [0.36, 0.94] | 0.44 / 0.48 |
| gt | 4.40 x 2.00 (0.38) | 2.20 / -2.20 | 0.99 | 0.83 / 1.40, -1.40 / 0.36 | 0.41 | 0.26-0.34 | 0.80 | 1.31 | [0.2, 0.95] | 0.62 / 0.56 |
| muscle | 4.90 x 2.05 (0.34) | 2.45 / -2.45 | 1.02 | 0.84 / 1.55, -1.50 / 0.40 | 0.45 | 0.34-0.40 | 1.02 | 1.42 | [0.5, 1.08] | <null> / 0.62 |
| fastback | 4.80 x 2.03 (0.36) | 2.40 / -2.40 | 1.01 | 0.83 / 1.50, -1.50 / 0.39 | 0.44 | 0.34-0.40 | 0.99 | 1.36 | [0.5, 1.06] | 0.48 / 0.56 |
| sedan | 4.85 x 1.95 (0.38) | 2.42 / -2.42 | 0.97 | 0.81 / 1.55, -1.55 / 0.37 | 0.42 | 0.29-0.36 | 0.95 | 1.48 | [0.78, 1.03] | 0.56 / 0.62 |
| wagon | 4.95 x 1.98 (0.38) | 2.48 / -2.48 | 0.98 | 0.82 / 1.55, -1.50 / 0.37 | 0.42 | 0.29-0.36 | 0.96 | 1.48 | [0.78, 1.03] | 0.56 / 0.62 |
| evo | 4.50 x 1.90 (0.36) | 2.25 / -2.25 | 0.94 | 0.78 / 1.35, -1.30 / 0.36 | 0.41 | 0.31-0.38 | 0.93 | 1.46 | [0.66, 1.03] | 0.62 / 0.62 |
| super | 4.50 x 2.05 (0.40) | 2.25 / -2.25 | 1.02 | 0.84 / 1.45, -1.40 / 0.36 | 0.41 | 0.24-0.32 | 0.63 | 1.12 | [0.62, 0.86] | <null> / 0.52 |
| hyper | 4.80 x 2.02 (0.42) | 2.40 / -2.40 | 1.01 | 0.81 / 1.50, -1.50 / 0.36 | 0.41 | 0.20-0.30 | 0.58 | 1.11 | [0.68, 0.82] | <null> / <null> |
| longtail | 5.33 x 2.05 (0.60) | 2.50 / -2.83 | 1.02 | 0.83 / 1.60, -1.35 / 0.36 | 0.41 | 0.20-0.30 | 0.60 | 1.10 | [1.1, 0.8] | <null> / 0.62 |
| proto | 4.80 x 2.05 (0.48) | 2.40 / -2.40 | 1.02 | 0.83 / 1.45, -1.45 / 0.37 | 0.42 | 0.18-0.25 | 0.48 | 1.02 | [0.9, 0.66] | <null> / <null> |
| v12 | 4.75 x 2.02 (0.42) | 2.38 / -2.38 | 1.01 | 0.82 / 1.50, -1.42 / 0.37 | 0.42 | 0.22-0.30 | 0.72 | 1.19 | [-0.06, 0.92] | <null> / 0.53 |
| speedster | 4.60 x 2.00 (0.42) | 2.30 / -2.30 | 0.99 | 0.81 / 1.45, -1.45 / 0.36 | 0.41 | 0.22-0.30 | 0.61 | open | [0.24, 0.88] | <null> / 0.52 |


## Lichten-API

- `CarKit.setLights(m, brake, reverse)`: wisselt het materiaal van de achterlichten (1 mesh): tail / brake / rev / brakeRev.
- `CarKit.autoBrake(m, speed, dt)`: remlicht uit vertraging (> 3 m/s², 0,25 s nagloeien), achteruitrijlicht bij v < -0,5.
  Aangesloten: bots (game.gd 2×), verkeer (game.gd), online-spelers (net.gd), replay (replay.gd). Speler: game.gd syncCar.
- `CarKit.applyEnv(t, lamps)` (env.gd): lampen aan bij schemer/nacht/regen/mist; `m.beam` = lichtvlek voor bots/verkeer/online.
- Lak: `CarPaint.paint(color, finish)`; finish uit `G.carUp(car).finish` via `styleCar`; `CarKit.setGlass(m, hex, opacity)`,
  `CarKit.setCalipers(m, color)`, `setRims`, `setPlate`, `setDriver`.

## Samenvoegen met Aanpassen deel 1 (CarLook)

- `styleCar` = `CarLook.pre` + `_styleStd` + `CarLook.post`; `_styleStd` zet `paint.finish` en `paint.set_meta("finish", true)`
  (CarLook.finish blijft van de CarPaint af). `applyEnv` roept `CarLook.envChanged` aan.
- In `car_look.gd` aangepast aan de nieuwe kit: onderdelen hangen aan `m.shell` (`CarLook._par`); tweekleurig dak via
  `CarKit.roofSplit(K)` (verlakte mesh zonder cabine + cabine apart in dakkleur, +1 mesh); remklauwen via
  `CarKit.setCalipers`; bandopdruk/witte wang als dunne ring op de buitenwang (`CarKit.setTyreWall`, +1 mesh per wiel,
  uv zoals CarDecal.tyre); ruitkleur via `CarKit.setGlass` (CarPaint-glas, tabel `CarLook.GLASS`); lampkleur = getinte kopie
  van de lampen-atlas (`lampMat.clone()`); velgkleur via `CarKit.setRims`; voorruitband: punt 9 van de cabinering.
- `test_looks.gd`: remklauwen/banden-controle aangepast, volle look ≤ 13 meshes extra (4 bandringen), glaskleur `CarKit.GLASS_TINT`.
- `view_car.py ... look`: set met een volle look (bandopdruk, remklauwen, ruit, lampkleur, dak, vlammen, sticker, band).
- Gezien (tests/.out/looks/sheet_cars_*.png): alles zit op de nieuwe carrosserieën. Proto: flank te laag, het deurontwerp
  zakt onder de witte fabrieksstreep en er is geen plek voor stickers (de test staat dat al toe).

## Nog open / ideeën

- hyper en proto hebben geen kenteken (raceauto-achtig, bewust zo gelaten); super/hyper/proto/v12/speedster geen voorkenteken.
- retro heeft geen grille-opening (bewust: achterin-motor-look).
- hatch en rally lijken op elkaar (zelfde carrosserie, rally met lampenbalk en vleugel).
- garage/podium/menu met de nieuwe modellen niet apart bekeken (alleen via de vellen en de tests).
