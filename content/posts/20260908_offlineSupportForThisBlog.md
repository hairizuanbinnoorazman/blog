+++
title = "Making This Blog Available Offline for In-Flight Reading"
description = "How we added offline support with Service Workers, disk-backed CacheStorage, cache-first static assets, dynamic fallback listing, and connection sync."
tags = [
    "pwa",
    "javascript",
    "hugo",
    "offline",
    "web",
]
date = "2026-09-08"
categories = [
    "development",
]
+++

Whenever I board a flight, one of the first things I do after reaching cruising altitude is open my laptop or tablet to read through saved technical articles, documentation, or past notes. In-flight Wi-Fi is either non-existent, prohibitively expensive, or throttled to the point where simple page requests time out.

For a static technical blog like this one, there is no real justification for failing to load when there is no internet connection. Every post is pure HTML, CSS, a sprinkling of JavaScript, and images. Once a reader visits a page, that content should ideally remain accessible on disk so they can read it at 35,000 feet in Airplane Mode without seeing the browser's default connection error screen.

We recently rolled out full offline support to this blog. If you visit any article while online, that post and its required assets are automatically cached in your browser's persistent local storage. If your connection drops—or if you flip on Airplane Mode—the blog detects the offline state, presents clear indicators, serves the cached content directly from disk, and even provides an offline index of every article saved on your device.

Here is an architectural walkthrough of how we implemented this, how the caching strategies work under the hood, the client-side synchronization mechanics, and browser compatibility across modern platforms.

---

## Architectural Overview

The core building block for client-side offline support is the **Service Worker API** paired with the **Cache Storage API**.

A Service Worker acts as a client-side programmable network proxy. It runs in an independent background execution thread, decoupled from any single browser tab or window. Every HTTP request made by the page (whether a document navigation, stylesheet, script, font, or image) passes through the Service Worker's `fetch` event handler before hitting the physical network.

```text
+-------------------------------------------------------------+
|                        Browser Tab                          |
|         (DOM, article metadata badge, toast alert)          |
+------------------------------+------------------------------+
                               | 1. HTTP Request
                               v
+-------------------------------------------------------------+
|                       Service Worker                        |
|   - Excludes 3rd-party ads/telemetry                        |
|   - Routes HTML navigation (Network-first with disk fallback)|
|   - Routes static assets (Stale-while-revalidate)           |
+---------------+-----------------------------+---------------+
                |                             |
                | 2a. Offline / Cache hit     | 2b. Online
                v                             v
+-------------------------------+   +-------------------------+
|     Cache Storage (Disk)      |   |   Remote Server (CDN)   |
|   - blog-offline-v1           |   |   - Origin host         |
|   - HTML docs & path aliases  |   +-------------------------+
|   - CSS, JS, SVG, WebFonts    |
+-------------------------------+
```

The system is organized into four main layers:

1. **The Service Worker (`sw.js`)**: Handles pre-caching fallback pages, intercepting fetch requests, matching requests against local caches, and storing responses.
2. **Client-Side Orchestrator (`offline.js`)**: Runs on every page, registers the worker, checks whether the current page is stored on disk, monitors online/offline network transitions, and updates UI status badges.
3. **The Offline Fallback Page (`offline.html`)**: Displayed if a user attempts to navigate to a page that was never previously cached, complete with a client-side script that inspects `CacheStorage` and dynamically lists all saved articles.
4. **Hugo Layout Integration (`layouts/partials/`)**: Injects the offline indicator badge into the post metadata header and renders a floating connection status toast.

---

## Service Worker Lifecycle and Implementation

The service worker lives at the root of the site (`/sw.js`) so that its scope covers all paths (`/`).

### 1. Installation and Pre-caching

During the `install` phase, the worker opens a versioned cache bucket (`blog-offline-v1`) and downloads the minimal fallback shell. It calls `self.skipWaiting()` to activate immediately without waiting for existing open tabs to close:

```javascript
const CACHE_NAME = 'blog-offline-v1';
const OFFLINE_FALLBACK = '/offline.html';

// Static core assets to pre-cache on install
const PRECACHE_ASSETS = [
  OFFLINE_FALLBACK,
  '/favicon.svg'
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
```

