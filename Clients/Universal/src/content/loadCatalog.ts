import { decodeEnglishContent, decodeRussianContent } from './adapters'
import type { ContentCatalog, StudyLanguage } from '../domain/models'

async function json(path: string): Promise<unknown> {
  const response = await fetch(`/content/${path}`)
  if (!response.ok) throw new Error(`无法读取本地内容：${path}`)
  return response.json()
}

export async function loadCatalog(language: StudyLanguage): Promise<ContentCatalog> {
  if (language === 'english') {
    const [sentences, lexemes, topics] = await Promise.all([
      json('english-sentences.json'), json('english-lexemes.json'), json('english-topics.json'),
    ])
    return decodeEnglishContent(sentences as unknown[], lexemes as unknown[], topics as unknown[])
  }

  const [longTerm, supplementalSentences, lexemes, supplementalLexemes, topics, challenges] = await Promise.all([
    json('long-term-sentences.json'), json('supplemental-sentences.json'), json('lexemes.json'),
    json('supplemental-lexemes.json'), json('topics.json'), json('speaking-challenges.json'),
  ])
  const baseSentences = (longTerm as { sentences?: unknown[] }).sentences ?? []
  return decodeRussianContent(
    [...baseSentences, ...(supplementalSentences as unknown[])],
    [...(lexemes as unknown[]), ...(supplementalLexemes as unknown[])],
    topics as unknown[], challenges as unknown[],
  )
}
