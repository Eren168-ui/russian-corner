import { describe, expect, it } from 'vitest'
import { rankedVoices } from '../src/domain/speech'

const voice = (name: string, lang: string, localService = true, isDefault = false) => ({
  name, lang, localService, default: isDefault, voiceURI: name,
} as SpeechSynthesisVoice)

describe('speech voice selection', () => {
  it('rejects novelty voices and prefers a natural English voice', () => {
    const result = rankedVoices('english', [voice('Bubbles', 'en-US'), voice('Samantha', 'en-US'), voice('Generic English', 'en-US')])
    expect(result.map((item) => item.name)).not.toContain('Bubbles')
    expect(result[0].name).toBe('Samantha')
  })

  it('keeps Russian voices separate and prefers the known natural voice', () => {
    const result = rankedVoices('russian', [voice('Daniel', 'en-GB'), voice('Milena', 'ru-RU'), voice('Generic Russian', 'ru-RU')])
    expect(result.map((item) => item.name)).toEqual(['Milena', 'Generic Russian'])
  })
})
