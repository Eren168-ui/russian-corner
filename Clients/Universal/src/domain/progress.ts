import type { StudyLanguage } from './models'

export type RecallOutcome = 'fluentUnder3s' | 'meaningButUsageIssue' | 'afterReveal' | 'unknown'

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
  attempts: StudyAttempt[]
}

export const progressKey = (language: StudyLanguage) => `languageCorner.progress.${language}`

export function recordAttempt(progress: StudyProgress, attempt: StudyAttempt): StudyProgress {
  return { ...progress, currentIndex: progress.currentIndex + 1, attempts: [...progress.attempts, attempt] }
}

export function saveProgress(progress: StudyProgress, storage: Pick<Storage, 'setItem'> = localStorage) {
  storage.setItem(progressKey(progress.language), JSON.stringify(progress))
}
