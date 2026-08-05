const { app, BrowserWindow } = require('electron')
const { createServer } = require('node:http')
const fs = require('node:fs')
const fsp = require('node:fs/promises')
const path = require('node:path')
const { URL } = require('node:url')

/**
 * Desktop shell only. All UI and learning logic come from Clients/Universal dist.
 */

function mimeFor(ext) {
  const map = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.webmanifest': 'application/manifest+json; charset=utf-8',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.txt': 'text/plain; charset=utf-8',
  }
  return map[ext] ?? 'application/octet-stream'
}

async function startLocalServer(rootDir) {
  const root = path.resolve(rootDir)

  const server = createServer(async (request, response) => {
    try {
      const requestUrl = new URL(request.url || '/', 'http://127.0.0.1')
      let pathname = decodeURIComponent(requestUrl.pathname || '/')
      if (pathname === '/') pathname = '/index.html'

      const resolved = path.resolve(root, pathname.replace(/^\/+/, ''))
      if (!resolved.startsWith(root + path.sep)) {
        response.writeHead(403)
        response.end('Forbidden')
        return
      }

      try {
        const stat = await fsp.stat(resolved)
        const target = stat.isDirectory() ? path.join(resolved, 'index.html') : resolved
        const fileBuffer = await fsp.readFile(target)
        const extension = path.extname(target).toLowerCase()
        response.writeHead(200, {
          'Content-Type': mimeFor(extension),
          'Cache-Control': 'no-store',
        })
        response.end(fileBuffer)
      } catch {
        const indexFallback = path.join(root, 'index.html')
        if (path.resolve(root, 'index.html') === resolved) {
          response.writeHead(404)
          response.end('Not found')
          return
        }

        if (!resolved.includes('index.html') && !resolved.includes('manifest.webmanifest') && !resolved.includes('sw.js')) {
          // for robustness, map unknown routes to SPA entry page
          const fileBuffer = await fsp.readFile(indexFallback)
          response.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-store',
          })
          response.end(fileBuffer)
          return
        }

        response.writeHead(404)
        response.end('Not found')
      }
    } catch {
      response.writeHead(500)
      response.end('Server error')
    }
  })

  await new Promise((resolve, reject) => {
    server.once('error', reject)
    server.listen(0, '127.0.0.1', resolve)
  })

  return {
    server,
    port: server.address().port,
    stop: () => new Promise((resolveStop) => server.close(() => resolveStop())),
  }
}

async function createMainWindow(rootDir) {
  const { port, stop } = await startLocalServer(rootDir)
  let didClose = false
  const window = new BrowserWindow({
    width: 1280,
    height: 860,
    minWidth: 1024,
    minHeight: 680,
    title: 'Language Corner',
    show: false,
    backgroundColor: '#f3f0e9',
    webPreferences: {
      contextIsolation: true,
      sandbox: false,
    },
  })

  window.loadURL(`http://127.0.0.1:${port}/`)
  window.once('ready-to-show', () => {
    window.show()
  })

  window.on('closed', () => {
    didClose = true
    stop()
  })

  app.on('before-quit', () => {
    if (!didClose) {
      stop()
    }
  })
}

async function getDistDirectory() {
  const localDist = path.join(__dirname, '../Universal/dist')
  if (!app.isPackaged) {
    return localDist
  }

  const candidates = [
    path.join(process.resourcesPath, 'dist'),
    path.join(process.resourcesPath, 'app.dist'),
    path.join(process.resourcesPath, 'app.asar', 'dist'),
    path.join(app.getAppPath(), 'dist'),
    path.join(app.getAppPath(), '..', 'dist'),
    localDist,
  ]

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate
  }

  throw new Error(`找不到 Windows 壳体静态资源目录：已检查 ${candidates.join(' ; ')}`)
}

app.whenReady().then(async () => {
  try {
    const distDir = await getDistDirectory()
    await createMainWindow(distDir)
  } catch (error) {
    console.error(error)
    app.quit()
  }
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
