export type StudyLanguage = 'english' | 'russian'

export interface PracticeSentence {
  id: string
  language: StudyLanguage
  promptZh: string
  cueTarget: string
  targetText: string
  speechText: string
  topicID: string
  lexemeIDs: string[]
  expectedReply?: string
  transferHint?: string
  source: string
}

export interface PracticeLexeme {
  id: string
  language: StudyLanguage
  lemma: string
  currentForm: string
  glossZh?: string
  partOfSpeech?: string
  grammar: string[]
  collocations: string[]
  example?: string
  source: string
  sentenceIDs: string[]
  surfaceForms: string[]
}

export interface PracticeChallenge {
  id: string
  language: StudyLanguage
  promptZh: string
  promptTarget: string
  suggestedAnswer?: string
  topicID: string
  lexemeIDs: string[]
  structureHintsZh: string[]
  replacementSlots: string[]
  source: string
}

export interface PracticeTopic {
  id: string
  language: StudyLanguage
  titleZh: string
  titleTarget: string
}

export interface ContentCatalog {
  language: StudyLanguage
  sentences: PracticeSentence[]
  lexemes: PracticeLexeme[]
  topics: PracticeTopic[]
  challenges: PracticeChallenge[]
}

export type PracticeCardType = 'sentence' | 'lexeme' | 'challenge'

export interface PracticeCard {
  id: string
  sourceID: string
  cardType: PracticeCardType
  language: StudyLanguage
  promptZh: string
  cueTarget: string
  targetText: string
  speechText: string
  topicID: string
  lexemeIDs: string[]
  expectedReply?: string
  transferHint?: string
  source: string
}
