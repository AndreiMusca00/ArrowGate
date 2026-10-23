# Workflow permanent pentru niveluri Pictarrow

Actualizat: 23 octombrie 2026. Ghid principal pentru autor și pentru viitoarele sesiuni de lucru cu un asistent. Se păstrează în Git împreună cu scripturile, profilele și exemplele. Nu depinde de istoricul conversației sau de un skill instalat pe un anumit calculator.

## 1. Ce stabilim înainte de un lot

Notăm în manifestul lotului: campanie/event, tema, numărul de niveluri, ID-urile, profilul de dificultate, imaginile și recompensa finală. Pentru events notăm perioada, fusul orar, accesul temporar pentru test și modul de deblocare.

Cererea explicită a utilizatorului are prioritate. O modificare pentru un singur nivel sau event este o excepție locală, nu o schimbare implicită a întregii campanii.

## 2. Reguli permanente

- Tabla urmărește silueta obiectului din imagine, cu proporții păstrate. Nu umplem automat un dreptunghi în jurul obiectului.
- Săgețile au minimum 3 celule, inclusiv vârful. Fără săgeți formate doar din vârf.
- Fără suprapuneri între corpuri; fiecare celulă activă aparține unei săgeți. Orice eliminare de insule mici din mască se consemnează și se verifică vizual.
- Nivelul trebuie să aibă o soluție completă verificată prin regulile jocului.
- Culorile vin din imagine: RGB opac, contrast de minimum 4.5:1 față de alb. O cerere de recolorare păstrează toate coordonatele, direcțiile și lungimile.
- Fără timer în loturile noi, dacă nu este cerut explicit. Generatorul are încă valori implicite istorice pentru timer: pune `timeLimit: 0` în fiecare override și verifică JSON-ul rezultat.
- Nu schimbăm ID-uri deja publicate și nu suprascriem alte niveluri la publicarea unui lot.
- Camera, zoom-ul și prezentarea Journey sunt comportamente UI separate; nu le modificăm automat când generăm conținut.
- Niciun lot nou nu se publică în Firebase înainte de aprobarea lui în Local Preview. Fișierele candidate rămân în directorul lotului, separat de catalogul canonic.

## 3. Repere de dificultate

Pentru un capitol de 25: 13 buffer, 6 hard, 4 veryHard, 2 nightmare. Buffer este un termen de design, nu o valoare JSON: folosim `easy` sau profilul introductiv. Primele 50 de niveluri trebuie să ofere o intrare mai accesibilă; reglajul final se confirmă prin joacă. Pentru capitolul 1, nivelul 1 pornește orientativ la 8–10 săgeți, iar bugetele cresc gradual. Valorile mari din tabel sunt repere pentru capitole mature, nu pentru introducerea jocului.

| Tip | Săgeți orientative | Latura lungă a grilei, profil de bază |
| --- | ---: | ---: |
| Intro / buffer | 50 | 16–24; primele patru: 16, 18, 20, 22 |
| Hard | 75 | 30 |
| Very hard (`veryHard`) | 100 | 40 |
| Nightmare | 150 | 50 |

Acestea sunt repere ajustabile, nu garanții de dificultate. Profilele de capitol pot avea alte dimensiuni. Verifică `Scripts/point_shape_profiles*.json` și override-urile lotului.

Dificultatea se evaluează prin numărul de săgeți libere inițial, straturile de deblocare, distribuția opțiunilor pe parcurs și lizibilitate. Un strat reprezintă un val de săgeți care pot fi eliminate înainte de următoarele deblocări; nu măsoară direct timpul sau dificultatea percepută. Obiectivul discutat de 1–2 minute se validează prin sesiuni de joc, nu se promite pe baza raportului.

Exemple de comparație:

- Campanie, nivelul 25: 150 de săgeți, reper pentru provocări grele. Citește JSON-ul și rapoartele disponibile înainte de comparație.
- Nivelul 100: excepție de final, 250 de săgeți; nu este bugetul implicit pentru nightmare.
- Halloween 2026: 30 de niveluri nightmare, fiecare 150 de săgeți, 29–56 straturi și maximum 29 săgeți libere inițial. Vezi `Design/ArrowTrialHalloween2026/report.json`.
- Primele 100 de niveluri au temă forest. Tema capitolelor următoare se decide separat.

## 4. Etapele de producție

### A. Artwork

Creăm imaginea finală și obiectele individuale recognoscibile. Un capitol existent are 24 de piese și imaginea completă la nivelul 25. Un event poate avea altă structură; Halloween are 30 de piese și o recompensă completă separată.