### 2. Activation and Cache Pruning

During activation, the worker deletes obsolete cache stores from previous deployments and calls `self.clients.claim()` so that currently open pages immediately fall under its control:

```javascript
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});
```

### 3. Request Routing and Caching Strategies

Not all requests should be treated equally:

- **HTML Navigation**: We want readers to always see the freshest version of a post when connected, but seamlessly fall back to the disk copy when disconnected. This calls for a **Network-First with Cache Fallback** strategy.
- **Static Assets (CSS, JS, Fonts, Images)**: Assets rarely change without cache-busting hashes or distinct URLs, so we use **Stale-While-Revalidate**—serving from cache instantly while asynchronously querying the network for updates.
- **Third-Party Services**: External ad scripts, analytics (Google Tag Manager), and third-party comment systems (Disqus) must be strictly bypassed and ignored. Caching third-party beacons is unnecessary and can cause stale telemetry or noisy console errors.

Here is how the fetch handler manages this:

```javascript
// Domains to exclude from caching (ads, analytics, dynamic APIs)
const EXCLUDED_HOSTS = [
  'googletagmanager.com',
  'google-analytics.com',
  'pagead2.googlesyndication.com',
  'www.googletagmanager.com',
  'disqus.com'
];

self.addEventListener('fetch', (event) => {
  const request = event.request;

  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (!url.protocol.startsWith('http')) return;

  // Exclude third-party services
  if (EXCLUDED_HOSTS.some((host) => url.hostname.includes(host))) {
    return;
  }

  const isNavigation = request.mode === 'navigate' ||
    (request.headers.get('accept') && request.headers.get('accept').includes('text/html'));

  if (isNavigation) {
    event.respondWith(
      fetch(request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              // Store under both full request and clean pathname
              cache.put(request, responseClone);
              cache.put(url.pathname, networkResponse.clone());
            });
          }
          return networkResponse;
        })
        .catch(async () => {
          const cache = await caches.open(CACHE_NAME);

          // Attempt flexible path matching (with or without trailing slashes)
          const cachedMatch =
            (await cache.match(request)) ||
            (await cache.match(url.pathname)) ||
            (await cache.match(url.pathname.endsWith('/') ? url.pathname.slice(0, -1) : url.pathname + '/'));

          if (cachedMatch) {
            return cachedMatch;
          }

          // Uncached page: serve offline fallback shell
          const offlinePage = await cache.match(OFFLINE_FALLBACK);
          if (offlinePage) {
            return offlinePage;
          }

          return new Response('<h1>Offline</h1><p>Page not cached.</p>', {
            headers: { 'Content-Type': 'text/html' }
          });
        })
    );
    return;
  }

  // Handle static assets
  if (
    url.origin === self.location.origin ||
    ['style', 'script', 'image', 'font'].includes(request.destination)
  ) {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        const networkFetch = fetch(request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(request, responseClone);
            });
          }
          return networkResponse;
        }).catch(() => {});

        return cachedResponse || networkFetch;
      })
    );
  }
});
```

One subtle detail in the navigation handler is **dual-key caching**:
When a page is saved, we put it into `CacheStorage` under both `request` (which includes the full origin, scheme, and query params) and `url.pathname`. When offline in transit, relative cross-links or URL variations with or without a trailing slash (e.g. `/posts/foo/` vs `/posts/foo`) will still resolve cleanly against the local disk cache.

---

## Client-Side Presence and Synchronization (`offline.js`)

A service worker operates silently in the background, but users need visual confirmation that their reading session is safe before boarding a flight. They also need to know whether the page they are looking at is a live network copy or a local cache.

To achieve this, `offline.js` is loaded with `defer` on every page. It fulfills four responsibilities:

### 1. Ensuring Automatic Page Persistence

When a user reads any post while online, `offline.js` verifies whether the post has been written to `CacheStorage`. If not, it triggers an immediate local cache write:

