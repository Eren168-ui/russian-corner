import { useEffect, useMemo, useState } from 'react'
import type { ContentCatalog, PracticeLexeme, PracticeSentence, StudyLanguage } from './domain/models'
import { localDateKey } from './domain/dailyQueue'
import {
  buildLearningHistory,
  loadDiagnosticReport,
  loadReflection,
  saveDiagnosticReport,
  saveReflection,
  scorePercent,
  type CompletionReason,
  type DiagnosticScores,
  type NaturalSpeechAnswer,
} from './domain/insights'
import { speakText } from './domain/speech'

type CatalogLoader = (language: StudyLanguage) => Promise<ContentCatalog>

const languageLabel = (language: StudyLanguage) => language === 'english' ? '英语' : '俄语'
const clean = (value: string) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase().replace(/[^\p{L}\p{M}]+/gu, '')

function WorkspaceTitle({ index, eyebrow, title, description, onBack }: {
  index: string
  eyebrow: string
  title: string
  description: string
  onBack: () => void
}) {
  return (
    <header className="workspace-title">
      <div>
        <div className="section-index"><span>{index}</span><b>{eyebrow}</b></div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      <button className="text-button" type="button" onClick={onBack}>返回今日练习 →</button>
    </header>
  )
}

export function LearningHistoryView({ language, todayTarget, onBack }: {
  language: StudyLanguage
  todayTarget: number
  onBack: () => void
}) {
  const [version, setVersion] = useState(0)
  const summary = useMemo(() => buildLearningHistory(language, todayTarget), [language, todayTarget, version])
  const maxCompleted = Math.max(1, ...summary.recentDays.map((day) => day.completed))
  const weekday = new Intl.DateTimeFormat('zh-CN', { weekday: 'short' })

  return (
    <section className="workspace-page">
      <WorkspaceTitle
        index="02"
        eyebrow="LEARNING RECORD"
        title={`${languageLabel(language)}学习记录`}
        description="不是统计你看过多少页，而是记录你真正尝试说出的句子、反应速度和连续练习。"
        onBack={onBack}
      />
      <div className="metric-grid" aria-label="学习概览">
        <article><span>今日完成</span><strong>{summary.todayCompleted}<small> / {summary.todayTarget || '—'}</small></strong><p>已作答卡片</p></article>
        <article><span>连续学习</span><strong>{summary.streakDays}<small> 天</small></strong><p>允许今天尚未开始</p></article>
        <article><span>今日回忆</span><strong>{summary.todayAccuracy === null ? '—' : `${Math.round(summary.todayAccuracy * 100)}%`}</strong><p>流利或用法基本正确</p></article>
        <article><span>已流利说出</span><strong>{summary.masteredCount}<small> 句</small></strong><p>至少一次在 3 秒内取出</p></article>
      </div>
      <section className="workspace-card history-chart">
        <div className="workspace-card__heading">
          <div><span className="eyebrow">RECENT 7 DAYS</span><h2>最近七天，真正开口了多少次</h2></div>
          <button className="text-button" type="button" onClick={() => setVersion((value) => value + 1)}>刷新数据</button>
        </div>
        <div className="bar-chart" aria-label="最近七天完成量">
          {summary.recentDays.map((day) => (
            <div className="bar-column" key={day.date}>
              <strong>{day.completed || '·'}</strong>
              <div><i style={{ height: `${Math.max(day.completed ? 12 : 2, (day.completed / maxCompleted) * 100)}%` }} /></div>
              <span>{weekday.format(new Date(`${day.date}T12:00:00`))}</span>
            </div>
          ))}
        </div>
        <footer className="history-footer">
          <span>平均反应时间</span>
          <strong>{summary.averageResponseMs ? `${(summary.averageResponseMs / 1000).toFixed(1)} 秒` : '完成练习后生成'}</strong>
          <p>数据只保存在当前设备，不需要账号。</p>
        </footer>
      </section>
    </section>
  )
}

