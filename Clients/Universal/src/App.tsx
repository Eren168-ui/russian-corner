import { useEffect, useMemo, useRef, useState } from 'react'
import { loadCatalog } from './content/loadCatalog'
import { createDailyQueue, localDateKey } from './domain/dailyQueue'
import type { ContentCatalog, PracticeCard, StudyLanguage } from './domain/models'
import { buildDailyPracticeCards, buildPracticeCards } from './domain/practiceCards'
import { loadProgress, recordAttempt, saveProgress, type RecallOutcome, type StudyProgress } from './domain/progress'
import { hasCompletedFirstSession, markFirstSessionCompleted, sessionCardCount } from './domain/session'
import { resolveWord, type WordResolution } from './domain/wordResolution'
import { lookupOnlineDictionary, type OnlineDictionaryEntry } from './domain/onlineDictionary'
import { recordHistoryAttempt } from './domain/insights'
import { DailyFeedbackView, DiagnosticView, LearningHistoryView } from './WorkspaceViews'
import { rankedVoices, speakText } from './domain/speech'

type CatalogLoader = (language: StudyLanguage) => Promise<ContentCatalog>
type Stage = 'prompt' | 'revealed' | 'rated'
type AppView = 'practice' | 'history' | 'feedback' | 'diagnostics'
type ThemeMode = 'light' | 'dark'
type InstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>
}

const outcomes: { value: RecallOutcome; label: string; short: string }[] = [
  { value: 'fluentUnder3s', label: '流利说出（3 秒内）', short: '流利' },
  { value: 'meaningButUsageIssue', label: '想到意思，但用法不稳', short: '用法不稳' },
  { value: 'afterReveal', label: '揭晓后想起', short: '揭晓后想起' },
  { value: 'unknown', label: '完全不会', short: '完全不会' },
]

const languageLabel = (language: StudyLanguage) => language === 'english' ? '英语' : '俄语'
const cardTypeLabel = { sentence: '场景句', lexeme: '词汇 / 句块', challenge: '开口挑战' } as const

function useVoice(language: StudyLanguage) {
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([])
  const [selectedName, setSelectedName] = useState('')

  useEffect(() => {
    if (!('speechSynthesis' in window)) return
    const key = `languageCorner.voice.${language}`
    setSelectedName(localStorage.getItem(key) ?? '')
    const update = () => {
      setVoices(rankedVoices(language, window.speechSynthesis.getVoices()))
    }
    update()
    window.speechSynthesis.addEventListener('voiceschanged', update)
    return () => window.speechSynthesis.removeEventListener('voiceschanged', update)
  }, [language])

  const voice = voices.find((candidate) => candidate.name === selectedName) ?? voices[0] ?? null
  function selectVoice(name: string) {
    setSelectedName(name)
    localStorage.setItem(`languageCorner.voice.${language}`, name)
  }
  return { voice, voices, selectVoice }
}

function useInstallPrompt() {
  const [installEvent, setInstallEvent] = useState<InstallPromptEvent | null>(null)
  const [installed, setInstalled] = useState(false)

  useEffect(() => {
    const onBeforeInstall = (event: Event) => {
      event.preventDefault()
      setInstallEvent(event as InstallPromptEvent)
    }
    const onInstalled = () => {
      setInstalled(true)
      setInstallEvent(null)
    }
    window.addEventListener('beforeinstallprompt', onBeforeInstall)
    window.addEventListener('appinstalled', onInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', onBeforeInstall)
      window.removeEventListener('appinstalled', onInstalled)
    }
  }, [])

  async function install() {
    if (!installEvent) return false
    await installEvent.prompt()
    setInstallEvent(null)
    return true
  }

  return { canInstall: Boolean(installEvent), installed, install }
}

function InstallHelp({ canInstall, installed, onInstall }: { canInstall: boolean; installed: boolean; onInstall: () => Promise<boolean> }) {
  const [open, setOpen] = useState(false)

  async function handleInstall() {
    if (canInstall) {
      await onInstall()
      return
    }
    setOpen((value) => !value)
  }

  if (installed) return <p className="install-confirmation">已放到这台设备的桌面，之后可以像普通 App 一样打开。</p>

  return (
    <div className="install-help-wrap">
      <button className="secondary-button" type="button" onClick={handleInstall} aria-expanded={open}>
        {canInstall ? '安装到手机 / 桌面' : '查看安装方法'}
      </button>
      {open && (
        <div className="install-help" role="note">
          <strong>放到手机桌面</strong>
          <p><b>iPhone：</b>在浏览器里点“分享” → “添加到主屏幕”。</p>
          <p><b>Android：</b>打开浏览器菜单 → “安装应用”或“添加到主屏幕”。</p>
          <p>电脑上也可以把当前页面安装成一个独立窗口；不安装也不影响使用。</p>
        </div>
      )}
    </div>
  )
}

