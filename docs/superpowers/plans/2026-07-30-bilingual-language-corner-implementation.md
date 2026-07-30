# Language Corner Bilingual Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the existing Russian Corner macOS app into one bilingual Language Corner app with isolated Russian/English progress, English active-speaking cards, listening drills, full micro-scene sessions, and local expression capture.

**Architecture:** Keep the existing bundle identifier, install path, Russian resources, and Russian SwiftData stores intact. Introduce language-neutral content and service interfaces, then run one `LanguageRuntime` per language behind the existing floating panel. English receives its own catalog, stores, settings namespace, dictionary direction, tokenizer, and training content; shared UI selects the active runtime.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit `NSPanel`, SwiftData, AVFoundation/AVSpeechSynthesizer, URLSession, XCTest, local JSON resources.

---

### Task 1: Add language identity and profiles

**Files:**
- Create: `Sources/RussianCornerCore/StudyLanguage.swift`
- Test: `Tests/RussianCornerCoreTests/StudyLanguageTests.swift`

- [ ] **Step 1: Write failing profile tests**

```swift
import XCTest
@testable import RussianCornerCore

final class StudyLanguageTests: XCTestCase {
    func testEnglishAndRussianProfilesUseIndependentNamespaces() {
        XCTAssertEqual(StudyLanguage.english.storageNamespace, "english")
        XCTAssertEqual(StudyLanguage.russian.storageNamespace, "russian")
        XCTAssertNotEqual(
            StudyLanguage.english.storageNamespace,
            StudyLanguage.russian.storageNamespace
        )
    }

    func testDefaultVoicePreferences() {
        XCTAssertEqual(StudyLanguage.english.preferredVoiceLanguages.first, "en-US")
        XCTAssertEqual(StudyLanguage.russian.preferredVoiceLanguages.first, "ru-RU")
    }
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
swift test --filter StudyLanguageTests
```

Expected: compile failure because `StudyLanguage` does not exist.

- [ ] **Step 3: Implement the language type**

```swift
import Foundation

public enum StudyLanguage: String, Codable, CaseIterable, Sendable {
    case english
    case russian

    public var storageNamespace: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .english: "EN"
        case .russian: "RU"
        }
    }

    public var displayName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        }
    }

    public var preferredVoiceLanguages: [String] {
        switch self {
        case .english: ["en-US", "en-GB", "en"]
        case .russian: ["ru-RU", "ru"]
        }
    }

    public var dictionaryLanguagePairs: [String] {
        switch self {
        case .english: ["en-zh", "en-ru"]
        case .russian: ["ru-zh", "ru-en"]
        }
    }
}
```

- [ ] **Step 4: Run the tests and verify GREEN**

Run: `swift test --filter StudyLanguageTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RussianCornerCore/StudyLanguage.swift Tests/RussianCornerCoreTests/StudyLanguageTests.swift
git commit -m "feat: add bilingual language profiles"
```

### Task 2: Introduce language-neutral content models and legacy Russian adapters

**Files:**
- Create: `Sources/RussianCornerCore/StudyContent.swift`
- Modify: `Sources/RussianCornerCore/ContentCatalog.swift`
- Test: `Tests/RussianCornerCoreTests/StudyContentTests.swift`

- [ ] **Step 1: Write failing adapter tests**

Test that:

- A current Russian `Lexeme` maps to `StudyLexeme(language: .russian)`.
- A current Russian `SentenceCard.practiceRu` maps to `StudySentence.targetText`.
- Existing reviewed/verified filtering is preserved.
- English v2 JSON decodes `targetText`, `phonetic`, `phrasalVerbs`, and `memoryNotes`.

Use this expected English fixture:

