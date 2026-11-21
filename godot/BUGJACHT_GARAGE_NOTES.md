# Bugjacht garage, uiterlijk en bodykits — notities

Werknotities van de bugjager voor de garage, het uiterlijk van auto's en de bodykits (fase 2, ronde 3, zie `PLAN2.md`).

## Gevonden en opgelost

| # | Wat | Waar | Hoe gevonden | Commit |
|---|---|---|---|---|
| 1 | Willekeurig gaf met de kleurenmenger soms een eigen kleur aan dak of neon zonder dat je die set had: die belandde in de paskamer | `garage_ui.gd` randomLook | code lezen; test `test_looks` (60 keer Willekeurig met kleurenmenger) | |
| 3 | Kleurenkiezer (eigen kleur) met de gamepad: niet te bedienen, en B verliet de garage terwijl de kiezer open bleef; een kleur uit die verweesde kiezer kwam in de paskamer buiten de garage (en zo in de race) | `garage_ui.gd`, `menu.gd` padNav/_input | code lezen; test `test_looks` part_picker | |
| 4 | Carbon / mat zwarte motorkap kleurde de spatbordbulten naast de kap mee (super, hyper, longtail, proto, v12, speedster) | `car_parts.gd` hoodSplit | screenshot `kit_hyper_c_q.png`; test "carbon motorkap: alleen de kap" | |
| 5 | Zwarte ring "zwevend" in de garage (boven de auto in de zijaanzichten): de tuinslang hing zonder haspel op 3 m; nu op een rode haspel op 1,35 m met slang en spuitstuk | `garage_room.gd` | screenshots (`car_*_side.png`, `kit_*_q.png`) | |
| 6 | Diffuser (bodykit) liep door de uitlaten: de plaat en de vinnen zaten op de hoogte van de uitlaat af fabriek, sport, dubbel, centraal en kanon (rally, fastback, sedan, wagon, evo: kanon door de buitenste vin; hatch e.a.: de pijp door de plaat). Nu blijft de plaat onder de laagste pijp en stoppen de vinnen onder de pijpen | `car_parts.gd` _diffuser, exhaustTips | hint + rekenen (probe); test "diffuser: geen uitlaat door de vinnen"; `view_car kita tail/under` | |
| 7 | Mat zwarte motorkap op de evo was half (de kap loopt licht op naar de spatborden): de bultregel geldt nu alleen waar echt een bult staat (≥ 10 cm) | `car_parts.gd` hoodSplit | screenshot `evo__kitc__top.png` (na fix 4) | |
| 8 | Neon onder de auto werd in de race (van sommige hoeken) door de contactschaduw van Fx gedimd: volgorde hing af van de afstand | `car_look.gd` _glow (render_priority 1) | code lezen (Fx-schaduw op 0,1 m, neon op 0,105 m, beide doorzichtig) | |
| 9 | Een keuze die binnenkomt nadat de garage dicht is (tekstveld dat bij verbergen nog bevestigt, oude kleurenkiezer) kon de paskamer vullen waar de raceauto uit gestyled wordt: `pick` doet nu niets buiten de garage | `garage_ui.gd` pick | code lezen; test "kenteken getypt, garage uit met de focus in het veld" (via Terug was de volgorde al goed) | |
| 10 | Paskamer liet je betalen voor wat niet te zien is: een eigen tweede kleur bleef staan na een ontwerp met één kleur (ook nummerkleuren zonder nummer, bandkleur zonder band) en vroeg de kleurenmenger | `garage_ui.gd` syncLook | code lezen; test "tweede kleur van een ontwerp met één kleur" | |
| 11 | Coureur zat in de auto in de garage (CarKit.setDriver "de garage toont een lege auto" werd nergens aangeroepen) | `garage_room.gd`, 1 regel `game.gd` rebuildPlayerCar | screenshots (helm in `car_*_side.png`); test "de garage toont een lege auto" | |
| 2 | Onbeperkte voorraad: elke kleur uit de kleurenkiezer (velgen, remklauwen) bouwde een nieuwe wielvorm die nooit wegging; elke bodykit-combinatie bleef per model bewaard | `car_kit.gd` WGEO, `car_parts.gd` combo | code lezen; `test_memory` past nu in de garage (30 kits, 40 kleuren per ronde) | |

## Bekeken (screenshots)

- `shot_looks only=groups,cars`: alle 18 auto's met een drukke look, schuin en van opzij.
- `shot_looks only=kits`: drie kits op alle auto's.

## Open / niet gedaan

