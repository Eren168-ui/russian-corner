import type { StudyLanguage } from './models'

export type RecallOutcome = 'fluentUnder3s' | 'meaningButUsageIssue' | 'afterReveal' | 'unknown'

export const requiresTransfer = (outcome: RecallOutcome) => outcome === 'fluentUnder3s' || outcome === 'meaningButUsageIssue'

export interface StudyAttempt {
  sentenceID: string
  responseTimeMs: number
  outcome: RecallOutcome
  transferEvidence: string
  completedAt: string
}

export interface StudyProgress {
  language: StudyLanguage
  date: string
  currentIndex: number
  queueIDs: string[]
  dailyMinutes: number
  attempts: StudyAttempt[]
}

export const progressKey = (language: StudyLanguage) => `languageCorner.progress.${language}`

export function recordAttempt(progress: StudyProgress, attempt: StudyAttempt): StudyProgress {
  return { ...progress, currentIndex: progress.currentIndex + 1, attempts: [...progress.attempts, attempt] }
}

export function saveProgress(progress: StudyProgress, storage: Pick<Storage, 'setItem'> = localStorage) {
  storage.setItem(progressKey(progress.language), JSON.stringify(progress))
}

export function loadProgress(
  language: StudyLanguage,
  date: string,
  storage: Pick<Storage, 'getItem'> = localStorage,
): StudyProgress | null {
  const raw = storage.getItem(progressKey(language))
  if (!raw) return null
  try {
    const value = JSON.parse(raw) as Partial<StudyProgress>
    if (
      value.language !== language || value.date !== date ||
      !Number.isInteger(value.currentIndex) || (value.currentIndex ?? -1) < 0 ||
      !Array.isArray(value.queueIDs) || !value.queueIDs.every((id) => typeof id === 'string') ||
      !Array.isArray(value.attempts) || typeof value.dailyMinutes !== 'number'
    ) return null
    return value as StudyProgress
  } catch {
    return null
  }
}
