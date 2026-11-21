# Bugjacht spel (fase 2, ronde 3) — werknotities

Gereedschap: `tools/hunt.tscn` (rijdt races met echte toetsen en een rijder die remt voor bochten of plankgas geeft,
meldt `VREEMD`-regels: auto niet waar de camera hem hoort te tonen, camera in een andere auto, NaN, spin zonder botsing,
auto onder de weg; schermafdrukken met `shots=`). Zie de kop van `tools/hunt.gd`.

## Gevonden en opgelost

| # | Wat | Waar | Hoe gevonden | Commit / test |
|---|---|---|---|---|
| 1 | Camera van speler 2 (split screen) volgde met een vaste stap van 1/60 s: bij 120 fps twee keer zo snel, bij 30 fps half zo snel als speler 1 | `split.gd` tick | code lezen | test `flow` |
| 2 | Stoppen tijdens een windvlaag (Afsluitdijk/Zeeland): de regen bleef op elke volgende baan opzij waaien (`Env.wind_x` werd niet terug op 0 gezet) | `game.gd` updateWind | code lezen | test `flow` |
| 3 | Achterlichten van de vrachtwagen (verkeer, geparkeerd) hingen in de lucht naast het chassis | `vehicles.gd` makeTruck | hint + view_car | golden cars (truck) |
| 4 | Na "In de sloot!" sprong de camera niet mee: vanaf de dijkvoet keek hij omhoog, de auto verdween boven uit beeld | `game.gd` edges | tools/hunt (polder rev, plankgas) | test `flow` |
| 5 | Camera in een busje/vrachtwagen die vlak achter je stopt (tijdrit met verkeer) | `game.gd` updateCamera (`camClear`, `PlayerState.camDodge`) | tools/hunt style=stop | test `flow` |
| 6 | Mist/regen: verre heuvels (zonder eigen mist) stonden scherp boven de mistbank | `env.gd` apply (hillMats) | screenshot limburg mist | test `flow` |
| 7 | Online: de uitslag kwam terwijl het pauzescherm open stond; dat bleef erover staan | `game.gd` showResults | code lezen | test `flow` |
| 8 | Test audio "vol gas schakelt op" faalde op een drukke machine (frames > 0,1 s werden ingekort) | `tests/test_audio.gd` | baseline | — |
| 9 | Replay "Langs de baan": in dorp/grachten/Rotterdam stond de camera in een huis of boom | `replay.gd` trackCam | screenshots (tools/hunt replay=1, tools/hunt_cams) | test `flow` |
| 10 | 2 spelers: beeldhoek van speler 2 begon elk frame bij die van speler 1 (zoomde mee met speler 1's snelheid) | `split.gd` (`fov2`) | code lezen | test `flow` |
| 11 | 2 spelers: bumpercamera verborg de auto in beide helften (de ander zag je niet meer) | `game.gd` updateCamera, `split.gd` (cull masks, `P2_LAYER`) | code lezen + screenshot | test `flow` |
| 12 | 2 spelers: camerawissel van speler 2 werd als voorkeur van speler 1 opgeslagen | `game.gd` cycleCam | code lezen | test `flow` |

## Open / gemeld

- Muscle car en V12 met een rijder die gas geeft tot de bochtsnelheid: veel vaker in de sloot dan de rest (polder: 8-9 keer per tijdrit, de rest 0-3). De powerslide is bewust (test handling), maar met toetsen is hij lastig te houden. Voor Rijgedrag/Yip om te beoordelen; niet veranderd.
- Windturbines Afsluitdijk staan met `randf()` (JS Math.random) een paar meter anders: alleen beeld, online niet gelijk. Gelaten (portregel).
- Glow/lichtvlekken 's nachts op 'laag': veel overdraw op software-OpenGL; op een echte GPU klein. Niet veranderd.
- 'Auto onderaan het beeld' (hint): in echt rijden niet gezien (tools/hunt meet de plek: mediaan 0,64, max 0,72 van de vensterhoogte op alle banen); wel in de screenshot-tools die de camera pas bij de foto bijwerken.
- Audio-test 'motor A stationair' en 'noise() uitsterven' wiebelen als de machine druk is (audiothread); stil: groen.

## Bekeken schermafdrukken

(in de scratchpad van de sessie, niet in git) races met HUD: polder dag; limburg mist vóór en na fix 6; zeeland, rotterdam,
dorp (laag), haven (regen, middel), grachten (2 spelers, kwaliteit hoog→laag→middel) 's nachts; polder avond regen vooruit
en achteruit kijkend; veluwe avond regen; circuit avond laag→hoog; dorp ghost 's nachts; 2 spelers met bumpercamera;
replay (drie camera's, dorp) vóór fix 9; camera langs de baan op alle tien banen vóór en na fix 9; vrachtwagen (zij, achter)
vóór en na fix 3; GT 's nachts met rem- en achteruitrijlicht; achteruit in de regen 's nachts.

## Rest gecontroleerd zonder bevinding

- Alle tien banen heen en terug, met een rijder die remt (GT) en met plankgas (hyper, 7 bots): geen NaN, geen camera in een
  auto, auto altijd op de juiste plek in beeld, geen fouten in de uitvoer. Modi: eliminatie, tijdrit (ook regen), ghost,
  2 spelers. Alle 18 auto's een tijdrit op de polder (zie Open: muscle en V12).
- `perf` en `memory` met renderer (xvfb, OpenGL): groen; video ±168 MB, stabiel over drie rondes.
