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

## Wat zwak is in het uitgangsbeeld
(nog invullen na het bekijken van de contactvellen)

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
- [x] gereedschap, uitgangsbeelden (270)
- [ ] perf_render-uitgangsmeting (`tests/.out/beeld/perf_base.json`)
