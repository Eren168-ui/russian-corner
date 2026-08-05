import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { existsSync, rmSync, cpSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

const currentFile = fileURLToPath(import.meta.url)
const rootDir = dirname(currentFile)
const windowsDir = resolve(rootDir, '..')
const projectDir = resolve(windowsDir, '..')
const universalDir = resolve(projectDir, 'Universal')
const outputDist = resolve(windowsDir, 'dist')

function run(command, args, cwd) {
  const result = spawnSync(command, args, {
    stdio: 'inherit',
    shell: true,
    cwd,
  })

  if (result.status !== 0) {
    process.exit(result.status ?? 1)
  }
}

run('npm', ['run', 'build'], universalDir)

if (!existsSync(universalDir)) {
  console.error(`sync=failed path_missing universal=${universalDir}`)
  process.exit(1)
}

if (!existsSync(resolve(universalDir, 'node_modules'))) {
  console.warn('sync=warn universal_deps_missing run_npm_install first=cd ../Universal && npm install')
}

const sourceDist = resolve(universalDir, 'dist')
if (!existsSync(sourceDist)) {
  console.error(`sync=failed dist_missing path=${sourceDist}`)
  process.exit(1)
}

rmSync(outputDist, { recursive: true, force: true })
cpSync(sourceDist, outputDist, { recursive: true })

console.log(`sync=done dist=${outputDist}`)
