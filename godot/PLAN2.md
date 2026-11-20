# Polderrace pc-versie — Fase 2: beter dan de browserversie

Yip vroeg op 20 november 2026 om een team van agents dat het pc-spel (Godot) verbetert op vier punten:
rijgedrag en beeld (automodellen, banen), meer aanpasmogelijkheden voor auto's, een zo soepel mogelijke LAN-ervaring,
en zo veel mogelijk bugs vinden en oplossen. Dit document is het plan en de werkafspraken voor dat team.
De techniek van de port zelf staat in `PLAN.md`.

## Wat er verandert ten opzichte van fase 1

- **De Godot-versie is nu de hoofdversie.** Tot nu toe was hij een getrouwe port van `polderrace-3d.html`; vanaf nu mag
  en moet hij beter worden dan de browserversie. De HTML-versie blijft staan zoals hij is (niet aanpassen).
- **De portregels uit `PLAN.md` zijn nu richtlijnen**: zelfde stijl, zelfde helpers (`World`, `Geo`, `Mats`, `O3`,
  `Canvas2D`, geseede `World.rnd` voor decor), maar "regel voor regel de JS volgen" hoeft niet meer.
- **Golden-bestanden zijn de goedgekeurde stand van Godot zelf** (`tests/golden/build.json`, `cars.json`, `laps.json`).
  Een bewuste verandering leg je vast met `python godot/tests/run.py --update cars` (of `build`, `laps`; beperken kan met
  `CARS=gt,hatch` / `TRACKS=polder`), **nadat je het resultaat bekeken hebt** (screenshots). Zonder `--update`
  controleren dezelfde tests of er niets ongemerkt verschoof. `tracks.json` (baanvorm) en `rules.json` (spelregels,
  prijzengeld, punten) blijven zoals ze zijn: de baanvormen en de spelregels veranderen in deze fase niet.
  Bij een merge-conflict in een golden-bestand: neem één kant en leg je eigen deel opnieuw vast.

## Het team (wie is eigenaar van welke bestanden)

| Rol | Doel | Eigen bestanden |
|---|---|---|
| **Rijgedrag** | Auto's die lekker en geloofwaardig rijden: gewichtsverplaatsing, grip en slippen, driften, bermen en kerbs, remmen, botsingen zonder plakken of tunnelen, bots die netjes inhalen en eerlijk blijven. Carrière blijft haalbaar. | `scripts/game/game.gd` (rijden, botsingen, bots, camera-gevoel), `mover.gd`, `player_state.gd`, `golden/laps.json` |
| **Automodellen** | Alle 18 auto's en het verkeer zien er van elke kant heel goed uit en kloppen: verhoudingen, wielkasten, ruiten, lampen, spiegels, velgen en banden, lak (glans), remlichten; niets steekt door iets anders heen; hitbox past. | `scripts/car/car_body.gd`, `car_kit.gd`, `cars.gd`, `vehicles.gd`, `golden/cars.json`, `tools/view_car.*` |
| **Aanpassen** | Veel meer opties in de garage (lak-afwerkingen, kleuren, stickers en strepen, velgen, bodykit-onderdelen, ruiten, kenteken, …), betaalbaar en in het verhaal passend, zichtbaar voor iedereen online, oude saves blijven werken. | `scripts/car/car_acc.gd`, `scripts/ui/garage_ui.gd`, `scripts/game/garage_room.gd`, de garage-tabellen in `scripts/core/globals.gd` |
| **Banen A** | polder, dorp, circuit, afsluitdijk, haven: fouten weg (zwevend, half in de grond, op de weg, flikkeren, gaten), mooier en rijker decor, betere texturen. Bouwt eerst de gereedschappen voor beide banen-agents. | `scripts/track/builders/{polder,dorp,circuit,afsluitdijk,haven}.gd`, `tests/test_roadclear.gd`, `tools/tour.*` |
| **Banen B** | veluwe, grachten, limburg, rotterdam, zeeland: idem, plus het terrein van Veluwe en Limburg. | `scripts/track/builders/{veluwe,grachten,limburg,rotterdam,zeeland}.gd`, `scripts/track/terrain.gd` |
| **Beeld** | Licht, lucht en effecten: mooiere lucht en wolken, schaduwen, water, mist en regen (nat wegdek), nacht (koplampen, lantaarns, gloed), rook/stof/vonken, anti-aliasing; de drie kwaliteitsniveaus blijven snel. | `scripts/core/lmat.gd`, `mats.gd`, `scripts/track/env.gd`, `scripts/game/fx.gd`, `scripts/ui/fx_overlay.gd` |
| **LAN** | Een LAN-party met 8 spelers loopt vanzelf: vinden en meedoen zonder gedoe, lobby waarin iedereen ziet wat er gaat gebeuren, soepele auto's van anderen, opnieuw verbinden, stand over meerdere races, duidelijke meldingen als iets niet lukt. | `scripts/net/*`, `scripts/ui/net_ui.gd`, `tests/test_net*.py`, `tests/net_*` |
| **Bugjacht** (aan het eind) | Het samengevoegde spel doorspelen en doorlezen op zoek naar bugs, in elk scherm en elke modus, ook geheugen en snelheid; alles wat gevonden wordt oplossen en met een test afdekken. | alles (kleine gerichte wijzigingen) |
| **Hoofdagent** | Plan, basis, samenvoegen, volledige tests, CI, release, verslag aan Yip. | `PLAN*.md`, `CLAUDE.md`, `.github/`, `tests/runner.gd`, `tests/report.gd` |

