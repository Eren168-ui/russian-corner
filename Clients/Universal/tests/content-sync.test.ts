import { execFile } from 'node:child_process'
import { readFile, readdir } from 'node:fs/promises'
import { promisify } from 'node:util'
import { resolve } from 'node:path'
import { createHash } from 'node:crypto'
import { describe, expect, it } from 'vitest'

const execFileAsync = promisify(execFile)
const root = resolve(import.meta.dirname, '..')
const source = resolve(root, '../../Sources/RussianCornerCore/Resources')

async function hashes(directory: string) {
  const files = (await readdir(directory)).filter((file) => file.endsWith('.json')).sort()
  return Object.fromEntries(await Promise.all(files.map(async (file) => {
    const bytes = await readFile(resolve(directory, file))
    return [file, createHash('sha256').update(bytes).digest('hex')]
  })))
}

describe('audited content sync', () => {
  it('copies the approved corpus, emits hashes, and leaves every source byte unchanged', async () => {
    const before = await hashes(source)
    await execFileAsync(process.execPath, [resolve(root, 'scripts/sync-content.mjs')], { cwd: root })
    const after = await hashes(source)
    const manifest = JSON.parse(await readFile(resolve(root, 'public/content/content-manifest.json'), 'utf8'))
    expect(after).toEqual(before)
    expect(manifest.counts).toEqual({
      english: { lexemes: 480, sentences: 240, topics: 24, lessons: 24 },
      russian: { lexemes: 360, supplementalLexemes: 80, sentences: 231, supplementalSentences: 60, topics: 32, speakingChallenges: 24 },
    })
    expect(Object.values(manifest.files).every((entry: unknown) => /^[a-f0-9]{64}$/.test((entry as { sha256: string }).sha256))).toBe(true)
  })

  it('generates the same manifest when audited content has not changed', async () => {
    await execFileAsync(process.execPath, [resolve(root, 'scripts/sync-content.mjs')], { cwd: root })
    const first = await readFile(resolve(root, 'public/content/content-manifest.json'), 'utf8')
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 5))
    await execFileAsync(process.execPath, [resolve(root, 'scripts/sync-content.mjs')], { cwd: root })
    const second = await readFile(resolve(root, 'public/content/content-manifest.json'), 'utf8')
    expect(second).toBe(first)
  })
})