Folosim transparență reală și păstrăm sursele și prompturile. Piesele sunt obiecte semantice, nu fragmente dreptunghiulare din tablou. La extragere din atlas verificăm componentele conectate de alpha și evităm tăierea obiectelor vecine. Inspectăm contururile și asset-urile pe fundal deschis.

Publicăm asset-urile sursă în `Backend/ContentSource/Artwork`, în `.imageset` cu `Contents.json` corect. Acest director nu intră în targetul aplicației. Păstrăm pozițiile de assembly acolo unde capitolul le folosește. Scripturile `prepare_*` sunt specifice temelor existente: citește-le înainte de reutilizare, pot suprascrie asset-uri sau scaffolds.

### B. Puncte și săgeți

Pregătim un JSON de lucru cu `levels`, fiecare având ID, `completionArtwork` și metadata necesară, plus un profil cu `chapterPlan` de aceeași lungime. Schema unui nivel se ia dintr-un exemplu real; nu inventăm câmpuri.

Inspectăm întâi siluetele în puncte. Apoi generăm săgețile, încercăm mai multe variante și verificăm rapoartele. Generatorul de săgeți extrage el însuși masca din artwork: nu consumă direct JSON-urile produse de etapa de previzualizare în puncte.

Parametri importanți în profil: `gridSizes`, `introGridSizes`, `chapterPlan`, `arrowCounts`; pentru fiecare ID, `levelOverrides` poate seta `gridSize`, `arrowCount`, `timeLimit`, `candidateCount`, `tuningPasses`, `depthWeight`, `freeWeight`, `minimumDependencyLayers`, `maximumInitiallyFree`.

Pragurile de straturi și săgeți libere influențează selecția candidaților, dar nu sunt o garanție că generatorul le atinge. Verificăm explicit raportul final. Dacă o siluetă subțire produce prea multe ieșiri, ajustăm rezoluția, candidații sau artwork-ul, apoi regenerăm numai nivelurile afectate.

Generatorul de săgeți folosește primele patru valori `introGridSizes` pentru primele patru poziții dacă nu există override, inclusiv într-un lot special. Pentru events foarte grele punem override explicit la toate nivelurile. La o submulțime de regenerat, păstrăm ID-urile și facem un profil de aceeași lungime cu submulțimea.

### C. Culori

Mapăm culorile după aprobarea geometriei. Scriptul verifică faptul că toate câmpurile în afară de culori rămân identice. Verificăm și imaginile de preview; o paletă validă numeric poate totuși necesita reglaje vizuale.

### D. Publicare și joc

Campanie: `Backend/ContentSource/Levels/chapter-XX.json`; index: `catalog.json`. Event: `event-*.json`, cu `event` și lista `levels` de obiecte `{day, date, level}`. Generatorul lucrează cu lista simplă de niveluri, deci pentru event folosim un scaffold intermediar și împachetăm ulterior rezultatul.

Fișierele din `Backend/ContentSource/Levels` sunt surse de publicare și fixtures pentru testele Swift Package și se află în afara surselor aplicației iOS. Nici JSON-urile de campanie/event, nici artwork-ul lor nu se livrează în `.app`. La prima instalare aplicația cere internet, descarcă și validează conținutul necesar, apoi poate folosi cache-ul validat offline.

Păstrăm ID-uri unice în întreg catalogul, adăugăm fișierul în index și incrementăm versiunea la publicarea conținutului. Formatăm doar fișierele atinse. Comparăm capitolele care trebuiau să rămână neschimbate.

Distribuția către aplicație folosește Firebase Storage: un catalog principal mic și versionat la `catalog/catalog.json`, câte un pachet JSON separat pentru fiecare capitol și event și asset-urile aferente în directoare versionate, imuabile. La fiecare pornire aplicația verifică indexul și păstrează complet capitolul curent plus următoarele două, fără prag intermediar de nivel. Pentru capitolele anterioare păstrează JSON-ul, iar pentru cele completate și recompensa finală; piesele de gameplay pot fi șterse. Eventurile se descarcă de la `previewStartsAt` și urmează intervalul lor propriu. Player progress rămâne numai local.

Generează structura de upload cu `Backend/Firebase/prepare_content.py`, verifică raportul și încarcă mai întâi toate pachetele. `catalog/catalog.json` se publică ultimul, astfel încât nicio aplicație să nu primească referințe către fișiere încă inexistente. Orice schimbare într-un pachet publicat primește un nou director `vN`; nu suprascriem versiunea veche.

Events, regula actuală: primul nivel este disponibil, apoi se deblochează succesiv. Poza piesei apare numai după completarea nivelului. Imaginea finală din calendar apare numai după completarea tuturor nivelurilor. Progresul este separat de campanie și rejucarea nu adaugă încă o completare. Nu se impune așteptarea zilei calendaristice pentru fiecare nivel.