```swift
let english = StudyLexeme(
    id: "en.about-to",
    language: .english,
    lemma: "about to",
    displayForm: "about to",
    speechText: "about to",
    phonetic: "/əˈbaʊt tə/",
    partOfSpeech: "phrase",
    glossZh: "正要；即将",
    inflections: [],
    collocations: ["be just about to do something"],
    phrasalVerbs: [],
    wordFamily: [],
    morphologyNotes: ["be about to + 动词原形"],
    memoryNotes: [],
    exampleSentenceIDs: ["en.sentence.about-to-call"],
    reviewStatus: .reviewed,
    provenanceType: .derived,
    sourcePath: "bundled/english/daily-plans"
)
```

- [ ] **Step 2: Verify RED**

Run: `swift test --filter StudyContentTests`

Expected: compile failure for `StudyLexeme` and `StudySentence`.

- [ ] **Step 3: Add v2 content types**

Define:

```swift
public enum MemoryNoteKind: String, Codable, Sendable {
    case verifiedEtymology
    case morphologicalBreakdown
    case mnemonic
}

public struct MemoryNote: Codable, Equatable, Sendable {
    public let kind: MemoryNoteKind
    public let text: String
}

public struct SentenceVariant: Codable, Equatable, Sendable {
    public let promptZh: String
    public let targetText: String
}
```

Add complete `StudyLexeme` and `StudySentence` structs matching the approved design. Include `reviewStatus`, `provenanceType`, `sourcePath`, and `qualityFlags` as required provenance fields.

- [ ] **Step 4: Add Russian legacy mapping**

Add `Lexeme.studyContent` and `SentenceCard.studyContent` computed mappings. Keep all current stored fields and JSON decoding unchanged.

- [ ] **Step 5: Add `LanguageContentCatalog`**

Create an initializer accepting `[StudyLexeme]` and `[StudySentence]`, filter to `.reviewed/.verified`, and validate:

- non-empty target and speech text;
- unique IDs;
- every sentence lexeme ID resolves;
- every lexeme has a collocation or linked sentence;
- every sentence has source path and language.

- [ ] **Step 6: Run focused tests**

Run: `swift test --filter StudyContentTests`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/RussianCornerCore/StudyContent.swift Sources/RussianCornerCore/ContentCatalog.swift Tests/RussianCornerCoreTests/StudyContentTests.swift
git commit -m "feat: add language-neutral study content"
```

### Task 3: Generalize tokenization and clickable text

**Files:**
- Create: `Sources/RussianCornerCore/TargetLanguageTokenizer.swift`
- Create: `Sources/RussianCornerUI/InteractiveTargetText.swift`
- Modify: `Sources/RussianCornerUI/InteractiveRussianText.swift`
- Test: `Tests/RussianCornerCoreTests/TargetLanguageTokenizerTests.swift`
- Test: `Tests/RussianCornerAppTests/InteractiveRussianTextTests.swift`

- [ ] **Step 1: Write failing tokenizer tests**

Cover:

```swift
XCTAssertEqual(
    TargetLanguageTokenizer.words(
        in: "I'm about to check-in.",
        language: .english
    ),
    ["I'm", "about", "to", "check-in"]
)
XCTAssertEqual(
    TargetLanguageTokenizer.words(
        in: "Я хочу́ заброни́ровать столик.",
        language: .russian
    ),
    ["Я", "хочу́", "заброни́ровать", "столик"]
)
```

Also assert every English word receives a clickable token index while punctuation remains plain text.

- [ ] **Step 2: Verify RED**

Run:

```bash
swift test --filter TargetLanguageTokenizerTests
swift test --filter InteractiveRussianTextTests
```

- [ ] **Step 3: Implement language-aware tokenization**

English word characters must accept Unicode Latin letters, combining marks, apostrophes inside words, and hyphens inside words. Russian behavior must remain byte-for-byte compatible for current bundled cards.

- [ ] **Step 4: Implement `InteractiveTargetText`**

Use a neutral URL scheme such as `language-corner-word://token/{index}` and expose language-specific accessibility labels. Keep `InteractiveRussianText` as a compatibility wrapper until all Russian views migrate.

