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

## Te doen

- garage / podium / menu / spiegel bekijken; perf (tekenaanroepen) meten; main mergen; alle tests; eindverslag.
