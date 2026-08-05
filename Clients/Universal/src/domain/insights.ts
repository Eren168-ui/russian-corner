import type { PracticeCard, StudyLanguage } from './models'
import { localDateKey } from './dailyQueue'
import { progressKey, type RecallOutcome, type StudyAttempt, type StudyProgress } from './progress'

export interface HistoryAttempt extends StudyAttempt {
  id: string
  language: StudyLanguage
  cardID: string
  topicID: string
}

export interface DailyHistoryRecord {
  date: string
  completed: number
  correct: number
  attempts: number
  averageResponseMs: number
}

export interface LearningHistorySummary {
  todayCompleted: number
  todayTarget: number
  todayAccuracy: number | null
  streakDays: number
  masteredCount: number
  averageResponseMs: number
  recentDays: DailyHistoryRecord[]
}

export type NaturalSpeechAnswer = 'yes' | 'no' | 'unsure'
export type CompletionReason = 'completed' | 'time' | 'energy' | 'interrupted' | 'other'

export interface DailyReflectionRecord {
  language: StudyLanguage
  date: string
  mostBlocked: string
  naturalSpeech: NaturalSpeechAnswer
  naturalSpeechNote: string
  completionReason: CompletionReason
  completionReasonNote: string
  updatedAt: string
}

export interface DiagnosticScores {
  recognition: number
  production: number
  listening: number
  collocation: number
}

export interface DiagnosticReport {
  language: StudyLanguage
  completedAt: string
  scores: DiagnosticScores
}

const historyKey = (language: StudyLanguage) => `languageCorner.history.v1.${language}`
const reflectionKey = (language: StudyLanguage, date: string) => `languageCorner.reflection.v1.${language}.${date}`
const diagnosticKey = (language: StudyLanguage) => `languageCorner.diagnostic.v1.${language}`

function readJSON<T>(key: string, storage: Pick<Storage, 'getItem'>): T | null {
  const raw = storage.getItem(key)
  if (!raw) return null
  try {
    return JSON.parse(raw) as T
  } catch {
    return null
  }
}

export function loadHistoryAttempts(
  language: StudyLanguage,
  storage: Pick<Storage, 'getItem'> = localStorage,
): HistoryAttempt[] {
  const value = readJSON<unknown>(historyKey(language), storage)
  if (!Array.isArray(value)) return []
  return value.filter((item): item is HistoryAttempt => Boolean(
    item && typeof item === 'object'
      && (item as HistoryAttempt).language === language
      && typeof (item as HistoryAttempt).completedAt === 'string'
      && typeof (item as HistoryAttempt).cardID === 'string',
  ))
}

export function recordHistoryAttempt(
  language: StudyLanguage,
  card: PracticeCard,
  attempt: StudyAttempt,
  storage: Pick<Storage, 'getItem' | 'setItem'> = localStorage,
) {
  const id = `${card.id}:${attempt.completedAt}`
  const previous = loadHistoryAttempts(language, storage)
  if (previous.some((item) => item.id === id)) return
  const next: HistoryAttempt = {
    ...attempt,
    id,
    language,
    cardID: card.id,
    topicID: card.topicID,
  }
  storage.setItem(historyKey(language), JSON.stringify([...previous, next].slice(-2_000)))
}

function currentProgressAttempts(
  language: StudyLanguage,
  storage: Pick<Storage, 'getItem'>,
): HistoryAttempt[] {
  const value = readJSON<StudyProgress>(progressKey(language), storage)
  if (!value || value.language !== language || !Array.isArray(value.attempts)) return []
  return value.attempts.map((attempt, index) => ({
    ...attempt,
    id: `progress:${value.date}:${attempt.sentenceID}:${attempt.completedAt}:${index}`,
    language,
    cardID: attempt.sentenceID,
    topicID: 'current-session',
  }))
}

