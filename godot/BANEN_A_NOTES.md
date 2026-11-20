# Banen A — werknotities (polder, dorp, circuit, afsluitdijk, haven)

Werkbestand van de Banen A-agent; overleeft onderbrekingen. Wordt aan het eind het eindverslag.

## Gereedschap (stap 1, commit 40333a2)
- `python godot/tools/tour.py <baan> [fwd|rev] [day|dusk|night] [dry|rain|fog] [--step N --from A --to B --views ... --spot s,lat --cam ...]`
- `TRACKS=<baan> python godot/tests/run.py roadclear zfight ground` (zelftest + alle banen, ±2 min voor alles)
- Bevindingen Banen B doorgestuurd naar main (bericht na commit 40333a2).

## Voor-tours (stand f530f27): `godot/tests/.out/tour/before/<baan>_fwd_day/sheet_NN.png`

## Gedeeld (klaar)
- dress.gd roadGrime: 0.085 -> 0.13 (2 cm boven kerbs, 4 cm boven startlijn); roadclear UP_ROAD 0.16
- common.gd lampRow: arm aan de paal (kop hing 0,75 m los)

## Polder
Fout (tests): hek/sloot/fietspad kruisen elkaar in krappe dijkbocht 2420-2520 m.
Zwak (tour): neongroen egaal talud en land, heuvels aan de horizon (polder hoort vlak), bochten op de dijk en S-bocht
zonder bochtschilden, geen boerderij bij de S-bocht (staat wel in de beschrijving), molens/boerderijen ver weg.
Plan: filter sloot/pad/hek waar binnenbocht vouwt; vlakke bomenrand-horizon; grastextuur; bochtschilden (TrackCommon.chevrons);
boerderij bij S-bocht; molenrij + vaart naast start; dorpje met kerk midden in de ronde; tulpenvelden langs de weg.

## Dorp
(nog doen)

## Circuit
Fout (tests): reclameborden op lat 19.6 = EDGE (auto rijdt er 0,9 m doorheen), bandenstapels op 17.5 midden in uitloop,
duin 70x9x87 raakt uitloop bij 420-438 m, 18 masten 1,26 m boven de grond, vuil/kerb 0,5 cm (opgelost via grime).

## Afsluitdijk
Fout (tests): dijkvoetstrook #6d6a64 1 cm boven zeevlak (7400 m2 flikkert), 84 schapen? (0.8x0.8x1.3 #efece2) 0,35 m boven de grond.

## Haven
Fout (tests): 343 paren containers staan in elkaar (flikkeren), kraanonderdelen/containers zweven (ground).
