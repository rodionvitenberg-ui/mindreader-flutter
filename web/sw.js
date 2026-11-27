'use strict';

/**
 * Tarot Tree PWA Service Worker
 *
 * - Shell files (HTML, manifest, Flutter bootstrap & main bundle): Network-First
 *   with Cache fallback so updates roll out cleanly while offline reloads work.
 * - Runtime assets (CanvasKit/Wasm, fonts, deck art, rune stones, zodiac art):
 *   Lazy Cache-First — decks (~36 MB total) are NEVER precached upfront; each
 *   card/deck caches on first view for instant offline replay.
 * - API calls (/api/*) and non-GET requests: strictly Network-Only.
 */

const SHELL_CACHE = 'tarot-tree-shell-v1';
const ASSETS_CACHE = 'tarot-tree-assets-v1';

const SHELL_PRECACHE = [
  './',
  './index.html',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
];

const LAZY_ASSET_PREFIXES = [
  '/assets/',
  '/canvaskit/',
  '/icons/',
];

const LAZY_ASSET_EXT_RE = /\.(wasm|js|mjs|woff2?|ttf|otf|webp|png|jpe?g|svg|json)$/i;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      .then((cache) => cache.addAll(SHELL_PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  const keep = new Set([SHELL_CACHE, ASSETS_CACHE]);
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => !keep.has(k)).map((k) => caches.delete(k)))
      )
      .then(() => self.clients.claim())
  );
});

function isShellRequest(url, request) {
  if (request.mode === 'navigate') return true;
  const p = url.pathname;
  return (
    p === '/' ||
    p.endsWith('/index.html') ||
    p.endsWith('/manifest.json') ||
    p.endsWith('/flutter_bootstrap.js') ||
    p.endsWith('/flutter.js') ||
    p.endsWith('/main.dart.js') ||
    p.endsWith('/main.dart.wasm') ||
    p.endsWith('/main.dart.mjs')
  );
}

function isLazyAssetRequest(url) {
  const p = url.pathname;
  if (LAZY_ASSET_PREFIXES.some((prefix) => p.includes(prefix))) {
    return true;
  }
  return LAZY_ASSET_EXT_RE.test(p);
}

async function networkFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  try {
    const response = await fetch(request);
    if (response && response.ok && response.type === 'basic') {
      cache.put(request, response.clone()).catch(() => {});
    }
    return response;
  } catch (_) {
    const cached = await cache.match(request);
    if (cached) return cached;
    if (request.mode === 'navigate') {
      const shell = await cache.match('./index.html') || await cache.match('./');
      if (shell) return shell;
    }
    throw new Error('Offline and not cached');
  }
}

async function cacheFirstLazy(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response && response.ok && (response.type === 'basic' || response.type === 'cors')) {
    cache.put(request, response.clone()).catch(() => {});
  }
  return response;
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Never intercept API traffic or non-HTTP(S) schemes.
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
  if (url.pathname.startsWith('/api/')) return;

  const sameOrigin = url.origin === self.location.origin;
  const isCanvasKitCdn = url.hostname === 'www.gstatic.com' && url.pathname.includes('flutter-canvaskit');

  if (!sameOrigin && !isCanvasKitCdn) return;

  if (sameOrigin && isShellRequest(url, request)) {
    event.respondWith(networkFirst(request, SHELL_CACHE));
    return;
  }

  if (isLazyAssetRequest(url)) {
    event.respondWith(cacheFirstLazy(request, ASSETS_CACHE));
  }
});
