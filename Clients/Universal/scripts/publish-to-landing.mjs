import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const clientRoot = resolve(fileURLToPath(new URL('..', import.meta.url)))
const source = resolve(clientRoot, 'dist')
const destination = resolve(clientRoot, '../../../russian-corner-landing/app')

await mkdir(destination, { recursive: true })
await rm(destination, { recursive: true, force: true })
await cp(source, destination, { recursive: true })
const indexPath = resolve(destination, 'index.html')
const index = await readFile(indexPath, 'utf8')
const versionedIndex = index
  .replace('/app/assets/app.js', '/app/assets/app.js?v=17')
  .replace('/app/assets/app.css', '/app/assets/app.css?v=17')
await writeFile(indexPath, versionedIndex)
process.stdout.write(`Published browser client to ${destination}\n`)
