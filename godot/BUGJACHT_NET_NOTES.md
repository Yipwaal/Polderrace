# Bugjacht online/LAN — notities

Bugjager voor online spelen (fase 2, ronde 3). Gevonden / opgelost / open. Tests: `tests/test_net.py`, `tests/test_net_more.py`.

## Opgelost

1. **Host gaat midden in de race naar de lobby: bots bevriezen op de weg bij de anderen, de race krijgt nooit een uitslag
   of punten.** (gevonden met een eigen scenario: host + speler, host pauzeert → Naar lobby.) De host blijft nu scheidsrechter
   van de lopende race vanuit de lobby (`net.ref`: uitslag, punten, zijn eigen finish houdt zijn plek, baanlengte van de race
   zelf onthouden), en een speler wiens host geen botposities meer stuurt (host uit de race, of hostwissel) laat de bots zelf
   rijden (`Net.hostBots()`, twee regels in `game.gd`). Test: `test_net_more.py 5`.
2. **"Nieuwe race" terwijl nog iemand rijdt: de lopende race telde nooit mee.** De host maakt die race nu eerst af (wie nog
   rijdt krijgt de plek die hij heeft). Test: `test_net_more.py 5`.

## Open

