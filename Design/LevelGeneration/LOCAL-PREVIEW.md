# Local Preview pentru niveluri nepublicate

Acest mod există pentru aprobarea fiecărui lot înainte de Firebase.

## Cum îl rulezi

1. Deschide `Pictarrow.xcodeproj` în Xcode.
2. Din lista de scheme alege `Pictarrow Local Preview`.
3. Alege simulatorul sau iPhone-ul și apasă Run.
4. Pe Home trebuie să apară eticheta portocalie `LOCAL LEVEL PREVIEW`.
5. Apasă `TEST LEVELS` și alege oricare dintre cele 25 de niveluri. Le poți deschide direct, indiferent de progresul salvat.

Aplicația citește nivelurile din `Design/LevelGeneration/LocalPreview`. Nu contactează Firebase, iar progresul și baza de date sunt separate de aplicația normală.

Schema obișnuită `Pictarrow` continuă să folosească Firebase. Build-ul Release nu include nivelurile de preview.

## Schimbarea lotului verificat

`Design/LevelGeneration/LocalPreview` indică directorul `PreviewSource` al lotului activ. La pregătirea unui lot nou, actualizează această legătură numai după ce acel lot a trecut validările automate. Fiecare lot rămâne arhivat separat în `Design/LevelGeneration/Batches`.

Un lot poate fi copiat în catalogul canonic și publicat numai după aprobarea explicită în urma testării prin joacă.
