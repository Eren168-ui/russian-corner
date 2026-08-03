import { createHash } from 'node:crypto'
import { copyFile, mkdir, readFile, readdir, stat, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const clientRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const sourceRoot = resolve(clientRoot, '../../Sources/RussianCornerCore/Resources')
const destinationRoot = resolve(clientRoot, 'public/content')

const approvedFiles = [
  'english-lessons.json',
  'english-lexemes.json',
  'english-sentences.json',
  'english-topics.json',
  'lexemes.json',
  'long-term-sentences.json',
  'speaking-challenges.json',
  'supplemental-lexemes.json',
  'supplemental-sentences.json',
  'topics.json',
]

const expectedCounts = {
  english: { lexemes: 400, sentences: 200, topics: 20, lessons: 20 },
  russian: { lexemes: 360, supplementalLexemes: 80, sentences: 214, supplementalSentences: 60, topics: 32, speakingChallenges: 24 },
}

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')

async function sourceHashes() {
  const files = (await readdir(sourceRoot)).filter((file) => file.endsWith('.json')).sort()
  return Object.fromEntries(await Promise.all(files.map(async (file) => [file, sha256(await readFile(resolve(sourceRoot, file)))])))
}

async function parse(file) {
  return JSON.parse(await readFile(resolve(sourceRoot, file), 'utf8'))
}

async function verifyCounts() {
  const [englishLexemes, englishSentences, englishTopics, englishLessons, russianLexemes, longTerm, supplementalLexemes, supplementalSentences, topics, challenges] = await Promise.all([
    parse('english-lexemes.json'), parse('english-sentences.json'), parse('english-topics.json'), parse('english-lessons.json'),
    parse('lexemes.json'), parse('long-term-sentences.json'), parse('supplemental-lexemes.json'), parse('supplemental-sentences.json'),
    parse('topics.json'), parse('speaking-challenges.json'),
  ])
  const actual = {
    english: { lexemes: englishLexemes.length, sentences: englishSentences.length, topics: englishTopics.length, lessons: englishLessons.length },
    russian: { lexemes: russianLexemes.length, supplementalLexemes: supplementalLexemes.length, sentences: longTerm.sentences.length, supplementalSentences: supplementalSentences.length, topics: topics.length, speakingChallenges: challenges.length },
  }
  if (JSON.stringify(actual) !== JSON.stringify(expectedCounts)) {
    throw new Error(`审核内容数量不匹配：${JSON.stringify(actual)}`)
  }
  return actual
}

export async function syncContent() {
  const before = await sourceHashes()
  const counts = await verifyCounts()
  await mkdir(destinationRoot, { recursive: true })

  const files = {}
  for (const file of approvedFiles) {
    const sourcePath = resolve(sourceRoot, file)
    const destinationPath = resolve(destinationRoot, file)
    await copyFile(sourcePath, destinationPath)
    const bytes = await readFile(destinationPath)
    const sourceDigest = before[file]
    const destinationDigest = sha256(bytes)
    if (destinationDigest !== sourceDigest) throw new Error(`复制校验失败：${file}`)
    files[file] = { sha256: destinationDigest, bytes: (await stat(destinationPath)).size }
  }

  const after = await sourceHashes()
  if (JSON.stringify(after) !== JSON.stringify(before)) {
    throw new Error('同步期间源资源发生变化；已停止生成清单')
  }

  const manifest = {
    version: 1,
    sourcePolicy: 'reviewed-local-resources-read-only',
    counts,
    files,
  }
  await writeFile(resolve(destinationRoot, 'content-manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8')
  return manifest
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const manifest = await syncContent()
  process.stdout.write(`Synced ${Object.keys(manifest.files).length} audited files; source hashes unchanged.\n`)
}
