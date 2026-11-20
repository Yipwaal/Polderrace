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

## Afsluitdijk (klaar, commit 04308a5, opvolger)
Fout (tests): dijkvoetstrook #6d6a64 1 cm boven zeevlak (7400 m2 flikkert), 84 schapen 0,35 m boven de grond. Opgelost.
Zwak: neongroen egaal land, harde rand land/zee, "brug over de sluizen" was een bult in een grasdijk, sluizen dozen op het land.
Gedaan: brug met landhoofden/pijlers over een schutsluis (deuren, spuisluis, kotter), Stevinsluizen in het water,
Vlietermonument + loopbrug (s~450), basaltranden rond het land, 14 boten (kotters, jachten, coasters), fietspad,
bochtschilden, naadloos gras (ook polder), land in vakken van 40 m, World.noDress (decor niet in zee/sluis).
Tekenaanroepen high (4 punten): 529/118 (beeld/spiegel) -> 566/150 (budget 700/160).

## Haven (klaar, commit 2a0e9d3, opvolger)
Fout (tests): 343 paren containers in elkaar, kraangiek 0,5 m boven portaal, lantaarnpalen 1 m boven talud,
geparkeerde trucks: container 12 cm boven chassis (model, vehicles.gd: gemeld, niet aangepast; test telt voertuig als geheel).
Gedaan: containerblokken op raster met paden, viaduct op kolommen (VIA 2,6 m), kades rondom met fenders/bolders,
tankpark, loods met deuren en naam, kraanloopkat met spreader, locomotief, lichtmasten, bochtschilden, donkerdere bestrating.
Tekenaanroepen high: 491/121, 206k driehoeken -> 535/151, 255k (budget 650/170/280k): containers zonder onderkant.

## Gedeeld (opvolger)
- world.gd: World.noDress; dress.gd: alongSides en crates slaan noDress over
- common.gd: landPlane(..., cell) optioneel onderverdeeld
- startlijn/vuilstrook: bekeken (circuit), ziet er goed uit, niet veranderd

## Na de merges (Beeld, Rijgedrag, Aanpassen)
- circuit: driehoeken 600 347 > budget 600 000 na de merge -> duinen 16x7 segmenten: 563k
- sway (Beeld) op polderbomen en -riet, circuitdennen en helmgras
- CI: stap "Map tests" met TRACKS=polder,dorp,circuit,afsluitdijk,haven,rotterdam (Banen B-banen faalden nog)
- tekenaanroepen high na merge (beeld/spiegel/driehoeken): polder 636/420/639k, dorp 540/186/333k,
  circuit 687/122/563k, afsluitdijk 625/142/381k, haven 602/139/260k
