import { useEffect, useMemo, useRef, useState } from 'react'
import { loadCatalog } from './content/loadCatalog'
import { createDailyQueue, localDateKey } from './domain/dailyQueue'
import type { ContentCatalog, PracticeLexeme, PracticeSentence, StudyLanguage } from './domain/models'
import { recordAttempt, saveProgress, type RecallOutcome, type StudyProgress } from './domain/progress'

type CatalogLoader = (language: StudyLanguage) => Promise<ContentCatalog>
type Stage = 'prompt' | 'hint' | 'revealed' | 'rated'

const outcomes: { value: RecallOutcome; label: string; short: string }[] = [
  { value: 'fluentUnder3s', label: '流利说出（3 秒内）', short: '流利' },
  { value: 'meaningButUsageIssue', label: '想到意思，但用法不稳', short: '用法不稳' },
  { value: 'afterReveal', label: '揭晓后想起', short: '揭晓后想起' },
  { value: 'unknown', label: '完全不会', short: '完全不会' },
]

const languageLabel = (language: StudyLanguage) => language === 'english' ? '英语' : '俄语'
const locale = (language: StudyLanguage) => language === 'english' ? 'en-US' : 'ru-RU'
const normalizeWord = (value: string) => value.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase()

function useVoice(language: StudyLanguage) {
  const [voice, setVoice] = useState<SpeechSynthesisVoice | null>(null)

  useEffect(() => {
    if (!('speechSynthesis' in window)) return
    const update = () => {
      const prefix = locale(language).slice(0, 2).toLowerCase()
      setVoice(window.speechSynthesis.getVoices().find((candidate) => candidate.lang.toLowerCase().startsWith(prefix)) ?? null)
    }
    update()
    window.speechSynthesis.addEventListener('voiceschanged', update)
    return () => window.speechSynthesis.removeEventListener('voiceschanged', update)
  }, [language])

  return voice
}

function WordDetail({ word, lexeme, sentence, onClose }: {
  word: string
  lexeme?: PracticeLexeme
  sentence: PracticeSentence
  onClose: () => void
}) {
  return (
    <aside className="word-sheet" role="region" aria-label="词义详情">
      <div className="word-sheet__handle" aria-hidden="true" />
      <div className="word-sheet__heading">
        <div>
          <span className="eyebrow">刚才点的词</span>
          <h3>{word}</h3>
        </div>
        <button className="icon-button" onClick={onClose} aria-label="关闭词义详情">×</button>
      </div>
      <dl className="word-grid">
        <div><dt>中文义</dt><dd>{lexeme?.glossZh || '本地内容暂未提供单独释义'}</dd></div>
        <div><dt>原形 / 当前形式</dt><dd>{lexeme ? `${lexeme.lemma} / ${lexeme.currentForm}` : `${word} / ${word}`}</dd></div>
        <div><dt>语法</dt><dd>{[lexeme?.partOfSpeech, ...(lexeme?.grammar ?? [])].filter(Boolean).join('；') || '本地内容暂无语法说明'}</dd></div>
        <div><dt>搭配</dt><dd>{lexeme?.collocations.join('；') || '本地内容暂无搭配'}</dd></div>
        <div><dt>例句</dt><dd>{lexeme?.example || sentence.targetText}</dd></div>
        <div><dt>来源</dt><dd>{lexeme?.source || sentence.source}</dd></div>
      </dl>
    </aside>
  )
}

