import { beforeEach, describe, expect, it } from 'vitest'
import { buildLearningHistory, loadReflection, recordHistoryAttempt, saveReflection, scorePercent } from '../src/domain/insights'
import type { PracticeCard } from '../src/domain/models'
import { localDateKey } from '../src/domain/dailyQueue'

const card: PracticeCard = {
  id: 'sentence:test', sourceID: 'test', cardType: 'sentence', language: 'english',
  promptZh: '测试', cueTarget: '', targetText: 'Test it.', speechText: 'Test it.', topicID: 'daily', lexemeIDs: [], source: 'test',
}

describe('learning insights', () => {
  beforeEach(() => localStorage.clear())

  it('records a real attempt once and builds today statistics', () => {
    const completedAt = new Date().toISOString()
    const attempt = { sentenceID: card.id, responseTimeMs: 2400, outcome: 'fluentUnder3s' as const, transferEvidence: 'Test it later.', completedAt }
    recordHistoryAttempt('english', card, attempt)
    recordHistoryAttempt('english', card, attempt)
    const summary = buildLearningHistory('english', 3)
    expect(summary.todayCompleted).toBe(1)
    expect(summary.todayTarget).toBe(3)
    expect(summary.todayAccuracy).toBe(1)
    expect(summary.masteredCount).toBe(1)
  })

  it('persists one concise daily reflection', () => {
    const date = localDateKey()
    saveReflection({ language: 'russian', date, mostBlocked: '搭配', naturalSpeech: 'no', naturalSpeechNote: '', completionReason: 'time', completionReasonNote: '有课', updatedAt: new Date().toISOString() })
    expect(loadReflection('russian', date)?.mostBlocked).toBe('搭配')
    expect(scorePercent(2, 3)).toBe(67)
  })
})
