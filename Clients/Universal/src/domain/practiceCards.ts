import type { ContentCatalog, PracticeCard } from './models'

export function buildDailyPracticeCards(catalog: ContentCatalog): PracticeCard[] {
  return catalog.sentences.map((sentence) => ({
    ...sentence,
    id: `sentence:${sentence.id}`,
    sourceID: sentence.id,
    cardType: 'sentence',
  }))
}

export function buildPracticeCards(catalog: ContentCatalog): PracticeCard[] {
  const sentenceCards = buildDailyPracticeCards(catalog)

  const lexemeCards: PracticeCard[] = catalog.lexemes
    .filter((lexeme) => Boolean(lexeme.glossZh && lexeme.currentForm))
    .map((lexeme) => {
      const linkedSentence = catalog.sentences.find((sentence) =>
        lexeme.sentenceIDs.includes(sentence.id) || sentence.lexemeIDs.includes(lexeme.id),
      )
      return {
        id: `lexeme:${lexeme.id}`,
        sourceID: lexeme.id,
        cardType: 'lexeme',
        language: catalog.language,
        promptZh: lexeme.glossZh!,
        cueTarget: lexeme.collocations[0] ?? lexeme.currentForm,
        targetText: lexeme.currentForm,
        speechText: lexeme.lemma,
        topicID: linkedSentence?.topicID ?? 'lexicon',
        lexemeIDs: [lexeme.id],
        source: lexeme.source,
      }
    })

  const challengeCards: PracticeCard[] = catalog.challenges
    .filter((challenge) => Boolean(challenge.promptZh && challenge.promptTarget))
    .map((challenge) => ({
      id: `challenge:${challenge.id}`,
      sourceID: challenge.id,
      cardType: 'challenge',
      language: catalog.language,
      promptZh: challenge.promptZh,
      cueTarget: challenge.promptTarget,
      targetText: challenge.suggestedAnswer ?? challenge.promptTarget,
      speechText: challenge.suggestedAnswer ?? challenge.promptTarget,
      topicID: challenge.topicID,
      lexemeIDs: challenge.lexemeIDs,
      transferHint: challenge.structureHintsZh.join('；') || undefined,
      source: challenge.source,
    }))

  return [...sentenceCards, ...lexemeCards, ...challengeCards]
}
