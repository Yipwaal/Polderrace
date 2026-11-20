# Automodellen — werknotities (fase 2)

Notities van de Automodellen-agent: wat er per auto mis was, wat er veranderd is en wat nog open staat.
Contactvellen: `python3 godot/tools/view_car.py [auto's] [sets]` → `godot/tests/.out/cars/<auto>.png` (zie de kop van het script).
(Let op: `python` = 3.11 zonder werkende PIL op deze machine; gebruik `/usr/bin/python3` voor view_car.py.)

## Uitgangssituatie (vellen in tests/.out/cars0, bekeken 20 nov)

Algemeen (alle 18 + verkeer):
- Carrosserie is een gladde "zeep"-loft zonder lijnen: geen deurnaden, geen motorkap-/kofferlijn, geen taillelijn.
- Lak is vlak Phong: geen glans, geen spiegeling.
- Ruiten: één donkere massa, geen raamlijsten, geen interieur, niet doorzichtig.
- Koplampen: witte rechthoekige plakkers; **ontbreken helemaal** op gt, hatch(?), sedan e.a. omdat het vlak (`hF`) om de
  hoek van neus/motorkap valt en dan wordt weggeklipt (`_cl`/`_fits`). Supercars: witte vlakken plat op de kap.
- Achterlichten: platte rode rechthoeken; geen remlicht bij bots/verkeer/online-spelers, geen achteruitrijlicht.
- Grille: zwart vlak. Spiegels: bolletjes op een stokje. Uitlaten: chromen buizen die te ver onder de bumper uitsteken.
- Wielen redelijk (5 dubbele spaken), band heeft weinig wang; 4 meshes per wiel.
- Kosten: 27-30 meshes (±33 tekenaanroepen) per auto; kit bouwen 35-100 ms.
- Verkeer: bus, vrachtwagen en trekker zijn kale dozen.

## Ontwerp (wat ik bouw)

- `car_paint.gd` (CarPaint extends LMat): lak met blanke lak-glans, fresnel, nep-spiegeling van lucht/horizon/weg; afwerkingen
  gloss/metallic/matte/satin/pearl/chrome; DETAIL-materiaal (vertexkleur + alpha = glans) voor al het overige; GLASS doorzichtig.
  Haakt in op LMat's shader via ankers (valt terug op LMat als die verdwijnen; test bewaakt `CarPaint.hooked`).
- `car_body.gd` v2: ring 22 punten (taillevouw, wielkastverbreding), cabine met raamlijsten/gordellijst, gat in de carrosserie
  onder de cabine met kuip/dashboard/stoelen/stuur/coureur, paneellijnen als kaart in autoruimte (`lines_image`), `proj()`
  voor lampen die om een hoek lopen.
- `car_kit.gd`: meshes samenvoegen per materiaal (lak, detail, glas, lamp, achterlicht, kenteken, coureur, wielen 1 mesh),
  lampen uit een canvas-atlas met emissiekaart, rem-/achteruitrijlicht door materiaal te wisselen (`CarKit.setLights`),
  contactschaduw.

## Per auto

(nog in te vullen tijdens het werk)

## Buiten eigen bestanden (melden in eindverslag)

- `tests/golden/build.json`: aantal meshes per baan verandert doordat geparkeerde auto's/vrachtwagens anders zijn opgebouwd.
- `scripts/game/game.gd`: remlicht via `CarKit.setLights` (paar regels), nog te doen.
