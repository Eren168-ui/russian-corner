# Russian Corner catalog curation audit

Date: 2026-07-26
Scope: `ContentCatalog`, bundled `lexemes.json` / `sentences.json`, and catalog tests only
Editorial status: `reviewed`; this audit does not claim native-speaker `verified`

## TDD RED evidence

Command:

```bash
swift test --filter ContentCatalogTests
```

The first test-first run exited 1 with 21 assertion failures. It established:

- only 72 of 360 examples were unique;
- all 72 sentence cards had exactly five links;
- 14 collocations had a truncated function-word ending or an unbalanced quote;
- the validator did not report duplicate examples, truncated/unbalanced
  collocations, uniform link counts, or a sentence-side absent lexical form.

The raw run was retained at `/tmp/russian-corner-content-red.log` for this
work session.

## Full automated audit

The independent resource audit checks normalized Russian word sequences,
reciprocal links, source/status restrictions, duplicate content, quote
balance, collocation word counts and endings, and cross-lexeme surface-form
ownership.

| Check | Result |
|---|---:|
| reviewed lexemes | 360 |
| reviewed sentence cards | 72 |
| unique examples | 360 |
| linked lexemes | 360 |
| duplicate examples | 0 |
| example missing lemma/surface form | 0 |
| collocation missing lemma/surface form | 0 |
| collocation outside 2–6 words | 0 |
| truncated collocation | 0 |
| unbalanced collocation quotes | 0 |
| duplicate lemma | 0 |
| morphological duplicate | 0 |
| duplicate surface form within one lexeme | 0 |
| stressed form normalization mismatch | 0 |
| multisyllable stressed form missing stress mark | 0 |
| missing or non-reciprocal link | 0 |
| linked form absent from sentence | 0 |
| duplicate Russian practice sentence | 0 |
| duplicate Chinese prompt | 0 |
| excluded source path | 0 |

Sentence link-count distribution:

- 3 links: 6 cards
- 4 links: 21 cards
- 5 links: 18 cards
- 6 links: 21 cards
- 7 links: 6 cards

## Manual semantic and naturalness sample

Fifty lexemes were read as complete learning records: lemma, stress, Chinese
gloss, collocation, example, surface forms, and linked sentence context.

Sample:

```text
здравствуйте, спасибо, свидание, семья, родитель, внучка, светлый,
удобный, принимать, распорядок, свежий, ужин, банковский, скидка,
просить, счёт, приехать, через, вести, напротив, возможный, таять,
четверть, назначать, отвечать, фраза, советовать, поддерживать,
играть, бегать, собираться, бронировать, задерживаться, отправляться,
позвонить, или, разрядиться, подключиться, впору, волос, видеться,
если, приглашать, отказываться, чистый, записаться, прозрачный,
поздравлять, потерять, местонахождение
```

Twenty-four sentence cards were read against both languages and every linked
form:

```text
sentence-greetings-2, sentence-family-1, sentence-home-2,
sentence-daily-routine-2, sentence-food-1, sentence-shopping-2,
sentence-cafe-1, sentence-transport-1, sentence-city-1,
sentence-directions-2, sentence-weather-2, sentence-seasons-2,
sentence-time-1, sentence-calendar-1, sentence-language-learning-2,
sentence-health-2, sentence-hobbies-2, sentence-travel-2,
sentence-hotel-1, sentence-airport-2, sentence-technology-1,
sentence-invitations-2, sentence-services-1, sentence-emergencies-1
```

Issues found during the sample were repaired before final verification:

- replaced a repetitive mixed farewell with a natural contrast between
  `пока` and `до свидания`;
- removed aspect partners and derived nouns that had been provisionally
  treated as surface forms;
- made family co-residence, a dead phone, an invitation response, a delayed
  flight, and a lost wallet state the same fact in Russian and Chinese;
- replaced stiff singular generic season wording with natural plurals;
- clarified discount checking and removed the ambiguous wallet pronoun;
- changed `будет вести` to natural `ведёт` and completed governed
  collocations such as `играть на гитаре`, `собираться в поездку`,
  `подключиться к сети`, and `записаться на стрижку`.

`SentenceCard` currently has no `cueRu` field. This content-only change keeps
the existing schema intact; `speechText` is synchronized exactly with the
natural `practiceRu` cue for all 72 cards.