export function allHistoryAttempts(
  language: StudyLanguage,
  storage: Pick<Storage, 'getItem'> = localStorage,
) {
  const combined = [...loadHistoryAttempts(language, storage), ...currentProgressAttempts(language, storage)]
  const bySignature = new Map<string, HistoryAttempt>()
  for (const item of combined) bySignature.set(`${item.cardID}:${item.completedAt}`, item)
  return [...bySignature.values()].sort((a, b) => a.completedAt.localeCompare(b.completedAt))
}

const isCorrect = (outcome: RecallOutcome) => outcome === 'fluentUnder3s' || outcome === 'meaningButUsageIssue'

export function buildLearningHistory(
  language: StudyLanguage,
  todayTarget = 0,
  now = new Date(),
  storage: Pick<Storage, 'getItem'> = localStorage,
): LearningHistorySummary {
  const attempts = allHistoryAttempts(language, storage)
  const today = localDateKey(now)
  const recentDates = Array.from({ length: 7 }, (_, offset) => {
    const day = new Date(now)
    day.setHours(12, 0, 0, 0)
    day.setDate(day.getDate() - (6 - offset))
    return localDateKey(day)
  })
  const recentDays = recentDates.map((date) => {
    const items = attempts.filter((attempt) => localDateKey(new Date(attempt.completedAt)) === date)
    const responseTotal = items.reduce((sum, attempt) => sum + Math.max(0, attempt.responseTimeMs), 0)
    return {
      date,
      completed: items.length,
      correct: items.filter((attempt) => isCorrect(attempt.outcome)).length,
      attempts: items.length,
      averageResponseMs: items.length ? Math.round(responseTotal / items.length) : 0,
    }
  })
  const activeDates = new Set(attempts.map((attempt) => localDateKey(new Date(attempt.completedAt))))
  let streakDays = 0
  const cursor = new Date(now)
  cursor.setHours(12, 0, 0, 0)
  if (!activeDates.has(today)) cursor.setDate(cursor.getDate() - 1)
  while (activeDates.has(localDateKey(cursor))) {
    streakDays += 1
    cursor.setDate(cursor.getDate() - 1)
  }
  const todayRecord = recentDays.at(-1)!
  const fluentCards = new Set(attempts.filter((attempt) => attempt.outcome === 'fluentUnder3s').map((attempt) => attempt.cardID))
  const responseTotal = attempts.reduce((sum, attempt) => sum + Math.max(0, attempt.responseTimeMs), 0)
  return {
    todayCompleted: todayRecord.completed,
    todayTarget: Math.max(todayTarget, todayRecord.completed),
    todayAccuracy: todayRecord.attempts ? todayRecord.correct / todayRecord.attempts : null,
    streakDays,
    masteredCount: fluentCards.size,
    averageResponseMs: attempts.length ? Math.round(responseTotal / attempts.length) : 0,
    recentDays,
  }
}

export function loadReflection(
  language: StudyLanguage,
  date = localDateKey(),
  storage: Pick<Storage, 'getItem'> = localStorage,
) {
  const value = readJSON<DailyReflectionRecord>(reflectionKey(language, date), storage)
  return value?.language === language && value.date === date ? value : null
}

export function saveReflection(
  reflection: DailyReflectionRecord,
  storage: Pick<Storage, 'setItem'> = localStorage,
) {
  storage.setItem(reflectionKey(reflection.language, reflection.date), JSON.stringify(reflection))
}

export function loadDiagnosticReport(
  language: StudyLanguage,
  storage: Pick<Storage, 'getItem'> = localStorage,
) {
  const value = readJSON<DiagnosticReport>(diagnosticKey(language), storage)
  return value?.language === language ? value : null
}

export function saveDiagnosticReport(
  report: DiagnosticReport,
  storage: Pick<Storage, 'setItem'> = localStorage,
) {
  storage.setItem(diagnosticKey(report.language), JSON.stringify(report))
}

export function scorePercent(correct: number, total: number) {
  return total > 0 ? Math.round((correct / total) * 100) : 0
}

