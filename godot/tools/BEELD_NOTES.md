# Beeld-agent: werknotities (overleven een onderbreking)

Tijdelijk bestand van de Beeld-agent (fase 2). De hoofdagent mag het na het samenvoegen weghalen.

## Gereedschap
- `godot/tools/beeld.sh <scene> args...` draait een tool-scene onder xvfb met eigen savemap; log in `tests/.out/beeld/<scene>.log`.
  **Kijk altijd in de log**: een parse-fout laat de scene eindeloos stilstaan (zo ging de eerste poging 15 min verloren).
- `tools/shot_beeld.tscn`: echte spelscene, race met bots, speler op punten langs de ronde, elke tijd x weer.
  Alle 10 banen x 9 combinaties x 3 punten = 270 beelden in ~10 min.
- `tools/sheet_beeld.py <map> [<map2>]`: contactvellen (met twee mappen: voor | na). Draai met `/usr/bin/python3`
  (de `python3` op PATH vindt een kapotte PIL).
- `tools/exp_beeld.tscn`: renderer-experimenten (zie Metingen).
- Uitgangsbeelden: `godot/tests/.out/beeld/base/` (+ `sheet_<baan>.jpg`). Niet in git (tests/.out staat in .gitignore).

## Metingen (Compatibility-renderer, Godot 4.7.2, llvmpipe)
- Screen-space AA (FXAA/SMAA) en TAA: **niet beschikbaar** in Compatibility (waarschuwing). Alleen MSAA 2x/4x/8x.
- `Environment.glow_enabled` en `adjustment_enabled` werken en laten LMat-kleuren vrijwel gelijk
  (vloer 0.6431/0.8824/0.3137 -> 0.6431/0.8784/0.3137; donker kanaal van de doos 0.0745 -> 0.0549). Bruikbaar voor "hoog".
- Tekenaanroepen (viewport render info, VISIBLE): 10 dozen die schaduw werpen kosten +20 (2 splits schaduwpas wordt
  bij VISIBLE geteld). Shaded / shadows_disabled / unshaded geeft hetzelfde aantal: de additieve lichtpas is in deze
  teller niet te zien. Nog te meten met frametijd (software-render = evenredig met fragmentwerk).

- **Skybox**: `POSITION = vec4(p.xy, -p.w * 0.99999, p.w)` is het verre vlak in Compatibility (diepte is omgekeerd
  binnen OpenGL-clipruimte: z = +w is dichtbij, 0 ook nog voor alles). Gemeten met drie pogingen.
- Uitgangsmeting tekenaanroepen (hoog, dag, 7 bots, spiegel aan; `tests/.out/beeld/perf_base.log`): polder 553 (+373 spiegel),
  dorp 442, circuit 572, afsluitdijk 518, haven 484, veluwe 572 (+262), grachten 438, limburg 424, rotterdam 471, zeeland 468;
  laag ~100 minder (schaduwpas); split 775-1214. Hiervan zijn 34 wolk-sprites, ~40 vogels en tot 90 rook-sprites elk een
  eigen aanroep. De teller toont de additieve lichtpas niet (prims gelijk bij hoog en laag).

## Wat zwak is in het uitgangsbeeld
- Lucht: vlak verloop, cartoon-wolken als sprites met harde rand, geen zongloed, zon als sprite; 's nachts losse punten.
- Water: egaal donker vlak met harde horizon, geen beweging of spiegeling.
- Nacht: koplamp van de speler verlicht nauwelijks iets, auto's zijn zwarte vlekken, geen gloed op lampen; nacht + regen is bijna zwart.
- Regen: dunne witte lijntjes van 1 pixel (in de spiegel juist fel), weg alleen 30% donkerder, geen glans.
- Geen schaduw onder auto's op "laag"; rook is wit en lichtgevend in het donker; remsporen blijven eeuwig even zwart.
- Mist/haze: een kleur, geen gloed aan de zonkant.

## Plan (volgorde)
1. Lucht: shader-koepel (verloop, horizonnevel, zonneschijf + gloed, maan, wolkenlaag uit ruis, bewolkt bij regen),
   sterren die twinkelen. Mistkleur volgt de lucht, met zongloed aan de zonkant.
2. LMat: per-pixel licht, nieuwe globals (pr_sky, pr_glow, pr_wet, pr_wind, pr_head*), koplamp in de shader,
   nat wegdek (variant WET op World.roadMats), water (Mats.water + herkenning van de bestaande water-phongs), wuiven (sway).
3. Schaduwen: zachte rand, afstand, bias; blob-schaduw onder auto's.
4. Regen als GPU-strepen; rook/stof/vonken als een MultiMesh; remsporen die vervagen; gloed-sprites op lantaarns en autolampen.
5. Kwaliteitsniveaus laag/middel/hoog; vignette/kleurtint per tijd.
6. Kosten meten (perf, perf_render), memory, alle tests, merge, eindverslag.

## Voortgang
- [x] gereedschap, uitgangsbeelden (270), perf-uitgangsmeting
- [x] lucht-shader (verloop, zon/maan + gloed, wolkenlaag, sterren, skybox), mist met zongloed (pr_glow)
- [x] LMat v2: per pixel, onbelicht ("unshaded") voor alles wat geen schaduw ontvangt, water (Mats.water + herkenning),
      nat wegdek (LMat.wet via World.roadMats), koplamp-globals pr_head0/1, glans op phong, sway (optie, nog nergens gebruikt)
- [x] regen (GPU-strepen), vogels (1 mesh per zwerm), gloed op lantaarns (via World.lampMats), lichtpoelen
- [x] fx: rook/stof/vonken/uitlaatvlam als 1 MultiMesh, remsporen vervagen, CarFx per auto (gloed, natte streep, schaduwvlek)
- [x] kwaliteit: Env.set_quality / Fx.set_quality / Game.applyPrefs (MSAA 4x op hoog)
- [ ] fx_overlay: vignet/kleurtint, blur per kwaliteit
- [ ] sway toepassen in dress.gd (riet, gras, bloemen, struiken, vlaggen)
- [ ] tijdmeting unshaded vs shaded (exp_beeld), perf na, memory, alle banen bekijken (ook rev, split, laag/middel)
- [ ] grachten/dorp/polder water bekijken; koplampkegel breder; regen iets dichter
- [ ] merge main (f697bff of later), tests, eindverslag
- Buiten eigen bestanden gewijzigd: project.godot (shader_globals), game.gd (applyPrefs), tests/test_memory.gd (deeltjespool)
