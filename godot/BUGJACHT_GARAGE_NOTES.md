# Bugjacht garage, uiterlijk en bodykits — notities

Werknotities van de bugjager voor de garage, het uiterlijk van auto's en de bodykits (fase 2, ronde 3, zie `PLAN2.md`).

## Gevonden en opgelost

| # | Wat | Waar | Hoe gevonden | Commit |
|---|---|---|---|---|
| 1 | Willekeurig gaf met de kleurenmenger soms een eigen kleur aan dak of neon zonder dat je die set had: die belandde in de paskamer | `garage_ui.gd` randomLook | code lezen; test `test_looks` (60 keer Willekeurig met kleurenmenger) | |
| 3 | Kleurenkiezer (eigen kleur) met de gamepad: niet te bedienen, en B verliet de garage terwijl de kiezer open bleef; een kleur uit die verweesde kiezer kwam in de paskamer buiten de garage (en zo in de race) | `garage_ui.gd`, `menu.gd` padNav/_input | code lezen; test `test_looks` part_picker | |
| 4 | Carbon / mat zwarte motorkap kleurde de spatbordbulten naast de kap mee (super, hyper, longtail, proto, v12, speedster) | `car_parts.gd` hoodSplit | screenshot `kit_hyper_c_q.png`; test "carbon motorkap: alleen de kap" | |
| 5 | Zwarte ring "zwevend" in de garage: de tuinslang aan de muur had geen haak | `garage_room.gd` | screenshots (`car_*_side.png`, `kit_*_q.png`) | |
| 2 | Onbeperkte voorraad: elke kleur uit de kleurenkiezer (velgen, remklauwen) bouwde een nieuwe wielvorm die nooit wegging; elke bodykit-combinatie bleef per model bewaard | `car_kit.gd` WGEO, `car_parts.gd` combo | code lezen; `test_memory` past nu in de garage (30 kits, 40 kleuren per ronde) | |

## Bekeken (screenshots)

- `shot_looks only=groups,cars`: alle 18 auto's met een drukke look, schuin en van opzij.
- `shot_looks only=kits`: drie kits op alle auto's.

## Open / niet gedaan

