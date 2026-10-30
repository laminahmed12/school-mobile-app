const CACHE_NAME = "lamin-portal-shell-v9";
const SHELL = ["./", "./index.html", "./styles.css", "./app.js", "./reminders.js"];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("lamin-portal-") && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin && !url.hostname.endsWith("esm.sh") && !url.hostname.endsWith("fonts.googleapis.com") && !url.hostname.endsWith("fonts.gstatic.com")) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) {
      event.waitUntil(fetch(request).then(response => { if (response && response.ok) return cache.put(request, response.clone()); }).catch(() => {}));
      return cached;
    }
    try {
      const response = await fetch(request);
      if (response && response.ok && (url.origin === self.location.origin || response.type === "cors" || response.type === "basic")) await cache.put(request, response.clone());
      return response;
    } catch (error) {
      if (url.origin === self.location.origin) {
        const fallback = await cache.match("./index.html");
        if (fallback && (request.mode === "navigate" || url.pathname.endsWith("/"))) return fallback;
      }
      throw error;
    }
  })());
});
