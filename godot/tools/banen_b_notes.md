# Banen B — werknotities (veluwe, grachten, limburg, rotterdam, zeeland)

Notities van de Banen B-agent, zodat het werk een onderbreking overleeft. De hoofdagent mag dit bestand na het
samenvoegen weggooien; het eindverslag staat in het bericht aan de hoofdagent.

## Gereedschap (eigen, tijdelijk)
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

## Grachten — TE DOEN
Gezien (a_grachten_*): bomen zonder stam (zwevende bollen, te groot, door de gevels); langs de grachten buiten de eigen
huizenrij is de wereld leeg (kale vlakte tot de horizon); gevels grof (enorme zwarte ramen), alle topgevels gelijk;
brugleuning een donkere dichte muur; stoep bijna wit.
Plan: straatbomen met stam, huizen/kades/bomen/bootjes langs de grachten, gevarieerde topgevels (trap/hals/klok) met
hijsbalk, betere geveltextuur, brugleuningen met lantaarns en fietsen, rondvaartboot die vaart, kerktoren, terrasjes.

## Limburg — TE DOEN
Gezien: kale felgroene heuvels, bijna geen bomen, geen dorp; kerk alleen. Plan: boomgaarden, populieren, bosjes op de
toppen, akkers in stroken, mergelgroeve, kasteel, vakwerkboerderijen, dorp rond de kerk, vangrail + pijlborden in de
haarspelden, verf op de klim (Cauberg), wegkruis, publiek.

## Rotterdam — TE DOEN
Gezien: grote grijze vlakte met losse torens, niets langs de weg. Plan: bebouwing langs de weg, herkenbare torens
(De Rotterdam, kubuswoningen, Euromast beter), havenkranen, schepen (één varend), tram, neon/lichtreclame 's nachts.

## Zeeland — TE DOEN
Gezien: zand bijna wit en leeg, felgroene berm, rechte eilandranden, lege zee. Plan: zandkleur, duinen en helmgras,
paalhoofden, strandpaviljoens, windturbines op zee (draaiend), schepen, vliegers, dorpje, reflectoren.

## Indelingsvoorstellen (niet uitgevoerd; baanvorm blijft)
- (nog geen)

## Voor de bugjacht
- (aanvullen)
