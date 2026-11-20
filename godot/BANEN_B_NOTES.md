# Banen B — werknotities (veluwe, grachten, limburg, rotterdam, zeeland)

Notities van de Banen B-agent, zodat het werk een onderbreking overleeft. De hoofdagent mag dit bestand na het
samenvoegen weggooien; het eindverslag staat in het bericht aan de hoofdagent.

## Gereedschap
- `tools/tour.py` (Banen A) is de standaard; testen draaien in ±30 s per baan (`TRACKS=zeeland run.py roadclear zfight ground`).
- Snelle parse-check: `godot --headless --path godot --check-only -s res://scripts/track/builders/<baan>.gd` (alleen 'Parse Error' telt).

## Gereedschap van de voorganger (tijdelijk)
- `godot/tools/btour.gd/.tscn`: veel standpunten van één baan in één proces (chase/high/side/back, `pts=i:lat:h:li:llat:lh;…`,
  `info=1` drukt bochten en gereserveerde plekken af). Wordt vervangen door `tools/tour.*` van Banen A zodra die er is.
- Contactbladen: scratchpad `b/tour.py <baan> [dir] [tijd] [weer] [mode] [n] [tag] [k=v …]` (met `/usr/bin/python3`, die heeft PIL),
  bladen in scratchpad `b/sheets/`. Voor = tag `a_`, na = tag `b_`/`c_`.
- Kosten: `tools/perf_render.tscn -- tracks=<baan> variants=high points=4` onder xvfb.

## Gedeelde hulpmiddelen die ik toevoegde
- `scripts/track/bkit.gd` (`BKit`): `merge()` (onderdelen met vertexkleur als één Geo, dus één `World.inst` per boom/hert),
  `Acc` (uniek decor als één mesh per cel van 300 m), bomen (spar, grove den, berk, eik, populier, straatboom, fruitboom),
  `crowd()`/`crowdRow()` (publiek), `deerGeo()`, `bends()` + `chevrons()` (pijlborden buitenbocht, per rijrichting goed),
  `reflectors()`, `decal()` + `paintTex()` (verf op de weg), `noiseTex()` (detailtextuur).
- `terrain.gd`: `groundMesh` in 6×6 stukken (alleen wat in beeld is wordt getekend) met uv's en een detailtextuur.
- `dress.gd` `alongSides`: slaat plekken in `World.pavTaken` over (gebouwen/tribunes van een builder). Enige wijziging daar.

## Kosten vooraf (high: beeld / spiegel / driehoeken totaal)
veluwe 583/270/1.19M · grachten 435/110/368k · limburg 426/123/795k · rotterdam 469/205/360k · zeeland 468/98/421k

## Veluwe — KLAAR (eerste ronde)
Fout gevonden en opgelost:
- checkpointpoort stond ín het ecoduct (banner verstopt in het dek): ecoduct blijft nu 60 m van elk checkpoint.
- paaltjes langs de weg zweefden 0,3 m (terrein ligt daar 0,3 m onder de weg); paddenstoelen en picknicktafels idem
  (tafels hadden ook geen poten).
