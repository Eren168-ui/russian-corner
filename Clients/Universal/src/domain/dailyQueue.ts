import type { PracticeCardType, StudyLanguage } from './models'

interface QueueItem {
  id: string
  language: StudyLanguage
  cardType?: PracticeCardType
}

function hashSeed(value: string) {
  let hash = 2166136261
  for (const character of value) {
    hash ^= character.charCodeAt(0)
    hash = Math.imul(hash, 16777619)
  }
  return hash >>> 0
}

function random(seed: number) {
  let state = seed || 0x9e3779b9
  return () => {
    state += 0x6d2b79f5
    let value = state
    value = Math.imul(value ^ value >>> 15, value | 1)
    value ^= value + Math.imul(value ^ value >>> 7, value | 61)
    return ((value ^ value >>> 14) >>> 0) / 4294967296
  }
}

function shuffled<T>(items: T[], seed: number) {
  const nextRandom = random(seed)
  const result = [...items]
  for (let index = result.length - 1; index > 0; index -= 1) {
    const other = Math.floor(nextRandom() * (index + 1))
    ;[result[index], result[other]] = [result[other], result[index]]
  }
  return result
}

export function createDailyQueue<T extends QueueItem>(
  sentences: T[], language: StudyLanguage, localDate: string, count = 5,
): T[] {
  if (sentences.some((sentence) => sentence.language !== language)) {
    throw new Error('Daily queue language isolation violation')
  }
  const typed = sentences.filter((sentence) => sentence.cardType)
  const types: PracticeCardType[] = ['sentence', 'lexeme', 'challenge']
  if (typed.length === sentences.length && types.every((type) => typed.some((item) => item.cardType === type))) {
    const typeOrder = shuffled(types, hashSeed(`${language}:${localDate}:types`))
    const groups = new Map(typeOrder.map((type) => [
      type,
      shuffled(sentences.filter((item) => item.cardType === type), hashSeed(`${language}:${localDate}:${type}`)),
    ]))
    const mixed: T[] = []
    let round = 0
    while (mixed.length < Math.min(count, sentences.length)) {
      let added = false
      for (const type of typeOrder) {
        const item = groups.get(type)?.[round]
        if (item) {
          mixed.push(item)
          added = true
          if (mixed.length === Math.min(count, sentences.length)) return mixed
        }
      }
      if (!added) break
      round += 1
    }
    return mixed
  }
  return shuffled(sentences, hashSeed(`${language}:${localDate}`)).slice(0, Math.min(count, sentences.length))
}

export function localDateKey(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
