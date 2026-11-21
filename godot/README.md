# Polderrace 3D — pc-versie (Godot)

Arcaderacen over dijk, door dorp en langs duin: dezelfde 10 banen, 18 auto's, carrière en kampioenschap als de
browserversie, maar nu als echt pc-spel, met online racen op je eigen netwerk zonder codes.

## Spelen

1. Download de nieuwste versie op de downloadpagina: https://github.com/Yipwaal/Polderrace/releases/latest
   (rechtstreeks: https://github.com/Yipwaal/Polderrace/releases/latest/download/Polderrace-Setup.exe).
2. Start **Polderrace-Setup.exe**. Het spel komt op je bureaublad en in het Startmenu (**Polderrace 3D**); je hebt
   geen beheerdersrechten nodig. Een nieuwe versie installeer je gewoon over de oude heen; je voortgang blijft.
   Verwijderen: Instellingen → Apps → *Polderrace 3D*.
   - Windows kan de eerste keer "Windows heeft uw pc beschermd" zeggen (het spel is niet ondertekend):
     klik op *Meer info* → *Toch uitvoeren*.
   - Liever zonder installeren: download **Polderrace-Windows.zip**, pak hem uit en start **Polderrace.exe**
     (Linux: **Polderrace-Linux.zip**).
   - Bij de eerste keer online spelen vraagt Windows of het spel het netwerk mag gebruiken: vink **Particuliere
     netwerken** én **Openbare netwerken** aan en klik *Toegang toestaan*. Op een LAN-party noemt Windows het netwerk
     vaak "openbaar"; zonder dat vinkje zien anderen de game van de host niet.
3. Je voortgang (garage, carrière, records, instellingen) staat in je gebruikersmap (Windows:
   `%APPDATA%\Godot\app_userdata\Polderrace 3D\`).

## Besturing

| | Speler 1 | Speler 2 (split screen) | Gamepad |
|---|---|---|---|
| Gas | W of ↑ | ↑ | RT of A |
| Remmen / achteruit | S of ↓ | ↓ | LT of B |
| Sturen | A/D of ←/→ | ←/→ | linkerstick of d-pad |
| Handrem | Spatie of linker Shift | rechter Shift | X (of RB) |
| Terug op de baan | R | Num 0 | Y |
| Camera wisselen | V | Num 1 | Select |
| Achterom kijken | C | Num 2 | rechterstick indrukken |
| Schakelen (handbak) | E / Q | Page Up / Page Down | RB / LB |
| Pauze | Esc of P | | Start |
| Volledig scherm | F11 of Alt+Enter | | |

De toetsen zijn in te stellen bij Instellingen.

## Online spelen (LAN-party of thuis)

**Host (één pc):** Online spelen → *Nieuwe game maken*. Je ziet de lobby: links de spelers met auto, ping en *klaar*, en de
chat; rechts de race (baan, richting, ronden, bots, niveau, tijd, weer) en onder de chat startvolgorde en volgende baan.
Alles wat je instelt zien de anderen meteen. Het spel onthoudt je instellingen voor de volgende keer.
- *Start race* telt 3 seconden af bij iedereen (nog een keer klikken = annuleren). Is iemand nog niet klaar, dan staat er
  *Start toch (… niet klaar)*: klikken mag, hij rijdt gewoon mee.
- *Eruit* (twee keer klikken) zet een speler uit de game; *Nieuwe spelers: gesloten* laat niemand meer binnen.
- Na de race: uitslag met punten (10-8-6-5-4-3-2-1) en de *Stand van de avond*. *Nieuwe race* start de volgende,
  op de baan die bij *Volgende baan* hoort (zelf kiezen, om de beurt, willekeurig of stemmen). Rijdt er nog iemand,
  dan telt de race meteen mee met de plek die hij op dat moment heeft.
- Ga je als host terug naar de lobby terwijl de anderen nog rijden, dan rijden zij (en de bots) gewoon door en krijgt de
  race toch een uitslag en punten.
- Stopt de host (of valt zijn pc uit), dan neemt een andere speler de game vanzelf over: de race en de stand gaan door.

**Meedoen:** Online spelen → de game van de host staat vanzelf in de lijst *Games op dit netwerk* → *Meedoen*. Geen codes.
Kies in de lobby je auto en kleur (pijltjes of *Auto kiezen*), en klik *Ik ben klaar*. Je auto ziet er bij de anderen uit
zoals in je garage (lak, strepen, velgen, nummer, …).
- Kom je binnen terwijl er een race bezig is: *Meekijken*, en je doet mee vanaf de volgende race.
- Ben je klaar met de race, dan kijk je mee met de anderen (pijltjes: wie je volgt).
- Even geen wifi? Het spel verbindt zelf opnieuw, met je eigen plek en punten. Spel gecrasht? Start het opnieuw en klik
  weer *Meedoen*: je punten staan er nog.
- Twee spelers met dezelfde naam mag; de lijst laat zien wie wie is.

**Niemand ziet de game?** Na 10 seconden zonder games zegt het scherm wat je kunt nalopen. Kort:
1. Zit iedereen op hetzelfde netwerk (zelfde wifi of switch)? Gastnetwerken laten pc's elkaar vaak niet zien.
2. De host klikt *Windows-firewall openzetten* (of bij de eerste keer: **Particuliere** én **Openbare netwerken**
   aanvinken). Bij de host staat of spelers zijn game zien.
3. Lukt het nog niet: *Rechtstreeks via het IP-adres van de host* (het IP-adres staat bij de host). Het spel onthoudt
   het adres, de volgende keer is het één klik.
- Adressen met VirtualBox, Hyper-V of VPN erachter zijn meestal niet het goede; het echte netwerk staat vooraan.

**Via internet:** de host klikt *Via internet bereikbaar maken* (zet poort 47810 open via UPnP; bij afsluiten gaat hij
weer dicht) of zet zelf UDP-poort **47810** open in de router. De anderen doen mee via het internet-IP-adres van de host.

Tot 8 spelers per game, plus bots. Eén host per pc (de poort is dan bezet); meedoen kan wel met meerdere spellen op één pc.
Iedereen moet dezelfde versie hebben: anders zegt de lijst "andere versie".

Poorten: 47810/UDP (het spel), 47811/UDP en 47812/UDP (games vinden op het netwerk).

## Voor ontwikkelaars

Zie [PLAN.md](PLAN.md): opzet, portregels (de Godot-versie is een getrouwe port van `../polderrace-3d.html`) en tests.
Tests: `python godot/tests/run.py track build laps cars flow audio menus rules memory perf play` en `python godot/tests/test_net.py`
(meer online-scenario's, tot 9 spelers: `python godot/tests/test_net_more.py`, ±8 min).
