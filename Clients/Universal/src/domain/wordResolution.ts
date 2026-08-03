import type { ContentCatalog, PracticeCard, PracticeLexeme, PracticeSentence } from './models'

export interface WordResolution {
  atomic?: PracticeLexeme
  phrases: PracticeLexeme[]
}

const normalize = (value: string) => value.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase().trim()
const words = (value: string): string[] => normalize(value).match(/[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*/gu) ?? []
const forms = (lexeme: PracticeLexeme) => [lexeme.lemma, lexeme.currentForm, ...lexeme.surfaceForms].filter(Boolean)

const exact = (lexeme: PracticeLexeme, token: string) => forms(lexeme).some((form) => normalize(form) === token)
const containsAtBoundary = (lexeme: PracticeLexeme, token: string) => forms(lexeme).some((form) => words(form).includes(token))
const shortestForm = (lexeme: PracticeLexeme) => Math.min(...forms(lexeme).map((form) => normalize(form).length))

export function resolveWord(
  word: string,
  item: Pick<PracticeSentence | PracticeCard, 'lexemeIDs'>,
  catalog: ContentCatalog,
): WordResolution {
  const token = normalize(word)
  const linked = item.lexemeIDs
    .map((id) => catalog.lexemes.find((lexeme) => lexeme.id === id))
    .filter((lexeme): lexeme is PracticeLexeme => Boolean(lexeme))
    .sort((left, right) => shortestForm(left) - shortestForm(right))

  const linkedAtomic = linked.find((lexeme) => exact(lexeme, token))
  const globalAtomic = catalog.lexemes
    .filter((lexeme) => lexeme.language === catalog.language && exact(lexeme, token))
    .sort((left, right) => shortestForm(left) - shortestForm(right))[0]
  const phrases = linked.filter((lexeme) => !exact(lexeme, token) && containsAtBoundary(lexeme, token))

  return { atomic: linkedAtomic ?? globalAtomic, phrases }
}