function WebHeader({ language, topic, counter, activeView, theme, onNavigate, onLanguageChange, onToggleTheme, onReset, onControls, controlsOpen }: {
  language: StudyLanguage
  topic?: string
  counter?: string
  activeView: AppView
  theme: ThemeMode
  onNavigate: (view: AppView) => void
  onLanguageChange: (language: StudyLanguage) => void
  onToggleTheme: () => void
  onReset?: () => void
  onControls?: () => void
  controlsOpen?: boolean
}) {
  return (
    <header className="web-header">
      <button className="web-brand" type="button" aria-label="Language Corner 今日练习" onClick={() => onNavigate('practice')}>
        <span className="web-logo" aria-hidden="true">Я</span>
        <span>
          <strong>Language Corner</strong>
          <small>EREN LAB · 英语 × 俄语主动回忆</small>
        </span>
      </button>
      <nav className="web-nav" aria-label="页面导航">
        <button type="button" aria-current={activeView === 'practice' ? 'page' : undefined} onClick={() => onNavigate('practice')}>今日练习</button>
        <button type="button" aria-current={activeView === 'history' ? 'page' : undefined} onClick={() => onNavigate('history')}>学习记录</button>
        <button type="button" aria-current={activeView === 'feedback' ? 'page' : undefined} onClick={() => onNavigate('feedback')}>今日反馈</button>
        <button type="button" aria-current={activeView === 'diagnostics' ? 'page' : undefined} onClick={() => onNavigate('diagnostics')}>能力检测</button>
      </nav>
      <div className="web-header-actions">
        <span className="web-status"><i aria-hidden="true" />{topic ? `${languageLabel(language)} · ${topic}` : '浏览器版可用'}</span>
        {counter && <span className="web-counter">{counter}</span>}
        <div className="language-mini-switch" aria-label="练习语言">
          <button type="button" aria-label="切换到英语" aria-pressed={language === 'english'} onClick={() => onLanguageChange('english')}>EN <span>英语</span></button>
          <button type="button" aria-label="切换到俄语" aria-pressed={language === 'russian'} onClick={() => onLanguageChange('russian')}>РУ <span>俄语</span></button>
        </div>
        <button className="theme-toggle" type="button" aria-label={theme === 'light' ? '切换深色模式' : '切换浅色模式'} onClick={onToggleTheme}>{theme === 'light' ? '☾' : '☀'}</button>
        {onControls && (
          <button className="web-menu" type="button" aria-label="练习设置" title="练习设置" aria-expanded={controlsOpen} onClick={onControls}>
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none">
              <path d="M4 7h10M18 7h2M4 17h2M10 17h10M14 4v6M7 14v6" />
            </svg>
            <span>练习设置</span>
          </button>
        )}
        {onReset && <button className="web-reset" type="button" aria-label="返回语言选择" onClick={onReset}>−</button>}
      </div>
    </header>
  )
}

