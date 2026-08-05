import type { StudyLanguage } from './models'

const excludedVoiceNames = /albert|bad news|bahh|bells|boing|bubbles|cellos|deranged|good news|hysterical|jester|organ|superstar|trinoids|whisper|wobble|zarvox|novelty|compact/i
const preferredNames: Record<StudyLanguage, RegExp[]> = {
  english: [/samantha/i, /ava/i, /allison/i, /susan/i, /daniel/i, /google.*english/i, /microsoft.*(aria|jenny|guy)/i],
  russian: [/milena/i, /katya/i, /yuri/i, /google.*рус/i, /google.*russian/i, /microsoft.*(svetlana|dmitry)/i],
}

const languagePrefix = (language: StudyLanguage) => language === 'english' ? 'en' : 'ru'
const exactLocales: Record<StudyLanguage, string[]> = {
  english: ['en-US', 'en-GB'],
  russian: ['ru-RU'],
}

export function voiceScore(voice: SpeechSynthesisVoice, language: StudyLanguage) {
  if (excludedVoiceNames.test(voice.name)) return -1_000
  let score = 0
  if (exactLocales[language].some((locale) => voice.lang.toLowerCase() === locale.toLowerCase())) score += 30
  if (voice.localService) score += 20
  if (voice.default) score += 12
  const preferredIndex = preferredNames[language].findIndex((pattern) => pattern.test(voice.name))
  if (preferredIndex >= 0) score += 100 - preferredIndex * 7
  if (/natural|neural|enhanced|premium/i.test(voice.name)) score += 35
  return score
}

export function rankedVoices(language: StudyLanguage, voices: SpeechSynthesisVoice[]) {
  const prefix = languagePrefix(language)
  return voices
    .filter((voice) => voice.lang.toLowerCase().startsWith(prefix))
    .filter((voice) => !excludedVoiceNames.test(voice.name))
    .sort((left, right) => voiceScore(right, language) - voiceScore(left, language) || left.name.localeCompare(right.name))
}

export function speakText(text: string, language: StudyLanguage, voice?: SpeechSynthesisVoice | null) {
  if (!('speechSynthesis' in window) || !text.trim()) return false
  const selected = voice ?? rankedVoices(language, window.speechSynthesis.getVoices())[0] ?? null
  const utterance = new SpeechSynthesisUtterance(text)
  utterance.lang = language === 'english' ? 'en-US' : 'ru-RU'
  utterance.rate = language === 'english' ? 0.94 : 0.9
  utterance.pitch = 1
  if (selected) utterance.voice = selected
  window.speechSynthesis.cancel()
  window.speechSynthesis.speak(utterance)
  return true
}
