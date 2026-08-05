const CACHE = 'language-corner-core-v17'
const CORE = [
  '', 'index.html', 'assets/app.js', 'assets/app.css', 'manifest.webmanifest',
  'icon-192.png', 'icon-512.png', 'content/content-manifest.json',
  'content/english-lessons.json', 'content/english-lexemes.json',
  'content/english-sentences.json', 'content/english-topics.json', 'content/lexemes.json',
  'content/long-term-sentences.json', 'content/speaking-challenges.json',
  'content/supplemental-lexemes.json', 'content/supplemental-sentences.json', 'content/topics.json',
]

const scopedURL = (path) => new URL(path, self.registration.scope).toString()

self.addEventListener('install', (event) => {
  const freshRequests = CORE.map((path) => new Request(scopedURL(path), { cache: 'reload' }))
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(freshRequests)).then(() => self.skipWaiting()))
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return
  event.respondWith(
    caches.match(event.request, { ignoreVary: true }).then((cached) => cached || fetch(event.request).then((response) => {
      if (response.ok) caches.open(CACHE).then((cache) => cache.put(event.request, response.clone()))
      return response
    })),
  )
})