```javascript
async function checkAndCacheCurrentPage() {
  if (!('caches' in window)) return;

  try {
    const cache = await caches.open(CACHE_NAME);
    const pathname = window.location.pathname;
    const currentUrl = window.location.href;

    const match = (await cache.match(currentUrl)) || (await cache.match(pathname));

    if (match) {
      updatePostBadge(navigator.onLine ? 'available' : 'offline');
    } else if (navigator.onLine) {
      const res = await fetch(currentUrl, { cache: 'no-cache' });
      if (res.ok) {
        await cache.put(currentUrl, res.clone());
        await cache.put(pathname, res);
        updatePostBadge('available');
      }
    }
  } catch (err) {
    console.warn('[Offline] Cache check failed:', err);
  }
}
```

This means you do not need to manually press a "Save for Offline" button for every post. If you opened the tab or read through the article while sitting at the boarding gate, it is already cached locally on disk.

### 2. Real-Time State Indicators

We inject an offline badge into the article header (defined in `layouts/partials/article-meta/basic.html`):

```html
<span class="ps-2" id="offline-badge-slot">
  <span class="offline-badge" id="post-offline-indicator" style="display: none;">
    <span class="offline-badge-dot"></span>
    <span class="offline-badge-text">Available offline</span>
  </span>
</span>
```

The badge reflects four distinct states:
- **`✓ Available offline`**: Stored locally on disk; user is online.
- **`⚡ Offline Mode (Cached)`**: Network is disconnected; reader is reading the cached copy from disk.
- **`🔄 Refetching...`**: Device just reconnected to the internet; fetching fresh content from the origin server.
- **`✓ Available offline · Synced`**: Background refetch completed successfully and the local cache has been updated.

### 3. Connection State Transitions and Toasts

We attach listeners to the window's `online` and `offline` events:

```javascript
window.addEventListener('offline', () => {
  updatePostBadge('offline');
  showToast('⚡ You are currently offline. Visited posts are available from disk.', 'warning', 5000);
});

window.addEventListener('online', () => {
  refetchCurrentPost();
});
```

When network drops, a floating non-blocking toast informs the user that cached posts remain fully readable.

When connection returns (e.g. upon landing and turning off Airplane Mode), `refetchCurrentPost()` fires an HTTP request with `cache: 'reload'` to bypass local browser caches and pull down any newly committed edits:

```javascript
async function refetchCurrentPost() {
  showToast('🌐 Back online! Refetching latest blog post...', 'info', 0);
  updatePostBadge('refetching');

  try {
    const res = await fetch(window.location.href, {
      cache: 'reload',
      headers: { 'X-Requested-With': 'Offline-Sync' }
    });

    if (res && res.status === 200) {
      if ('caches' in window) {
        const cache = await caches.open(CACHE_NAME);
        await cache.put(window.location.href, res.clone());
        await cache.put(window.location.pathname, res.clone());
      }

      updatePostBadge('synced');
      showToast('✓ Blog post refetched & synchronized!', 'success', 3500);

      setTimeout(() => updatePostBadge('available'), 3000);
    }
  } catch (err) {
    updatePostBadge(navigator.onLine ? 'available' : 'offline');
    hideToast();
  }
}
```

---

## Dynamic On-Device Article Directory (`offline.html`)

What happens if a user is offline at 35,000 feet and clicks a link to an article they did *not* visit before the flight?

Instead of presenting an empty dead end, the Service Worker serves `/offline.html`. In addition to explaining that the current article was not pre-downloaded, the fallback page inspects the browser's `CacheStorage` directly and renders an interactive list of every post that *is* currently stored locally on disk:

```javascript
// Inside offline.html
if ('caches' in window) {
  caches.open('blog-offline-v1').then(function (cache) {
    return cache.keys();
  }).then(function (requests) {
    var list = document.getElementById('saved-posts-list');
    var section = document.getElementById('saved-posts-section');
    var paths = new Set();

    requests.forEach(function (req) {
      try {
        var url = new URL(req.url);
        var p = url.pathname;
        // Filter out assets and shell pages to list only blog posts
        if (p && p.length > 1 && !p.includes('.') && p !== '/offline.html') {
          paths.add(p);
        }
      } catch (e) {}
    });

    if (paths.size > 0) {
      paths.forEach(function (path) {
        var li = document.createElement('li');
        li.className = 'saved-item';
        var link = document.createElement('a');
        link.href = path;
        var cleanTitle = path.replace(/^\//, '').replace(/\/$/, '').replace(/[-_]/g, ' ');
        link.textContent = cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1);
        li.appendChild(link);
        list.appendChild(li);
      });
      section.style.display = 'block';
    }
  });
}
```

