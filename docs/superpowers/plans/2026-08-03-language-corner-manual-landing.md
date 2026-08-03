# Language Corner Manual Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old Russian-only poster page with a bilingual, beginner-readable product introduction and user manual that truthfully distinguishes the available macOS app from the soon-to-launch phone and Windows clients.

**Architecture:** Keep the existing self-contained HTML/CSS/JavaScript site and Playwright export flow. Rebuild the content as 14 semantic export sections, keep all demonstrations local, add deterministic export modes, and publish the same user-facing copy in a standalone Markdown manual.

**Tech Stack:** Semantic HTML5, CSS custom properties and responsive layout, vanilla JavaScript, Node.js 22, Playwright, Sharp, Markdown.

---

## File map

- Modify: `/Users/Openclawworkspace/workspace/russian-corner-landing/index.html` — 14-section manual landing page.
- Modify: `/Users/Openclawworkspace/workspace/russian-corner-landing/styles.css` — bilingual editorial visual system and responsive behavior.
- Modify: `/Users/Openclawworkspace/workspace/russian-corner-landing/script.js` — navigation, language demos, word panels, checklist, export state.
- Modify: `/Users/Openclawworkspace/workspace/russian-corner-landing/export.mjs` — manual, product-story, and section exports.
- Modify: `/Users/Openclawworkspace/workspace/russian-corner-landing/README.md` — preview and export instructions.
- Create: `/Users/Openclawworkspace/workspace/russian-corner-landing/package.json` — local export/test commands.
- Create: `/Users/Openclawworkspace/workspace/russian-corner-landing/tests/landing.test.mjs` — content and accessibility regression checks.
- Create: `/Users/Openclawworkspace/workspace/russian-corner-landing/assets/language-corner-icon.png` — self-contained copy of the real app icon.
- Create: `/Users/Openclawworkspace/workspace/russian-corner/Documentation/LANGUAGE_CORNER_USER_GUIDE.md` — standalone user manual.

### Task 1: Protect the old page and establish content tests

- [ ] **Step 1: Preserve a dated copy of the current page files**

Create `/Users/Openclawworkspace/workspace/russian-corner-landing/archive/2026-08-03-v1/` and copy `index.html`, `styles.css`, `script.js`, `export.mjs`, and `README.md` into it. Do not move or delete the originals.

- [ ] **Step 2: Add a local Node package**

Create `package.json` with scripts:

```json
{
  "name": "language-corner-landing",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test tests/*.test.mjs",
    "export": "node export.mjs"
  },
  "devDependencies": {
    "playwright": "^1.59.1",
    "sharp": "^0.34.5"
  }
}
```

- [ ] **Step 3: Write the failing content regression test**

The test must read `index.html` and assert:

```js
assert.match(html, /LANGUAGE CORNER/);
assert.match(html, /当前可用/);
assert.match(html, /即将上线/);
assert.match(html, /English|英语/);
assert.match(html, /Русский|俄语/);
assert.equal((html.match(/data-export-section=/g) || []).length, 14);
assert.doesNotMatch(html, /PWA|Tauri|Capacitor|Flutter/);
assert.doesNotMatch(html, /AI 发音评分|已经支持 Windows|已经支持 iPhone/);
```

- [ ] **Step 4: Run the test and verify it fails against the old page**

Run: `npm test`

Expected: FAIL because the old page is Russian-only and has nine export sections.

### Task 2: Write the user manual copy

- [ ] **Step 1: Create `Documentation/LANGUAGE_CORNER_USER_GUIDE.md`**

Use this user-facing order:

```markdown
# Language Corner 使用手册

## 先用一句话认识它
## 为什么不是普通背单词软件
## 现在可以在哪里使用
## 第一次打开：五分钟完成设置
## 一张卡的正确练法
## 英语和俄语分别怎么练
## 点击句中单词能看到什么
## 每天怎样安排最省力
## 悬浮卡、折叠和隐藏
## 学习诊断、今日反馈和学习记录
## 通知、朗读、麦克风和网络
## 常见问题
## 手机、iPhone、安卓和 Windows 版本
```

Every section must answer “what this does” before “where to click.” Use “手机打开即可使用” and “可安装到手机桌面” in user copy; never use implementation terms such as PWA, Tauri, Capacitor, runtime, store schema, or service worker.

- [ ] **Step 2: Verify the manual has no developer jargon**

Run:

```bash
rg -n 'PWA|Tauri|Capacitor|Flutter|SwiftData|runtime|schema|service worker' Documentation/LANGUAGE_CORNER_USER_GUIDE.md
```

Expected: no matches.

### Task 3: Rebuild the HTML information architecture

- [ ] **Step 1: Replace the old nine-section body with 14 semantic sections**

Each section must have a unique `id` and `data-export-section="NN-slug"`. The section order must be:

```text
01 what-it-is
02 why-speaking-stalls
03 available-platforms
04 learning-loop
05 first-five-minutes
06 one-card
07 clickable-words
08 two-languages
09 english-scenes
10 desktop-controls
11 daily-routines
12 review-and-diagnostics
13 privacy-and-content
14 start-and-roadmap
```

- [ ] **Step 2: Add truthful platform status cards**

The visible labels must be:

```html
<span class="status status-live">macOS · 当前可用</span>
<span class="status status-soon">手机打开即用 · 即将上线</span>
<span class="status status-soon">iPhone / Android · 即将上线</span>
<span class="status status-soon">Windows · 即将上线</span>
```

Do not render inactive fake download buttons.

- [ ] **Step 3: Add current bilingual content facts**