const completionReasons: { value: CompletionReason; label: string }[] = [
  { value: 'completed', label: '按计划完成' },
  { value: 'time', label: '时间不够' },
  { value: 'energy', label: '精力不够' },
  { value: 'interrupted', label: '被事情打断' },
  { value: 'other', label: '其他' },
]

export function DailyFeedbackView({ language, onBack }: { language: StudyLanguage; onBack: () => void }) {
  const date = localDateKey()
  const existing = loadReflection(language, date)
  const [mostBlocked, setMostBlocked] = useState(existing?.mostBlocked ?? '')
  const [naturalSpeech, setNaturalSpeech] = useState<NaturalSpeechAnswer>(existing?.naturalSpeech ?? 'unsure')
  const [naturalSpeechNote, setNaturalSpeechNote] = useState(existing?.naturalSpeechNote ?? '')
  const [completionReason, setCompletionReason] = useState<CompletionReason>(existing?.completionReason ?? 'completed')
  const [completionReasonNote, setCompletionReasonNote] = useState(existing?.completionReasonNote ?? '')
  const [saved, setSaved] = useState(Boolean(existing))

  function save() {
    saveReflection({
      language, date, mostBlocked: mostBlocked.trim(), naturalSpeech, naturalSpeechNote: naturalSpeechNote.trim(),
      completionReason, completionReasonNote: completionReasonNote.trim(), updatedAt: new Date().toISOString(),
    })
    setSaved(true)
  }

  return (
    <section className="workspace-page">
      <WorkspaceTitle
        index="03"
        eyebrow="DAILY FEEDBACK"
        title="今天卡在哪里？"
        description="只记下一条真实阻力，明天复习时才知道该把力气放在词、搭配、听力，还是开口速度上。"
        onBack={onBack}
      />
      <div className="feedback-layout">
        <section className="workspace-card feedback-form">
          <label htmlFor="blocked">今天最卡的一处</label>
          <textarea id="blocked" maxLength={200} value={mostBlocked} onChange={(event) => { setMostBlocked(event.target.value); setSaved(false) }} placeholder="例如：知道意思，但临时想不起动词搭配" />
          <span className="field-count">{mostBlocked.length} / 200</span>

          <fieldset>
            <legend>今天有没有一句真正脱口而出？</legend>
            <div className="segmented feedback-choice">
              {([['yes', '有'], ['no', '没有'], ['unsure', '不确定']] as const).map(([value, label]) => (
                <button key={value} type="button" aria-pressed={naturalSpeech === value} onClick={() => { setNaturalSpeech(value); setSaved(false) }}>{label}</button>
              ))}
            </div>
          </fieldset>
          <label htmlFor="speech-note">如果愿意，记下那句话或卡住的原因</label>
          <input id="speech-note" value={naturalSpeechNote} onChange={(event) => { setNaturalSpeechNote(event.target.value); setSaved(false) }} placeholder="一句就够，不要求完整复盘" />

          <label htmlFor="completion">今天为什么在这里结束？</label>
          <select id="completion" value={completionReason} onChange={(event) => { setCompletionReason(event.target.value as CompletionReason); setSaved(false) }}>
            {completionReasons.map((reason) => <option key={reason.value} value={reason.value}>{reason.label}</option>)}
          </select>
          <input aria-label="结束原因补充" value={completionReasonNote} onChange={(event) => { setCompletionReasonNote(event.target.value); setSaved(false) }} placeholder="可补充具体原因" />
          <button className="primary-button" type="button" onClick={save}>{saved ? '已保存到这台设备' : '保存今日反馈'}</button>
        </section>
        <aside className="feedback-note">
          <span>01</span><h2>它不是作业。</h2><p>不用写满，也不会自动给你下结论。它的作用是留下“今天为什么没说出来”的证据。</p>
          <span>02</span><h2>它会和记录一起看。</h2><p>学习记录告诉你做了多少；反馈告诉你为什么卡住。两者放在一起，下一轮调整才有意义。</p>
        </aside>
      </div>
    </section>
  )
}