- [ ] **Step 5: Run focused tests and commit**

```bash
swift test --filter TargetLanguageTokenizerTests
swift test --filter InteractiveRussianTextTests
git add Sources/RussianCornerCore/TargetLanguageTokenizer.swift Sources/RussianCornerUI/InteractiveTargetText.swift Sources/RussianCornerUI/InteractiveRussianText.swift Tests/RussianCornerCoreTests/TargetLanguageTokenizerTests.swift Tests/RussianCornerAppTests/InteractiveRussianTextTests.swift
git commit -m "feat: support clickable English and Russian text"
```

### Task 4: Generalize system speech and dictionary lookup

**Files:**
- Modify: `Sources/RussianCornerPlatform/SpeechService.swift`
- Modify: `Sources/RussianCornerPlatform/YandexDictionaryService.swift`
- Modify: `Sources/RussianCornerUI/OnlineDictionary.swift`
- Test: `Tests/RussianCornerPlatformTests/SpeechServiceTests.swift`
- Test: `Tests/RussianCornerPlatformTests/YandexDictionaryServiceTests.swift`

- [ ] **Step 1: Write failing speech tests**

Assert that `.english` selects `en-US`, falls back to `en-GB`, and never uses Russian when `allowUnrelatedFallback == false`. Assert current Russian selection remains unchanged.

- [ ] **Step 2: Write failing dictionary tests**

Capture request URLs and assert:

- English queries call `lang=en-zh` first.
- Russian queries call `lang=ru-zh` first.
- cache keys include language so English and Russian identical strings cannot collide.

- [ ] **Step 3: Verify RED**

Run:

```bash
swift test --filter SpeechServiceTests
swift test --filter YandexDictionaryServiceTests
```

- [ ] **Step 4: Implement generic voice selection**

Replace Russian-only public status names with:

```swift
public enum SpeechServiceStatus: Equatable, Sendable {
    case preferredVoice(identifier: String, language: String)
    case fallbackVoice(identifier: String, language: String)
    case unavailable
    case emptyText
}
```

Accept `StudyLanguage` and playback rate in `speak`. Preserve existing call sites through deprecated compatibility overloads until Task 9.

- [ ] **Step 5: Implement language-aware dictionary lookup**

Change:

```swift
func lookup(lemma: String, language: StudyLanguage) async throws
```

Send only the normalized lemma/phrase. Continue storing the API key in current app preferences. Mark all network results unreviewed.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter SpeechServiceTests
swift test --filter YandexDictionaryServiceTests
git add Sources/RussianCornerPlatform/SpeechService.swift Sources/RussianCornerPlatform/YandexDictionaryService.swift Sources/RussianCornerUI/OnlineDictionary.swift Tests/RussianCornerPlatformTests/SpeechServiceTests.swift Tests/RussianCornerPlatformTests/YandexDictionaryServiceTests.swift
git commit -m "feat: generalize speech and dictionary by language"
```

### Task 5: Create isolated English persistence and language settings

**Files:**
- Modify: `Sources/RussianCornerPlatform/Persistence.swift`
- Modify: `Sources/RussianCornerPlatform/TrialPersistence.swift`
- Create: `Sources/RussianCornerUI/LanguageStudySettings.swift`
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Test: `Tests/RussianCornerPlatformTests/PersistenceTests.swift`
- Test: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`

- [ ] **Step 1: Write failing store isolation tests**

Use a temporary Application Support directory and assert:

- `.russian` resolves existing `RussianCorner.store`.
- `.english` resolves new `EnglishCorner.store`.
- Writing an English event does not change Russian event count.
- Existing Russian records decode without a language migration.

- [ ] **Step 2: Write failing settings namespace tests**

Assert English daily queue keys start with `english.` and Russian legacy keys remain readable. English reminders default disabled.

- [ ] **Step 3: Verify RED**

Run:

```bash
swift test --filter PersistenceTests
swift test --filter PracticeViewModelTests
```

- [ ] **Step 4: Parameterize repository factories**

Add `StudyLanguage` to container factories. Do not rename, move, or recreate the Russian stores. Use `EnglishCorner.store` and `EnglishCornerTrial.store` for English.

- [ ] **Step 5: Split global and per-language settings**

Global:

- placement, screen, position, opacity, font scale, collapsed state.

Per language:

- daily count, practice mode, selected topic/day, daily queue snapshot, reminders enabled/times, preferred English accent.

Read current unnamespaced values as Russian compatibility defaults.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter PersistenceTests
swift test --filter PracticeViewModelTests
git add Sources/RussianCornerPlatform/Persistence.swift Sources/RussianCornerPlatform/TrialPersistence.swift Sources/RussianCornerUI/LanguageStudySettings.swift Sources/RussianCornerUI/AppModel.swift Tests/RussianCornerPlatformTests/PersistenceTests.swift Tests/RussianCornerAppTests/PracticeViewModelTests.swift
git commit -m "feat: isolate English and Russian learning data"
```

### Task 6: Add `LanguageRuntime` and safe language switching

**Files:**
- Create: `Sources/RussianCornerUI/LanguageRuntime.swift`
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Test: `Tests/RussianCornerAppTests/LanguageRuntimeTests.swift`

- [ ] **Step 1: Write failing runtime tests**

Test:

- both runtimes load independently;
- active language persists;
- switching preserves each practice index;
- English load failure leaves Russian usable;
- Russian load failure never writes an empty replacement store.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter LanguageRuntimeTests`

- [ ] **Step 3: Extract per-language state**

`LanguageRuntime` owns catalog, progress repository, trial repository, practice view model, diagnostics, reflection, history, and source-sync status.

`AppRuntime` owns:

```swift
public private(set) var activeLanguage: StudyLanguage
public private(set) var languageRuntimes: [StudyLanguage: LanguageRuntime]
public var activeRuntime: LanguageRuntime? { languageRuntimes[activeLanguage] }
```

Add `switchLanguage(to:)` that closes speech for the old runtime, persists the choice, and exposes the already-created queue for the new runtime.

- [ ] **Step 4: Run tests and commit**

```bash
swift test --filter LanguageRuntimeTests
git add Sources/RussianCornerUI/LanguageRuntime.swift Sources/RussianCornerUI/AppModel.swift Tests/RussianCornerAppTests/LanguageRuntimeTests.swift
git commit -m "feat: add isolated bilingual runtimes"
```

### Task 7: Build the English source audit and candidate pipeline

**Files:**
- Create: `Sources/RussianCornerPlatform/EnglishSourceCorpusScanner.swift`
- Create: `Sources/RussianCornerCore/EnglishCandidateContent.swift`
- Create: `Scripts/audit-english-corpus.swift`
- Test: `Tests/RussianCornerPlatformTests/EnglishSourceCorpusScannerTests.swift`

- [ ] **Step 1: Write failing scanner tests**

Fixture tree must include reviewed user notes, `AI整理`, `conflict`, reports, root notes, and unrelated life discussion. Assert:

