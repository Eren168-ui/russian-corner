import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it } from 'vitest'
import App from '../src/App'
import type { ContentCatalog } from '../src/domain/models'

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
    source: `bundled/${language}`,
  }],
})

describe('Language Corner app', () => {
  beforeEach(() => {
    localStorage.clear()
  })

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
})
