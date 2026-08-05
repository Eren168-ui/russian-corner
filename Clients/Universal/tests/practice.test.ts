import { describe, expect, it } from 'vitest'
import { buildDailyPracticeCards, buildPracticeCards } from '../src/domain/practiceCards'
import { createDailyQueue } from '../src/domain/dailyQueue'
import { requiresTransfer } from '../src/domain/progress'
import { resolveWord } from '../src/domain/wordResolution'
import type { ContentCatalog, PracticeLexeme, PracticeSentence } from '../src/domain/models'

const sentence: PracticeSentence = {
  id: 'en-sentence', language: 'english', promptZh: '我正要给你发消息。', cueTarget: 'You were going to do it now.',
  targetText: 'I was just about to text you.', speechText: 'I was just about to text you.', topicID: 'topic',
  lexemeIDs: ['phrase'], expectedReply: 'Perfect timing.', source: 'reviewed/english',
}
const phrase: PracticeLexeme = {
  id: 'phrase', language: 'english', lemma: 'be just about to text you', currentForm: 'be just about to text you',
  glossZh: '正要给你发消息', partOfSpeech: 'chunk', grammar: [], collocations: ['be about to do something'],
  example: sentence.targetText, source: 'reviewed/english', sentenceIDs: ['en-sentence'], surfaceForms: [],
}
const atomic: PracticeLexeme = {
  id: 'atomic', language: 'english', lemma: 'text', currentForm: 'text', glossZh: '发消息', partOfSpeech: 'verb',
  grammar: [], collocations: ['text someone'], example: 'Text me later.', source: 'reviewed/english',
  sentenceIDs: [], surfaceForms: ['texts', 'texted'],
}
const catalog: ContentCatalog = {
  language: 'english',
  topics: [{ id: 'topic', language: 'english', titleZh: '重逢', titleTarget: 'Reconnecting' }],
  sentences: [sentence],
  lexemes: [phrase, atomic],
  challenges: [{
    id: 'challenge', language: 'english', promptZh: sentence.promptZh, promptTarget: sentence.targetText,
    suggestedAnswer: sentence.expectedReply, topicID: 'topic', lexemeIDs: sentence.lexemeIDs,
    structureHintsZh: [], replacementSlots: [], source: sentence.source,
  }],
}

describe('three real practice card types', () => {
  it('builds scene sentence, reviewed lexeme/chunk, and speaking challenge cards', () => {
    const cards = buildPracticeCards(catalog)
    expect(new Set(cards.map((card) => card.cardType))).toEqual(new Set(['sentence', 'lexeme', 'challenge']))
    expect(cards.find((card) => card.cardType === 'lexeme' && card.sourceID === 'atomic')).toMatchObject({ targetText: 'text', promptZh: '发消息' })
    expect(cards.find((card) => card.cardType === 'challenge')).toMatchObject({ targetText: 'Perfect timing.', source: 'reviewed/english' })
  })

  it('keeps the daily active-recall queue semantically consistent with complete scene sentences', () => {
    const queue = createDailyQueue(buildDailyPracticeCards(catalog), 'english', '2026-08-03', 3)
    expect(queue).toHaveLength(1)
    expect(queue.every((card) => card.cardType === 'sentence')).toBe(true)
    expect(queue[0]).toMatchObject({ promptZh: '我正要给你发消息。', targetText: 'I was just about to text you.' })
  })
})

describe('atomic word resolution', () => {
  it('never presents a linked sentence chunk as the meaning of one token', () => {
    const phraseOnly = { ...catalog, lexemes: [phrase] }
    const resolution = resolveWord('text', sentence, phraseOnly)
    expect(resolution.atomic).toBeUndefined()
    expect(resolution.phrases).toEqual([phrase])
  })

  it('prefers an exact global atomic entry over a linked multiword chunk', () => {
    const resolution = resolveWord('text', sentence, catalog)
    expect(resolution.atomic?.id).toBe('atomic')
    expect(resolution.phrases[0]?.id).toBe('phrase')
  })

  it('finds an exact Russian surface form globally when the sentence has no lexeme IDs', () => {
    const russianSentence: PracticeSentence = {
      ...sentence, id: 'ru-sentence', language: 'russian', targetText: 'Я недавно останавливался в отеле.',
      speechText: 'Я недавно останавливался в отеле.', lexemeIDs: [], source: 'reviewed/russian',
    }
    const russianLexeme: PracticeLexeme = {
      ...atomic, id: 'ru-lexeme', language: 'russian', lemma: 'останавливаться', currentForm: 'остана́вливаться',
      glossZh: '入住；暂住', surfaceForms: ['останавливался'], source: 'reviewed/russian',
    }
    const resolution = resolveWord('останавливался', russianSentence, {
      language: 'russian', sentences: [russianSentence], lexemes: [russianLexeme], topics: [], challenges: [],
    })
    expect(resolution.atomic?.id).toBe('ru-lexeme')
  })
})

describe('transfer gate', () => {
  it.each([
    ['fluentUnder3s', true],
    ['meaningButUsageIssue', true],
    ['afterReveal', false],
    ['unknown', false],
  ] as const)('requires transfer for %s = %s', (outcome, expected) => {
    expect(requiresTransfer(outcome)).toBe(expected)
  })
})
