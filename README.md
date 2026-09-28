# Polderrace 3D

Arcade-racegame in de browser: 10 Nederlandse banen, kampioenschap, carrière, garage, 2 spelers en online.
Het hele spel zit in **`polderrace-3d.html`**. Zolang we in de HTML-fase zitten, levert Claude Code elke
wijziging op als een nieuwe versie van dit ene bestand (zoals in de chat); pas als jij erom vraagt, wordt er een echt spel van gemaakt. Open het in Chrome om te spelen. Online spelen
kan overal via "Spelen via host" (uitnodigingscodes, rechtstreeks tussen de browsers); de lobby met open games werkt
alleen via de artifact-link op claude.ai.

## Wat zit er in deze map?

| Bestand | Waarvoor |
|---|---|
| `polderrace-3d.html` | het spel |
| `CLAUDE.md` | uitleg over het spel voor Claude Code: afspraken, opbouw van de code, valkuilen, welke test bij welke wijziging |
| `PROMPT-bugfixes.md` | de prompt met de openstaande bugs; plak die in Claude Code |
| `.claude/agents/qa-reviewer.md` | de controle-agent: controleert elk stuk werk los van de bouwer (tests, screenshots, diff) |
| `.claude/settings.json` | de automatische Stop-hook: Claude kan pas afronden na de snelle test + goedkeuring van de qa-reviewer |
| `.claude/commands/` | `/qa` (laat de reviewer nu kijken) en `/testall` (volledige testsuite) |
| `tests/` | alle testscripts (Python + Playwright), zie hieronder |

## Eenmalig installeren (Windows, macOS of Linux)

1. Installeer **Python 3.10+** (Windows: vink "Add python.exe to PATH" aan), **Node.js** (LTS) en **Git**.
2. Open een terminal in deze map en voer uit:
   ```
   pip install -r requirements-dev.txt
   python -m playwright install chromium
   npm install
   ```
3. Zet de map in Git (en eventueel op GitHub, privé):
   ```
   git init
   git add .
   git commit -m "Polderrace 3D: startpunt met tests en QA-agent"
   ```
4. Controleer of alles werkt: `python tests/quick_check.py` → alles `OK`.
5. Start Claude Code in deze map (`claude`) en plak de inhoud van `PROMPT-bugfixes.md`.

## Zo werkt de controle

```
jij ──prompt──▶ Claude Code bouwt de fix
                   │  (wil afronden)
                   ▼
         Stop-hook: snelle test (±1 min) ──FOUT──▶ terug naar Claude Code
                   │ OK
                   ▼
         qa-reviewer agent: diff lezen, gerichte tests, screenshots bekijken
                   │ AFGEKEURD ─────────────▶ terug naar Claude Code
                   │ GOEDGEKEURD (hash in tests/reviewed.txt)
                   ▼
         Claude Code rondt af en vertelt wat er veranderd is
```

De hook laat Claude na 4 mislukte pogingen op dezelfde versie toch stoppen (en zegt dat eerlijk), zodat hij nooit
blijft hangen. Je kunt de reviewer ook zelf aanroepen met `/qa`.

## Tests

| Commando | Wat | Duur* |
|---|---|---|
| `python tests/quick_check.py` | statisch + laden + race tot podium + alle menu's | 1 min |
| `python tests/test_road_clear.py [banen] [--rev]` | niets op/over de weg (balken, duinen, poten) | 3–8 min |
| `python tests/test_zfight.py [banen\|none] [--no-cars]` | flikkerende vlakken op banen, garage, podium, auto's | 3 min |
| `python tests/test_regression.py [banen] [modi] [richtingen]` | elke baan × modus tot de uitslag | 10 min |
| `python tests/test_layout.py` | menu's op 6 schermformaten | 3 min |
| `python tests/test_collisions.py` | botsingen: tikje vs. PIT | 1 min |
| `python tests/test_camera_terrain.py` | camera nooit in de heuvels (ook 2 spelers) | 3 min |
| `python tests/test_championship.py` | heel kampioenschap + Polder Cup via echte klikken | 8 min |
| `python tests/test_multiplayer.py` | online met 3 spelers (gesimuleerd) | 2 min |
| `python tests/test_p2p.py` | online via host: 3 spelers met echte WebRTC en uitnodigingscodes | 2 min |
| `python tests/test_memory.py` | geen geheugenlekken | 3 min |
| `python tests/screenshots.py [banen]` | screenshots om zelf te bekijken → `tests/.out/screens/` | 3 min |
| `python tests/run_all.py [--fast]` | alles (parallel), met samenvatting | 30 min (fast: 10) |

\* op een gewone laptop; de tests tekenen zonder videokaart.

Visuele bugs vind jij het best door te spelen: stuur een screenshot + baan + ongeveer waar, dan maakt Claude Code
er een fix én (waar het kan) een test van, zodat de bug nooit terugkomt.

## Publiceren

Plak `polderrace-3d.html` in een claude.ai-chat en vraag om te publiceren naar
`https://claude.ai/artifact/Pe2uUr4oTeTjyDygDkzUgx` met capabilities `downloads` en `room`.
Doe dat alleen met een versie die de qa-reviewer heeft goedgekeurd.
