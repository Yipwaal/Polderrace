# Polderrace 3D — pc-versie (Godot)

Arcaderacen over dijk, door dorp en langs duin: dezelfde 10 banen, 18 auto's, carrière en kampioenschap als de
browserversie, maar nu als echt pc-spel, met online racen op je eigen netwerk zonder codes.

## Spelen

1. Download de nieuwste versie: op GitHub, tabblad **Actions** → workflow **Godot build** → de bovenste (groene) run →
   onderaan bij *Artifacts*: **Polderrace-Windows** (of **Polderrace-Linux**). Je krijgt een zip.
2. Pak de zip uit en start **Polderrace.exe**. Er hoeft niets geïnstalleerd te worden.
   - Windows kan de eerste keer "Windows heeft uw pc beschermd" zeggen (het spel is niet ondertekend):
     klik op *Meer info* → *Toch uitvoeren*.
   - Bij de eerste keer online spelen vraagt Windows of het spel het netwerk mag gebruiken: kies **Particuliere
     netwerken** (thuis/LAN) en klik *Toegang toestaan*. Zonder dat zien anderen je game niet.
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

Poorten: 47810/UDP (het spel), 47811/UDP (games vinden op het netwerk).

## Voor ontwikkelaars

Zie [PLAN.md](PLAN.md): opzet, portregels (de Godot-versie is een getrouwe port van `../polderrace-3d.html`) en tests.
Tests: `python godot/tests/run.py track build laps cars flow` en `python godot/tests/test_net.py`.
