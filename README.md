# Desetiprstka ⌨️

Česká aplikace pro Mac, která tě naučí psát všemi deseti. Nativní Swift + SwiftUI + SwiftData, bez backendu, data zůstávají v Macu.

🌐 Web → [desetiprstka.cz](https://desetiprstka.cz) · 𝕏 → [@fandasobased](https://x.com/fandasobased)

- Lekce od základní řady (F a J) po číslice a speciální znaky
- Zkouška se známkou 1–5 jako ve škole (čisté úhozy za minutu, % chyb)
- Test rychlosti v WPM, CPM i úhozech za minutu
- Vlastní text, rytmus a metronom, zvuky skutečných kláves, 7 témat
- Hodnosti a odemykání vzhledu za XP
- Záloha a obnova celého progresu do jednoho souboru (Nastavení → Obecné → Data)

## ⬇️ Stažení
- Nejnovější `.dmg` → záložka **Releases** vpravo
- Otevři `.dmg` → přetáhni **Desetiprstka** do složky **Aplikace**
- Požadavky → macOS 14 Sonoma nebo novější (Apple Silicon i Intel)

### ⚠️ První spuštění
Aplikace zatím není notarizovaná Applem, takže ji macOS napoprvé zablokuje.
- Zkus Desetiprstku otevřít → zobrazí se varování → **Hotovo**
- **Nastavení systému → Soukromí a zabezpečení** → dole u Desetiprstky **Přesto otevřít**
- Potvrď heslem → od teď se otevírá normálně
- Alternativa pro Terminál → `xattr -dr com.apple.quarantine /Applications/Desetiprstka.app`

## 🛠️ Build ze zdrojáků
- Požadavky → Xcode 16 nebo novější (ne beta)
- Otevři `Desetiprstka.xcodeproj` → schéma `Desetiprstka` → **Run** (⌘R)
- `build.command` → Debug build z Terminálu, log v `build.log`
- `release.command` → Release build (arm64 + x86_64) a `dist/Desetiprstka-<verze>.dmg`, log v `release.log`

## 🧱 Architektura
```
Desetiprstka/
├── App/                 vstupní bod, navigace (AppState), kořenové view
├── Models/              SwiftData entity
│   ├── UserProfile, PracticeSession, LetterStat      (v1)
│   └── PlayerProgress, PersonalRecord, AchievementRecord, DailyChallengeRecord (v2)
├── Domain/              čistá logika – žádné UI, žádná databáze
│   ├── Keyboard/        rozložení klávesnice, prsty
│   ├── Curriculum/      osnova, obtížnost textu (1–12)
│   ├── Speed/           rychlostní obtížnost (Relaxed … Expert, Custom) + doporučení
│   ├── Modes/           herní režimy, konfigurace cvičení, Adaptive plánovač
│   ├── Exercise/        generátor textů, slovník
│   ├── Typing/          TypingEngine – WPM, přesnost, combo, reakční doba
│   ├── Adaptive/        postup v textu, váhy slabých písmen
│   └── Progression/     XP + level, streak, denní výzva, rekordy, odznaky, doporučený krok
├── Services/            ProgressStore (+Gamification), Persistence, Audio (AudioManager, SampleLibrary)
├── Features/            Home, Modes, Letters, Practice, Statistics, Achievements, History, Settings
└── Shared/              klávesnice (+ heatmapa), ruce, karty, formátování
```

## 🎚️ Dvě nezávislé obtížnosti
- **Obtížnost textu** → písmena + typ cvičení (znaky → slova → věty), mění ji jen Practice
- **Rychlost** → cílové WPM (Relaxed bez cíle, Easy 12, Normal 20, Hard 35, Expert 55, Custom)
- Postup v textu → přesnost ≥ 94 % + tempo podle zvolené rychlosti

## 🎮 Režimy
- Practice, Time Attack (15/30/60/120 s), Sprint, Accuracy Challenge (max 3 chyby), Survival (3 životy, vlny), Endless

## 🏅 Gamifikace (neovlivňuje výuku)
- XP + level 1–100, denní streak, výzva dne, osobní rekordy, 12 odznaků, combo

## 🗄️ Migrace dat
- v2 přidává jen nové entity a volitelné atributy → lehká migrace SwiftData
- Před první migrací se databáze zkopíruje (`Desetiprstka.store.backup-v1`)
- XP, streak a rekordy se dopočítají ze stávající historie

## ➕ Rozšíření
- Slova/věty → `Domain/Exercise/WordBank.swift`
- Odznak → `AchievementCatalog.all`
- Režim → `GameMode` + větev v `PracticeViewModel`
- Typ denní výzvy → `DailyChallengeKind`

## 🔊 Zvuky
- Úhozy → nahrávky v `Resources/Sounds/key-<balíček>-<n>.wav` (44,1 kHz, mono, oříznuté na začátek úderu)
- Chybí-li nahrávky balíčku → použije se syntéza (`SoundSynthesizer`)
- Chyba a odměny → syntéza
- Úprava zdrojů → `process_sounds.py` (ořez, normalizace, varianty výšky)
- Zdroje:
  - Soft → Mixkit „Typewriter soft click“ (Mixkit License)
  - Clicky → Mixkit „Hard typewriter click“ (Mixkit License)
  - Typewriter → Freesound 9098 „Typewriter.wav“ od ddohler (CC BY 4.0, uvedeno v Nastavení → Zvuk) + Mixkit „Mechanical typewriter single hit“
  - Mechanical → Freesound 860426 „Typing on a mechanical keyboard“ od Vladislav_Sazonov (CC0)

## 🎓 Navíc oproti ZAV
- **Úhozy za minutu** → Nastavení → Obecné → Jednotka rychlosti (WPM / úhozy); Shift a mrtvé klávesy se počítají jako úhoz navíc
- **Zkouška** → opis na 1, 2, 5 nebo 10 min; čisté úhozy = hrubé − 100 × chyby, chybovost v %, orientační známka 1–5 (`ExamEvaluation`)
- **Vlastní text** → vložený text se znormalizuje (`CustomTextNormalizer`) a opisuje se jako cvičení
- **Rytmus** → pravidelnost úhozů ve výsledcích (`TypingMetrics.rhythm`), metronom v cílovém tempu (⇧⌘M, `AudioManager.startMetronome`)
- **Celá klávesnice** → lekce Číslice a Další znaky (? ! : ( ) " /); generátor přidává čísla, otázky, závorky a uvozovky
- **Obsah** → `WordBankExtended.swift` (~1 500 slov a ~140 vět navíc)

## 📄 Licence
- Zdrojový kód → © 2026 František Petráň, všechna práva vyhrazena. Kód můžeš číst, ale bez svolení ho nekopíruj ani nešiř.
- Zvuky mají vlastní licence (viz Zvuky výše). Freesound 9098 od ddohler je pod CC BY 4.0.