function TargetWords({ sentence, catalog, onSelect }: {
  sentence: PracticeSentence
  catalog: ContentCatalog
  onSelect: (word: string, lexeme?: PracticeLexeme) => void
}) {
  const linked = sentence.lexemeIDs.map((id) => catalog.lexemes.find((lexeme) => lexeme.id === id)).filter(Boolean) as PracticeLexeme[]
  const tokens = sentence.targetText.match(/[\p{L}\p{M}]+(?:['’’-][\p{L}\p{M}]+)*|[^\p{L}\p{M}]+/gu) ?? [sentence.targetText]
  return (
    <p className="target-words" data-testid="target-answer">
      {tokens.map((token, index) => {
        if (!/[\p{L}\p{M}]/u.test(token)) return <span key={`${token}-${index}`}>{token}</span>
        const normalized = normalizeWord(token)
        const lexeme = linked.find((entry) => normalizeWord(`${entry.lemma} ${entry.currentForm}`).includes(normalized))
        return <button key={`${token}-${index}`} onClick={() => onSelect(token, lexeme)}>{token}</button>
      })}
    </p>
  )
}

export default function App({ catalogLoader = loadCatalog }: { catalogLoader?: CatalogLoader }) {
  const [language, setLanguage] = useState<StudyLanguage>('english')
  const [dailyMinutes, setDailyMinutes] = useState(5)
  const [catalog, setCatalog] = useState<ContentCatalog | null>(null)
  const [queue, setQueue] = useState<PracticeSentence[]>([])
  const [cardIndex, setCardIndex] = useState(0)
  const [stage, setStage] = useState<Stage>('prompt')
  const [hintReady, setHintReady] = useState(false)
  const [selectedWord, setSelectedWord] = useState<{ word: string; lexeme?: PracticeLexeme } | null>(null)
  const [transferEvidence, setTransferEvidence] = useState('')
  const [transferError, setTransferError] = useState(false)
  const [chosenOutcome, setChosenOutcome] = useState<RecallOutcome | null>(null)
  const [environment, setEnvironment] = useState('quiet')
  const [selectedTopic, setSelectedTopic] = useState('all')
  const [loading, setLoading] = useState(false)
  const [loadError, setLoadError] = useState('')
  const [finished, setFinished] = useState(false)
  const [progress, setProgress] = useState<StudyProgress | null>(null)
  const promptStartedAt = useRef(Date.now())
  const current = queue[cardIndex]
  const voice = useVoice(language)

  useEffect(() => {
    if (!current) return
    setHintReady(false)
    promptStartedAt.current = Date.now()
    const timer = window.setTimeout(() => setHintReady(true), 3000)
    return () => window.clearTimeout(timer)
  }, [current])

  const topic = useMemo(() => catalog?.topics.find((item) => item.id === current?.topicID), [catalog, current])

  async function startSession() {
    setLoading(true)
    setLoadError('')
    try {
      const loaded = await catalogLoader(language)
      if (loaded.language !== language || loaded.sentences.some((sentence) => sentence.language !== language)) {
        throw new Error('内容语言校验失败')
      }
      const date = localDateKey()
      const daily = createDailyQueue(loaded.sentences, language, date, 5).slice(0, 3)
      if (!daily.length) throw new Error('本地审核内容为空')
      setCatalog(loaded)
      setQueue(daily)
      setProgress({ language, date, currentIndex: 0, attempts: [] })
      setCardIndex(0)
      setStage('prompt')
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : '内容读取失败')
    } finally {
      setLoading(false)
    }
  }

  function chooseTopic(topicID: string) {
    if (!catalog) return
    const source = topicID === 'all' ? catalog.sentences : catalog.sentences.filter((sentence) => sentence.topicID === topicID)
    const next = createDailyQueue(source, language, localDateKey(), 5).slice(0, 3)
    setSelectedTopic(topicID)
    setQueue(next)
    setCardIndex(0)
    setStage('prompt')
    setSelectedWord(null)
  }

  function speak() {
    if (!voice || !current) return
    const utterance = new SpeechSynthesisUtterance(current.speechText)
    utterance.lang = locale(language)
    utterance.voice = voice
    window.speechSynthesis.speak(utterance)
  }

  function chooseOutcome(outcome: RecallOutcome) {
    if (!current || !progress) return
    if (!transferEvidence.trim()) {
      setTransferError(true)
      return
    }
    const next = recordAttempt(progress, {
      sentenceID: current.id,
      responseTimeMs: Math.max(0, Date.now() - promptStartedAt.current),
      outcome,
      transferEvidence: transferEvidence.trim(),
      completedAt: new Date().toISOString(),
    })
    setProgress(next)
    saveProgress(next)
    setChosenOutcome(outcome)
    setStage('rated')
  }

  function nextCard() {
    if (cardIndex >= queue.length - 1) {
      setFinished(true)
      return
    }
    setCardIndex((index) => index + 1)
    setStage('prompt')
    setSelectedWord(null)
    setTransferEvidence('')
    setTransferError(false)
    setChosenOutcome(null)
  }

  if (!catalog) {
    return (
      <main className={`app-shell language-${language}`}>
        <section className="onboarding paper-card">
          <div className="brand-mark" aria-hidden="true"><i /><i /></div>
          <p className="kicker">LANGUAGE CORNER</p>
          <h1>把一句话，<br />练成你的话。</h1>
          <p className="lead"><strong>手机打开即可使用</strong><br />每天留一小段时间，先想、再听、最后换个场景说出来。</p>

          <fieldset>
            <legend>今天练哪种语言？</legend>
            <div className="segmented language-switch">
              {(['english', 'russian'] as const).map((value) => (
                <button key={value} type="button" aria-label={languageLabel(value)} aria-pressed={language === value} onClick={() => setLanguage(value)}>
                  <span>{value === 'english' ? 'EN' : 'РУ'}</span>{languageLabel(value)}
                </button>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>每天留多久？</legend>
            <div className="segmented time-switch">
              {[5, 10, 15].map((minutes) => (
                <button key={minutes} type="button" aria-pressed={dailyMinutes === minutes} onClick={() => setDailyMinutes(minutes)}>
                  每天 {minutes} 分钟
                </button>
              ))}
            </div>
          </fieldset>

          <button className="primary-button" onClick={startSession} disabled={loading}>
            {loading ? '正在准备真实内容…' : '开始今天练习'}
          </button>
          {loadError && <p className="error-message" role="alert">{loadError}</p>}
          <p className="install-note">把 Language Corner 放到手机桌面，下次像普通 App 一样打开。</p>
        </section>
      </main>
    )
  }

  if (finished) {
    return (
      <main className={`app-shell language-${language}`}>
        <section className="finish-card paper-card">
          <p className="kicker">TODAY · COMPLETE</p>
          <div className="finish-seal" aria-hidden="true">✓</div>
          <h1>今天这三句，<br />已经开口了。</h1>
          <p>迁移答案已保存在这台设备。明天的顺序会换一换。</p>
          <button className="primary-button" onClick={() => { setCatalog(null); setFinished(false) }}>返回语言选择</button>
        </section>
      </main>
    )
  }

  return (
    <main className={`app-shell practice-shell language-${language}`}>
      <header className="practice-header">
        <div>
          <p className="kicker">LANGUAGE CORNER</p>
          <strong>{languageLabel(language)} · {dailyMinutes} 分钟</strong>
        </div>
        <span className="counter">{cardIndex + 1} / {queue.length}</span>
      </header>

      <section className="practice-layout">
        <aside className="study-controls" aria-label="本次练习设置">
          <label htmlFor="topic">主题</label>
          <select id="topic" value={selectedTopic} onChange={(event) => chooseTopic(event.target.value)}>
            <option value="all">今日混合</option>
            {catalog.topics.map((item) => <option key={item.id} value={item.id}>{item.titleZh}</option>)}
          </select>
          <p className="control-caption">{topic?.titleTarget || 'Daily practice'}</p>
          <span className="control-label">练习环境</span>
          <div className="environment-list">
            {[
              ['quiet', '安静看一遍'], ['headphones', '戴耳机听和跟读'], ['speak', '现在可以开口'],
            ].map(([value, label]) => (
              <button key={value} aria-pressed={environment === value} onClick={() => setEnvironment(value)}>{label}</button>
            ))}
          </div>
        </aside>

        <article className="practice-card paper-card">
          <div className="card-meta">
            <span>{topic?.titleZh || current.topicID || '今日练习'}</span>
            <span>{stage === 'prompt' ? '先自己想' : stage === 'hint' ? '目标语提示' : stage === 'revealed' ? '核对并迁移' : '已记录'}</span>
          </div>
          <p className="intent-label">中文意图</p>
          <h1 className="prompt-text">{current.promptZh}</h1>

          {stage === 'prompt' && (
            <div className="action-zone">
              <div className={`three-second ${hintReady ? 'ready' : ''}`} aria-live="polite">
                <span aria-hidden="true" />{hintReady ? '可以看提示了' : '先想 3 秒'}
              </div>
              <button className="primary-button" disabled={!hintReady} onClick={() => setStage('hint')}>查看提示</button>
            </div>
          )}

          {stage === 'hint' && (
            <div className="reveal-block">
              <p className="cue-text">{current.cueTarget || '本地内容没有额外提示，请直接揭晓。'}</p>
              <button className="primary-button" onClick={() => setStage('revealed')}>揭晓答案</button>
            </div>
          )}

          {(stage === 'revealed' || stage === 'rated') && (
            <div className="answer-block">
              <div className="answer-heading"><span>点每个词查看词义</span>{voice && <button className="listen-button" onClick={speak}>朗读</button>}</div>
              <TargetWords sentence={current} catalog={catalog} onSelect={(word, lexeme) => setSelectedWord({ word, lexeme })} />

              <div className="transfer-box">
                <label htmlFor="transfer-answer">迁移任务</label>
                <p>换一个人物或场景说一句。{current.expectedReply ? `也可以回应：${current.expectedReply}` : '尽量沿用刚才的搭配。'}</p>
                <textarea
                  id="transfer-answer"
                  aria-label="迁移回答"
                  value={transferEvidence}
                  onChange={(event) => { setTransferEvidence(event.target.value); setTransferError(false) }}
                  placeholder="写下你的新句子或下一轮回应"
                  rows={2}
                  disabled={stage === 'rated'}
                />
              </div>

              {stage === 'revealed' && (
                <div className="outcome-block">
                  <span className="control-label">刚才是哪种情况？</span>
                  <div className="outcome-grid">
                    {outcomes.map((outcome) => <button key={outcome.value} onClick={() => chooseOutcome(outcome.value)}>{outcome.label}</button>)}
                  </div>
                  {transferError && <p className="error-message" role="alert">先完成迁移任务，再进入下一张。</p>}
                </div>
              )}

              {stage === 'rated' && (
                <div className="next-block">
                  <p>已记录：{outcomes.find((outcome) => outcome.value === chosenOutcome)?.short}</p>
                  <button className="primary-button" onClick={nextCard}>{cardIndex === queue.length - 1 ? '完成今天练习' : '下一张'}</button>
                </div>
              )}
            </div>
          )}
        </article>
      </section>
      {selectedWord && <WordDetail word={selectedWord.word} lexeme={selectedWord.lexeme} sentence={current} onClose={() => setSelectedWord(null)} />}
    </main>
  )
}
