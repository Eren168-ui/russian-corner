import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from '../src/App'
import type { ContentCatalog, StudyLanguage } from '../src/domain/models'
import { localDateKey } from '../src/domain/dailyQueue'
import { progressKey, type StudyProgress } from '../src/domain/progress'

const makeCatalog = (language: 'english' | 'russian'): ContentCatalog => ({
  language,
  topics: [{ id: `${language}-topic`, language, titleZh: language === 'english' ? '重逢与近况' : '酒店经历', titleTarget: language === 'english' ? 'Reconnecting' : 'Гостиница' }],
  sentences: Array.from({ length: 24 }, (_, index) => ({
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

const makeDiagnosticCatalog = (): ContentCatalog => {
  const catalog = makeCatalog('russian')
  const entries = [
    ['здравствуйте', '您好', 'вежливо сказать «здравствуйте»', 'Здравствуйте!'],
    ['уточнить', '确认；弄清楚', 'уточнить детали', 'Я хочу уточнить детали заказа.'],
    ['договориться', '商量好；约定', 'договориться о встрече', 'Давайте договоримся о времени встречи.'],
    ['предупредить', '提前告知；提醒', 'предупредить об изменениях', 'Предупредите меня об изменениях заранее.'],
    ['перенести', '改期；挪到别的时间', 'перенести встречу', 'Можно перенести встречу на завтра?'],
    ['разобраться', '弄明白；处理清楚', 'разобраться в ситуации', 'Мне нужно разобраться в этой ситуации.'],
    ['подтвердить', '确认；证实', 'подтвердить бронирование', 'Подтвердите, пожалуйста, бронирование.'],
  ] as const
  catalog.lexemes = entries.map(([lemma, glossZh, collocation, example], index) => ({
    id: `diagnostic-lexeme-${index}`, language: 'russian', lemma, currentForm: lemma,
    glossZh, partOfSpeech: 'verb', grammar: ['动词体与支配关系'], collocations: [collocation],
    example, source: 'reviewed/russian', sentenceIDs: [`diagnostic-sentence-${index}`], surfaceForms: [],
  }))
  catalog.sentences = entries.map(([, glossZh, , targetText], index) => ({
    id: `diagnostic-sentence-${index}`, language: 'russian', promptZh: `${glossZh}：在日常场景中把意思完整说出来。`,
    cueTarget: 'Скажите это естественно.', targetText, speechText: targetText,
    topicID: 'russian-topic', lexemeIDs: [`diagnostic-lexeme-${index}`],
    expectedReply: index % 2 ? 'Хорошо, давайте.' : 'Понятно, спасибо.', source: 'reviewed/russian',
  }))
  return catalog
}

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

function sentenceQueue(language: StudyLanguage, firstIndex = 0, count = 8) {
  const indexes = [firstIndex, ...Array.from({ length: 24 }, (_, index) => index).filter((index) => index !== firstIndex)]
  return indexes.slice(0, count).map((index) => `sentence:${language}-sentence-${index}`)
}

describe('Language Corner app', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('shows the brand and switches between English and Russian', async () => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    expect(screen.getByText(/LANGUAGE CORNER/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '切换到英语' })).toHaveAttribute('aria-pressed', 'true')
    await user.click(screen.getByRole('button', { name: '切换到俄语' }))
    expect(screen.getByRole('button', { name: '切换到俄语' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('今天练 俄语')).toBeInTheDocument()
    expect(screen.getByText(/学习进度保存在当前设备/)).toBeInTheDocument()
  })

  it('explains phone installation without requesting permissions', async () => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '查看安装方法' }))
    expect(screen.getByText('iPhone：')).toBeInTheDocument()
    expect(screen.getAllByText(/添加到主屏幕/).length).toBe(2)
    expect(document.body).not.toHaveTextContent(/通知权限|麦克风权限|登录账号/)
  })

  it('moves from prompt to reveal, optional transfer, outcome, and the next real card', async () => {
    const user = userEvent.setup()
    seedProgress('english', sentenceQueue('english'))
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '每天 5 分钟' }))
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText(/我正要给你发消息。/)).toBeInTheDocument()
    expect(screen.getByText('1 / 8')).toBeInTheDocument()

    expect(screen.getByRole('button', { name: '显示答案' })).toBeDisabled()
    await waitFor(() => expect(screen.getByRole('button', { name: '显示答案' })).toBeEnabled(), { timeout: 4000 })
    await user.click(screen.getByRole('button', { name: '显示答案' }))

    const answer = screen.getByTestId('target-answer')
    await user.click(within(answer).getByRole('button', { name: 'text' }))
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('发消息')
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('text someone')

    await user.click(screen.getByRole('button', { name: '想到意思，但用法不稳' }))
    expect(screen.getByText('迁移任务')).toHaveTextContent('选做')
    await user.click(screen.getByRole('button', { name: '下一项' }))
    expect(screen.getByText('2 / 8')).toBeInTheDocument()
  })

  it('offers three practice environments without requesting privileged access', async () => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    await user.click(screen.getByRole('button', { name: '练习设置' }))
    expect(await screen.findByRole('button', { name: '安静看一遍' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '戴耳机听和跟读' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '现在可以开口' })).toBeInTheDocument()
    expect(document.body).not.toHaveTextContent(/登录|麦克风|通知/)
  })

  it('restores the saved queue, current index, and attempts for the same language and date', async () => {
    const user = userEvent.setup()
    const saved = seedProgress('english', sentenceQueue('english', 4), 1)
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText('2 / 8')).toBeInTheDocument()
    expect(screen.getByText('场景句')).toBeInTheDocument()
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
    seedProgress('english', sentenceQueue('english'))
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: '开始今天练习' }))
    })
    act(() => vi.advanceTimersByTime(3000))
    fireEvent.click(screen.getByRole('button', { name: '显示答案' }))

    act(() => vi.advanceTimersByTime(20_000))
    fireEvent.click(within(screen.getByTestId('target-answer')).getByRole('button', { name: 'text' }))
    fireEvent.change(screen.getByLabelText('迁移回答'), { target: { value: 'text my friend' } })
    fireEvent.click(screen.getByRole('button', { name: '流利说出（3 秒内）' }))

    const updated = JSON.parse(localStorage.getItem(progressKey('english'))!) as StudyProgress
    expect(updated.attempts[0].responseTimeMs).toBe(3000)
  })

  it.each([
    [5, 8], [10, 15], [15, 22],
  ] as const)('uses %i minutes to create %i complete scene-sentence cards on first use', async (minutes, expectedCount) => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: `每天 ${minutes} 分钟` }))
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText(`1 / ${expectedCount}`)).toBeInTheDocument()
    expect(screen.getByText('场景句')).toBeInTheDocument()
  })

  it('migrates an old mixed three-card queue into the consistent sentence queue', async () => {
    const user = userEvent.setup()
    seedProgress('english', [
      'sentence:english-sentence-0', 'lexeme:english-lex', 'challenge:english-challenge',
    ])
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    expect(await screen.findByText('1 / 8')).toBeInTheDocument()
    expect(screen.getByText('场景句')).toBeInTheDocument()
    const migrated = JSON.parse(localStorage.getItem(progressKey('english'))!) as StudyProgress
    expect(migrated.queueIDs).toHaveLength(8)
    expect(migrated.queueIDs.every((id) => id.startsWith('sentence:'))).toBe(true)
  })

  it('shows linked phrase meaning separately and lets afterReveal continue without transfer', async () => {
    const user = userEvent.setup()
    const phraseCatalog = makeCatalog('english')
    phraseCatalog.lexemes = [{
      ...phraseCatalog.lexemes[0], id: 'phrase-only', lemma: 'be just about to text you',
      currentForm: 'be just about to text you', glossZh: '正要给你发消息', surfaceForms: [],
    }]
    phraseCatalog.sentences[0].lexemeIDs = ['phrase-only']
    seedProgress('english', sentenceQueue('english'))
    render(<App catalogLoader={async () => phraseCatalog} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    await waitFor(() => expect(screen.getByRole('button', { name: '显示答案' })).toBeEnabled(), { timeout: 4000 })
    await user.click(screen.getByRole('button', { name: '显示答案' }))
    await user.click(within(screen.getByTestId('target-answer')).getByRole('button', { name: 'text' }))
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('本地暂无这个单词的单独释义')
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('本句已审核句块')
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('正要给你发消息')
    await user.click(screen.getByRole('button', { name: '揭晓后想起' }))
    expect(screen.getByRole('button', { name: '下一项' })).toBeInTheDocument()
  })

  it('loads an online Chinese meaning when an English word has no local entry', async () => {
    const user = userEvent.setup()
    const phraseCatalog = makeCatalog('english')
    phraseCatalog.lexemes = [{
      ...phraseCatalog.lexemes[0], id: 'phrase-only', lemma: 'be figuring it out',
      currentForm: 'figuring it out', glossZh: '摸索清楚', surfaceForms: [],
    }]
    phraseCatalog.sentences[0] = {
      ...phraseCatalog.sentences[0],
      promptZh: '我还在摸索。',
      targetText: "I'm still figuring it out.",
      speechText: "I'm still figuring it out.",
      lexemeIDs: ['phrase-only'],
    }
    seedProgress('english', sentenceQueue('english'))
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        lemma: 'figure',
        partOfSpeech: 'verb',
        translations: ['理解；弄清楚'],
        synonyms: [],
        source: 'yandex-bridge',
      }),
    }))

    render(<App catalogLoader={async () => phraseCatalog} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    await waitFor(() => expect(screen.getByRole('button', { name: '显示答案' })).toBeEnabled(), { timeout: 4000 })
    await user.click(screen.getByRole('button', { name: '显示答案' }))
    await user.click(within(screen.getByTestId('target-answer')).getByRole('button', { name: 'figuring' }))

    expect(await screen.findByText('理解；弄清楚')).toBeInTheDocument()
    expect(screen.getByRole('region', { name: '词义详情' })).toHaveTextContent('在线词典 · 未人工审核')
    expect(fetch).toHaveBeenCalledWith(
      '/api/dictionary/v6?word=figuring&language=english',
      expect.objectContaining({ signal: expect.any(AbortSignal) }),
    )
  })

  it('loads an online Chinese meaning when a local lexeme exists without a gloss', async () => {
    const user = userEvent.setup()
    const catalog = makeCatalog('english')
    catalog.lexemes[0] = {
      ...catalog.lexemes[0], lemma: 'tonight', currentForm: 'tonight', glossZh: undefined,
      surfaceForms: ['tonight'], collocations: [], grammar: [],
    }
    catalog.sentences[0] = {
      ...catalog.sentences[0], targetText: "Thanks, I'll get to it tonight.",
      speechText: "Thanks, I'll get to it tonight.",
    }
    seedProgress('english', sentenceQueue('english'))
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ lemma: 'tonight', translations: ['今晚；今夜'], synonyms: [], source: 'yandex-bridge' }),
    }))

    render(<App catalogLoader={async () => catalog} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))
    await waitFor(() => expect(screen.getByRole('button', { name: '显示答案' })).toBeEnabled(), { timeout: 4000 })
    await user.click(screen.getByRole('button', { name: '显示答案' }))
    await user.click(within(screen.getByTestId('target-answer')).getByRole('button', { name: 'tonight' }))

    expect(await screen.findByText('今晚；今夜')).toBeInTheDocument()
    expect(fetch).toHaveBeenCalledWith(
      '/api/dictionary/v6?word=tonight&language=english',
      expect.objectContaining({ signal: expect.any(AbortSignal) }),
    )
  })

  it('uses one visible settings entry and an explicit close action', async () => {
    const user = userEvent.setup()
    seedProgress('english', sentenceQueue('english'))
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)
    await user.click(screen.getByRole('button', { name: '开始今天练习' }))

    expect(screen.getAllByRole('button', { name: '练习设置' })).toHaveLength(1)
    await user.click(screen.getByRole('button', { name: '练习设置' }))
    expect(screen.getByRole('complementary', { name: '本次练习设置' })).toBeVisible()
    await user.click(screen.getByRole('button', { name: '关闭练习设置' }))
    expect(screen.queryByRole('complementary', { name: '本次练习设置' })).not.toBeInTheDocument()
  })

  it('switches the whole product theme and opens the three functional workspaces', async () => {
    const user = userEvent.setup()
    render(<App catalogLoader={async (language) => makeCatalog(language)} />)

    await user.click(screen.getByRole('button', { name: '切换深色模式' }))
    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(localStorage.getItem('languageCorner.theme')).toBe('dark')

    await user.click(screen.getByRole('button', { name: '学习记录' }))
    expect(screen.getByRole('heading', { name: '英语学习记录' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: '今日反馈' }))
    expect(screen.getByRole('heading', { name: '今天卡在哪里？' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('今天最卡的一处'), '临时想不起搭配')
    await user.click(screen.getByRole('button', { name: '保存今日反馈' }))
    expect(screen.getByRole('button', { name: '已保存到这台设备' })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '能力检测' }))
    expect(screen.getByRole('heading', { name: '口语能力检查' })).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: '开始 20 题检查' })).toBeEnabled()
  })

  it('starts an A2+ oral check with five useful questions per skill and skips A1 greetings', async () => {
    const user = userEvent.setup()
    const catalog = makeDiagnosticCatalog()
    render(<App catalogLoader={async () => catalog} />)
    await user.click(screen.getByRole('button', { name: '切换到俄语' }))
    await user.click(screen.getByRole('button', { name: '能力检测' }))

    expect(screen.getByRole('heading', { name: '口语能力检查' })).toBeInTheDocument()
    await user.click(await screen.findByRole('button', { name: '开始 20 题检查' }))
    expect(screen.getByText('第 1 题 / 共 5 题')).toBeInTheDocument()
    expect(document.body).not.toHaveTextContent('здравствуйте')
  })

  it('explains every diagnostic answer in plain Chinese instead of vague AI wording', async () => {
    const user = userEvent.setup()
    const catalog = makeDiagnosticCatalog()
    render(<App catalogLoader={async () => catalog} />)
    await user.click(screen.getByRole('button', { name: '切换到俄语' }))
    await user.click(screen.getByRole('button', { name: '能力检测' }))
    await user.click(await screen.findByRole('button', { name: '开始 20 题检查' }))
    const firstOption = document.querySelector<HTMLButtonElement>('.diagnostic-options button')
    expect(firstOption).not.toBeNull()
    await user.click(firstOption!)

    const explanation = screen.getByRole('region', { name: '本题解析' })
    expect(explanation).toHaveTextContent('正确答案')
    expect(explanation).toHaveTextContent('为什么')
    expect(explanation).toHaveTextContent('怎么用')
    expect(explanation).not.toHaveTextContent('这次没有取出来')
    expect(explanation).not.toHaveTextContent('真实语料')
  })
})