- onzichtbare muur op 10,6 m: nu een houten rail van paal tot paal.
- berken hadden groene stammen bij kleurtint per boom → boomkleuren in de geometrie, tint alleen licht/donker.
Verbeterd: bos met open plekken (spar, grove den, berk, eik; `wood()`/`stand()`), grondkleuren (bosbodem, hei, stuifzand)
met detailtextuur, ecoduct met aarden taluds, uitkijktoren met trappen, pannenkoekenhuis met terras (verlicht 's nachts),
hoogzitten, herten in groepen (met gewei), heide-pollen, keien, dode bomen op het zand, tribune met publiek bij de start,
publiek in de twee scherpste bochten, pijlborden in alle bochten, reflectoren op de paaltjes (nacht).
Kosten na: 553/239/902k (was 583/270/1.19M).
Bekeken: a_veluwe_* (voor), b_veluwe_*, c_veluwe_* (na; dag, nacht rev, regen rev, mist).

## Limburg — KLAAR (eerste ronde)
Fout: witte paaltjes zweefden 0,3 m; onzichtbare muur → vangrail op 11,3 m (buiten de uitloop); struiken van de
dressing raakten de auto (nu 14,4–16,6 m).
Verbeterd: akkers in stroken (gras, graan, koolzaad, geploegd), bos op de toppen, boomgaarden in bloei, populierenrijen,
wijngaarden, mergelgroeve (in het terrein uitgesneden, open naar de weg, met blokken, gangen en graafmachine), kasteel
op de hoogste heuvel, dorp van mergel- en vakwerkhuizen rond de kerk (verlicht 's nachts), koeien, wegkruisen,
pijlborden, reflectoren, publiek + vlaggen + verf op de weg op de steilste klim.
Kosten na: 497/208/688k (was 426/123/795k). Spiegelbudget 160 moet omhoog (gemeten 208).
roadclear/zfight/ground: groen (op startlijn↔vuilstrook na: Banen A).

## Grachten — KLAAR (eerste ronde)
Fout: bomen zonder stam, kruin door camera en gevels (83 kruinen boven het asfalt) → iepen met 5,4 m stam, kruin boven
4,8 m; water lag 5 cm BOVEN de straat → grachten 1,3 m verdiept (grond met sleuven, kademuren); de bultbrug was een
dichte muur dwars door zijn eigen gracht → echte boog; huizen stonden op 2 m-monsters (overlap/gaten) → exact geplaatst
met niet-overlappende kavels (BKit.Lots); wereld hield op achter de eerste rij → drie rijen langs elke kade + kopblok.
Verbeterd: gevels met baksteen, hoge ramen, deur; trap-, hals-, klok- en tuitgevels met hijsbalk; pannendaken;
stenen brugleuning, lantaarns, fietsen; woonboten, sloepen, varende rondvaartboot per gracht (AnimB); Westertoren;
Amsterdamse vlaggen aan gevels; publiek bij start en bruggen; rustiger verlichte ramen 's nachts.
Kosten na: 484/154/240k beeld (was 435/110/180k). roadclear/zfight groen; ground: alleen lampkoppen (Banen A).

## Rotterdam — KLAAR (eerste ronde, door de opvolger afgemaakt)
WIP van de voorganger nagekeken en gehouden (stadsblokken langs de straten, De Rotterdam, kubuswoningen, Markthal,
Euromast met kraaiennest, containerkranen en containerschip, varende binnenvaart en watertaxi's, tram op het startrecht,
lichtreclames, brugpijlers, pijlborden, publiek). Fout: drie parse-fouten (getypeerde variabelen uit een Dictionary,
`floor`) — de testrunner bleef daarop hangen. Verbeterd: de stad houdt niet op achter de eerste rij (500 pogingen lagere
blokken, 220 torens), zeven parken met paden en bomen (wuivend), betonplaten in plaats van het 5 m-raster, Euromast vóór
de skyline (krijgt altijd een plek). roadclear/zfight groen; ground alleen lampkoppen (Banen A).
Kosten (perf-test): 593 / 274 / 277k.

## Zeeland — KLAAR (eerste ronde)
Fout: twee grondvlakken 1,2 cm boven elkaar (13.000 m², flikkerde) → één grondmesh met kustlijn; 22 paar keringdelen in
één vlak (schuif ↔ onderbalk) → schuif 9,4 m hoog, 1 m korter; vuurtoren: dak en lantaarn raakten de toren niet → nieuw
model (banden sluiten aan, omloop, lantaarn, koepel) en uit het dijktalud geschoven; strandhuisjes stonden op de
waterlijn (z=440, eiland hield daar op).
Verbeterd: eilanden met golvende kust en afgeronde stranden, schorren voor de dam (riet staat erop), basalt alleen onder
op de dijk boven water, polders in kavels, dorp met kerk (klok verlicht), schapen; duinen met helm (één Acc-mesh per cel
met strand), paalhoofden, paviljoens op palen (glaspui 's nachts verlicht), strandhuisjes, windschermen, parasols,
mensen, zes vliegers (wiegen), branding die het strand oprolt (AnimB.bob), windpark op zee (statisch, één mesh) en vijf
draaiende turbines langs de binnenkust (AnimB.spin), zeiljachten (twee varen), kotters (één vaart), containerschip aan de
horizon, lampen op de kering, lichtbundel van de vuurtoren (alleen met lampen aan), pijlborden, publiek in de lus.
Grondpunten nooit binnen 9 cm van het waterpeil (anders flikkert een plat strandstuk met het water).
Kosten (perf-test): 556 / 116 / 366k. Reflectorpaaltjes weggelaten (spiegelbudget); riet in dress.gd van 10 naar 16 m.

## Na de merge van Beeld + Rijgedrag (20 nov)
- roadclear/zfight/ground op alle vijf: groen, behalve bekende Banen A-punten (lampkoppen naast hun paal op
  grachten/rotterdam/zeeland, startlijn ↔ vuilstrook op veluwe/limburg).
- test_perf-budgetten van grachten (driehoeken), limburg (spiegel), rotterdam (beeld/spiegel), zeeland (spiegel)
  verhoogd met gemeten waarden (zie test_perf.gd).
- Limburg in mist: de horizonheuvels (dress.horizonHills, hillMats) staan scherp boven de mistbank (Beeld/dress).

## Indelingsvoorstellen (niet uitgevoerd; baanvorm blijft)
- (nog geen)

## Voor de bugjacht
- (aanvullen)