function WordDetail({ word, resolution, sentence, language, onClose }: {
  word: string
  resolution: WordResolution
  sentence: PracticeCard
  language: StudyLanguage
  onClose: () => void
}) {
  const lexeme = resolution.atomic
  const [online, setOnline] = useState<OnlineDictionaryEntry | null>(null)
  const [onlineStatus, setOnlineStatus] = useState<'idle' | 'loading' | 'failed'>('idle')

  useEffect(() => {
    setOnline(null)
    if (lexeme?.glossZh?.trim()) {
      setOnlineStatus('idle')
      return
    }
    const controller = new AbortController()
    setOnlineStatus('loading')
    lookupOnlineDictionary(word, language, controller.signal)
      .then((entry) => {
        setOnline(entry)
        setOnlineStatus('idle')
      })
      .catch((error: unknown) => {
        if ((error as { name?: string }).name !== 'AbortError') setOnlineStatus('failed')
      })
    return () => controller.abort()
  }, [language, lexeme, word])

  const gloss = lexeme?.glossZh || online?.translations.join('；')
  const lemma = lexeme?.lemma || online?.lemma || word
  const partOfSpeech = lexeme?.partOfSpeech || online?.partOfSpeech
  return (
    <aside className="word-detail" role="region" aria-label="词义详情">
      <div className="word-detail__heading">
        <div>
          <span className="eyebrow">刚才点的词</span>
          <h3>{word}</h3>
        </div>
        <button className="icon-button" onClick={onClose} aria-label="关闭词义详情">×</button>
      </div>
      <dl className="word-grid">
        <div><dt>中文义</dt><dd>{gloss || (onlineStatus === 'loading' ? '正在在线查词…' : onlineStatus === 'failed' ? '本地暂无这个单词的单独释义；在线词典暂时不可用' : '本地暂无这个单词的单独释义')}</dd></div>
        <div><dt>原形 / 当前形式</dt><dd>{`${lemma} / ${lexeme?.currentForm || word}`}</dd></div>
        <div><dt>语法</dt><dd>{[partOfSpeech, ...(lexeme?.grammar ?? [])].filter(Boolean).join('；') || '本地内容暂无语法说明'}</dd></div>
        <div><dt>搭配</dt><dd>{lexeme?.collocations.join('；') || '本地内容暂无搭配'}</dd></div>
        <div><dt>例句</dt><dd>{lexeme?.example || sentence.targetText}</dd></div>
        <div><dt>来源</dt><dd>{online ? '在线词典 · 未人工审核' : lexeme?.source || sentence.source}</dd></div>
      </dl>
      {resolution.phrases.length > 0 && (
        <section className="phrase-evidence" aria-label="本句已审核句块">
          <h4>本句已审核句块</h4>
          {resolution.phrases.map((phrase) => (
            <p key={phrase.id}><strong>{phrase.currentForm}</strong><span>{phrase.glossZh || '本地内容暂无中文释义'}</span></p>
          ))}
        </section>
      )}
    </aside>
  )
}

