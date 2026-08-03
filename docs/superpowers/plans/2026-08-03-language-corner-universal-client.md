# Language Corner Universal Client Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a working mobile-first Language Corner learning client that opens in modern phone and Windows browsers, can be installed to the device home screen, works offline after first load, and reuses the real English and Russian content model.

**Architecture:** Add a self-contained React/TypeScript client under the existing repository. Keep the Swift macOS app unchanged, load copied read-only JSON resources through a language-neutral adapter, persist progress locally, and use a manifest plus service worker for installability and offline use. This is the shared foundation for later iPhone, Android, and Windows store packages.

**Tech Stack:** React, TypeScript, Vite, Vitest, Testing Library, browser `localStorage`/IndexedDB-compatible repository interface, Web Speech API with graceful fallback, Web App Manifest, Service Worker.

---

## File map

- Create: `/Users/Openclawworkspace/workspace/russian-corner/Clients/Universal/` — universal client workspace.
- Create: `Clients/Universal/src/content/` — bilingual adapters and queue generation.
- Create: `Clients/Universal/src/practice/` — active-recall state machine and persistence.
- Create: `Clients/Universal/src/components/` — mobile-first practice UI.
- Create: `Clients/Universal/public/manifest.webmanifest` — install metadata.
- Create: `Clients/Universal/public/sw.js` — offline cache.
- Create: `Clients/Universal/scripts/sync-content.mjs` — copies reviewed bundled content without modifying sources.
- Create: `Clients/Universal/tests/` — unit and browser-oriented regression tests.

### Task 1: Scaffold the isolated client and test runner

- [ ] **Step 1: Create the Vite React TypeScript workspace**

From `Clients/Universal`, initialize package metadata and install React, Vite, TypeScript, Vitest, jsdom, Testing Library, and ESLint. The package scripts must be:

```json
{
  "scripts": {
    "content:sync": "node scripts/sync-content.mjs",
    "dev": "npm run content:sync && vite",
    "test": "vitest run",
    "build": "npm run content:sync && tsc -b && vite build",
    "preview": "vite preview"
  }
}
```

- [ ] **Step 2: Add the first failing render test**

```tsx
render(<App />);
expect(screen.getByText("LANGUAGE CORNER")).toBeInTheDocument();
expect(screen.getByRole("button", { name: "英语" })).toBeInTheDocument();
expect(screen.getByRole("button", { name: "俄语" })).toBeInTheDocument();
```

- [ ] **Step 3: Run the test and verify failure**

Run: `npm test`

Expected: FAIL because `App` does not exist.

- [ ] **Step 4: Implement the minimal shell and pass the test**

Create `src/App.tsx`, `src/main.tsx`, and `src/styles.css` with a mobile-first single-column shell and a language switcher.

### Task 2: Synchronize real reviewed content without mutating sources

- [ ] **Step 1: Write a failing sync-script test**

The test hashes all source JSON files before and after running `sync-content.mjs`, asserts hashes are unchanged, and asserts these output counts:

```text
english-lexemes.json: 400
english-sentences.json: 200
english-topics.json: 20
english-lessons.json: 20
lexemes.json: 360
supplemental-lexemes.json: 80
long-term-sentences.json.sentences: 214
supplemental-sentences.json: 60
topics.json: 32
speaking-challenges.json: 24
```

- [ ] **Step 2: Implement `scripts/sync-content.mjs`**

Resolve sources from `../../Sources/RussianCornerCore/Resources`, copy only the listed reviewed bundles into `public/content`, and write `public/content/manifest.json` containing file names, SHA-256 values, and counts.

- [ ] **Step 3: Run sync tests**

Run: `npm test -- content-sync`

Expected: PASS and all source hashes unchanged.

### Task 3: Create the language-neutral content adapter

- [ ] **Step 1: Define public types**

```ts
export type StudyLanguage = "english" | "russian";

export interface PracticeSentence {
  id: string;
  language: StudyLanguage;
  promptZh: string;
  targetText: string;
  speechText: string;
  topicId: string;
  lexemeIds: string[];
}

export interface PracticeLexeme {
  id: string;
  language: StudyLanguage;
  lemma: string;
  displayForm: string;
  glossZh: string;
  collocations: string[];
}
```

- [ ] **Step 2: Write adapter tests**

Tests must load one English and one Russian sentence, preserve language separation, reject empty target text, and map clickable surface words to lexeme details where available.