- originals are read-only;
- conflict/AI/report files are excluded from formal candidates;
- root mnemonics are tagged `.mnemonic`;
- source path and source text are preserved;
- malformed entries become `draft` with quality flags.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter EnglishSourceCorpusScannerTests`

- [ ] **Step 3: Implement the scanner**

Use the approved source root only. Exclude paths matching:

```swift
["conflict", "AI整理", "双链报告", "补链报告", "顶层补链报告"]
```

Treat “需要反复重复的单词”, CET vocabulary, examples, and root notes as candidates, never automatically reviewed.

- [ ] **Step 4: Add audit command**

The command writes only into the project’s derived-data directory and reports:

- total files;
- excluded by reason;
- candidate words/examples;
- duplicated lemmas;
- missing pronunciation/example/source;
- suspicious mnemonic-as-etymology entries.

- [ ] **Step 5: Verify source hashes**

Run an aggregate SHA-256 manifest before and after scanning and assert identical output.

- [ ] **Step 6: Commit**

```bash
git add Sources/RussianCornerPlatform/EnglishSourceCorpusScanner.swift Sources/RussianCornerCore/EnglishCandidateContent.swift Scripts/audit-english-corpus.swift Tests/RussianCornerPlatformTests/EnglishSourceCorpusScannerTests.swift
git commit -m "feat: audit English source corpus safely"
```

### Task 8: Add reviewed English resources and quality gates

**Files:**
- Create: `Sources/RussianCornerCore/Resources/english-lexemes.json`
- Create: `Sources/RussianCornerCore/Resources/english-sentences.json`
- Create: `Sources/RussianCornerCore/Resources/english-topics.json`
- Create: `Sources/RussianCornerCore/Resources/english-lessons.json`
- Create: `Scripts/validate-english-content.swift`
- Modify: `Scripts/build-app.sh`
- Test: `Tests/RussianCornerCoreTests/EnglishContentValidationTests.swift`

- [ ] **Step 1: Write failing content validation tests**

Require:

- 20 topic definitions;
- 200–300 reviewed/verified expressions;
- 400–600 linked lexemes/chunks;
- no elementary greeting-only cards;
- every sentence has a reply or variant;
- every lexeme has a collocation or sentence;
- all speech text is clean English;
- no AI/report/conflict source paths;
- mnemonic and etymology labels are distinct.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter EnglishContentValidationTests`

- [ ] **Step 3: Create the reviewed seed corpus**

Curate content around the 20 approved daily themes. Each sentence record must include:

```json
{
  "id": "en.plans.about-to-call",
  "language": "english",
  "promptZh": "我本来正想给你打电话。",
  "cueText": "You were going to call a friend right now.",
  "targetText": "I was just about to call you.",
  "displayText": "I was just about to call you.",
  "speechText": "I was just about to call you.",
  "theme": "Changing plans",
  "lexemeIDs": ["en.chunk.be-about-to", "en.word.call"],
  "dialogueAct": "informing",
  "register": "neutral",
  "speakerRole": "friend",
  "expectedReplies": ["Really? What's up?"],
  "variants": [
    {
      "promptZh": "我们正准备点餐。",
      "targetText": "We were just about to order."
    }
  ],
  "sourcePath": "bundled/english/changing-plans",
  "reviewStatus": "reviewed",
  "provenanceType": "derived",
  "qualityFlags": []
}
```

Do not label generated supplements `verified`; use `reviewed` after manual language and provenance checks.

- [ ] **Step 4: Add build-time validation**

`build-app.sh` must fail if counts, references, statuses, or speech-text sanitation fail. Extend the resource probe to report Russian and English counts separately.

- [ ] **Step 5: Run validation and commit**

```bash
swift test --filter EnglishContentValidationTests
./Scripts/build-app.sh
git add Sources/RussianCornerCore/Resources/english-*.json Scripts/validate-english-content.swift Scripts/build-app.sh Tests/RussianCornerCoreTests/EnglishContentValidationTests.swift
git commit -m "feat: add reviewed English speaking corpus"
```

### Task 9: Add card language switching and English presentation

