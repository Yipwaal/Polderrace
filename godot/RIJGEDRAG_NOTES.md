# Rijgedrag — werknotities (voor een opvolger)

Rol Rijgedrag uit `PLAN2.md`. Branch `worktree-agent-af8627a4a145c2dfd`. Eigen bestanden: rijgedeelte van
`scripts/game/game.gd`, `mover.gd`, `player_state.gd`, `tests/golden/laps.json`, plus `tests/handling_lib.gd`,
`tests/test_handling.gd`, `tests/test_measure.gd`, `tools/shot_handling.*`.

## Gereedschap

- `python godot/tests/run.py handling` — de testsuite (delen kiezen: `HANDLING=pace,limit,ground,same,hits,places,body,bots`).
- Meten zonder checks (voor/na-tabellen): `TAG=now MEASURE=basic,corner,slide,track godot --headless --path godot res://tests/runner.tscn -- measure`
  → `godot/tests/.out/handling_now.json`. De stand van vóór het werk staat in `tests/golden/handling_before.json`.
- Screenshots van de auto in actie: `tools/shot_handling.tscn` (zie de kop van `tools/shot_handling.gd`).
- Altijd eerst `export XDG_DATA_HOME="$PWD/.xdg"`.

## Wat er is (stand van de voorganger, commits 1544d3a..041a627)

- Bandenmodel in `driveStep`: snelheid langs de neus (`speed`) en dwars (`slide`), gierhoeksnelheid `yr`, twee assen met
  grip-limiet (sin(C·atan(B·x))-curve), gewichtsverplaatsing (`wt`), remmen/gas gebruiken grip (frictiecirkel),
  stabiliteitshulp, ABS/tractie op de achteras, handrem (`HAND_GRIP`), heuveltop/dal (`roadLoad`).
- `FEEL` per auto: aandrijving, gewichtsverdeling, achteras-marge, carrosseriehelling, tractie.
- Ondergrond per baan (`VERGE`, `GRAVEL`, kerbs op het circuit, klinkers trillen), links en rechts apart.
- Muren werken op de snelheidsvector (`WALL_RUB`, `WALL_BOUNCE`, `WALL_SCRAPE`).
- Carrosserie op veren in `syncCar` (`springStep`, `tiltRig`: wielen blijven op de weg).
- Camera kijkt mee in een slip, zakt terug bij optrekken.

## Overgenomen niet-gecommitte wijzigingen (van de voorganger)

- Bots: kleine fout = even wijd (wideT), verdedigen tegen snellere auto van achteren (DEFEND per moeilijkheid),
  inhalen naar de binnenkant, niet in een auto die er al rijdt, eerder remmen voor een veel langzamere auto.
- Bots hellen mee (`leanBot`), neus volgt de helling van de weg (`poseOnTrack`).

## Logboek

- **Opvolger (Opus 5.5), 20 nov:** overgenomen WIP gecommit (44d5adb); `handling` 107/107, `flow` groen; `laps`-golden
  liep uiteen (autopiloot = vol gas, stuurt niet af: circuit/polder trager, stadsbanen sneller). Gemeten met
  `test_measure` (`tools/handling_table.py before now`): nette ronden (`lap-*`) allemaal binnen ±5 % van vóór
  (uiterste: afsluitdijk super +4,4 %, haven/zeeland hatch −4 %). Daarna:
  - a0d84e2: camera kijkt een beetje de bocht in (`camSide`, gierhoeksnelheid), voorwielen van bots sturen mee,
    muurklap draait de auto in beeld in een flits in plaats van in één frame (`wallYaw`, alleen beeld),
    replay zet wielen recht onder de carrosserie (`replay.gd`, buiten eigen gebied: tiltRig-resten).
  - e859ec4: camera draait alleen achterom bij bewust achteruitrijden (`camBack`, rem ingedrukt), niet als de
    auto van een muur terugstuitert; test in `body`.
  - `test_dbg.gd` verwijderd; `handling` in de CI-stap Tests; `golden/laps.json` opnieuw vastgelegd.

## Wat nog kan (volgende stappen)

- Muurklap recht erin: fysiek draait de neus nog steeds in één stap langs de muur (alleen het beeld is nu zacht).
  Eerlijker zou zijn: minder direct draaien en de auto laten terugstuiteren; pas op voor de test `ground` (w45/w80).
- Handrem op 120 km/u kost de hatch veel snelheid (120 → 38 km/u bij 0,7 s vol); een korte tik is prima.
- `max_corner` op kleine straal (20–40 m) is nu bijna 2× sneller dan vóór (oude model werd daar door de
  draaisnelheid begrensd); de nette ronden merken het nauwelijks, maar haarspelden zijn makkelijker.
- Camera kan bij een bot vlak naast/achter je door die auto heen kijken (geen botsing van de camera met auto's).
- Autopiloot-ronde limburg/gt: 1 keer terug op de baan (vol gas zonder remmen spint hij één keer).
