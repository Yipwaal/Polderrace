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

(zie onder, nieuwste onderaan)
