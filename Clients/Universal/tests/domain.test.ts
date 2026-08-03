import { describe, expect, it } from 'vitest'
import { decodeEnglishContent, decodeRussianContent } from '../src/content/adapters'
import { createDailyQueue } from '../src/domain/dailyQueue'
import { progressKey, recordAttempt, type StudyProgress } from '../src/domain/progress'

const englishSentence = {
  id: 'en-1', language: 'english', promptZh: '我正要给你发消息。', cueText: 'You were going to do it now.',
  targetText: 'I was just about to text you.', speechText: 'I was just about to text you.',
  topicID: 'en-topic', lexemeIDs: ['en-lex'], expectedReplies: ['Perfect timing.'], sourcePath: 'bundled/english',
}
const englishLexeme = {
  id: 'en-lex', language: 'english', lemma: 'text', displayForm: 'text', glossZh: '发消息',
  partOfSpeech: 'verb', collocations: ['text someone'], exampleSentenceIDs: ['en-1'], sourcePath: 'bundled/english',
}
const russianSentence = {
  id: 'ru-1', promptZh: '我最近住过一家不错的酒店。', cueRu: 'Как вы расскажете об отеле?',
  practiceRu: 'Я недавно останавливался в хорошем отеле.', speechText: 'Я недавно останавливался в хорошем отеле.',
  topicID: 'ru-topic', lexemeIDs: ['ru-lex'], expectedReply: 'А вы вернётесь?', sourcePath: 'course/russian.md',
}
const russianLexeme = {
  id: 'ru-lex', lemma: 'останавливаться', stressedForm: 'остана́вливаться', glossZh: '入住；暂住',
  partOfSpeech: 'verb', collocations: ['останавливаться в отеле'], example: 'Я останавливался в отеле.',
  sentenceIDs: ['ru-1'], sourcePaths: ['course/russian.md'],
}

describe('language-neutral adapters', () => {
  it('decodes English source shapes without leaking Russian entries', () => {
    const catalog = decodeEnglishContent([englishSentence], [englishLexeme])
    expect(catalog.language).toBe('english')
    expect(catalog.sentences[0]).toMatchObject({ targetText: englishSentence.targetText, cueTarget: englishSentence.cueText })
    expect(catalog.lexemes[0]).toMatchObject({ lemma: 'text', glossZh: '发消息' })
    expect(catalog.sentences.every((sentence) => sentence.language === 'english')).toBe(true)
  })

  it('decodes Russian source shapes without leaking English entries', () => {
    const catalog = decodeRussianContent([russianSentence], [russianLexeme])
    expect(catalog.language).toBe('russian')
    expect(catalog.sentences[0]).toMatchObject({ targetText: russianSentence.practiceRu, cueTarget: russianSentence.cueRu })
    expect(catalog.lexemes[0]).toMatchObject({ currentForm: 'остана́вливаться', glossZh: '入住；暂住' })
    expect(catalog.sentences.every((sentence) => sentence.language === 'russian')).toBe(true)
  })
})

describe('daily queue', () => {
  const ids = Array.from({ length: 12 }, (_, index) => ({
    id: `en-${index}`, language: 'english' as const, promptZh: englishSentence.promptZh,
    cueTarget: englishSentence.cueText, targetText: englishSentence.targetText, speechText: englishSentence.speechText,
    topicID: englishSentence.topicID, lexemeIDs: englishSentence.lexemeIDs, expectedReply: englishSentence.expectedReplies[0],
    source: englishSentence.sourcePath,
  }))

  it('is stable on the same local date and changes on another date', () => {
    const first = createDailyQueue(ids, 'english', '2026-08-03', 5).map((item) => item.id)
    const again = createDailyQueue(ids, 'english', '2026-08-03', 5).map((item) => item.id)
    const tomorrow = createDailyQueue(ids, 'english', '2026-08-04', 5).map((item) => item.id)
    expect(again).toEqual(first)
    expect(tomorrow).not.toEqual(first)
    expect(first).toHaveLength(5)
  })

  it('never accepts content from another language', () => {
    expect(() => createDailyQueue([{ ...ids[0], language: 'russian' }], 'english', '2026-08-03', 5)).toThrow(/language/i)
  })
})

describe('isolated progress and recall evidence', () => {
  it('uses a separate storage key for every language', () => {
    expect(progressKey('english')).toBe('languageCorner.progress.english')
    expect(progressKey('russian')).toBe('languageCorner.progress.russian')
  })

  it.each([
    'fluentUnder3s', 'meaningButUsageIssue', 'afterReveal', 'unknown',
  ] as const)('records %s with response time and transfer evidence', (outcome) => {
    const initial: StudyProgress = {
      language: 'english', date: '2026-08-03', currentIndex: 0, queueIDs: ['en-1'], dailyMinutes: 5, attempts: [],
    }
    const next = recordAttempt(initial, {
      sentenceID: 'en-1', responseTimeMs: 2450, outcome, transferEvidence: 'text my friend', completedAt: '2026-08-03T08:00:00Z',
    })
    expect(next.currentIndex).toBe(1)
    expect(next.attempts[0]).toMatchObject({ outcome, responseTimeMs: 2450, transferEvidence: 'text my friend' })
  })
})