**Files:**
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Modify: `Sources/RussianCornerUI/PracticeDetailSection.swift`
- Modify: `Sources/RussianCornerUI/FloatingPanelController.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Test: `Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift`
- Test: `Tests/RussianCornerAppTests/InteractiveRussianTextTests.swift`

- [ ] **Step 1: Write failing UI-state tests**

Assert:

- header exposes EN/RU switch;
- collapsed badge is `EN` for English and `Я` for Russian;
- panel size and top anchoring do not change on language switch;
- English word selection expands below without changing width;
- language switching does not reset current index.

- [ ] **Step 2: Verify RED**

Run:

```bash
swift test --filter FloatingPanelControllerTests
swift test --filter InteractiveRussianTextTests
```

- [ ] **Step 3: Add language switch**

Replace the Russian-only heading with `LANGUAGE CORNER`, add an accessible `EN / RU` menu, and bind all card data/actions to `runtime.activeRuntime`.

- [ ] **Step 4: Generalize word details**

Russian retains stress/aspect/government. English displays IPA, inflection, collocations, phrasal verbs, word family, register, root/affix notes, mnemonic labeling, and current-sentence usage.

- [ ] **Step 5: Update visible branding**

Change menu/window titles to Language Corner while keeping bundle identifier and app bundle filename unchanged.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter FloatingPanelControllerTests
swift test --filter InteractiveRussianTextTests
git add Sources/RussianCornerUI/PracticeCardView.swift Sources/RussianCornerUI/PracticeDetailSection.swift Sources/RussianCornerUI/FloatingPanelController.swift Sources/RussianCornerApp/RussianCornerApp.swift Tests/RussianCornerAppTests/FloatingPanelControllerTests.swift Tests/RussianCornerAppTests/InteractiveRussianTextTests.swift
git commit -m "feat: add bilingual floating practice card"
```

### Task 10: Add structured recall and objective transfer checks

**Files:**
- Create: `Sources/RussianCornerCore/RecallOutcome.swift`
- Create: `Sources/RussianCornerCore/TransferExercise.swift`
- Modify: `Sources/RussianCornerUI/PracticeViewModel.swift`
- Modify: `Sources/RussianCornerUI/PracticeCardView.swift`
- Test: `Tests/RussianCornerCoreTests/TransferExerciseTests.swift`
- Test: `Tests/RussianCornerAppTests/PracticeViewModelTests.swift`

- [ ] **Step 1: Write failing grading tests**

Assert:

- fast complete recall + correct transfer maps to Easy;
- complete self-rating + failed transfer maps to Hard;
- partial recall maps to Hard;
- reveal-only and unknown map to Again;
- response time and transfer answer are persisted.

- [ ] **Step 2: Verify RED**

Run:

```bash
swift test --filter TransferExerciseTests
swift test --filter PracticeViewModelTests
```

- [ ] **Step 3: Implement four outcomes**

```swift
public enum RecallOutcome: String, Codable, Sendable {
    case fluentWithinThreeSeconds
    case coreMeaningWithUsageIssue
    case rememberedAfterReveal
    case unknown
}
```

- [ ] **Step 4: Implement transfer exercises**

Support slot replacement, collocation completion, and next-reply selection. Validate one correct answer and plausible distractors before serving.

- [ ] **Step 5: Wire scheduling**

Only `fluentWithinThreeSeconds + correct transfer` can produce Easy. Record all evidence through existing review and trial interaction stores.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter TransferExerciseTests
swift test --filter PracticeViewModelTests
git add Sources/RussianCornerCore/RecallOutcome.swift Sources/RussianCornerCore/TransferExercise.swift Sources/RussianCornerUI/PracticeViewModel.swift Sources/RussianCornerUI/PracticeCardView.swift Tests/RussianCornerCoreTests/TransferExerciseTests.swift Tests/RussianCornerAppTests/PracticeViewModelTests.swift
git commit -m "feat: verify active recall with transfer tasks"
```

### Task 11: Add full English micro-scene training

**Files:**
- Create: `Sources/RussianCornerCore/SceneLesson.swift`
- Create: `Sources/RussianCornerUI/SceneTrainingViewModel.swift`
- Create: `Sources/RussianCornerUI/SceneTrainingView.swift`
- Modify: `Sources/RussianCornerApp/RussianCornerApp.swift`
- Test: `Tests/RussianCornerAppTests/SceneTrainingViewModelTests.swift`

- [ ] **Step 1: Write failing lesson-flow tests**

Test the exact progression:

`context → bilingual → englishOnly → audioFirst → shadowing → retell → variants → dialogue → selection`

Assert reopening restores the current stage and completing a lesson offers selected expressions to the English queue.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter SceneTrainingViewModelTests`

