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

## Open / gemeld

- Muscle car en V12 met een rijder die gas geeft tot de bochtsnelheid: veel vaker in de sloot dan de rest (polder: 8-9 keer per tijdrit, de rest 0-3). De powerslide is bewust (test handling), maar met toetsen is hij lastig te houden. Voor Rijgedrag/Yip om te beoordelen; niet veranderd.
- Windturbines Afsluitdijk staan met `randf()` (JS Math.random) een paar meter anders: alleen beeld, online niet gelijk. Gelaten (portregel).
- Glow/lichtvlekken 's nachts op 'laag': veel overdraw op software-OpenGL; op een echte GPU klein. Niet veranderd.
- 'Auto onderaan het beeld' (hint): in echt rijden niet gezien (tools/hunt meet de plek: mediaan 0,64, max 0,72 van de vensterhoogte op alle banen); wel in de screenshot-tools die de camera pas bij de foto bijwerken.
- Audio-test 'motor A stationair' en 'noise() uitsterven' wiebelen als de machine druk is (audiothread); stil: groen.

## Bekeken schermafdrukken
