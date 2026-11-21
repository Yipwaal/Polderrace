# Bugjacht online/LAN — notities

Bugjager voor online spelen (fase 2, ronde 3). Gevonden / opgelost / open. Tests: `tests/test_net.py` (met
`tests/test_netunit.gd`), `tests/test_net_more.py` (scenario 5 is nieuw).

## Opgelost

1. **Host gaat midden in de race naar de lobby: bots bevriezen op de weg bij de anderen, de race krijgt nooit een uitslag
   of punten.** (gevonden met een eigen scenario: host + speler, host pauzeert → Naar lobby.) De host blijft nu scheidsrechter
   van de lopende race vanuit de lobby (`net.ref`: uitslag, punten, zijn eigen finish houdt zijn plek, baanlengte van de race
   zelf onthouden), en een speler wiens host geen botposities meer stuurt (host uit de race, of hostwissel) laat de bots zelf
   rijden (`Net.hostBots()`, twee regels in `game.gd`). Test: `test_net_more.py 5`.
2. **"Nieuwe race" terwijl nog iemand rijdt: de lopende race telde nooit mee.** De host maakt die race nu eerst af (wie nog
   rijdt krijgt de plek die hij heeft). Test: `test_net_more.py 5`.
3. **Windows-firewall-knop: het PowerShell-commando kwam kapot aan** (gelezen): Godot zet een argument met spaties tussen
   dubbele aanhalingstekens maar escapet de aanhalingstekens erin niet, en `program="C:\Program Files\…"` zat erin.
   Nu `-EncodedCommand`; UAC-Nee, netsh-fout of geen PowerShell geven een duidelijke melding in het hostscherm, knop uit
   zolang Windows vraagt. Test: `test_netunit.gd` (script komt ongeschonden aan, meldingen). Nooit op Windows gedraaid.
4. **Hostwissel koos twee hosts als iemand in de lobby stond** (gelezen, met test bevestigd): wie zelf niet in de race
   zat, zette de racers niet vooraan. Test: `test_net_more.py 5`.
5. **Tijdens een overname met bezette poort keek het scherm naar een opgeruimde game** (scriptfouten "previously freed"),
   en de speler viel daarna uit de game. Nu blijft de oude room geldig en gaat hij naar de volgende in de rij.
   Test: `test_net_more.py 5` (twee spelers kiezen zichzelf op één pc).
6. **Testfout scenario 1 "startvolgorde naar de stand"**: de test nam aan dat Bram stoel g1 had; de drie spelers kwamen
   tegelijk binnen. Nu één voor één en met de echte stoelen.
7. **Uiterlijk: clean_look kapte af bij 40 onderdelen, de catalogus heeft er met de bodykit precies 40.** Grens 64.
   Test: grootste look 659 van 1000 tekens gaat heel over; zo'n auto bouwen ±2 ms (CPU, headless).
8. **Focus sprong van Eruit naar Start** (lijst ververst elke seconde), **oude stem telde mee in de volgende stemronde**,
   **winst in de stand zonder finish**; het pauzescherm zegt nu dat de race online doorgaat.

## Bekeken (schermafdrukken)
`tools/shot_net.py` op 1024x600 en 1920x1080 (alle 17 schermen), eigen racebeeld met een volledig aangepaste laatkomer,
meekijken na de finish. De meekijk-camera loopt in de xvfb-test ver achter de auto (2 beelden/s; op een echte pc niet).

## Open
- Bouwtijd op de GPU (shaders van nieuwe materialen bij een laatkomer met chroom, neon …) niet meetbaar hier
  (software-OpenGL, basis ±450 ms per beeld; geen extra uitschieter gemeten).