Halloween păstrează perioada reală din noiembrie; câmpul opțional `testingStartsAt` permite acces mai devreme. Se scoate când se încheie verificarea. Nu lăsăm accidental această excepție în versiunea destinată lansării.

## 5. Comenzi verificate și lucru într-o copie

Din rădăcina proiectului. Python necesită Pillow, NumPy și SciPy; verifică importurile scripturilor și mediul disponibil. Comenzile următoare folosesc capitolul 1 drept exemplu într-o copie, fără a publica peste campanie:

```sh
mkdir -p Design/LevelGeneration/Working
cp Backend/ContentSource/Levels/chapter-01.json Design/LevelGeneration/Working/chapter.json
cp Scripts/point_shape_profiles.json Design/LevelGeneration/Working/profile.json
```

Înainte de generare, setează `levelOverrides` pentru fiecare ID din copia profilului, inclusiv `timeLimit: 0`. Pentru un lot nou, înlocuiește copia capitolului cu scaffold-ul nou și adaptează planul, ID-urile și asset-urile.

```sh
python3 Scripts/generate_point_shapes.py --chapter Design/LevelGeneration/Working/chapter.json --profiles Design/LevelGeneration/Working/profile.json --use-plan --output Design/LevelGeneration/Working/Points
python3 Scripts/generate_arrow_trial.py --chapter Design/LevelGeneration/Working/chapter.json --profiles Design/LevelGeneration/Working/profile.json --output Design/LevelGeneration/Working/Arrows --publish
python3 Scripts/map_arrow_colours.py --chapter Design/LevelGeneration/Working/chapter.json --output Design/LevelGeneration/Working/Colours --publish
```

`--publish` de mai sus modifică doar copia de lucru. Fără el, rezultatul este scris în directorul de output, iar intrarea rămâne neschimbată. Nu copia rezultatul peste catalog până nu ai verificat rapoartele și preview-urile.

Pentru verificarea în joc, legătura `Design/LevelGeneration/LocalPreview` indică `PreviewSource` al lotului curent. Selectează schema Xcode `Pictarrow Local Preview`; build-ul Debug împachetează automat candidatul în aplicația de test, folosește un cache și un progres separat și nu contactează Firebase. Funcționează identic pe simulator și pe iPhone. Build-ul Release nu include pachetul de preview.

Exemple de verificare după integrare:

```sh
python3 Design/Campaign/format_catalog.py Backend/ContentSource/Levels/catalog.json Backend/ContentSource/Levels/event-halloween-2026.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/ArrowGateRulesVerification
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Pictarrow.xcodeproj -scheme Pictarrow -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -derivedDataPath /tmp/ArrowGateBuild CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Înlocuiește lista formatterului cu fișierele efectiv modificate; rularea lui fără argumente poate reformata și alte capitole. Simulatorul și versiunea OS se adaptează celor instalate. `Scripts/verify.sh` rulează și suita UI completă; unele teste istorice au așteptări legate de artwork, date sau campanie și trebuie revizuite când produsul se schimbă. Nu elimina verificări valide doar pentru a obține verde.

## 6. Criterii înainte de livrare

- Asset-uri prezente, alpha corect, siluete recognoscibile și assembly corect unde este cazul.
- ID-uri unice, număr de niveluri și distribuție conform cererii, JSON valid și încărcabil.
- Toate nivelurile rezolvabile, minimum 3 celule pe săgeată, fără suprapuneri și cu acoperire completă a măștii finale.
- Bugetul de săgeți, timerul și pragurile de dificultate verificate în rezultat, nu doar în profil.
- Culori opace cu contrast valid; geometria păstrată la recolorare.
- În joc: deschidere, zoom/pan, completare, recompensă, salvare/reîncărcare și rejucare. Pentru events verificăm și blocarea succesivă, ascunderea imaginilor și datele de acces.
- Fișierele din afara lotului neschimbate. Menționăm testele rulate și ce nu a fost verificat prin joacă.

## 7. Ce arhivăm pentru fiecare lot

Folosește `BATCH-TEMPLATE.md`: păstrează sursele și prompturile, profilul exact, scaffold-ul, JSON-ul final, rapoartele de geometrie/soluție/culori, preview-urile, excepțiile și rezultatele testelor. Nu tratăm cache-urile sau memoria conversației ca backup. Pentru backup pe termen lung, utilizatorul păstrează repository-ul într-un remote ori într-o copie externă; documentația locală nu creează singură acel backup.

La schimbarea unei reguli permanente actualizăm acest ghid și testele relevante. La o excepție locală actualizăm numai manifestul lotului. Exemplu complet: `Design/Events/Halloween2026/README.md` și `imagegen-prompts.json`.
