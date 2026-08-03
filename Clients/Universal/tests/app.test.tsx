import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from '../src/App'
import type { ContentCatalog, StudyLanguage } from '../src/domain/models'
import { localDateKey } from '../src/domain/dailyQueue'
import { firstSessionKey } from '../src/domain/session'
import { progressKey, type StudyProgress } from '../src/domain/progress'

const makeCatalog = (language: 'english' | 'russian'): ContentCatalog => ({
  language,
  topics: [{ id: `${language}-topic`, language, titleZh: language === 'english' ? '重逢与近况' : '酒店经历', titleTarget: language === 'english' ? 'Reconnecting' : 'Гостиница' }],
  sentences: Array.from({ length: 6 }, (_, index) => ({
    id: `${language}-sentence-${index}`,
    language,
    promptZh: language === 'english' ? `我正要给你发消息。${index}` : `我最近住过一家不错的酒店。${index}`,
    cueTarget: language === 'english' ? 'You were going to do it now.' : 'Как вы расскажете об отеле?',
    targetText: language === 'english' ? 'I was just about to text you.' : 'Я недавно останавливался в хорошем отеле.',
    speechText: language === 'english' ? 'I was just about to text you.' : 'Я недавно останавливался в хорошем отеле.',
    topicID: `${language}-topic`, lexemeIDs: [`${language}-lex`],
    expectedReply: language === 'english' ? 'Perfect timing.' : 'А вы вернётесь?', source: `bundled/${language}`,
  })),
  lexemes: [{
    id: `${language}-lex`, language,
    lemma: language === 'english' ? 'text' : 'останавливаться',
    currentForm: language === 'english' ? 'text' : 'останавливался',
    glossZh: language === 'english' ? '发消息' : '入住；暂住', partOfSpeech: 'verb',
    grammar: language === 'english' ? ['动词'] : ['未完成体'],
    collocations: [language === 'english' ? 'text someone' : 'останавливаться в отеле'],
    example: language === 'english' ? 'Text me later.' : 'Я останавливался в отеле.',
    source: `bundled/${language}`, sentenceIDs: [`${language}-sentence-0`], surfaceForms: language === 'english' ? ['texts', 'texted'] : ['останавливался'],
  }],
  challenges: [{
    id: `${language}-challenge`, language,
    promptZh: language === 'english' ? '及时回应对方。' : '谈谈你的酒店经历。',
    promptTarget: language === 'english' ? 'I was just about to text you.' : 'Как вы расскажете об отеле?',
    suggestedAnswer: language === 'english' ? 'Perfect timing.' : undefined,
    topicID: `${language}-topic`, lexemeIDs: [`${language}-lex`], structureHintsZh: ['先回应，再补充细节'],
    replacementSlots: ['人物'], source: `bundled/${language}`,
  }],
})

function seedProgress(language: StudyLanguage, queueIDs: string[], currentIndex = 0, dailyMinutes = 5) {
  const value: StudyProgress = {
    language, date: localDateKey(), currentIndex, queueIDs, dailyMinutes,
    attempts: currentIndex > 0 ? [{
      sentenceID: queueIDs[0], responseTimeMs: 2200, outcome: 'fluentUnder3s',
      transferEvidence: 'saved transfer', completedAt: new Date().toISOString(),
    }] : [],
  }
  localStorage.setItem(progressKey(language), JSON.stringify(value))
  return value
}