- [ ] **Step 3: Add lesson model and persistence**

Each lesson references existing sentence IDs, supplies scene context and dialogue order, and stores only progress/selected expression IDs.

- [ ] **Step 4: Build the training window**

Use a `760 × 680` AppKit-hosted SwiftUI window. Provide:

- click-to-define English;
- Chinese support toggle;
- hide text;
- normal/slow playback;
- repeat sentence;
- shadowing controls;
- retell prompt;
- variant and role-swap tasks.

- [ ] **Step 5: Add app/card entry**

Expose “今日英语场景” in the card’s More menu and the menu-bar menu when English runtime is available.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter SceneTrainingViewModelTests
git add Sources/RussianCornerCore/SceneLesson.swift Sources/RussianCornerUI/SceneTrainingViewModel.swift Sources/RussianCornerUI/SceneTrainingView.swift Sources/RussianCornerApp/RussianCornerApp.swift Tests/RussianCornerAppTests/SceneTrainingViewModelTests.swift
git commit -m "feat: add English micro-scene training"
```

### Task 12: Add local expression capture and subtitle import

**Files:**
- Create: `Sources/RussianCornerCore/ImportedExpression.swift`
- Create: `Sources/RussianCornerPlatform/SubtitleParser.swift`
- Create: `Sources/RussianCornerPlatform/ExpressionCaptureStore.swift`
- Create: `Sources/RussianCornerUI/ExpressionCaptureViewModel.swift`
- Create: `Sources/RussianCornerUI/ExpressionCaptureView.swift`
- Test: `Tests/RussianCornerPlatformTests/SubtitleParserTests.swift`
- Test: `Tests/RussianCornerAppTests/ExpressionCaptureViewModelTests.swift`

- [ ] **Step 1: Write failing parser tests**

Cover valid and malformed `.srt`, `.vtt`, `.txt`, and `.md`. Assert timestamps are removed from candidate text, source files remain byte-identical, and malformed timeline entries fall back to plain text.

- [ ] **Step 2: Write failing candidate tests**

Assert imported candidates:

- start as `draft`;
- retain source path/text;
- cannot enter practice before review;
- can select a sentence or phrase rather than importing everything.

- [ ] **Step 3: Verify RED**

Run:

```bash
swift test --filter SubtitleParserTests
swift test --filter ExpressionCaptureViewModelTests
```

- [ ] **Step 4: Implement import and local store**

Use `NSOpenPanel` for local files and a paste field for text. Store a derived copy only in the English candidate store. Never edit, move, upload, or fetch the source.

- [ ] **Step 5: Build candidate review UI**

Let the user add Chinese intent, scene, speaker role, register, expected reply, and selected phrase. Online lookup remains optional and unreviewed.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter SubtitleParserTests
swift test --filter ExpressionCaptureViewModelTests
git add Sources/RussianCornerCore/ImportedExpression.swift Sources/RussianCornerPlatform/SubtitleParser.swift Sources/RussianCornerPlatform/ExpressionCaptureStore.swift Sources/RussianCornerUI/ExpressionCaptureViewModel.swift Sources/RussianCornerUI/ExpressionCaptureView.swift Tests/RussianCornerPlatformTests/SubtitleParserTests.swift Tests/RussianCornerAppTests/ExpressionCaptureViewModelTests.swift
git commit -m "feat: capture expressions from local English materials"
```

### Task 13: Apply the approved diagnostic and reflection redesign to both languages