Use exactly:

```text
俄语：440 词条、274 条长期表达、24 个开口挑战、32 个主题
英语：400 词条、200 条表达、20 个主题、20 节微场景
```

Add a note that counts describe bundled reviewed content, not guaranteed learning outcomes.

- [ ] **Step 4: Add the four recall outcomes and transfer evidence**

Visible copy must distinguish:

```text
3 秒内完整说出
意思正确，但搭配或用法有问题
揭晓后才想起来
完全不会
```

Explain that a collocation, next reply, or slot-replacement task is required after fluent or partial recall.

### Task 4: Build the bilingual interactive demonstrations

- [ ] **Step 1: Keep one Russian and one English clickable sentence**

Russian example:

```text
Я хочу́ уточни́ть, прошла́ ли бронь.
```

English example:

```text
I was wondering if we could move it to Friday.
```

- [ ] **Step 2: Extend `script.js` with a language-neutral word dictionary**

Use data keys rather than language-specific function names:

```js
const WORDS = {
  utochnit: {
    language: "ru",
    display: "уточни́ть",
    meaning: "确认；核实",
    grammar: "完成体动词；未完成体 уточня́ть",
    collocations: ["уточни́ть вре́мя", "уточни́ть дета́ли"],
    example: "Мо́жно уточни́ть а́дрес доста́вки?"
  },
  wondering: {
    language: "en",
    display: "wondering",
    meaning: "想知道；用于委婉提出请求",
    grammar: "wonder 的现在分词；I was wondering if... 为委婉句型",
    collocations: ["I was wondering if", "I wonder whether"],
    example: "I was wondering if we could reschedule."
  }
};
```

Clicking a word must update only the local word panel, keep the page position stable, and set `aria-expanded` on the active word button.

- [ ] **Step 3: Add navigation, reading progress, and a local checklist**

Persist checklist state only in `localStorage` under `languageCorner.landing.checklist`. Do not send analytics or network requests.

- [ ] **Step 4: Add deterministic export behavior**

When `?export=1` is present, reveal all content, disable transitions, hide the sticky navigation, set the Russian and English demo panels to predetermined states, and expand the five-minute checklist.

### Task 5: Upgrade the visual system and responsive layout

- [ ] **Step 1: Preserve the editorial foundation**

Keep warm paper, navy/charcoal ink, ruled dividers, serif Chinese headings, and dark product cards. Add language tokens:

```css
:root {
  --paper: #f3efe5;
  --ink: #17212d;
  --navy: #0d2038;
  --russian: #2468c9;
  --english: #c45d3f;
  --live: #2f7b5b;
  --soon: #9b6b32;
}
```

- [ ] **Step 2: Add responsive breakpoints**

At 768px and below, all two-column layouts become one column. At 390px, card padding decreases but body text remains at least 16px. Interactive targets must have `min-height: 44px` and `min-width: 44px`.

- [ ] **Step 3: Add accessible focus and reduced motion**

Use `:focus-visible` with a 3px outline. Under `prefers-reduced-motion: reduce` and `.export-static`, set all transition and animation durations to `0.01ms` and make all reveal elements visible.

- [ ] **Step 4: Copy the real icon locally**

Copy `Assets/AppIcon/RussianCorner-source.png` to `russian-corner-landing/assets/language-corner-icon.png`. Reference only the relative asset path from HTML.

### Task 6: Make exports reproducible

- [ ] **Step 1: Rewrite `export.mjs` around section screenshots**

Export each of the 14 sections first. Build the full manual and selected product-story long images by vertically joining section PNGs with Sharp; do not rely on one browser screenshot taller than 30,000 pixels.

- [ ] **Step 2: Use versioned output names**

Generate:

```text
exports/2026-08-03-language-corner-manual-full.png
exports/2026-08-03-language-corner-product-story.png
exports/2026-08-03-01-what-it-is.png
exports/2026-08-03-02-why-speaking-stalls.png
exports/2026-08-03-03-available-platforms.png
exports/2026-08-03-04-learning-loop.png
exports/2026-08-03-05-first-five-minutes.png
exports/2026-08-03-06-one-card.png
exports/2026-08-03-07-clickable-words.png
exports/2026-08-03-08-two-languages.png
exports/2026-08-03-09-english-scenes.png
exports/2026-08-03-10-desktop-controls.png
exports/2026-08-03-11-daily-routines.png
exports/2026-08-03-12-review-and-diagnostics.png
exports/2026-08-03-13-privacy-and-content.png
exports/2026-08-03-14-start-and-roadmap.png
```

- [ ] **Step 3: Run tests and exports**

Run:

```bash
npm install
npm test
npm run export
```

Expected: all tests pass and both long images plus 14 section images exist.

### Task 7: Browser acceptance and documentation

- [ ] **Step 1: Test 360, 390, 768, and 1440px viewports**

Assert there is no horizontal overflow:

```js
document.documentElement.scrollWidth <= document.documentElement.clientWidth
```

- [ ] **Step 2: Verify keyboard and word-panel behavior**

Tab through the sticky navigation, both language tabs, both word examples, and the checklist. Confirm visible focus and no scroll jump when word details change.

- [ ] **Step 3: Update README**

Document the bilingual brand, local preview, `?export=1`, `npm test`, `npm run export`, the two long-image outputs, and the difference between current macOS availability and upcoming clients.

- [ ] **Step 4: Run the final acceptance**

Run:

```bash
npm test
npm run export
```

Expected: PASS, with no console errors, missing images, truncated Russian stress marks, or stale `russian-corner-landing-full.png` references in README.