Gedeelde bestanden (`scripts/track/world.gd`, `dress.gd`, `common.gd`, `scripts/ui/menu.gd`, `hud.gd`, `globals.gd`,
`game.gd` buiten het eigen deel): alleen kleine, gerichte wijzigingen, zodat samenvoegen makkelijk blijft.
Heb je iets nodig in het gebied van een ander, maak dan de kleinst mogelijke wijziging en noem hem in je eindverslag.

## Volgorde

1. **Basis (hoofdagent, klaar):** golden-bestanden vastleggen vanuit Godot (`run.py --update`), dit plan.
2. **Ronde 1 (parallel):** Rijgedrag, Automodellen, Banen A, Banen B, Beeld, LAN, en Aanpassen deel 1 (alles wat geen
   nieuwe onderdelen op de carrosserie zet: opzet, opslag, garage-scherm, lak en kleuren, online zichtbaar).
3. **Ronde 2:** Aanpassen deel 2 (bodykit-onderdelen en alles wat op de nieuwe modellen moet passen), zodra Automodellen
   is samengevoegd.
4. **Ronde 3:** Bugjacht op het geheel (spel en menu's; online, geheugen en snelheid), daarna volledige tests, CI, nieuwe
   versie op de downloadpagina en verslag aan Yip.

De hoofdagent voegt elk klaar onderdeel samen op `claude/new-session-vj6qwu`, draait dan alle tests en pusht pas als ze
groen zijn (een groene build komt automatisch op de downloadpagina).

## Werkafspraken voor iedere agent

1. **Eigen werkkopie, eigen savemap.** Werk alleen in je worktree. Zet vóór elk Godot-commando
   `export XDG_DATA_HOME="$PWD/.xdg"` (staat in `.gitignore`): anders delen alle agents dezelfde `user://`-map en
   verstoren ze elkaars tests. Begin met `godot --headless --path godot --import`.
2. **Processen:** stop alleen je eigen Godot-processen (onthoud het PID of gebruik `timeout`); nooit `pkill godot` of
   `kill $(pgrep godot)`, want andere agents draaien op dezelfde machine. De machine heeft 4 kernen: draai niet meer
   dan één zware test of render tegelijk.
3. **Kijken.** Beeld beoordeel je op screenshots (`xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot
   --rendering-driver opengl3 --resolution 1280x720 res://tools/…`), vóór en na, met de Read-tool. Een groene test
   zegt niet dat het er goed uitziet. Check ook 's nachts, in de regen en in omgekeerde rijrichting (`rev`).
4. **Tests.** Draai wat bij je wijziging hoort en voor je eindverslag:
   `python godot/tests/run.py track build laps cars flow audio menus rules memory perf` (±12 min),
   `python godot/tests/run.py play` (±11 min) en `python godot/tests/test_net.py`. Verander je bewust auto's, banen of
   rijgedrag, leg dan de nieuwe stand vast met `--update` (zie boven). Voeg voor elk nieuw soort bug een test toe.
   Geen testcode in spelscripts.
5. **Snelheid en geheugen.** `perf` (met renderer ook tekenaanroepen per baan) en `memory` blijven groen; herhaalde
   objecten via `World.inst`, decor wordt na het bouwen samengevoegd (`World.batch`). Kwaliteit "laag" moet op een
   eenvoudige laptop blijven draaien.
6. **Saves en online.** Bestaande savebestanden blijven werken (nieuwe velden krijgen een standaardwaarde). Verandert
   wat spelers elkaar online sturen, verhoog dan `NetRoom.PROTO` (alleen de LAN-agent, of in overleg in je eindverslag).
7. **Teksten in het spel zijn Nederlands**, kort en duidelijk; code-commentaar Engels.
8. **Commits:** klein, Nederlandse boodschap ("Godot: …"), op je worktree-branch, niet pushen. Vóór je eindverslag:
   `git merge claude/new-session-vj6qwu`, conflicten oplossen, tests opnieuw.
9. **Eindverslag:** wat je verbeterd hebt (met de screenshots die je bekeek), wat je bewust niet deed en waarom,
   wijzigingen buiten je eigen bestanden, testuitslagen na de laatste merge, en wat je de bugjacht aanraadt te bekijken.

## Wisseling (20 november, avond)

De eerste ronde draaide op Fable 5.2; die limiet was na drie werkblokken op (tot 25 november). Op Yips verzoek leidt
Opus 5.5 vanaf nu het project en nemen Opus-agents elke rol over **in dezelfde werkkopie** (`.claude/worktrees/agent-…`),
met de commits en notities van hun voorganger (`*_NOTES.md`, `LOOKS.md`, `tools/view_car_notes.md`). Commits eindigen nu
met `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Stand

| Onderdeel | Stand |
|---|---|
| Basis: golden vanuit Godot, plan | klaar |
| Rijgedrag | klaar en samengevoegd (bandenmodel, gewichtsverplaatsing, driften, bots, camera; test `handling`) |
| Automodellen | loopt (Opus neemt over) |
| Aanpassen | deel 1 klaar en samengevoegd (27 onderdelen, 203 opties); deel 2 wacht op Automodellen |
| Banen A | gereedschap op main; banen loopt (Opus neemt over) |
| Banen B | loopt (Opus neemt over) |
| Beeld | klaar en samengevoegd (lucht-shader, licht per pixel, water, regen/nat wegdek, nacht, effecten, kwaliteitsniveaus) |
| LAN | loopt (Opus neemt over) |
| Bugjacht | wacht op ronde 1 en 2 |
