# Diagnostic and Reflection Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the self-report-heavy diagnostic with objective local quiz evidence and redesign Daily Reflection as a compact, visually coherent daily closing card.

**Architecture:** Add deterministic question generation and structured diagnostic outcomes in `RussianCornerCore`, keep orchestration and persistence in `DiagnosticViewModel`, and render the new workflow in focused SwiftUI components. Reuse `PracticeProgressStoring`, `ReviewScheduler`, and existing report persistence so failed diagnostic items enter the normal review system instead of creating a parallel scheduler.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, XCTest, AVSpeechSynthesizer through the existing `SpeechService`.

---

## File map

- `Sources/RussianCornerCore/DiagnosticQuestions.swift`: deterministic recognition, listening, and collocation question builders plus production outcome mapping.
- `Sources/RussianCornerCore/Diagnostics.swift`: retain report compatibility and support anchor/challenge sampling.
- `Sources/RussianCornerUI/DiagnosticViewModel.swift`: run objective questions, record attempts and reaction times, persist review consequences, and expose actionable summary data.
- `Sources/RussianCornerUI/DiagnosticView.swift`: objective quiz UI, clear intro, four-grade production flow, and actionable summary.
- `Sources/RussianCornerUI/DailyReflectionView.swift`: reusable styled feedback cards and compact standalone/embedded layouts.
- `Sources/RussianCornerApp/RussianCornerApp.swift`: pass the review store to diagnostics and retain existing feature-window behavior.
- `Tests/RussianCornerCoreTests/DiagnosticQuestionTests.swift`: question correctness, deterministic distractors, production grade mapping.
- `Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift`: workflow, timing, review linkage, listening replay, and compatibility.
- `Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift`: existing data remains loadable and savable after visual changes.

### Task 1: Objective question model and builder

**Files:**
- Create: `Sources/RussianCornerCore/DiagnosticQuestions.swift`
- Create: `Tests/RussianCornerCoreTests/DiagnosticQuestionTests.swift`

- [ ] Write failing tests that require:
  - recognition questions to contain one correct Chinese gloss and unique same-part-of-speech distractors;
  - listening questions to contain one correct Chinese intent and unique alternatives;
  - collocation questions to contain one reviewed correct collocation and unique alternatives;
  - identical input and seed to produce identical option order;
  - `DiagnosticProductionOutcome` to map `completeFast → easy`, `partial → hard`, and both reveal-only outcomes to `again`.
- [ ] Run `swift test --filter DiagnosticQuestionTests` and verify missing types fail compilation.
- [ ] Implement `DiagnosticChoiceQuestion`, `DiagnosticQuestionBuilder`, `DiagnosticProductionOutcome`, and `reviewGrade`.
- [ ] Re-run `swift test --filter DiagnosticQuestionTests` and require zero failures.
- [ ] Commit core question generation.

### Task 2: Objective diagnostic orchestration and normal-review linkage

**Files:**
- Modify: `Sources/RussianCornerUI/DiagnosticViewModel.swift`
- Modify: `Sources/RussianCornerUI/AppModel.swift`
- Modify: `Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift`

- [ ] Add failing tests proving:
  - selecting a recognition option scores from the option ID rather than a supplied Boolean;
  - production outcomes record the elapsed time and use the four-grade mapping;
  - listening cannot be scored before playback and option selection;
  - replayed listening success becomes `hard`;
  - collocation questions advance one at a time and compute rate from correct answers;
  - failed/partial items create or advance existing `ReviewState` through `ReviewScheduler`;
  - unavailable TTS skips without an incorrect attempt.
- [ ] Run the focused tests and verify failures are caused by the missing objective API.
- [ ] Extend `DiagnosticViewModel` with current question properties, attempt records, replay count, production outcome submission, and objective option submission.
- [ ] Add optional `PracticeProgressStoring` injection. Persist diagnostic consequences with existing `commitReview`, preserving the current daily completed count.
- [ ] Keep compatibility wrappers for older tests and stored reports, but stop using Boolean self-report methods from the UI.
- [ ] Pass the runtime repository as `reviewStore` from `AppRuntime`.
- [ ] Run `swift test --filter DiagnosticViewModelTests` and require zero failures.
- [ ] Commit diagnostic orchestration.

### Task 3: Anchor/challenge sampling

