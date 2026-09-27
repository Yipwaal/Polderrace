# Prompt voor Claude Code — bugfixes ronde 1

Kopieer alles onder de streep in Claude Code (in deze projectmap).

---

Lees eerst `CLAUDE.md`. We zitten nog in de HTML-fase: het resultaat is een bijgewerkte `polderrace-3d.html` (één bestand,
net zoals we het tot nu toe deden), geen andere engine of opsplitsing. Los daarna de volgende bugs in `polderrace-3d.html` op. Ik heb ze gevonden door het spel te
spelen; de screenshots-beschrijvingen staan erbij. Werk ze één voor één af, met per bug: oorzaak vinden, fixen,
bewijzen met test + screenshot (vóór en na, bekijk ze zelf met Read), en een eigen commit.

## 1. Rotterdam — de Erasmusbrug-pyloon staat "midden op de weg"

Wat ik zie: rijdend over de brug staan de twee witte poten van de pyloon op de rand van het wegdek en hellen ze
schuin over de rijstroken naar elkaar toe. Het lijkt alsof de pyloon midden op de weg staat en dwars door het
brugdek komt. Het ziet er geglitcht uit.

Waar: `buildRotterdam()`, het blok dat de pyloon bouwt (`let ib=0;... HT[ib]` hoogste punt, `legs`, `l.rotation.z=-s*0.13`,
de kabels via `wire([top, ...])`). De poten staan op `s*8` (de weg is `ROAD_HALF=7.5`, `SHOULDER=10`) en hellen 0,13 rad naar binnen.

Wat ik wil: een pyloon die er als een echte tuibrug-pyloon uitziet en duidelijk **naast** het wegdek staat.
- Poten staan buiten de reling (|lat| ≥ SHOULDER + 1,5 m) en gaan eerst **recht omhoog** tot ruim boven het verkeer
  (≥ 12 m boven het wegdek) voordat ze naar elkaar toe buigen of met een dwarsbalk verbonden worden.
- Geen enkel deel van de pyloon op of dwars door het wegdek of de rijstroken. Kabels lopen van de pyloon naar de
  brugrand (buiten de rijstroken) en kruisen de rijbaan niet laag.
- Klopt in beide rijrichtingen (`rev`) en past bij de rest van de brug (de rode klapbrug-portalen niet slopen).
- Bewijs: `python tests/test_road_clear.py rotterdam --rev` groen + `python tests/screenshots.py rotterdam` (spot_rotterdam_brug.png) bekijken.

## 2. Zeeland — er ligt zand op de weg

Wat ik zie: een grote zandduin ligt over de berm en de wegrand, tot op de rijbaan.

Oorzaak (al gevonden): in `buildZeeland()` worden duinen (`dn`, ellipsoïdes `SphereGeometry` met schaal tot ± 24 m,
kleur `0xd8c898`) geplaatst met alleen `if(distToTrack(x,z)<14)continue;`. Dat test het **middelpunt**, niet de rand
van de duin. Bovendien trekt `distToTrack` het dijktalud (EMB) er al af. Resultaat: een duin rond x=421, z=355
ligt tot 1,5 m hoog op de rijbaan (track-index ~1604–1612).

Fix: houd rekening met de straal van elke duin (grootste horizontale as) plus een marge, zodat duinen
minimaal ~4 m buiten de berm (SHOULDER + EMB) blijven; sla anders de duin over of verplaats hem. Doe hetzelfde
voor de grasplukjes die bij die duin horen.
Bewijs: `python tests/test_road_clear.py zeeland --rev` (nu FOUT, moet OK worden) + spot_zeeland_duinen.png.

## 3. Zeeland — de Oosterscheldekering heeft te veel gaten

Wat ik zie: de stormvloedkering naast de weg bestaat uit losse pijlers met losse bovenbalken die niet op elkaar
aansluiten. Er zitten gaten tussen en er ontbreken stukken.

Oorzaak: in `buildZeeland()` wordt per 45 m track-afstand een pijler (`pm`), bovenbalk (`bm`, 44 m lang) en schuif (`gm`)
geplaatst op `onTrack(i,-34)` met de **richting van de weg op dat punt**. De weg slingert, dus de balken staan
schuin t.o.v. elkaar en sluiten niet aan. Waar de weg afbuigt (`P[i].z>80 || P[i].x<60 || P[i].x>1300`) vallen
pijlers helemaal weg.

