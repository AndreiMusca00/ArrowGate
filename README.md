# Arrow Gate

Joc pentru iPhone, în SwiftUI și SpriteKit. Prototipul conține un capitol local cu 25 de niveluri.

## Rulare

Deschide `ArrowGate.xcodeproj` în Xcode, selectează schema `ArrowGate` și un simulator sau iPhone, apoi Run.
Pentru telefon, configurează echipa de semnare în Signing & Capabilities.

## Structură

| Componentă | Rol |
|---|---|
| `ArrowGate/ArrowGateApp.swift`, `AppState.swift` | Pornire, meniu și deschiderea nivelului |
| `ArrowGate/Views/` | Ecranele principale ale aplicației |
| `ArrowGate/Views/Components/` | Componente independente pentru niveluri, capitole, Journey și navigație |
| `ArrowGate/GameScene.swift` | Tabla, desenarea săgeților, animații, porți și gesturi |
| `ArrowGate/GameViewModel.swift` | Partidă, vieți, timer, pauză, hint și rezultat |
| `ArrowGate/Models/` | Definiția nivelului, reguli, geometrie și încărcarea campaniei |
| `ArrowGate/Levels/catalog.json` | Catalogul versionat cu toate capitolele și nivelurile incluse |
| `ArrowGate/Services/LocalDatabase.swift` | Core Data: niveluri, nivel deblocat și cei mai buni timpi |
| `ArrowGate/Services/ProgressStore.swift` | Progres și preferințe |
| `ArrowGate/Services/AudioHapticsManager.swift` | Sunet și feedback haptic |
| `Tests/`, `ArrowGateUITests/` | Verificări pentru reguli, salvare și joc |

UI-ul folosește fundal alb cald, puncte de ghidaj și săgeți subțiri.
Nivelul apare întâi complet, apoi camera se apropie de centru. Tabla se poate deplasa și mări,
cu limite controlate de joc. Tutorialul nu are limită de timp.

Catalogul declară momentan un singur capitol de 25 de niveluri. Culorile, decorațiile și
dimensiunile vizuale vin din câmpul `style`. Stările și animațiile nodurilor de nivel sunt
definite central în Swift, în `LevelComponents.swift`. Structura rămâne pregătită pentru
adăugarea ulterioară a altor capitole din catalog.

## Salvare locală

Nivelurile din JSON sunt copiate în Core Data și rămân disponibile offline.
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
