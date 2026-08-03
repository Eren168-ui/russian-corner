import type { ContentCatalog, PracticeLexeme, PracticeSentence, PracticeTopic } from '../domain/models'

type JsonObject = Record<string, unknown>

const text = (value: unknown, fallback = '') => typeof value === 'string' ? value : fallback
const strings = (value: unknown) => Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : []

function reviewed(item: JsonObject) {
  return item.reviewStatus === undefined || item.reviewStatus === 'reviewed'
}

export function decodeEnglishContent(
  sentenceSource: unknown[],
  lexemeSource: unknown[],
  topicSource: unknown[] = [],
): ContentCatalog {
  const sentences: PracticeSentence[] = sentenceSource
    .filter((item): item is JsonObject => Boolean(item) && typeof item === 'object')
    .filter((item) => reviewed(item) && item.language !== 'russian')
    .map((item) => ({
      id: text(item.id), language: 'english', promptZh: text(item.promptZh), cueTarget: text(item.cueText),
      targetText: text(item.targetText, text(item.displayText)), speechText: text(item.speechText, text(item.targetText)),
      topicID: text(item.topicID), lexemeIDs: strings(item.lexemeIDs), expectedReply: strings(item.expectedReplies)[0],
      source: text(item.sourcePath, '本地审核内容'),
    }))

  const sentenceByID = new Map(sentences.map((sentence) => [sentence.id, sentence]))
  const lexemes: PracticeLexeme[] = lexemeSource
    .filter((item): item is JsonObject => Boolean(item) && typeof item === 'object')
    .filter((item) => reviewed(item) && item.language !== 'russian')
    .map((item) => {
      const exampleID = strings(item.exampleSentenceIDs)[0]
      return {
        id: text(item.id), language: 'english', lemma: text(item.lemma, text(item.displayForm)),
        currentForm: text(item.displayForm, text(item.lemma)), glossZh: text(item.glossZh) || undefined,
        partOfSpeech: text(item.partOfSpeech) || undefined,
        grammar: [...strings(item.morphologyNotes), ...strings(item.inflections)], collocations: strings(item.collocations),
        example: sentenceByID.get(exampleID)?.targetText, source: text(item.sourcePath, '本地审核内容'),
      }
    })

  const topics: PracticeTopic[] = topicSource
    .filter((item): item is JsonObject => Boolean(item) && typeof item === 'object')
    .map((item) => ({ id: text(item.id), language: 'english', titleZh: text(item.titleZh), titleTarget: text(item.titleTarget) }))

  return { language: 'english', sentences, lexemes, topics }
}

export function decodeRussianContent(
  sentenceSource: unknown[],
  lexemeSource: unknown[],
  topicSource: unknown[] = [],
): ContentCatalog {
  const sentences: PracticeSentence[] = sentenceSource
    .filter((item): item is JsonObject => Boolean(item) && typeof item === 'object')
    .filter(reviewed)
    .map((item) => ({
      id: text(item.id), language: 'russian', promptZh: text(item.promptZh), cueTarget: text(item.cueRu),
      targetText: text(item.practiceRu), speechText: text(item.speechText, text(item.practiceRu)),
      topicID: text(item.topicID, text(item.theme)), lexemeIDs: strings(item.lexemeIDs), expectedReply: text(item.expectedReply) || undefined,
      source: text(item.sourcePath, '本地审核内容'),
    }))

  const lexemes: PracticeLexeme[] = lexemeSource
    .filter((item): item is JsonObject => Boolean(item) && typeof item === 'object')
    .filter(reviewed)
    .map((item) => ({
      id: text(item.id), language: 'russian', lemma: text(item.lemma),
      currentForm: text(item.stressedForm, text(item.lemma)), glossZh: text(item.glossZh) || undefined,
      partOfSpeech: text(item.partOfSpeech) || undefined,
      grammar: [text(item.aspect), text(item.aspectPair), text(item.government), text(item.usageNote)].filter(Boolean),
      collocations: strings(item.collocations), example: text(item.example) || undefined,
      source: strings(item.sourcePaths)[0] ?? text(item.sourcePath, '本地审核内容'),
    }))

  const topics: PracticeTopic[] = topicSource
    .filter((item): item is JsonObject => Boolean(item) && typeof item === 'object')
    .map((item) => ({ id: text(item.id), language: 'russian', titleZh: text(item.titleZh), titleTarget: text(item.titleRu) }))

  return { language: 'russian', sentences, lexemes, topics }
}