**Files:**
- Modify: `Sources/RussianCornerUI/DiagnosticViewModel.swift`
- Modify: `Sources/RussianCornerUI/DiagnosticView.swift`
- Modify: `Sources/RussianCornerUI/DailyReflectionView.swift`
- Modify: `Sources/RussianCornerCore/Diagnostics.swift`
- Test: `Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift`
- Test: `Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift`

- [ ] **Step 1: Add failing objective-diagnostic tests**

Assert recognition/listening/collocation choices have one correct answer, response time is recorded, wrong answers enter the active language queue, skipped unavailable audio is not wrong, and English/Russian diagnostic reports remain isolated.

- [ ] **Step 2: Verify RED**

Run: `swift test --filter DiagnosticViewModelTests`

- [ ] **Step 3: Implement objective question types**

Use language catalog distractors and the transfer-exercise engine. Preserve legacy diagnostic report decoding and label old runs “旧版自评诊断”.

- [ ] **Step 4: Implement actionable results**

Show the primary bottleneck, concrete failed items, queued reviews, and next-seven-day training changes before metric tables.

- [ ] **Step 5: Redesign reflection UI**

Use three compact cards, warm accent styling, stacked fields, language label, and fixed bottom actions. Keep current `DailyReflection` data fields and stored records compatible.

- [ ] **Step 6: Run tests and commit**

```bash
swift test --filter DiagnosticViewModelTests
swift test --filter DailyReflectionViewModelTests
git add Sources/RussianCornerUI/DiagnosticViewModel.swift Sources/RussianCornerUI/DiagnosticView.swift Sources/RussianCornerUI/DailyReflectionView.swift Sources/RussianCornerCore/Diagnostics.swift Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift
git commit -m "feat: improve bilingual diagnostics and reflection"
```

### Task 14: Package, migrate, and perform business acceptance

**Files:**
- Modify: `Scripts/build-app.sh`
- Modify: `Sources/RussianCornerResourceProbe/main.swift`
- Test: existing full Swift test suite

- [ ] **Step 1: Snapshot Russian data and source hashes**

Record hashes for the Russian source folder and copies of existing Russian SwiftData stores before launching the new build.

- [ ] **Step 2: Run the complete automated suite**

```bash
swift test
```

Expected: all tests pass with no unexpected warnings.

- [ ] **Step 3: Build and verify bundle resources**

```bash
./Scripts/build-app.sh
codesign --verify --deep --strict "dist/Russian Corner.app"
```

Resource probe must report valid Russian and English catalogs independently.

- [ ] **Step 4: Install recoverably**

Stop the running app, move the existing app bundle into a unique `/tmp/russian-corner-bilingual-backup.*` directory, copy the new bundle to `/Applications/Russian Corner.app`, verify executable identity, and reopen.

- [ ] **Step 5: Run manual business acceptance**

Verify:

- Russian resumes at the existing progress.
- English switches in place without panel jump.
- English sentence words are clickable.
- English voice and dictionary direction are correct.
- one transfer task affects grading correctly;
- one micro-scene completes;
- one pasted expression becomes draft only;
- diagnostics and reflection show active language;
- restarting restores both queues and card position.

- [ ] **Step 6: Recheck original source hashes**

Russian and English source roots must match the pre-build manifests exactly.

- [ ] **Step 7: Commit final integration**

```bash
git add Scripts/build-app.sh Sources/RussianCornerResourceProbe/main.swift
git commit -m "feat: ship bilingual Language Corner"
```

## Self-review result

- Spec coverage: bilingual runtime, data safety, English card, word details, listening, transfer validation, full training, local capture, corpus quality, diagnostics, reflection, packaging, and failure isolation are all mapped to tasks.
- Placeholder scan: no implementation placeholders remain.
- Type consistency: `StudyLanguage`, `StudyLexeme`, `StudySentence`, `LanguageRuntime`, `RecallOutcome`, and `TransferExercise` are introduced before use.
- Execution mode: inline in the existing repository, as explicitly requested; no parallel project or subagent workflow.
