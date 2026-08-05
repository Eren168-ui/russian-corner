import type { StudyLanguage } from './models'

export interface OnlineDictionaryEntry {
  lemma: string
  partOfSpeech?: string
  translations: string[]
  synonyms: string[]
  source: string
}

export async function lookupOnlineDictionary(
  word: string,
  language: StudyLanguage,
  signal?: AbortSignal,
): Promise<OnlineDictionaryEntry> {
  const query = new URLSearchParams({ word, language })
  const response = await fetch(`/api/dictionary/v6?${query}`, { signal })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json() as Promise<OnlineDictionaryEntry>
}