type DiagnosticSection = keyof DiagnosticScores
type DiagnosticStep = 'intro' | DiagnosticSection | 'summary'

interface DiagnosticQuestion {
  section: DiagnosticSection
  prompt: string
  display?: string
  context?: string
  speechText?: string
  answer: string
  accepted?: string[]
  options?: string[]
  explanationZh: string
  usageZh: string
}

function unique(values: (string | undefined)[]) {
  return [...new Set(values.filter((value): value is string => Boolean(value?.trim())))]
}

function choices(correct: string, candidates: string[], fallbacks: string[]) {
  const values = unique([correct, ...candidates, ...fallbacks]).slice(0, 4)
  const offset = values.length > 1 ? correct.length % values.length : 0
  return [...values.slice(offset), ...values.slice(0, offset)]
}

const BASIC_RUSSIAN = new Set([
  'здравствуйте', 'привет', 'спасибо', 'пожалуйста', 'пока', 'да', 'нет', 'хорошо',
  'имя', 'друг', 'познакомиться', 'знать', 'понимать', 'говорить', 'жить', 'учиться', 'работать',
])

const BASIC_ENGLISH = new Set([
  'hello', 'hi', 'thanks', 'thank you', 'please', 'goodbye', 'yes', 'no', 'good',
  'name', 'friend', 'meet', 'know', 'understand', 'speak', 'live', 'study', 'work',
])

const BASIC_SENTENCE_PATTERNS: Record<StudyLanguage, RegExp[]> = {
  russian: [/^здравствуйте\b/i, /^привет\b/i, /^как дела\b/i, /^до завтра\b/i, /познаком(?:иться|им)/i, /^меня зовут\b/i],
  english: [/^hello\b/i, /^hi\b/i, /^how are you\b/i, /^thank you\b/i, /^my name is\b/i, /^nice to meet you\b/i],
}

