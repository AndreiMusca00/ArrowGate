# Lot: Chapter 01 Accessible V1

- Data: 23 octombrie 2026
- Tip: campanie, publicat după verificare în Local Preview
- Tema și recompensa: The Enchanted Treehouse / EnchantedTreeComplete
- Număr de niveluri și ID-uri: 25, ID 1–25 păstrate
- Destinație: `Backend/ContentSource/Levels/chapter-01.json`; Firebase `chapter-1/v2`, catalog 17
- Distribuție: 16 tutorial/easy, 6 hard, 2 veryHard, 1 nightmare
- Bugete: 8, 10, 12, 14, apoi creștere graduală până la 55; toate timerele sunt 0
- Artwork: asset-urile existente EnchantedTreePiece01–24 și EnchantedTreeComplete
- Excepție aprobată: capitol introductiv mai ușor decât reperele mature din workflow

## Fișiere și reproducere

- `Source/chapter-01.json`: copia catalogului existent înainte de regenerare
- `profile.json`: profilul exact al lotului
- `Points/`: siluete și overview pentru verificarea formei
- `Arrows/`: geometria monocromă, raportul și preview-urile
- `Colours/`: culorile mapate din artwork și raportul de contrast
- `PreviewSource/`: catalogul candidat folosit exclusiv de Local Preview

```sh
python3 Scripts/generate_point_shapes.py \
  --chapter Design/LevelGeneration/Batches/Chapter01AccessibleV1/Source/chapter-01.json \
  --profiles Design/LevelGeneration/Batches/Chapter01AccessibleV1/profile.json \
  --use-plan \
  --output Design/LevelGeneration/Batches/Chapter01AccessibleV1/Points

python3 Scripts/generate_arrow_trial.py \
  --chapter Design/LevelGeneration/Batches/Chapter01AccessibleV1/Source/chapter-01.json \
  --profiles Design/LevelGeneration/Batches/Chapter01AccessibleV1/profile.json \
  --output Design/LevelGeneration/Batches/Chapter01AccessibleV1/Arrows \
  --publish

python3 Scripts/map_arrow_colours.py \
  --chapter Design/LevelGeneration/Batches/Chapter01AccessibleV1/Source/chapter-01.json \
  --output Design/LevelGeneration/Batches/Chapter01AccessibleV1/Colours \
  --publish
```

După generare, `Source/chapter-01.json` se copiază în `PreviewSource/chapter-01.json`. Această copiere publică numai în preview-ul local, nu în catalogul canonic.

## Aprobare

- Status: aprobat explicit și publicat în Firebase la 23 octombrie 2026
- Verificări automate: 25/25 niveluri rezolvabile; minimum 3 celule pe săgeată; fără suprapuneri; acoperire completă; culorile țintă sunt realizabile; contrast minimum 4.5:1; ID-urile 1–25 păstrate; catalogul canonic a rămas neschimbat
- Integrare: schema `Pictarrow Local Preview` compilează și încarcă 25 de niveluri din pachetul Debug; Level 1 are 8 săgeți, Level 25 are 55
- Izolare: build-ul Release compilează fără `LocalPreviewContent`; progresul preview-ului folosește stocare separată
- Regresie: 33 teste rulate, 0 erori; testul candidat separat a trecut 1/1
- Testare prin joacă: lotul rămâne disponibil în Local Preview pentru reglaje ulterioare ale dificultății percepute
- Firebase: 26 de obiecte imuabile încărcate în `chapters/chapter-1/v2`; catalogul 17 publicat ultimul
