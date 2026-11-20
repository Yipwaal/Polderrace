# Aanpassen (uiterlijk van auto's) — ontwerp en stand

Werknotities van de Aanpassen-agent (fase 2, zie `PLAN2.md`). Wordt bijgehouden tijdens het werk.

## Ontwerp

- **Eén catalogus**: `scripts/car/car_look.gd` (`CarLook.ITEMS`): per item `k` (sleutel in de look), `g` (groep in de
  garage), `type` (choice / color / num / text), `def`, `opts` `[id, naam, prijs, extra]`, `kit` (prijs die het hele item
  vrijgeeft), `mix` (vrije kleur mag, vraagt de kleurenmenger), `fit` (`cab` = auto met dak, `BA` = klasse B en A),
  `view` (garagecamera). Tekeningen (deurontwerpen, stickers, nummers, kentekens, voorruitband, banden) in
  `scripts/car/car_decal.gd` (`CarDecal`, Canvas2D).
- **Look** = klein JSON-veilig woordenboek `{sleutel: waarde}`. Altijd eerst door `CarLook.clean(u, car)`: onbekende
  sleutels weg, rommel wordt de standaardwaarde, oude strepen (`stripe: white/black/yellow`) worden `twin` + kleur.
  `CarLook.compact(L)` laat standaardwaarden weg (opslaan/versturen).
- **Toepassen**: `CarKit.styleCar(m, id_of_look)` roept `CarLook.pre(m, u)` aan (maakt de look schoon, bewaart hem op
  `m.look`, geeft terug wat de standaardcode van CarKit kent: velgkleur op naam, strepen std/none/white, nummer, spoiler,
  uitlaat), dan de oude styleCar-code (`_styleStd`), dan `CarLook.post(m)` (lak/afwerking/dak, materiaalwissels voor
  remklauwen, banden, ruiten, lampen, kenteken; velgkleur; nummerstijl; strepen/deurontwerpen; stickers; voorruitband;
  neon). Tweede haakje: `CarKit.applyEnv` → `CarLook.envChanged(niveau)` (getinte lampen en neon volgen dag/nacht).
- **Standaardlook verandert niets** aan meshes of materialen (golden `cars.json` blijft gelijk voor bestaande varianten).
- **Opslag**: per auto in `G.garage.cars[id]` (naast de upgrades); lakkleur per auto in `col` (`G.settings.color` blijft
  de kleur van de auto waar je in zit; `G.carPicked(oud, nieuw)` in `Menu.pickCar`). Bezit account-breed in
  `G.garage.looks = {"<k>:<id>": 1, "<k>": 1 (kit), "mix": 1}`. Oude saves (geen `looks`) krijgen de kleurenmenger
  gratis (de vrije kleurkiezer was gratis).
- **`G.lookOf(car)`**: schone, compacte look met `paint` (voor de LAN-agent: `buildCar(type, kleur)` +
  `CarKit.styleCar(m, look)`). **`G.styleUp(id)`** (= `CarKit.up_of`): garage-entry plus wat in de paskamer hangt.
- **Paskamer (passen voor je koopt)**: `G.fit = {car, look}`; kijken is gratis, niet-gekochte keuzes staan alleen in de
  paskamer (nooit in de save, nooit in `lookOf`); balk onderaan de garage: wat het kost, Kopen, Terugzetten. Garage of
  tabblad verlaten / andere auto = teruggezet.
- **Vrijspelen**: opties met `ach` zijn niet te koop maar komen vrij met een prestatie (Finishvlag-sticker: eerste
  overwinning; Polder Cup, Team Delta, Legende: de cups; Patat met: alle duels; Tulpen: Nederland rond; Oranje leeuw:
  Oranje Grand Prix; Xenon-blauw: Nachtbraker).
- **Bots**: `CarLook.botLook(naam, type, kleur, rival)` — vast per naam/auto (iedereen online ziet hetzelfde);
  carrière-rivalen hebben een eigen look (`RIVAL_LOOKS`).

## Stand (deel 1)

- [x] haakjes in `car_kit.gd` (styleCar = `CarLook.pre` + `_styleStd` (de oude code) + `CarLook.post`; `applyEnv` →
      `CarLook.envChanged`)
- [x] `globals.gd`: carUp-migratie, lookOf, styleUp, fit, lookNeeds/lookPick/fitCost/fitBuy/fitClear, carPicked
- [x] `garage_ui.gd` tabblad Uiterlijk uit de catalogus (groepen, swatches, chips met prijs/slot, paskamerbalk,
      Willekeurig, Standaard, Licht uit)
- [x] `garage_room.gd`: camera per onderdeel (`aim(view)`), licht uit (`setDark`)
- [x] kleine wijzigingen elders: `menu.gd` (pickCar → `G.carPicked`, orb-straal `orb.r`, gamepad links/rechts in
      de panelen), `game.gd` setupBots (botlook), `podium.gd` (botlook op het podium)
- [x] tests: `tests/test_looks.gd` (106 controles), varianten look/flag/triple in `test_cars.gd` (golden: 54 nieuwe
      sleutels, 94 ongewijzigd), `test_menus.gd`/`test_play.gd` bijgewerkt, workflow