This ensures the user can immediately jump to another cached article without guessing which URLs are available.

---

## Browser Support and Platform Differences

Service Workers and the Cache Storage API are established web standards (W3C recommendations), but platform implementation details vary.

| Browser Family | Engines / Examples | Service Worker & Cache API Support | Storage Quota & Persistence Notes |
| :--- | :--- | :--- | :--- |
| **Chromium** | Google Chrome, Microsoft Edge, Brave, Opera, Vivaldi, Arc, Samsung Internet (Desktop & Android) | **Full Support** | Up to 60–80% of free disk space. Uses Least Recently Used (LRU) eviction under extreme disk pressure, but typical static blog storage (a few megabytes) is never evicted. Background Sync supported. |
| **Gecko** | Mozilla Firefox (Desktop & Android) | **Full Support** | Full support for Service Worker and Cache Storage. Group quota is up to 10% of free disk space per origin, up to several gigabytes. |
| **WebKit** | Apple Safari (macOS, iOS, iPadOS) | **Full Support (with caveats)** | Supported since Safari 11.1 / iOS 11.3. See specific WebKit caveats below. |
| **Proxy Browsers** | Opera Mini (Extreme Mode) | **No Support** | Traffic routes through Opera transcoding compression servers; client-side Service Workers cannot run. |
| **Legacy Browsers**| Internet Explorer 11 | **No Support** | Does not support Service Workers or modern ES6 APIs. |

### WebKit / Safari Nuances to Keep in Mind

If you are using an iPhone, iPad, or Mac Safari during your flight, there are three practical caveats worth noting:

1. **Intelligent Tracking Prevention (ITP) Eviction**: Safari enforces client-side storage deletion rules if a site has had no user interaction for 7 days. For travel, this is not an issue if you browse posts the day of or day before your flight. Furthermore, if you tap **Add to Home Screen** on iOS to install the blog as a progressive web app (PWA), WebKit treats it as an installed application and exempts it from the 7-day eviction timer.
2. **Private Browsing Mode**: Safari completely disables Service Worker registration in Private Browsing tabs. To use offline reading, you must open the blog in a standard tab.
3. **Secure Contexts (HTTPS)**: Like all browsers, Safari strictly requires HTTPS to register a Service Worker (with `localhost` being the only exception for development).

---

## Testing Offline Mode

To verify that offline reading works before stepping onto a plane, you can test it directly in your browser's developer tools:

1. Open DevTools (**F12** or **Cmd + Option + I**).
2. Go to the **Application** tab (in Chrome/Edge) or **Storage** tab (in Firefox).
3. Under **Application > Service Workers**, check that `/sw.js` is registered, active, and running.
4. Check **Cache Storage > blog-offline-v1** to inspect the cached HTML entries, stylesheets, and images.
5. In the **Network** tab, switch the throttling dropdown from **No throttling** to **Offline** (or toggle your computer's Wi-Fi off).
6. Click around the blog. Visited posts will load instantly from disk with the badge displaying `⚡ Offline Mode (Cached)`. Clicking an unvisited article will present the offline fallback directory showing all available saved articles.

---

## Conclusion

Making a static blog work offline does not require complex frameworks or client-side single-page application (SPA) architectures. By combining standard Hugo layouts with a lightweight Service Worker (`sw.js`), an offline UI supervisor (`offline.js`), and a dynamic fallback screen (`offline.html`), we can turn standard static HTML pages into a resilient, offline-first reading experience.

Now, whether you are on a 14-hour transpacific flight, riding a subway tunnel, or dealing with intermittent mobile data, every article you have visited remains right there on your local storage—ready to read whenever you want.
