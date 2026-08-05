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

export function sessionCardCount(minutes: number, _completedFirstSession: boolean) {
  if (minutes >= 15) return 22
  if (minutes >= 10) return 15
  return 8
}
