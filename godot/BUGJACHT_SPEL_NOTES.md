# Bugjacht spel (fase 2, ronde 3) — werknotities

Gereedschap: `tools/hunt.tscn` (rijdt races met echte toetsen en een rijder die remt voor bochten of plankgas geeft,
meldt `VREEMD`-regels: auto niet waar de camera hem hoort te tonen, camera in een andere auto, NaN, spin zonder botsing,
auto onder de weg; schermafdrukken met `shots=`). Zie de kop van `tools/hunt.gd`.

## Gevonden en opgelost

| # | Wat | Waar | Hoe gevonden | Commit / test |
|---|---|---|---|---|
| 1 | Camera van speler 2 (split screen) volgde met een vaste stap van 1/60 s: bij 120 fps twee keer zo snel, bij 30 fps half zo snel als speler 1 | `split.gd` tick | code lezen | test `flow` |
| 2 | Stoppen tijdens een windvlaag (Afsluitdijk/Zeeland): de regen bleef op elke volgende baan opzij waaien (`Env.wind_x` werd niet terug op 0 gezet) | `game.gd` updateWind | code lezen | test `flow` |

## Open / gemeld

## Bekeken schermafdrukken