describe('Language Corner app', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  afterEach(() => vi.useRealTimers())

  it('shows the brand and switches between English and Russian', async () => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    expect(screen.getByText('LANGUAGE CORNER')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '英语' })).toHaveAttribute('aria-pressed', 'true')
    await user.click(screen.getByRole('button', { name: '俄语' }))
    expect(screen.getByRole('button', { name: '俄语' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('手机打开即可使用')).toBeInTheDocument()
  })

  it('moves from prompt to reveal, word detail, transfer, outcome, and the next real card', async () => {
    const user = userEvent.setup()
    seedProgress('english', [
      'sentence:english-sentence-0', 'sentence:english-sentence-1', 'sentence:english-sentence-2',
    ])
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '每天 5 分钟' }))
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText(/我正要给你发消息。/)).toBeInTheDocument()
    expect(screen.getByText('1 / 3')).toBeInTheDocument()

    expect(screen.getByRole('button', { name: '查看提示' })).toBeDisabled()
    await waitFor(() => expect(screen.getByRole('button', { name: '查看提示' })).toBeEnabled(), { timeout: 4000 })
    await user.click(screen.getByRole('button', { name: '查看提示' }))
    expect(screen.getByText('You were going to do it now.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: '揭晓答案' }))

    const answer = screen.getByTestId('target-answer')
    await user.click(within(answer).getByRole('button', { name: 'text' }))
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('发消息')
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('text someone')

    await user.click(screen.getByRole('button', { name: '想到意思，但用法不稳' }))
    expect(screen.getByText('先完成迁移任务，再进入下一张。')).toBeInTheDocument()
    await user.type(screen.getByLabelText('迁移回答'), 'text my friend')
    await user.click(screen.getByRole('button', { name: '想到意思，但用法不稳' }))
    await user.click(screen.getByRole('button', { name: '下一张' }))
    expect(screen.getByText('2 / 3')).toBeInTheDocument()
  })

  it('offers three practice environments without requesting privileged access', async () => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByRole('button', { name: '安静看一遍' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '戴耳机听和跟读' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '现在可以开口' })).toBeInTheDocument()
    expect(document.body).not.toHaveTextContent(/登录|麦克风|通知/)
  })

  it('restores the saved queue, current index, and attempts for the same language and date', async () => {
    const user = userEvent.setup()
    const saved = seedProgress('english', [
      'sentence:english-sentence-4', 'lexeme:english-lex', 'challenge:english-challenge',
    ], 1, 10)
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText('2 / 3')).toBeInTheDocument()
    expect(screen.getByText('词汇 / 句块')).toBeInTheDocument()
    expect(JSON.parse(localStorage.getItem(progressKey('english'))!)).toEqual(saved)
  })

  it('rebuilds a topic queue without clearing completed attempts or transfer evidence', async () => {
    const user = userEvent.setup()
    const saved = seedProgress('english', [
      'sentence:english-sentence-0', 'lexeme:english-lex', 'challenge:english-challenge',
    ], 1)
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    await user.selectOptions(screen.getByLabelText('主题'), 'english-topic')
    const updated = JSON.parse(localStorage.getItem(progressKey('english'))!) as StudyProgress
    expect(updated.currentIndex).toBe(0)
    expect(updated.attempts).toEqual(saved.attempts)
    expect(updated.attempts[0].transferEvidence).toBe('saved transfer')
  })

  it('freezes response time when the learner requests the hint', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2030-01-02T08:00:00Z'))
    seedProgress('english', ['sentence:english-sentence-0'])
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: '开始今天练习' }))
    })
    act(() => vi.advanceTimersByTime(3000))
    fireEvent.click(screen.getByRole('button', { name: '查看提示' }))
    expect(screen.getByRole('button', { name: '揭晓答案' })).toBeInTheDocument()

    act(() => vi.advanceTimersByTime(20_000))
    fireEvent.click(screen.getByRole('button', { name: '揭晓答案' }))
    fireEvent.click(within(screen.getByTestId('target-answer')).getByRole('button', { name: 'text' }))
    fireEvent.change(screen.getByLabelText('迁移回答'), { target: { value: 'text my friend' } })
    fireEvent.click(screen.getByRole('button', { name: '流利说出（3 秒内）' }))

    const updated = JSON.parse(localStorage.getItem(progressKey('english'))!) as StudyProgress
    expect(updated.attempts[0].responseTimeMs).toBe(3000)
  })

  it('keeps the first experience at three cards, then lets 15 minutes produce eight', async () => {
    const user = userEvent.setup()
    const { unmount } = render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '每天 15 分钟' }))
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText('1 / 3')).toBeInTheDocument()
    unmount()

    localStorage.removeItem(progressKey('english'))
    localStorage.setItem(firstSessionKey('english'), 'true')
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '每天 15 分钟' }))
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText('1 / 8')).toBeInTheDocument()
  })

  it.each([
    [0, '场景句'], [1, '词汇 / 句块'], [2, '开口挑战'],
  ] as const)('renders restored card type at index %i as %s', async (currentIndex, label) => {
    const user = userEvent.setup()
    seedProgress('english', [
      'sentence:english-sentence-0', 'lexeme:english-lex', 'challenge:english-challenge',
    ], currentIndex)
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText(label)).toBeInTheDocument()
  })

  it('shows linked phrase meaning separately and lets afterReveal continue without transfer', async () => {
    const user = userEvent.setup()
    const phraseCatalog = makeCatalog('english')
    phraseCatalog.lexemes = [{
      ...phraseCatalog.lexemes[0], id: 'phrase-only', lemma: 'be just about to text you',
      currentForm: 'be just about to text you', glossZh: '正要给你发消息', surfaceForms: [],
    }]
    phraseCatalog.sentences[0].lexemeIDs = ['phrase-only']
    seedProgress('english', ['sentence:english-sentence-0'])
    render(<App catalogLoader={async () => phraseCatalog} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    await waitFor(() => expect(screen.getByRole('button', { name: '查看提示' })).toBeEnabled(), { timeout: 4000 })
    await user.click(screen.getByRole('button', { name: '查看提示' }))
    await user.click(screen.getByRole('button', { name: '揭晓答案' }))
    await user.click(within(screen.getByTestId('target-answer')).getByRole('button', { name: 'text' }))
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('本地暂无这个单词的单独释义')
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('本句已审核句块')
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('正要给你发消息')
    await user.click(screen.getByRole('button', { name: '揭晓后想起' }))
    expect(screen.getByRole('button', { name: '完成今天练习' })).toBeInTheDocument()
  })
})