**Files:**
- Modify: `Sources/RussianCornerCore/Diagnostics.swift`
- Modify: `Tests/RussianCornerCoreTests/DiagnosticsTests.swift`

- [ ] Add failing tests that a weekly sample with ten baseline IDs keeps seven anchors and fills three challenge slots from other reviewed content, while missing anchor content is still marked repaired.
- [ ] Run the sampler tests and verify the existing all-anchor behavior fails the new assertion.
- [ ] Add `anchorRatio` and `challengeSeedOffset` inputs to `DiagnosticSampler.sample`, defaulting to backward-compatible values for callers that do not request weekly challenge rotation.
- [ ] In `DiagnosticViewModel`, request 70% anchors only for weekly runs and derive the challenge offset from valid diagnostic-history count.
- [ ] Update repaired-sample detection to compare required anchors rather than all rotating challenge IDs.
- [ ] Run `swift test --filter DiagnosticsTests` and `swift test --filter DiagnosticViewModelTests`.
- [ ] Commit anchor/challenge sampling.

### Task 4: Diagnostic workflow UI and actionable results

**Files:**
- Modify: `Sources/RussianCornerUI/DiagnosticView.swift`
- Modify: `Tests/RussianCornerAppTests/DiagnosticViewModelTests.swift`

- [ ] Add view-model-facing tests for intro copy, step labels, attempt summaries, weak-area headline, review-added items, and seven-day adjustments.
- [ ] Run focused tests and verify the new presentation properties are missing.
- [ ] Replace recognition, listening, and collocation self-report controls with option cards that provide a selected/correct/incorrect state.
- [ ] Replace production’s two buttons with the four explicit outcomes and retain measured reveal time.
- [ ] Rewrite the intro as a five-to-eight-minute strategy calibration with visible steps.
- [ ] Rewrite the summary to lead with one plain-language conclusion, four ability cards, concrete mistakes added to review, and actual next-seven-day adjustments.
- [ ] Keep oral activity honest: timing, microphone activity, pauses, and one self-rating only.
- [ ] Run `swift test --filter DiagnosticViewModelTests` and build the app.
- [ ] Commit the diagnostic UI.

### Task 5: Daily Reflection visual redesign

**Files:**
- Modify: `Sources/RussianCornerUI/DailyReflectionView.swift`
- Modify: `Tests/RussianCornerAppTests/DailyReflectionViewModelTests.swift`

- [ ] Add tests for the stable three-section presentation metadata and action labels while retaining the existing model data contract.
- [ ] Run the focused test and verify the presentation metadata is missing.
- [ ] Implement a warm editorial header with date, three compact icon cards, custom rounded input surfaces, stacked controls, and a fixed bottom action row.
- [ ] Ensure standalone `500 × 470` and embedded `430 × 386` layouts both fit without unnecessary empty space.
- [ ] Preserve every existing binding, 200-character limit, save path, and completion-offer behavior.
- [ ] Run `swift test --filter DailyReflectionViewModelTests`.
- [ ] Commit the reflection UI.

### Task 6: Integration, regression checks, and installation

**Files:**
- Modify only files required by failures found in this task.

- [ ] Run `swift test`.
- [ ] Run `./Scripts/build-app.sh` and require signature, resource probe, permissions, and source-resource hash checks to pass.
- [ ] Install `dist/Russian Corner.app` into `/Applications/Russian Corner.app` using a dated temporary backup of the current installed bundle.
- [ ] Open the app and verify with the real UI:
  - Daily Reflection shows the three styled cards and save action;
  - Diagnostic intro explains its purpose and duration;
  - recognition shows objective choices;
  - card “更多功能” still opens both windows.
- [ ] Run `git diff --check`, confirm original Obsidian files were not modified, and commit only relevant project files.

## Self-review

- Spec coverage: objective recognition, production, listening, collocation, oral evidence limits, review linkage, anchor/challenge sampling, actionable results, visual reflection redesign, compatibility, and degradation paths all map to tasks.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation steps.
- Type consistency: question types live in Core; orchestration stays in UI; persistence is injected through existing Platform protocols; no new parallel review store is introduced.
- Scope decision: implementation stays in the existing project and current branch because the user explicitly requested direct work in the current checkpoint and previously rejected a parallel project.
