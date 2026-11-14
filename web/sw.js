const CACHE_NAME = "lamin-portal-shell-v15";
const SUPABASE_CLIENT_MODULE = "https://esm.sh/@supabase/supabase-js@2.57.4?bundle";
const SHELL = [
  "./",
  "./index.html",
  "./styles.css",
  "./app.js",
  "./reminders.js",
  SUPABASE_CLIENT_MODULE
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(key => key.startsWith("lamin-portal-") && key !== CACHE_NAME)
          .map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  const sameOrigin = url.origin === self.location.origin;
  const allowedExternal = url.hostname === "esm.sh" ||
    url.hostname === "fonts.googleapis.com" ||
    url.hostname === "fonts.gstatic.com";
  if (!sameOrigin && !allowedExternal) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) {
      if (sameOrigin) {
        event.waitUntil(
          fetch(request).then(response => {
            if (response && response.ok) return cache.put(request, response.clone());
          }).catch(() => {})
        );
      }
      return cached;
    }

    try {
      const response = await fetch(request);
      if (response && response.ok &&
          (sameOrigin || response.type === "cors" || response.type === "basic")) {
        await cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      if (sameOrigin && (request.mode === "navigate" || url.pathname.endsWith("/"))) {
        const fallback = await cache.match("./index.html");
        if (fallback) return fallback;
      }
      throw error;
    }
  })());
});