function plain(value: string) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase().replace(/[“”«»'’.!?]/g, '').trim()
}

function isBasicLexeme(lexeme: PracticeLexeme) {
  const blocked = lexeme.language === 'russian' ? BASIC_RUSSIAN : BASIC_ENGLISH
  return blocked.has(plain(lexeme.lemma)) || /greetings?|reconnecting/.test(lexeme.id.toLocaleLowerCase()) && plain(lexeme.lemma).split(/\s+/).length === 1
}

function isBasicSentence(sentence: PracticeSentence) {
  const target = plain(sentence.targetText)
  return BASIC_SENTENCE_PATTERNS[sentence.language].some((pattern) => pattern.test(target))
}

function lexemeDifficulty(lexeme: PracticeLexeme) {
  const words = plain(lexeme.lemma).split(/\s+/).filter(Boolean).length
  return Math.min(4, plain(lexeme.lemma).length / 4)
    + Math.min(3, words)
    + (lexeme.collocations.length ? 3 : 0)
    + (lexeme.grammar.length ? 2 : 0)
    + (lexeme.example ? 2 : 0)
    + ((lexeme.glossZh?.includes('；') || lexeme.glossZh?.includes('，')) ? 1 : 0)
}

function sentenceDifficulty(sentence: PracticeSentence) {
  const wordCount = sentence.targetText.split(/\s+/).filter(Boolean).length
  return Math.min(8, wordCount) + (sentence.expectedReply ? 2 : 0) + (sentence.lexemeIDs.length ? 2 : 0) + Math.min(3, sentence.promptZh.length / 12)
}

function takeDiverse<T>(items: T[], count: number, group: (item: T) => string) {
  const result: T[] = []
  const used = new Set<string>()
  for (const item of items) {
    const key = group(item)
    if (!used.has(key)) {
      result.push(item)
      used.add(key)
      if (result.length === count) return result
    }
  }
  for (const item of items) {
    if (!result.includes(item)) result.push(item)
    if (result.length === count) return result
  }
  return result
}

function diagnosticQuestions(catalog: ContentCatalog): Record<DiagnosticSection, DiagnosticQuestion[]> {
  const sentenceByID = new Map(catalog.sentences.map((sentence) => [sentence.id, sentence]))
  const eligibleLexemes = catalog.lexemes
    .filter((item) => item.glossZh && !isBasicLexeme(item))
    .sort((left, right) => lexemeDifficulty(right) - lexemeDifficulty(left))
  const lexemes = takeDiverse(eligibleLexemes, 8, (lexeme) => sentenceByID.get(lexeme.sentenceIDs[0])?.topicID ?? lexeme.source)
  const eligibleSentences = catalog.sentences
    .filter((item) => item.promptZh && item.targetText && item.speechText && !isBasicSentence(item))
    .sort((left, right) => sentenceDifficulty(right) - sentenceDifficulty(left))
  const sentences = takeDiverse(eligibleSentences, 8, (sentence) => sentence.topicID)
  const fallbackLexeme: PracticeLexeme = {
    id: 'fallback', language: catalog.language, lemma: '—', currentForm: '—', glossZh: '暂无', partOfSpeech: '', grammar: [], collocations: [], source: '', sentenceIDs: [], surfaceForms: [],
  }
  const recognition = lexemes.slice(0, 5).map((lexeme, index) => ({
    section: 'recognition' as const,
    prompt: `在下面的句子里，“${lexeme.currentForm || lexeme.lemma}”最接近什么意思？`,
    display: lexeme.currentForm || lexeme.lemma,
    context: lexeme.example,
    answer: lexeme.glossZh!,
    options: choices(lexeme.glossZh!, [...lexemes.slice(index + 1), ...lexemes.slice(0, index)].map((item) => item.glossZh!), ['调整原计划', '说明具体原因', '确认对方意见']),
    explanationZh: `这里考的是“${lexeme.currentForm || lexeme.lemma}”在这句话中的核心意思：${lexeme.glossZh}。`,
    usageZh: lexeme.collocations[0] ? `优先连同搭配“${lexeme.collocations[0]}”一起记。` : `回到完整句中记忆：${lexeme.example ?? lexeme.lemma}`,
  }))
  const production = sentences.slice(0, 5).map((sentence) => ({
    section: 'production' as const,
    prompt: `在这个场景里，你会怎么说：“${sentence.promptZh}”`,
    answer: sentence.targetText,
    accepted: [sentence.targetText],
    explanationZh: `本应用核对的参考表达是“${sentence.targetText}”。标点和重音符号不影响判定。`,
    usageZh: sentence.expectedReply ? `对方下一轮可能会说：“${sentence.expectedReply}”` : `把人物、时间或地点换成你自己的信息，再完整说一遍。`,
  }))
  const listening = sentences.slice(0, 5).map((sentence, index) => ({
    section: 'listening' as const,
    prompt: '只听一遍，选出说话人真正想表达的意思。',
    speechText: sentence.speechText,
    answer: sentence.promptZh,
    options: choices(sentence.promptZh, [...sentences.slice(index + 1), ...sentences.slice(0, index)].map((item) => item.promptZh), ['确认计划是否有变化', '解释自己暂时无法决定', '请对方补充具体信息']),
    explanationZh: `刚才播放的是：“${sentence.targetText}”，它表达的意思是“${sentence.promptZh}”。`,
    usageZh: sentence.expectedReply ? `自然的下一轮回应可以是：“${sentence.expectedReply}”` : `再听一次，然后遮住文字复述整句。`,
  }))
  const collocationLexemes = lexemes.filter((item) => item.collocations.length > 0)
  const collocation = collocationLexemes.slice(0, 5).map((lexeme, index) => ({
    section: 'collocation' as const,
    prompt: `想表达“${lexeme.glossZh}”时，哪一个完整搭配最合适？`,
    answer: lexeme.collocations[0],
    options: choices(lexeme.collocations[0], [...collocationLexemes.slice(index + 1), ...collocationLexemes.slice(0, index)].flatMap((item) => item.collocations), ['уточнить условия', 'перенести разговор', 'объяснить причину']),
    explanationZh: `“${lexeme.lemma}”不要只背中文义；这道题里的自然组合是“${lexeme.collocations[0]}”。`,
    usageZh: lexeme.example ? `放进完整句：${lexeme.example}` : `把这个搭配作为一个整体朗读两遍。`,
  }))
  const ensure = (section: DiagnosticSection, items: DiagnosticQuestion[]) => items.length ? items : [{
    section, prompt: '当前已审核内容不足，先完成今日练习。', display: fallbackLexeme.currentForm, answer: fallbackLexeme.glossZh!, options: [fallbackLexeme.glossZh!],
    explanationZh: '当前没有足够的已审核内容生成这一组题。', usageZh: '完成今日练习后再回来检查。',
  }]
  return {
    recognition: ensure('recognition', recognition), production: ensure('production', production),
    listening: ensure('listening', listening), collocation: ensure('collocation', collocation),
  }
}

const sectionMeta: Record<DiagnosticSection, { title: string; note: string; action: string }> = {
  recognition: { title: '词义判断', note: '看到较难词，能否结合句子理解意思。', action: '先读完整句猜词义，再点词核对；把答错的词连同例句一起复习。' },
  production: { title: '主动表达', note: '看到中文场景，能否写出一整句可直接说的表达。', action: '坚持中文场景 → 完整句；先说再揭晓，并替换人物、时间或地点重说一次。' },
  listening: { title: '听句反应', note: '不看原文，能否从语流中抓住整句意图。', action: '先只听一遍再判断；错题跟读两遍，然后遮住文字复述。' },
  collocation: { title: '自然搭配', note: '不只认识单词，还要知道它通常和什么一起说。', action: '不要孤立背词义；把支配关系、固定搭配和场景例句作为一个整体复习。' },
}

export function DiagnosticView({ language, catalog, catalogLoader, onBack }: {
  language: StudyLanguage
  catalog: ContentCatalog | null
  catalogLoader: CatalogLoader
  onBack: () => void
}) {
  const [loaded, setLoaded] = useState(catalog)
  const [loadError, setLoadError] = useState('')
  const [step, setStep] = useState<DiagnosticStep>('intro')
  const [index, setIndex] = useState(0)
  const [correct, setCorrect] = useState<Record<DiagnosticSection, number>>({ recognition: 0, production: 0, listening: 0, collocation: 0 })
  const [answered, setAnswered] = useState(false)
  const [wasCorrect, setWasCorrect] = useState(false)
  const [selectedAnswer, setSelectedAnswer] = useState('')
  const [typedAnswer, setTypedAnswer] = useState('')
  const previous = loadDiagnosticReport(language)

  useEffect(() => {
    if (loaded) return
    catalogLoader(language).then(setLoaded).catch((error) => setLoadError(error instanceof Error ? error.message : '无法读取诊断内容'))
  }, [catalogLoader, language, loaded])

  const questions = useMemo(() => loaded ? diagnosticQuestions(loaded) : null, [loaded])
  const sections: DiagnosticSection[] = ['recognition', 'production', 'listening', 'collocation']
  const currentQuestions = step !== 'intro' && step !== 'summary' ? questions?.[step] ?? [] : []
  const current = currentQuestions[index]

  function start() {
    setCorrect({ recognition: 0, production: 0, listening: 0, collocation: 0 })
    setIndex(0); setAnswered(false); setSelectedAnswer(''); setTypedAnswer(''); setStep('recognition')
  }

  function answer(value: string) {
    if (!current || answered) return
    const accepted = current.accepted ?? [current.answer]
    const ok = accepted.some((candidate) => clean(candidate) === clean(value))
    setWasCorrect(ok)
    setSelectedAnswer(value)
    setAnswered(true)
    if (ok) setCorrect((scores) => ({ ...scores, [current.section]: scores[current.section] + 1 }))
  }

  function next() {
    if (index < currentQuestions.length - 1) {
      setIndex((value) => value + 1); setAnswered(false); setSelectedAnswer(''); setTypedAnswer(''); return
    }
    const sectionIndex = sections.indexOf(step as DiagnosticSection)
    if (sectionIndex < sections.length - 1) {
      setStep(sections[sectionIndex + 1]); setIndex(0); setAnswered(false); setSelectedAnswer(''); setTypedAnswer(''); return
    }
    if (!questions) return
    const scores = Object.fromEntries(sections.map((section) => [section, scorePercent(correct[section], questions[section].length)])) as unknown as DiagnosticScores
    saveDiagnosticReport({ language, completedAt: new Date().toISOString(), scores })
    setStep('summary')
  }

  function speak(text: string) {
    speakText(text, language)
  }

  if (step === 'intro') return (
    <section className="workspace-page diagnostic-workspace">
      <WorkspaceTitle index="04" eyebrow="ORAL READINESS CHECK" title="口语能力检查" description="20 道 A2+ 日常题，检查词义、主动表达、听句反应和自然搭配。它不测发音，也不把结果冒充成语言等级。" onBack={onBack} />
      <section className="workspace-card diagnosis-intro">
        <div className="diagnosis-stamp">20</div>
        <div><span className="eyebrow">FOUR PRACTICAL SKILLS</span><h2>每项 5 题，约 8–10 分钟</h2><p>已排除“你好、谢谢、认识”等 A1 入门内容。每题答完都会给出正确答案、原因和实际用法。</p></div>
        <ol>{sections.map((section, sectionIndex) => <li key={section}><b>0{sectionIndex + 1}</b><span>{sectionMeta[section].title}</span></li>)}</ol>
        {previous && <p className="previous-score">上次检查：{new Date(previous.completedAt).toLocaleDateString('zh-CN')} · 四项平均 {Math.round(Object.values(previous.scores).reduce((sum, score) => sum + score, 0) / 4)}%</p>}
        {loadError && <p className="error-message">{loadError}</p>}
        <button className="primary-button diagnosis-start" type="button" disabled={!questions} onClick={start}>{questions ? '开始 20 题检查' : '正在准备已审核内容…'}</button>
      </section>
      <section className="diagnosis-flow" aria-label="口语能力检查怎么使用">
        <article><b>01</b><h3>题目来自已审核内容</h3><p>不拿“你好、谢谢”凑数，优先检查需要搭配和完整表达的 A2+ 内容。</p></article>
        <article><b>02</b><h3>答完立即看解析</h3><p>不仅告诉你对错，还会说明正确答案为什么成立、应该怎样放进句子里用。</p></article>
        <article><b>03</b><h3>结果直接变成练法</h3><p>四项分别给出下一步动作，分数只代表本轮题目，不等于 CEFR 等级。</p></article>
      </section>
    </section>
  )

  if (step === 'summary' && questions) {
    const scores = Object.fromEntries(sections.map((section) => [section, scorePercent(correct[section], questions[section].length)])) as unknown as DiagnosticScores
    const weakest = sections.reduce((left, right) => scores[left] <= scores[right] ? left : right)
    return (
      <section className="workspace-page diagnostic-workspace">
        <WorkspaceTitle index="05" eyebrow="CHECK RESULT" title="下一轮该怎么练" description="结果来自刚才 20 道题，只说明本轮四项表现，不等于 A2、B1 或其他语言等级。" onBack={onBack} />
        <section className="workspace-card diagnosis-summary">
          <div className="score-grid">{sections.map((section) => <article key={section}><span>{sectionMeta[section].title}</span><strong>{scores[section]}%</strong><small>{correct[section]} / {questions[section].length} 题</small></article>)}</div>
          <div className="diagnosis-advice"><span>本轮优先训练</span><h2>{sectionMeta[weakest].title}</h2><p>{sectionMeta[weakest].action}</p></div>
          <div className="diagnosis-breakdown" aria-label="四项训练建议">
            {sections.map((section) => <article key={section} data-weakest={section === weakest ? 'true' : undefined}><div><b>{sectionMeta[section].title}</b><strong>{scores[section]}%</strong></div><p>{sectionMeta[section].action}</p></article>)}
          </div>
          <p className="diagnosis-disclaimer">结果只代表本轮 20 道题，不等于 CEFR 等级。隔一段时间用同类题再测，才适合比较变化。</p>
          <div className="diagnosis-actions"><button className="primary-button" type="button" onClick={onBack}>返回今日练习</button><button className="secondary-button" type="button" onClick={start}>重新检查</button></div>
        </section>
      </section>
    )
  }

  if (!current || step === 'summary') return null
  const meta = sectionMeta[step]
  return (
    <section className="workspace-page diagnostic-workspace">
      <WorkspaceTitle index="04" eyebrow={`DIAGNOSIS · ${sections.indexOf(step) + 1} / 4`} title={meta.title} description={meta.note} onBack={onBack} />
      <section className="workspace-card diagnosis-question">
        <div className="question-progress"><span style={{ width: `${((index + 1) / currentQuestions.length) * 100}%` }} /></div>
        <p className="question-kicker">第 {index + 1} 题 / 共 {currentQuestions.length} 题</p>
        <h2>{current.prompt}</h2>
        {current.display && <strong className="question-display">{current.display}</strong>}
        {current.context && <p className="question-context"><span>句中用法</span>{current.context}</p>}
        {current.speechText && <button className="listen-diagnostic" type="button" onClick={() => speak(current.speechText!)}>▶　播放句子</button>}
        {current.options ? (
          <div className="diagnostic-options">{current.options.map((option) => <button key={option} type="button" disabled={answered} data-correct={answered && clean(option) === clean(current.answer) ? 'true' : undefined} data-selected={answered && clean(option) === clean(selectedAnswer) ? 'true' : undefined} onClick={() => answer(option)}>{option}</button>)}</div>
        ) : (
          <form className="production-answer" onSubmit={(event) => { event.preventDefault(); answer(typedAnswer) }}>
            <label htmlFor="diagnostic-answer">输入你会实际说出的表达</label>
            <input id="diagnostic-answer" value={typedAnswer} disabled={answered} onChange={(event) => setTypedAnswer(event.target.value)} autoComplete="off" />
            {!answered && <button className="primary-button" type="submit" disabled={!typedAnswer.trim()}>核对答案</button>}
          </form>
        )}
        {answered && <section className={`answer-result ${wasCorrect ? 'is-correct' : 'is-wrong'}`} role="region" aria-label="本题解析">
          <header><b>{wasCorrect ? '回答正确' : current.options ? '这题答错了' : '这次没写对'}</b>{!wasCorrect && selectedAnswer && <span>你的答案：{selectedAnswer}</span>}</header>
          <dl><div><dt>正确答案</dt><dd>{current.answer}</dd></div><div><dt>为什么</dt><dd>{current.explanationZh}</dd></div><div><dt>怎么用</dt><dd>{current.usageZh}</dd></div></dl>
          {!current.options && !wasCorrect && <p className="answer-caveat">这里只核对本应用的参考表达；你写的其他自然说法不一定真的错误。</p>}
          <button className="primary-button" type="button" onClick={next}>{step === 'collocation' && index === currentQuestions.length - 1 ? '查看检查结果' : '下一题'}</button>
        </section>}
      </section>
    </section>
  )
}
