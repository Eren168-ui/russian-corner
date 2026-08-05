import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const root = resolve(import.meta.dirname, '..')

describe('browser app typography', () => {
  it('uses the landing page type system inside the app without changing the landing page', async () => {
    const css = await readFile(resolve(root, 'src/redesign.css'), 'utf8')

    expect(css).toContain('--display: "Songti SC", "STSong", "Iowan Old Style", "Palatino Linotype", Georgia, serif;')
    expect(css).toContain('--ui: "Avenir Next", "PingFang SC", "Hiragino Sans GB", sans-serif;')
    expect(css).toContain('--reading: Georgia, "Times New Roman", "Songti SC", serif;')
    expect(css).toMatch(/h1, h2, h3 \{ font-family: var\(--display\); \}/)
  })
})
