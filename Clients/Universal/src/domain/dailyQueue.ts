import type { PracticeSentence, StudyLanguage } from './models'

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

export function createDailyQueue<T extends PracticeSentence>(
  sentences: T[], language: StudyLanguage, localDate: string, count = 5,
): T[] {
  if (sentences.some((sentence) => sentence.language !== language)) {
    throw new Error('Daily queue language isolation violation')
  }
  const nextRandom = random(hashSeed(`${language}:${localDate}`))
  const shuffled = [...sentences]
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const other = Math.floor(nextRandom() * (index + 1))
    ;[shuffled[index], shuffled[other]] = [shuffled[other], shuffled[index]]
  }
  return shuffled.slice(0, Math.min(count, shuffled.length))
}

export function localDateKey(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
