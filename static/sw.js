const CACHE_NAME = 'blog-offline-v1';
const OFFLINE_FALLBACK = '/offline.html';

// Static core assets to pre-cache on install
const PRECACHE_ASSETS = [
  OFFLINE_FALLBACK,
  '/favicon.svg'
];

// Domains to exclude from caching (ads, analytics, dynamic APIs)
const EXCLUDED_HOSTS = [
  'googletagmanager.com',
  'google-analytics.com',
  'pagead2.googlesyndication.com',
  'www.googletagmanager.com',
  'disqus.com',
  'bus-arrival-sj5kqt5fxq-as.a.run.app',
  'shopping-list-sj5kqt5fxq-as.a.run.app'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_ASSETS).catch((err) => {
        console.warn('[SW] Pre-caching warning:', err);
      });
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Only handle GET requests
  if (request.method !== 'GET') {
    return;
  }

  const url = new URL(request.url);

  // Skip unsupported schemes
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // Exclude third-party ads and analytics
  if (EXCLUDED_HOSTS.some((host) => url.hostname.includes(host))) {
    return;
  }

  // Handle HTML navigation requests (blog entries & pages)
  const isNavigation = request.mode === 'navigate' ||
    (request.headers.get('accept') && request.headers.get('accept').includes('text/html'));

  if (isNavigation) {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          // If response is valid, cache on disk for offline access
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              // Store under both request and pathname for robust offline matching
              cache.put(request, responseClone);
              cache.put(url.pathname, networkResponse.clone());
            });
          }
          return networkResponse;
        })
        .catch(async () => {
          // Offline fallback: try cache first
          const cache = await caches.open(CACHE_NAME);
          const cachedMatch =
            (await cache.match(request)) ||
            (await cache.match(url.pathname)) ||
            (await cache.match(url.pathname.endsWith('/') ? url.pathname.slice(0, -1) : url.pathname + '/'));

          if (cachedMatch) {
            return cachedMatch;
          }

          // If this page was never cached, serve the offline fallback page
          const offlinePage = await cache.match(OFFLINE_FALLBACK);
          if (offlinePage) {
            return offlinePage;
          }

          return new Response(
            '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Offline</title></head><body><h1>Offline</h1><p>You are offline and this page was not saved previously.</p></body></html>',
            { headers: { 'Content-Type': 'text/html' } }
          );
        })
    );
    return;
  }

  // Handle static assets (CSS, JS, Fonts, Images)
  if (
    url.origin === self.location.origin ||
    request.destination === 'style' ||
    request.destination === 'script' ||
    request.destination === 'image' ||
    request.destination === 'font'
  ) {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        // Fetch from network to update cache in background
        const networkFetch = fetch(request)
          .then((networkResponse) => {
            if (networkResponse && networkResponse.status === 200) {
              const responseClone = networkResponse.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(request, responseClone);
              });
            }
            return networkResponse;
          })
          .catch(() => {
            // Network failed, nothing to do since cached response was served if present
          });

        // Return cached immediately if found, otherwise wait for network
        return cachedResponse || networkFetch;
      })
    );
  }
});

// Communication channel with page scripts
self.addEventListener('message', (event) => {
  if (!event.data) return;

  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data.type === 'CHECK_CACHED') {
    const targetUrl = event.data.url;
    caches.open(CACHE_NAME).then(async (cache) => {
      const parsed = new URL(targetUrl);
      const isCached = !!(
        (await cache.match(targetUrl)) ||
        (await cache.match(parsed.pathname)) ||
        (await cache.match(parsed.pathname.endsWith('/') ? parsed.pathname.slice(0, -1) : parsed.pathname + '/'))
      );
      event.ports[0].postMessage({ cached: isCached });
    });
  }

  if (event.data.type === 'GET_CACHED_ENTRIES') {
    caches.open(CACHE_NAME).then(async (cache) => {
      const requests = await cache.keys();
      const urls = requests
        .map((r) => {
          try {
            return new URL(r.url).pathname;
          } catch {
            return r.url;
          }
        })
        .filter((path) => path.startsWith('/') && !path.includes('.') && path !== '/offline.html');
      
      // Return unique pathnames
      const uniqueUrls = Array.from(new Set(urls));
      event.ports[0].postMessage({ entries: uniqueUrls });
    });
  }
});