- [ ] **Step 3: Implement English and Russian adapters**

Keep source-specific decoding inside `src/content/englishAdapter.ts` and `src/content/russianAdapter.ts`; expose only `PracticeSentence` and `PracticeLexeme` to the UI.

- [ ] **Step 4: Verify content counts and isolation**

Run: `npm test -- content`

Expected: PASS; no English IDs appear in the Russian catalog and vice versa.

### Task 4: Implement a local-first daily queue

- [ ] **Step 1: Define the persistence boundary**

```ts
export interface ProgressRepository {
  load(language: StudyLanguage): Promise<LanguageProgress>;
  save(language: StudyLanguage, progress: LanguageProgress): Promise<void>;
}
```

- [ ] **Step 2: Write tests for stable daily ordering**

The same date and language must produce the same queue; the next date must produce a different order. English and Russian progress keys must be separate.

- [ ] **Step 3: Implement the queue and browser repository**

Use a deterministic date seed, default to five sentences, keep the current index, and save under `languageCorner.progress.english` and `languageCorner.progress.russian`.

- [ ] **Step 4: Add the four recall outcomes**

Use:

```ts
export type RecallOutcome =
  | "fluentUnder3s"
  | "meaningButUsageIssue"
  | "afterReveal"
  | "unknown";
```

Store response time and require a transfer result after `fluentUnder3s` or `meaningButUsageIssue`.

### Task 5: Build the phone-first practice flow

- [ ] **Step 1: Write interaction tests**

Test: prompt is visible before answer; reveal shows target sentence; each target-language word is a button; choosing a high outcome opens a transfer task; completing it advances the queue.

- [ ] **Step 2: Build `PracticeScreen`**

The screen order must be:

```text
language/topic → Chinese intent or target-language cue → 3-second indicator → reveal → clickable target sentence → transfer task → outcome → next card
```

- [ ] **Step 3: Build local word details**

Clicking a word opens a bottom sheet that never replaces or enlarges the main sentence. It shows meaning, lemma/current form, grammar, collocations, example, and source when present.

- [ ] **Step 4: Add speech with fallback**

Use `speechSynthesis` with `en-US` for English and `ru-RU` for Russian. If unavailable, hide the audio control and keep all text practice usable.

### Task 6: Add installability and offline behavior

- [ ] **Step 1: Create `manifest.webmanifest`**

Use `name: "Language Corner"`, `short_name: "Language Corner"`, `display: "standalone"`, brand colors, and local 192/512px icons.

- [ ] **Step 2: Add and register `sw.js`**

Cache the app shell and content manifest on install. Cache successful same-origin GET responses at runtime. Never cache API keys or user-entered secrets.

- [ ] **Step 3: Add user-facing install help**

Copy must say:

```text
把 Language Corner 放到手机桌面，下次像普通 App 一样打开。
```

Never show `PWA`, `service worker`, or implementation framework names in the UI.

- [ ] **Step 4: Test offline reload**

Build, open once online, switch browser context offline, reload, and verify the current queue still opens.

### Task 7: Add the first-use experience

- [ ] **Step 1: Implement three-card guest onboarding**

The first session asks only for language and daily duration, then starts three real cards. Do not request login, microphone, or notifications before the first completed card.

- [ ] **Step 2: Add contextual practice choices**

Expose plain-language modes:

```text
安静看一遍
戴耳机听和跟读
现在可以开口
```

- [ ] **Step 3: Add platform status**

Show “手机网页版正在建设中” only in development builds. Production readiness is determined by passing build, offline, content, and responsive acceptance—not by a hard-coded marketing claim.

### Task 8: Verify the foundation

- [ ] **Step 1: Run unit tests and production build**

Run:

```bash
npm test
npm run build
```

Expected: PASS and `dist/` created.

- [ ] **Step 2: Run responsive checks**

Verify at 360×800, 390×844, 768×1024, and 1366×768. No horizontal overflow; all interactive targets at least 44px; body text at least 16px on phones.

- [ ] **Step 3: Verify content integrity**

Re-run the source hash test and verify no original Russian or English resource changed.

- [ ] **Step 4: Document the next packaging boundary**

Create `Clients/Universal/README.md` with exact commands and a plain separation:

```text
当前交付：浏览器运行、可安装、离线核心学习。
下一打包步骤：iPhone/Android 原生容器与 Windows 桌面外壳；共用本客户端，不重写学习流程。
```