- [x] screenshots: `tools/shot_looks.tscn` (groepen, looks, alle 18 auto's; contactbladen `sheet_*.png`)
- [x] perf (tekenaanroepen) onder xvfb: 49/49, bots met eigen look kosten geen merkbare tekenaanroepen (polder 566 van 750)
- [x] garage in een smal venster (1024x600): de auto staat midden in de ruimte naast het paneel (`menu.gd` `_wideOff`,
      alleen in de garage), niet meer half achter het paneel
- [x] volledige tests na merge van main (20 november, avond): track build laps cars flow audio menus rules memory perf
      looks groen, play 324/324, test_net 13/13
- [ ] toeter: niet gedaan (er is geen toetertoets, geen toetergeluid en niets online; raakt invoer, Sfx en net)
- [ ] verkeer: kleurt al willekeurig (`Vehicles`, eigendom Automodellen/Rijgedrag); geen looks op verkeer gezet

Gereedschap: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720
res://tools/shot_looks.tscn -- out=/map [only=groups,looks,cars] [car=gt]`.

## Catalogus (deel 1): 27 items, 203 opties

| Groep | Item (sleutel) | Opties | Prijs |
|---|---|---|---|
| Lak | Lakkleur (`paint`) | 7 klassiek + 21 speciaal + eigen kleur | klassiek gratis, speciaal € 150, kleurenmenger € 600 (eenmalig, voor alle kleur-items) |
| | Afwerking (`finish`) | glans, metallic, zijdeglans, mat, parelmoer, chroom | 0 / 400 / 300 / 500 / 900 / 2.500 |
| | Dak in tweede kleur (`roof`) | 8 kleuren + eigen | set € 350 (auto's met dak) |
| Striping | Ontwerp (`stripe`) | af fabriek, geen, dubbele streep, middenstreep, drie strepen, zijstreep, rally, finishvlag, vlammen, rood-wit-blauw, Delfts blauw, tulpen, Oranje leeuw | 0–700; tulpen en leeuw vrijspelen |
| | Kleur, Tweede kleur (`sc`, `sc2`) | 10 + eigen | gratis |
| Wielen | Velgmodel (`rimStyle`) | 3 | gratis |
| | Velgkleur (`rim`) | 4 + 8 + eigen | 4 gratis, rest € 100 |
| | Remklauwen (`cal`) | 8 + eigen | rood gratis, rest € 50 |
| | Banden (`tw`) | zwart, witte wand, rode lijn, witte/gele letters | 0 / 300 / 250 / 350 / 350 |
| Ruiten & licht | Ruiten (`tint`) | 7 | 0–700 |
| | Koplampen (`lamp`) | 6 | 0–400; xenon-blauw vrijspelen |
| | Neon onder de auto (`glow`) | 8 kleuren + eigen | set € 900 |
| Nummer | Startnummer (`num`), Vorm, Vlak, Cijfers, Lettertype, Plek | 0–99; 4 vormen; 10 + 8 kleuren; 3 letters; 3 plekken | gratis |
| | Kenteken (`plate`) + plaat (`plateStyle`) | eigen tekst (8 tekens); geel, blauw, zwart, wit | set € 250; platen € 150 |
| Stickers | Sticker voor / achter (`d1`, `d2`) | 14 stickers | € 120; 5 vrijspelen |
| | Voorruitband (`ban`, `banCol`) | eigen tekst (14 tekens), 10 kleuren | set € 300 |
| Onderdelen | Spoiler (`wing`), Uitlaat (`exhaust`) | 3, 4 (zoals het was) | gratis |

## Voor andere agents

- **LAN**: stuur `G.lookOf(G.settings.car)` mee in de presence (bijv. sleutel `look`; < 600 tekens JSON) en bouw een
  speler bij de ander met `CarKit.buildCar(carId, look.paint)` + `CarKit.styleCar(m, look)`. Opnieuw sturen als
  `JSON.stringify(G.lookOf(car))` verandert (nu alleen auto + kleur). Rommel is veilig (`CarLook.clean`). Het podium
  neemt een look aan via `entries[k].look`; bots krijgen daar hun botlook vanzelf.
- **Automodellen**: `CarKit.styleCar` is nu `CarLook.pre` + `_styleStd` (jullie code, ongewijzigd) + `CarLook.post`.
  `CarLook.finish(paint, id)` is een noodoplossing voor de lak-afwerking (past glans/kleur van de Phong-lak aan); zet
  `paint.set_meta("finish", true)` zodra het lakmateriaal `m.look.finish` zelf afhandelt, dan blijft CarLook eraf.
  CarLook leunt op: `K.on_side/on_top/on_cab`, `K.top/bot`, `K.ra`, `K.S.wz`, `K.C.sg/ws/z0`, `K.csec` (punt 8 = eind
  van de dakronding), `K.sideRects`, `CarKit.patch/stripeGeo/numSpot/mesh/set_geo`, `K.stripes/stripeNum/numGeo`,
  `K.G.stripe`, de meta `rim` op velgmeshes, en de gedeelde materialen `carGlass`, `lampMat`, `caliperMat`, `tyreMat`,
  `carPlate` (worden per auto vervangen). Band-uv: draaiing rond het wiel = u, dwars = v (buitenwand = bovenste 29 %).
- **Rijgedrag**: één regel in `setupBots` (bots krijgen `CarLook.botLook`).

## Wacht op deel 2

Bodykit-onderdelen op de nieuwe carrosserieën, meer velgmodellen, tweekleurige motorkap/spiegels, deurontwerpen
voorbij de wielkasten, toeter (er is nog geen toetertoets in het spel).
