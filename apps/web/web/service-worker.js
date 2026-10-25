const CACHE = 'attendly-shell-__BUILD_ID__';
self.addEventListener('install', event => event.waitUntil((async () => {
  const response = await fetch('precache-manifest.json', {cache: 'no-store'});
  if (!response.ok) throw new Error('Offline manifest unavailable');
  const files = await response.json();
  const cache = await caches.open(CACHE);
  await cache.addAll(files);
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  await Promise.all((await caches.keys()).filter(k => k.startsWith('attendly-shell-') && k !== CACHE).map(k => caches.delete(k)));
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/') || url.pathname.startsWith('/oauth2/') || url.pathname.startsWith('/login/')) return;
  event.respondWith(fetch(event.request).then(response => {
    if (response.ok) { const copy = response.clone(); caches.open(CACHE).then(cache => cache.put(event.request, copy)); }
    return response;
  }).catch(async () => (await caches.match(event.request)) || (event.request.mode === 'navigate' ? caches.match('./index.html') : Response.error())));
});
