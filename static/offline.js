(function () {
  'use strict';

  const CACHE_NAME = 'blog-offline-v1';

  // Ensure Service Worker is registered
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker
        .register('/sw.js', { scope: '/' })
        .then((reg) => {
          // Check for SW updates
          reg.addEventListener('updatefound', () => {
            const newWorker = reg.installing;
            if (newWorker) {
              newWorker.addEventListener('statechange', () => {
                if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                  // Service worker updated
                  newWorker.postMessage({ type: 'SKIP_WAITING' });
                }
              });
            }
          });
        })
        .catch((err) => {
          console.warn('[Offline] ServiceWorker registration failed:', err);
        });
    });
  }

  // Helper to ensure an indicator badge element exists in DOM for single articles
  function getOrCreatePostBadge() {
    let indicator = document.getElementById('post-offline-indicator');
    if (indicator) return indicator;

    // Look for slot in article meta
    const slot = document.getElementById('offline-badge-slot');
    if (slot) {
      indicator = createBadgeElement();
      slot.appendChild(indicator);
      return indicator;
    }

    // Fallback: look for single_header or article header
    const singleHeader = document.querySelector('#single_header .article-meta, #single_header');
    if (singleHeader) {
      const wrapper = document.createElement('div');
      wrapper.className = 'mt-2 mb-1';
      indicator = createBadgeElement();
      wrapper.appendChild(indicator);
      singleHeader.appendChild(wrapper);
      return indicator;
    }

    return null;
  }

  function createBadgeElement() {
    const badge = document.createElement('span');
    badge.id = 'post-offline-indicator';
    badge.className = 'offline-badge offline-badge-available';
    badge.title = 'Stored locally on disk for offline reading';
    badge.innerHTML = `
      <span class="offline-badge-dot"></span>
      <span class="offline-badge-text">Available offline</span>
    `;
    return badge;
  }

  // Update badge display based on current network and cache status
  function updatePostBadge(status) {
    const badge = getOrCreatePostBadge();
    if (!badge) return;

    badge.style.display = 'inline-flex';

    if (status === 'offline') {
      badge.className = 'offline-badge offline-badge-offline';
      badge.title = 'You are offline. Reading cached copy from disk.';
      badge.innerHTML = `
        <span class="offline-badge-dot dot-offline"></span>
        <span class="offline-badge-text">⚡ Offline Mode (Cached)</span>
      `;
    } else if (status === 'refetching') {
      badge.className = 'offline-badge offline-badge-syncing';
      badge.title = 'Back online: refetching latest content from server...';
      badge.innerHTML = `
        <span class="offline-badge-dot dot-syncing"></span>
        <span class="offline-badge-text">🔄 Refetching...</span>
      `;
    } else if (status === 'synced') {
      badge.className = 'offline-badge offline-badge-available';
      badge.title = 'Refetched and up to date with server. Stored on disk.';
      badge.innerHTML = `
        <span class="offline-badge-dot dot-online"></span>
        <span class="offline-badge-text">✓ Available offline · Synced</span>
      `;
    } else {
      // Available / cached
      badge.className = 'offline-badge offline-badge-available';
      badge.title = 'Stored locally on disk for offline reading';
      badge.innerHTML = `
        <span class="offline-badge-dot dot-online"></span>
        <span class="offline-badge-text">✓ Available offline</span>
      `;
    }
  }

  // Floating toast notification for connection state changes
  function showToast(message, type = 'info', duration = 4000) {
    let toast = document.getElementById('offline-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'offline-toast';
      toast.className = 'offline-toast';
      document.body.appendChild(toast);
    }

    toast.className = `offline-toast toast-${type} toast-show`;
    toast.innerHTML = `
      <div class="toast-content">
        <span class="toast-message">${message}</span>
      </div>
    `;

    if (window.toastTimeout) {
      clearTimeout(window.toastTimeout);
    }

    if (duration > 0) {
      window.toastTimeout = setTimeout(() => {
        toast.classList.remove('toast-show');
      }, duration);
    }
  }

  function hideToast() {
    const toast = document.getElementById('offline-toast');
    if (toast) {
      toast.classList.remove('toast-show');
    }
  }

  // Verify page cache status and cache current page if needed
  async function checkAndCacheCurrentPage() {
    if (!('caches' in window)) return;

    try {
      const cache = await caches.open(CACHE_NAME);
      const pathname = window.location.pathname;
      const currentUrl = window.location.href;

      const match = (await cache.match(currentUrl)) || (await cache.match(pathname));

      if (match) {
        if (!navigator.onLine) {
          updatePostBadge('offline');
        } else {
          updatePostBadge('available');
        }
      } else if (navigator.onLine) {
        // If not cached yet, cache current page now so it is stored to disk
        try {
          const res = await fetch(currentUrl, { cache: 'no-cache' });
          if (res.ok) {
            await cache.put(currentUrl, res.clone());
            await cache.put(pathname, res);
            updatePostBadge('available');
          }
        } catch (e) {
          // fetch error
        }
      }
    } catch (err) {
      console.warn('[Offline] Cache check failed:', err);
    }
  }

  // Refetch the current post when reconnected to network
  async function refetchCurrentPost() {
    showToast('🌐 Back online! Refetching latest blog post...', 'info', 0);
    updatePostBadge('refetching');

    try {
      // Refetch from network with cache bypass
      const res = await fetch(window.location.href, {
        cache: 'reload',
        headers: { 'X-Requested-With': 'Offline-Sync' }
      });

      if (res && res.status === 200) {
        // Store fresh copy to disk cache
        if ('caches' in window) {
          const cache = await caches.open(CACHE_NAME);
          await cache.put(window.location.href, res.clone());
          await cache.put(window.location.pathname, res.clone());
        }

        updatePostBadge('synced');
        showToast('✓ Blog post refetched & synchronized!', 'success', 3500);

        // After a moment, revert badge back to standard available state
        setTimeout(() => {
          updatePostBadge('available');
        }, 3000);
      } else {
        updatePostBadge('available');
        hideToast();
      }
    } catch (err) {
      console.warn('[Offline] Failed to refetch:', err);
      updatePostBadge(navigator.onLine ? 'available' : 'offline');
      hideToast();
    }
  }

  // Event listeners for offline and online transitions
  window.addEventListener('offline', () => {
    updatePostBadge('offline');
    showToast('⚡ You are currently offline. Visited posts are available from disk.', 'warning', 5000);
  });

  window.addEventListener('online', () => {
    refetchCurrentPost();
  });

  // Initial check upon page load
  document.addEventListener('DOMContentLoaded', () => {
    if (!navigator.onLine) {
      updatePostBadge('offline');
      showToast('⚡ You are currently offline. Reading from disk cache.', 'warning', 4000);
    } else {
      checkAndCacheCurrentPage();
    }
  });

  // Re-verify when page finishes loading
  window.addEventListener('load', () => {
    checkAndCacheCurrentPage();
  });
})();
