import { describe, expect, it } from 'vitest'
import { loadProgress, progressKey, type StudyProgress } from '../src/domain/progress'
import { firstSessionKey, hasCompletedFirstSession, markFirstSessionCompleted, sessionCardCount } from '../src/domain/session'

function memoryStorage(entries: Record<string, string> = {}) {
  const values = new Map(Object.entries(entries))
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    value: (key: string) => values.get(key),
  }
}

describe('session restore', () => {
  const progress: StudyProgress = {
    language: 'english',
    date: '2026-08-03',
    currentIndex: 2,
    queueIDs: ['sentence:en-3', 'lexeme:en-2', 'challenge:en-7'],
    dailyMinutes: 10,
    attempts: [{
      sentenceID: 'sentence:en-3', responseTimeMs: 2100, outcome: 'fluentUnder3s',
      transferEvidence: 'a new reply', completedAt: '2026-08-03T08:00:00Z',
    }],
  }

  it('restores the same language, date, queue, index, and attempts', () => {
    const storage = memoryStorage({ [progressKey('english')]: JSON.stringify(progress) })
    expect(loadProgress('english', '2026-08-03', storage)).toEqual(progress)
  })

  it('does not expose English progress to Russian or a different date', () => {
    const raw = JSON.stringify(progress)
    const storage = memoryStorage({ [progressKey('english')]: raw })
    expect(loadProgress('russian', '2026-08-03', storage)).toBeNull()
    expect(loadProgress('english', '2026-08-04', storage)).toBeNull()
    expect(storage.value(progressKey('english'))).toBe(raw)
  })
})

describe('first experience and daily duration', () => {
  it('keeps the first completed-session marker separate by language', () => {
    const storage = memoryStorage()
    markFirstSessionCompleted('english', storage)
    expect(storage.value(firstSessionKey('english'))).toBe('true')
    expect(hasCompletedFirstSession('english', storage)).toBe(true)
    expect(hasCompletedFirstSession('russian', storage)).toBe(false)
  })

  it.each([
    [5, false, 3], [10, false, 3], [15, false, 3],
    [5, true, 3], [10, true, 5], [15, true, 8],
  ] as const)('maps %i minutes with completed=%s to %i cards', (minutes, completed, expected) => {
    expect(sessionCardCount(minutes, completed)).toBe(expected)
  })
})
