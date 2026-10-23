# Pictarrow

## Generare de niveluri

Procesul permanent este în [Design/LevelGeneration/WORKFLOW.md](Design/LevelGeneration/WORKFLOW.md): reguli, dificultate, artwork, comenzi, publicare și validare. Pentru fiecare lot folosim [șablonul de evidență](Design/LevelGeneration/BATCH-TEMPLATE.md). [AGENTS.md](AGENTS.md) indică acest ghid viitoarelor sesiuni de lucru cu un asistent.

Secțiunile de mai jos includ descrieri istorice ale prototipului; pentru producția de conținut folosește workflow-ul de mai sus și catalogul actual.

Joc pentru iPhone, în SwiftUI și SpriteKit. Campania și eventurile sunt livrate din Firebase Storage.

## Rulare

Deschide `Pictarrow.xcodeproj` în Xcode, selectează schema `Pictarrow` și un simulator sau iPhone, apoi Run.
Pentru telefon, configurează echipa de semnare în Signing & Capabilities.

### Conținut remote

O instalare nouă are nevoie de internet pentru prima descărcare. După validare,
aplicația folosește cache-ul local și poate porni offline. Variabila Debug
`PICTARROW_LOCAL_ONLY=1` oprește Firebase doar pentru verificarea ecranului de
eroare/retry; nu mai există o campanie inclusă în aplicație.

## Structură

| Componentă | Rol |
|---|---|
| `ArrowGate/ArrowGateApp.swift`, `AppState.swift` | Pornire, meniu și deschiderea nivelului |
| `ArrowGate/Views/` | Ecranele principale ale aplicației |
| `ArrowGate/Views/Components/` | Componente independente pentru niveluri, capitole, Journey și navigație |
| `ArrowGate/GameScene.swift` | Tabla, desenarea săgeților, animații, porți și gesturi |
| `ArrowGate/GameViewModel.swift` | Partidă, vieți, timer, pauză, hint și rezultat |
| `ArrowGate/Models/` | Definiția nivelului, reguli, geometrie și încărcarea campaniei |
| `Backend/ContentSource/Levels/` | Sursele JSON pentru publicare și fixtures de test; în afara aplicației iOS |
| `Backend/ContentSource/Artwork/` | Sursele imaginilor de conținut; excluse din aplicația iOS |
| `Backend/Firebase/` | Pregătirea și publicarea pachetelor remote |
| `ArrowGate/Services/LocalDatabase.swift` | Core Data: niveluri, nivel deblocat și cei mai buni timpi |
| `ArrowGate/Services/ProgressStore.swift` | Progres și preferințe |
| `ArrowGate/Services/AudioHapticsManager.swift` | Sunet și feedback haptic |
| `Tests/`, `ArrowGateUITests/` | Verificări pentru reguli, salvare și joc |

UI-ul folosește fundal alb cald, puncte de ghidaj și săgeți subțiri.
Nivelul apare întâi complet, apoi camera se apropie de centru. Tabla se poate deplasa și mări,
cu limite controlate de joc. Tutorialul nu are limită de timp.

Fiecare capitol publicat declară 25 de niveluri. Culorile, decorațiile și dimensiunile
vizuale vin din câmpul `style`. Stările și animațiile nodurilor de nivel sunt definite
central în Swift, în `LevelComponents.swift`.

## Salvare locală

Nivelurile descărcate și validate sunt copiate în Core Data și rămân disponibile offline.
Core Data păstrează progresul campaniei și cei mai buni timpi.
Sunetul și vibrațiile sunt salvate în UserDefaults.
Reset Progress resetează progresul și recordurile, păstrând nivelurile și preferințele.

Progresul versiunii anterioare este importat o singură dată, fără a păstra vechiul model de date.
Baza locală curentă este `Application Support/ArrowGateLocal.sqlite`.

## Verificare

`Scripts/verify.sh` rulează testele de reguli și salvare, apoi testele din simulator.
Rezultatele și capturile sunt scrise într-un director temporar, în afara proiectului.
Testele folosesc o bază și preferințe separate de cele ale jucătorului.

## Version control

`.gitignore` exclude fișierele personale Xcode, cache-urile, buildurile și rezultatele testelor.
Generatorul local din `Design/Campaign` reproduce exact catalogul și asset-urile capitolului curent.
