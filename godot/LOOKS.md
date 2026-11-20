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
- [ ] perf (tekenaanroepen) onder xvfb, volledige tests na merge van main

Gereedschap: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720
res://tools/shot_looks.tscn -- out=/map [only=groups,looks,cars] [car=gt]`.

## Wacht op deel 2

Bodykit-onderdelen op de nieuwe carrosserieën, meer velgmodellen, tweekleurige motorkap/spiegels, deurontwerpen
voorbij de wielkasten, toeter (er is nog geen toetertoets in het spel).
