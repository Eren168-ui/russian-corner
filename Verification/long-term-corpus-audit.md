# 长期俄语语料只读审查报告

- topicsRead: 32
- candidates: 483
- excluded: 251

## Exclusion counts

- aiGeneratedSource: 6
- conflictSource: 3
- emptyDialogue: 20
- variant: 222

## Manual readback

- reviewedCount: 64
- accepted: [candidate-topic-03-0277393c7df0, candidate-topic-03-0c87ee7aaab6, candidate-topic-04-37acbe4ff96e, candidate-topic-04-2f3ce71076ff, candidate-topic-05-5d789c5270c3, candidate-topic-05-766a88ab03fa, candidate-topic-06-86c8983bd640, candidate-topic-07-94850490b25f, candidate-topic-07-8c3992359bad, candidate-topic-08-aa654665ea92, candidate-topic-10-3c2e0cc4e5c8, candidate-topic-10-c4dac9576b94, candidate-topic-11-853a6f8d3efa, candidate-topic-11-b789e5443b74, candidate-topic-12-2b3131e760c2, candidate-topic-12-f0e4e9dfab04, candidate-topic-13-94a3f5f0aac9, candidate-topic-13-91631d31a26b, candidate-topic-14-28b86dc95817, candidate-topic-14-c07f4cf74c77, candidate-topic-15-ee05fd983ca3, candidate-topic-16-d4b27dfe91c5, candidate-topic-17-6ddb18ba204e, candidate-topic-17-a6df6dba4ffe, candidate-topic-18-d1cce70d187c, candidate-topic-18-b2dde611ec75, candidate-topic-19-05dd9fe44747, candidate-topic-19-e7687ee9c39b, candidate-topic-20-10bdb03010d2, candidate-topic-20-570f3a527c23, candidate-topic-21-35a0aa49271c, candidate-topic-21-c8156f86c284, candidate-topic-22-bbbbc15e35ab, candidate-topic-22-12a592e7b8c7, candidate-topic-23-9672d58555f9, candidate-topic-23-889933282716, candidate-topic-24-595b0dc118aa, candidate-topic-24-dfe84027aba7, candidate-topic-25-4cc85e5266ca, candidate-topic-25-a4e4db9b3af3, candidate-topic-26-2714ccd08d62, candidate-topic-26-5e7f44ecfdea, candidate-topic-27-7630321be321, candidate-topic-27-0d31f6eaf565, candidate-topic-28-da722f151350, candidate-topic-29-f4ab77d07721, candidate-topic-29-bbf2bd3c2873, candidate-topic-30-d29b892123fb, candidate-topic-31-373e0c924ba2, candidate-topic-31-00e34ece4c20, candidate-topic-32-6910cfaa3e1d, candidate-topic-32-eca3212ef024]
- rejected: [candidate-topic-01-e06711089fc7, candidate-topic-01-9dcd0a66217b, candidate-topic-02-e1a78fe70b54, candidate-topic-02-5fd00a8ff070, candidate-topic-06-d37313df2664, candidate-topic-08-221a9600b4b9, candidate-topic-09-6e64a68e6d79, candidate-topic-09-bdd1be4cd79c, candidate-topic-15-14351567a976, candidate-topic-16-42c3d874970a, candidate-topic-28-1b2b528140df, candidate-topic-30-ce898bd4c9d4]
- rejectionReasons:
  - belowLearnerLevel: 5
  - incomplete: 3
  - typo: 1
  - grammarSuspect: 1
  - ambiguousTranslation: 1
  - possiblyDated: 1

所有候选均保持 draft；本报告不改写原始笔记。

## Final manifest readback

- reviewedCount: 220
- accepted: 214
- rejected: 6
- rejectedIDs: [longterm-t04-14b373ff336c, longterm-t06-78b8c6d9974a, longterm-t07-8c3992359bad, longterm-t24-5878045dcfbf, longterm-t31-373e0c924ba2, longterm-t32-89d9a0d9955a]
- reasons: possiblyDated / mixedPrompt / possiblyDated / unnatural / punctuationSuspect / governmentSuspect

## Stress annotation audit

- engine: Silero Stress 1.4 (local inference, MIT)
- annotatedSentences: 214
- automaticGate: every multisyllabic Cyrillic word has a combining acute mark or `ё`
- canonicalTextGate: removing stress marks and normalizing `ё/е` must reproduce `practiceRu`
- manualReadback: 54 evenly distributed sentences
- contextualCorrections:
  - `Мне уже́ лу́чше.`
  - `У нас экза́мены уже́ на носу́.`
  - `Ско́лько сто́ит э́та су́мка?`
- sourceNotesChanged: 0
