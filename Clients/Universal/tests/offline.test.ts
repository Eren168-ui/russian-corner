import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const root = resolve(import.meta.dirname, '..')

describe('offline and install checklist', () => {
  it('declares an installable standalone app with both phone icons', async () => {
    const manifest = JSON.parse(await readFile(resolve(root, 'public/manifest.webmanifest'), 'utf8'))
    expect(manifest.name).toBe('Language Corner')
    expect(manifest.display).toBe('standalone')
    expect(manifest.start_url).toBe('./')
    expect(manifest.scope).toBe('./')
    expect(manifest.icons.map((icon: { sizes: string }) => icon.sizes)).toEqual(expect.arrayContaining(['192x192', '512x512']))
  })

  it('pre-caches the shell and every audited content file without secret material', async () => {
    const worker = await readFile(resolve(root, 'public/sw.js'), 'utf8')
    expect(worker).toContain("'assets/app.js'")
    expect(worker).toContain("'content/english-sentences.json'")
    expect(worker).toContain("'content/supplemental-sentences.json'")
    expect(worker).toContain("new Request(scopedURL(path), { cache: 'reload' })")
    expect(worker).toContain("caches.match(event.request, { ignoreVary: true })")
    expect(worker).not.toMatch(/api[_-]?key|secret|token/i)
  })

  it('registers offline support after the page loads', async () => {
    const entry = await readFile(resolve(root, 'src/main.tsx'), 'utf8')
    expect(entry).toContain("window.addEventListener('load'")
    expect(entry).toContain("navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js?v=")
  })
})