function TargetWords({ sentence, catalog, onSelect }: {
  sentence: PracticeCard
  catalog: ContentCatalog
  onSelect: (word: string, resolution: WordResolution) => void
}) {
  const tokens = sentence.targetText.match(/[\p{L}\p{M}]+(?:['’’-][\p{L}\p{M}]+)*|[^\p{L}\p{M}]+/gu) ?? [sentence.targetText]
  return (
    <p className="target-words" data-testid="target-answer">
      {tokens.map((token, index) => {
        if (!/[\p{L}\p{M}]/u.test(token)) return <span key={`${token}-${index}`}>{token}</span>
        return <button key={`${token}-${index}`} onClick={() => onSelect(token, resolveWord(token, sentence, catalog))}>{token}</button>
      })}
    </p>
  )
}

export default function App({ catalogLoader = loadCatalog }: { catalogLoader?: CatalogLoader }) {
  const [language, setLanguage] = useState<StudyLanguage>('english')
  const [activeView, setActiveView] = useState<AppView>('practice')
  const [theme, setTheme] = useState<ThemeMode>(() => localStorage.getItem('languageCorner.theme') === 'dark' ? 'dark' : 'light')
  const [dailyMinutes, setDailyMinutes] = useState(5)
  const [catalog, setCatalog] = useState<ContentCatalog | null>(null)
  const [queue, setQueue] = useState<PracticeCard[]>([])
  const [cardIndex, setCardIndex] = useState(0)
  const [stage, setStage] = useState<Stage>('prompt')
  const [hintReady, setHintReady] = useState(false)
  const [selectedWord, setSelectedWord] = useState<{ word: string; resolution: WordResolution } | null>(null)
  const [transferEvidence, setTransferEvidence] = useState('')
  const [chosenOutcome, setChosenOutcome] = useState<RecallOutcome | null>(null)
  const [environment, setEnvironment] = useState('quiet')
  const [selectedTopic, setSelectedTopic] = useState('all')
  const [loading, setLoading] = useState(false)
  const [loadError, setLoadError] = useState('')
  const [finished, setFinished] = useState(false)
  const [progress, setProgress] = useState<StudyProgress | null>(null)
  const [showControls, setShowControls] = useState(false)
  const promptStartedAt = useRef(Date.now())
  const frozenResponseTimeMs = useRef<number | null>(null)
  const current = queue[cardIndex]
  const voiceControl = useVoice(language)
  const installPrompt = useInstallPrompt()

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    localStorage.setItem('languageCorner.theme', theme)
  }, [theme])

  useEffect(() => {
    if (!current) return
    setHintReady(false)
    promptStartedAt.current = Date.now()
    frozenResponseTimeMs.current = null
    const timer = window.setTimeout(() => setHintReady(true), 3000)
    return () => window.clearTimeout(timer)
  }, [current])

  useEffect(() => {
    if (!catalog || finished) return
    if (/jsdom/i.test(navigator.userAgent)) return
    try {
      window.scrollTo(0, 0)
    } catch {
      // Some embedded webviews do not expose scrolling until the first paint.
    }
  }, [catalog, finished])

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
      const cards = buildPracticeCards(loaded)
      const dailyCards = buildDailyPracticeCards(loaded)
      const count = sessionCardCount(dailyMinutes, hasCompletedFirstSession(language))
      const expectedCount = Math.min(count, dailyCards.length)
      const restored = loadProgress(language, date)
      if (restored) {
        const byID = new Map(cards.map((card) => [card.id, card]))
        const restoredQueue = restored.queueIDs
          .map((id) => byID.get(id))
          .filter((card): card is PracticeCard => Boolean(card))
        const canResume = restored.dailyMinutes === dailyMinutes &&
          restoredQueue.length === restored.queueIDs.length &&
          restoredQueue.length === expectedCount &&
          restoredQueue.every((card) => card.cardType === 'sentence')
        if (canResume) {
          setCatalog(loaded)
          setQueue(restoredQueue)
          setDailyMinutes(restored.dailyMinutes)
          setProgress(restored)
          if (restored.currentIndex >= restoredQueue.length) {
            markFirstSessionCompleted(language)
            setCardIndex(Math.max(0, restoredQueue.length - 1))
            setFinished(true)
          } else {
            setCardIndex(restored.currentIndex)
            setStage('prompt')
          }
          return
        }
      }
      const generated = createDailyQueue(dailyCards, language, date, count)
      const completedIDs = new Set(restored?.attempts.map((attempt) => attempt.sentenceID) ?? [])
      const completed = generated.filter((card) => completedIDs.has(card.id))
      const daily = [...completed, ...generated.filter((card) => !completedIDs.has(card.id))]
      if (!daily.length) throw new Error('本地审核内容为空')
      const resumedIndex = completed.length
      const initial: StudyProgress = {
        language,
        date,
        currentIndex: resumedIndex,
        queueIDs: daily.map((card) => card.id),
        dailyMinutes,
        attempts: restored?.attempts ?? [],
      }
      setCatalog(loaded)
      setQueue(daily)
      setProgress(initial)
      saveProgress(initial)
      if (resumedIndex >= daily.length) {
        markFirstSessionCompleted(language)
        setCardIndex(Math.max(0, daily.length - 1))
        setFinished(true)
      } else {
        setCardIndex(resumedIndex)
        setStage('prompt')
      }
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : '内容读取失败')
    } finally {
      setLoading(false)
    }
  }

  function chooseTopic(topicID: string) {
    if (!catalog) return
    const cards = buildDailyPracticeCards(catalog)
    const source = topicID === 'all' ? cards : cards.filter((card) => card.topicID === topicID)
    const next = createDailyQueue(source, language, localDateKey(), sessionCardCount(dailyMinutes, hasCompletedFirstSession(language)))
    const reset: StudyProgress = {
      language,
      date: localDateKey(),
      currentIndex: 0,
      queueIDs: next.map((card) => card.id),
      dailyMinutes,
      attempts: progress?.attempts ?? [],
    }
    setSelectedTopic(topicID)
    setQueue(next)
    setProgress(reset)
    saveProgress(reset)
    setCardIndex(0)
    setStage('prompt')
    setSelectedWord(null)
  }

  function speak() {
    if (!current) return
    speakText(current.speechText, language, voiceControl.voice)
  }

  function showHint() {
    frozenResponseTimeMs.current ??= Math.max(0, Date.now() - promptStartedAt.current)
    setStage('revealed')
  }

  function chooseOutcome(outcome: RecallOutcome) {
    if (!current || !progress) return
    const attempt = {
      sentenceID: current.id,
      responseTimeMs: frozenResponseTimeMs.current ?? Math.max(0, Date.now() - promptStartedAt.current),
      outcome,
      transferEvidence: transferEvidence.trim(),
      completedAt: new Date().toISOString(),
    }
    const next = recordAttempt(progress, attempt)
    recordHistoryAttempt(language, current, attempt)
    setProgress(next)
    saveProgress(next)
    setChosenOutcome(outcome)
    setStage('rated')
  }

  function nextCard() {
    if (cardIndex >= queue.length - 1) {
      markFirstSessionCompleted(language)
      setFinished(true)
      return
    }
    setCardIndex((index) => index + 1)
    setStage('prompt')
    setSelectedWord(null)
    setShowControls(false)
    setTransferEvidence('')
    setChosenOutcome(null)
  }

  function changeLanguage(nextLanguage: StudyLanguage) {
    if (nextLanguage === language) return
    setLanguage(nextLanguage)
    setCatalog(null)
    setQueue([])
    setProgress(null)
    setFinished(false)
    setCardIndex(0)
    setStage('prompt')
    setSelectedWord(null)
    setShowControls(false)
    setSelectedTopic('all')
  }

  const header = (extra?: { topic?: string; counter?: string; onReset?: () => void; onControls?: () => void; controlsOpen?: boolean }) => (
    <WebHeader
      language={language}
      activeView={activeView}
      theme={theme}
      onNavigate={setActiveView}
      onLanguageChange={changeLanguage}
      onToggleTheme={() => setTheme((value) => value === 'light' ? 'dark' : 'light')}
      {...extra}
    />
  )

  if (activeView === 'history') {
    return (
      <main id="top" className={`app-shell workspace-shell theme-${theme} language-${language}`}>
        {header()}
        <LearningHistoryView language={language} todayTarget={queue.length || sessionCardCount(dailyMinutes, hasCompletedFirstSession(language))} onBack={() => setActiveView('practice')} />
      </main>
    )
  }

  if (activeView === 'feedback') {
    return (
      <main id="top" className={`app-shell workspace-shell theme-${theme} language-${language}`}>
        {header()}
        <DailyFeedbackView language={language} onBack={() => setActiveView('practice')} />
      </main>
    )
  }

  if (activeView === 'diagnostics') {
    return (
      <main id="top" className={`app-shell workspace-shell theme-${theme} language-${language}`}>
        {header()}
        <DiagnosticView key={language} language={language} catalog={catalog} catalogLoader={catalogLoader} onBack={() => setActiveView('practice')} />
      </main>
    )
  }

  if (!catalog) {
    return (
      <main id="top" className={`app-shell onboarding-shell theme-${theme} language-${language}`}>
        {header()}
        <section className="start-page" id="practice">
          <header className="start-heading">
            <div>
              <p className="start-kicker">LANGUAGE CORNER　/　今日主动回忆</p>
              <h1>今天练 {languageLabel(language)}</h1>
            </div>
            <p>先尝试说出一句，再听标准朗读；遇到不认识的词直接点开，最后换一个场景再说一次。</p>
          </header>

          <div className="start-workspace">
            <section className="start-settings" aria-label="今日练习设置">
              <p className="start-language-note"><span>{language === 'english' ? 'EN' : 'РУ'}</span> 当前语言：<strong>{languageLabel(language)}</strong>　·　可在页面右上角切换</p>
              <fieldset>
                <legend>今天准备练多久？</legend>
                <div className="segmented time-switch">
                  {[5, 10, 15].map((minutes) => (
                    <button key={minutes} type="button" aria-label={`每天 ${minutes} 分钟`} aria-pressed={dailyMinutes === minutes} onClick={() => setDailyMinutes(minutes)}>
                      {minutes} 分钟
                    </button>
                  ))}
                </div>
                <p className="start-card-count">本次共 {sessionCardCount(dailyMinutes, hasCompletedFirstSession(language))} 张完整场景句</p>
              </fieldset>
              <button className="primary-button start-button" aria-label="开始今天练习" onClick={startSession} disabled={loading}>
                {loading ? '正在准备今天的内容…' : `开始 ${dailyMinutes} 分钟${languageLabel(language)}练习`}
              </button>
              {loadError && <p className="error-message" role="alert">{loadError}</p>}
              <InstallHelp canInstall={installPrompt.canInstall} installed={installPrompt.installed} onInstall={installPrompt.install} />
              <p className="start-local-note">学习进度保存在当前设备；安装到手机桌面后，也可以像普通 App 一样打开。</p>
            </section>

            <section className="start-method" aria-label="一次练习怎么进行">
              <h2>一次练习，只做三件事</h2>
              <ol>
                <li><b>01</b><div><strong>先说</strong><p>只看一句完整的中文意思，给自己三秒钟，说出对应的外语场景句。</p></div></li>
                <li><b>02</b><div><strong>再核对</strong><p>揭晓自然表达，听朗读，点击句子里卡住的单词查看用法。</p></div></li>
                <li><b>03</b><div><strong>换场景</strong><p>替换人物、时间或地点，让这句话真正进入主动词汇。</p></div></li>
              </ol>
            </section>
          </div>

          <footer className="start-footer">
            <span>已选：{languageLabel(language)} · {dailyMinutes} 分钟</span>
            <span>无需登录</span>
            <span>支持离线继续练习</span>
          </footer>
        </section>
      </main>
    )
  }

  if (finished) {
    return (
      <main id="top" className={`app-shell finish-shell theme-${theme} language-${language}`}>
        {header()}
        <section className="finish-card paper-card">
          <div className="section-index"><span>03</span><b>TODAY · COMPLETE</b></div>
          <div className="finish-seal" aria-hidden="true">✓</div>
          <h1>今天这组练习，<br /><em>已经开口了。</em></h1>
          <p>迁移答案已保存在这台设备。明天的顺序会换一换。</p>
          <div className="finish-actions">
            <button className="primary-button" onClick={() => setActiveView('feedback')}>填写今日反馈</button>
            <button className="secondary-button" onClick={() => setActiveView('history')}>查看学习记录</button>
            <button className="text-button" onClick={() => { setCatalog(null); setFinished(false) }}>返回语言选择</button>
          </div>
        </section>
      </main>
    )
  }

  return (
    <main id="top" className={`app-shell practice-shell theme-${theme} language-${language}`}>
      {header({ topic: topic?.titleZh, onControls: () => setShowControls((value) => !value), controlsOpen: showControls })}

      <div className="practice-page">
        <div className="practice-context">
          <div>
            <p className="eyebrow">TODAY · {language === 'english' ? 'ENGLISH' : 'РУССКИЙ'}</p>
            <h1>{topic?.titleZh || '今日混合练习'}</h1>
          </div>
          <div className="practice-context-actions">
            <span className="counter">{cardIndex + 1} / {queue.length}</span>
            <button className="practice-reset" type="button" onClick={() => setCatalog(null)}>调整今日计划</button>
          </div>
        </div>

      <section className={`practice-layout ${showControls ? 'controls-open' : ''}`}>
        <aside className="study-controls" aria-label="本次练习设置" hidden={!showControls}>
          <div className="study-controls__heading">
            <strong>练习设置</strong>
            <button type="button" aria-label="关闭练习设置" onClick={() => setShowControls(false)}>×</button>
          </div>
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
          <label className="voice-label" htmlFor="voice">朗读声音</label>
          <select id="voice" value={voiceControl.voice?.name ?? ''} onChange={(event) => voiceControl.selectVoice(event.target.value)} disabled={!voiceControl.voices.length}>
            {!voiceControl.voices.length && <option value="">当前设备没有可选语音</option>}
            {voiceControl.voices.map((candidate, index) => <option key={candidate.voiceURI} value={candidate.name}>{index === 0 ? '推荐 · ' : ''}{candidate.name}</option>)}
          </select>
          <p className="control-caption">已排除系统特效音；如果仍不自然，可以在这里换一个声音。</p>
        </aside>

        <article className={`practice-card paper-card stage-${stage} ${selectedWord ? 'details-open' : ''}`}>
          <div className="card-meta">
            <span>{cardTypeLabel[current.cardType]}</span>
            <span>{topic?.titleZh || current.topicID || '今日练习'}</span>
            <span>{stage === 'prompt' ? '先自己想' : stage === 'revealed' ? '核对并迁移' : '已记录'}</span>
          </div>
          <p className="intent-label">你想表达的中文</p>
          <h1 className="prompt-text">{current.promptZh}</h1>

          {stage === 'prompt' && (
            <div className="recall-hint">
              <div className={`three-second ${hintReady ? 'ready' : ''}`} aria-live="polite">
                <span aria-hidden="true" />{hintReady ? '现在核对你的表达' : '先说出来，再核对答案'}
              </div>
            </div>
          )}

          {stage === 'prompt' && (
            <div className="practice-focus">
              <span className="practice-focus__label">FOCUS · 主动提取</span>
              <strong>不要先找“正确答案”，先把你的那句话说完整。</strong>
              <p>哪怕只想起一半，也先说出来。揭晓之后，你会更清楚自己卡在词义、搭配，还是下一轮回应。</p>
            </div>
          )}

          {(stage === 'revealed' || stage === 'rated') && (
            <div className="answer-block">
              <div className="answer-heading"><span>点每个词查看词义</span>{voiceControl.voice && <button className="listen-button" onClick={speak}>朗读</button>}</div>
              <TargetWords sentence={current} catalog={catalog} onSelect={(word, resolution) => setSelectedWord({ word, resolution })} />
              {selectedWord && <WordDetail word={selectedWord.word} resolution={selectedWord.resolution} sentence={current} language={language} onClose={() => setSelectedWord(null)} />}

              <div className="transfer-box">
                <label htmlFor="transfer-answer">迁移任务 <span>选做</span></label>
                <p>换一个人物或场景说一句。{current.transferHint ? `提示：${current.transferHint}` : current.expectedReply ? `也可以回应：${current.expectedReply}` : '尽量沿用刚才的搭配。'}</p>
                <textarea
                  id="transfer-answer"
                  aria-label="迁移回答"
                  value={transferEvidence}
                  onChange={(event) => setTransferEvidence(event.target.value)}
                  placeholder="愿意的话，写下你的新句子或下一轮回应"
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
                </div>
              )}

              {stage === 'rated' && (
                <div className="next-block">
                  <p>已记录：{outcomes.find((outcome) => outcome.value === chosenOutcome)?.short}</p>
                </div>
              )}
            </div>
          )}
          <footer className="card-footer">
            <div className="footer-left">
              <button type="button" className="compact-button" onClick={speak} disabled={!voiceControl.voice}>朗读</button>
            </div>
            <div className="footer-right">
              {stage === 'prompt' && <button className="primary-button footer-primary" disabled={!hintReady} onClick={showHint}>显示答案</button>}
              {stage === 'revealed' && <span className="footer-note">选择实际回忆表现</span>}
              {stage === 'rated' && <button className="primary-button footer-primary" onClick={nextCard}>{cardIndex === queue.length - 1 ? '完成今天练习' : '下一项'}</button>}
            </div>
          </footer>
        </article>
        <aside className="practice-rail" id="paths">
          <section className="rail-card">
            <p className="eyebrow">SESSION NOTE</p>
            <h2>{topic?.titleZh || '今日练习'}</h2>
            <p>这张卡不是阅读题。先在没有答案的情况下取出一句话，再用详情、朗读和迁移任务把它变成自己的表达。</p>
            <div className="rail-progress"><span style={{ width: `${Math.round(((cardIndex + 1) / Math.max(queue.length, 1)) * 100)}%` }} /></div>
            <small>{cardIndex + 1} / {queue.length} 张 · {dailyMinutes} 分钟节奏</small>
          </section>
          <section className="rail-card" id="records">
            <p className="eyebrow">HOW TO USE</p>
            <ol className="rail-steps">
              <li><b>01</b><span>看中文，完整说出外语句子</span></li>
              <li><b>02</b><span>三秒内主动说</span></li>
              <li><b>03</b><span>揭晓后点卡住的词</span></li>
              <li><b>04</b><span>换场景再说一次</span></li>
            </ol>
          </section>
          <section className="rail-card rail-quote">
            <p>“认识一个词”只是开始。能在需要的时候把它放进一句话，才是今天真正练到的东西。</p>
            <span>LANGUAGE CORNER · {language === 'english' ? 'ENGLISH' : 'РУССКИЙ'}</span>
          </section>
        </aside>
      </section>
      </div>
    </main>
  )
}
