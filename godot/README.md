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

- **Host:** Online spelen → *Nieuwe game maken*. Kies baan, ronden en bots; wacht tot iedereen in de lijst staat en
  klik *Start race*.
- **Meedoen:** Online spelen → de game van de host staat vanzelf in de lijst *Games op dit netwerk* → *Meedoen*.
  Geen codes nodig. Iedereen moet op hetzelfde netwerk zitten (zelfde wifi of switch).
- Werkt het vinden niet (sommige routers of gastnetwerken blokkeren dat), dan kan meedoen ook via het IP-adres van de
  host: dat staat in het scherm van de host ("Jouw IP-adres").
- **Via internet:** de host klikt *Via internet bereikbaar maken* (zet poort 47810 open via UPnP), of zet zelf
  UDP-poort **47810** open in de router. De anderen doen mee via het internet-IP-adres van de host.
- Tot 8 spelers per game, plus bots. De host bepaalt de race; iedereen ziet elkaars auto's en dezelfde bots.
- Je auto kies je in de game met *Auto kiezen*. Kom je binnen terwijl er een race bezig is, dan doe je mee vanaf de
  volgende race. *Nieuwe race* (host, op de uitslag) start de volgende race voor iedereen, ook voor wie nog rijdt.
- Alleen de host hoeft het spel door de firewall te laten (zie hierboven). Ziet niemand de game van de host:
  check de firewall van de host, of doe mee via het IP-adres dat bij de host staat (het echte netwerk staat vooraan;
  adressen met VirtualBox, Hyper-V of VPN erachter zijn het meestal niet).
- Eén host per pc (de poort is dan bezet); meedoen kan wel met meerdere spellen op één pc.

Poorten: 47810/UDP (het spel), 47811/UDP (games vinden op het netwerk).

## Voor ontwikkelaars

Zie [PLAN.md](PLAN.md): opzet, portregels (de Godot-versie is een getrouwe port van `../polderrace-3d.html`) en tests.
Tests: `python godot/tests/run.py track build laps cars flow audio menus rules memory perf play` en `python godot/tests/test_net.py`
(meer online-scenario's, tot 9 spelers: `python godot/tests/test_net_more.py`).
