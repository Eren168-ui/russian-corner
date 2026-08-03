import type { StudyLanguage } from './models'

export const firstSessionKey = (language: StudyLanguage) => `languageCorner.firstSessionCompleted.${language}`

export function hasCompletedFirstSession(
  language: StudyLanguage,
  storage: Pick<Storage, 'getItem'> = localStorage,
) {
  return storage.getItem(firstSessionKey(language)) === 'true'
}

export function markFirstSessionCompleted(
  language: StudyLanguage,
  storage: Pick<Storage, 'setItem'> = localStorage,
) {
  storage.setItem(firstSessionKey(language), 'true')
}

export function sessionCardCount(minutes: number, completedFirstSession: boolean) {
  if (!completedFirstSession) return 3
  if (minutes >= 15) return 8
  if (minutes >= 10) return 5
  return 3
}