Wat ik wil: één doorlopende, strakke kering zoals de echte:
- Pijlers op een vaste, regelmatige afstand langs een eigen rechte (of heel licht gebogen) lijn naast de weg,
  niet per track-sample.
- Bovenbalk/weg en schuiven lopen **van pijler naar pijler** (lengte = afstand tussen twee pijlers, richting = de lijn
  ertussen), zodat alles naadloos aansluit. Geen gaten, geen overlappende of flikkerende stukken.
- Niet door de rijbaan en niet door water/eilanden heen prikken op een rare manier; aan de uiteinden netjes afgesloten
  (landhoofd of laatste pijler).
- Bewijs: `python tests/test_zfight.py zeeland --no-cars`, `python tests/test_road_clear.py zeeland --rev`, en screenshots
  (spot_zeeland_kering.png en een eigen overzichtsshot van bovenaf) bekijken.

## 4. Grachten — er ligt een balk dwars over de weg

Wat ik zie: een bruinrode balk ligt dwars over de weg, vlak voor een grachtbruggetje.

Oorzaak (al gevonden): in `buildGrachten()` krijgt elke gracht aan beide kanten een kademuur:
`for(const s of [-1,1])box(520,0.5,0.7,brick,0,0.22,s*10.4,g,false);` — 520 m lang, dwars door de baan. Waar de weg
vóór/na de brug nog laag ligt, steekt die muur 0,47 m door het wegdek (x≈313, z≈−299, track-index ~276).

Fix: onderbreek de kademuren waar de weg de gracht kruist (twee stukken met een opening van de wegbreedte + berm),
of laat ze onder het wegdek stoppen. Controleer alle drie de bruggetjes en beide rijrichtingen, en of de
woonboten/het water niet op dezelfde manier door de weg steken.
Bewijs: `python tests/test_road_clear.py grachten --rev` (nu FOUT, moet OK worden) + spot_grachten_brug.png.

## 5. Klein: twee flikkerpunten bij auto-tuning (gevonden door de tests)

- **Hot hatch met startnummer:** de nummerstickers op de zijkant (`styleExtras`, `u.num>0`, `x=±(bp.width/2+0.006)`)
  liggen 4 mm achter de iets bredere donkere onderrand (`box(1.88,0.2,3.92,dark,...)`), dus ze flikkeren en worden
  deels afgedekt. Zet ze op de werkelijke buitenkant van de carrosserie op die hoogte (+1 cm), voor alle modellen.
- **Roadster met GT-vleugel:** de steunen van de vleugel vallen precies samen met de zijkant van de achterbulten
  (`box(0.4,0.12,0.8,paint,x,0.93,-1.35)`). Verschuif de steunen of maak ze zo dat ze niet in hetzelfde vlak liggen.
- Bewijs: `python tests/test_zfight.py none` groen.

## 6. Controleren: zwevende trapgevel in Grachten?

Op screenshot `spot_grachten_brug.png` lijkt rechtsboven een schuin gezet dakblok (de trapgevel/`gB` in `buildGrachten`,
een kubus 45° gedraaid) los boven een lager pand te hangen. Zoek uit of gevels bij het verkeerde (hogere) pand horen of
verkeerd geschaald zijn, en fix het als het een bug is. Kijk daarbij de hele baan rond met screenshots.

## Afronden

- Draai `python tests/run_all.py --fast` en zorg dat alles groen is. Op de huidige versie zijn precies deze punten
  rood: `test_road_clear` (grachten en zeeland, beide richtingen) en `test_zfight` (getunede varianten hatch en roadster). Daarna mag niets anders rood worden.
- Laat de qa-reviewer-agent alles controleren (de Stop-hook vraagt daar ook om) en verwerk zijn bevindingen.
- Vertel me in het Nederlands, kort: wat je per bug veranderd hebt, wat je gecontroleerd hebt, en welke andere
  bugs je onderweg zag. Zeg erbij dat ik `polderrace-3d.html` kan publiceren naar mijn artifact-link.
