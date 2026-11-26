/* Service worker « réseau d'abord » pour Kilométrage Pro.
 *
 * - En ligne : toujours la version la plus récente (jamais de vieux fichiers collés
 *   en cache après une mise à jour) ; chaque réponse est copiée dans le cache.
 * - Hors ligne ou réseau lent (> 4 s) : on sert la dernière copie en cache.
 * - Tout est résolu par rapport au dossier du service worker : fonctionne à la racine
 *   d'un domaine comme dans un sous-dossier (ex. GitHub Pages).
 * Pensez à changer VERSION à chaque publication si vous voulez repartir d'un cache vide.
 */
'use strict';

const VERSION = 'v2';
const CACHE = 'kilometrage-pwa-' + VERSION;
const SCOPE = self.registration.scope; // se termine par « / »
const NETWORK_TIMEOUT_MS = 4000;

// Fichiers courants, mis en cache à l'installation (si l'un manque, on l'ignore).
// Le reste est ajouté automatiquement par l'application après son premier affichage.
const CORE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'manifest.json',
  'version.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/NOTICES',
  'assets/assets/fonts/Roboto-Regular.ttf',
  'assets/assets/fonts/Roboto-Bold.ttf',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  'assets/shaders/ink_sparkle.frag',
  'assets/shaders/stretch_effect.frag',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(precache());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  const data = event.data;
  if (!data) return;
  if (data.type === 'CACHE_URLS' && Array.isArray(data.urls)) {
    event.waitUntil(cacheUrls(data.urls));
  } else if (data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || !request.url.startsWith(SCOPE)) return;
  event.respondWith(networkFirst(event, request));
});

function cacheKey(request) {
  // Toutes les navigations (accueil, index.html, ?paramètres) = même page.
  if (request.mode === 'navigate') return SCOPE;
  return request.url;
}

function isCacheable(response) {
  return response && response.ok && response.status === 200;
}

async function networkFirst(event, request) {
  const cache = await caches.open(CACHE);
  const key = cacheKey(request);
  const isNavigation = request.mode === 'navigate';

  const network = (async () => {
    const fresh = isNavigation
      ? await fetch(new Request(SCOPE, { cache: 'no-cache' }))
      : await fetch(request, { cache: 'no-cache' });
    if (isCacheable(fresh)) {
      const copy = fresh.clone();
      event.waitUntil(cache.put(key, copy).catch(() => {}));
    }
    return fresh;
  })();
  network.catch(() => {}); // évite un rejet non géré si le délai a gagné la course

  const cached = await cache.match(key, { ignoreSearch: !isNavigation, ignoreVary: true });

  const timeout = new Promise((resolve) => setTimeout(() => resolve(null), NETWORK_TIMEOUT_MS));
  const winner = await Promise.race([network.catch(() => null), timeout]);

  if (winner && winner.ok) return winner;
  if (cached) return cached;
  if (winner) return winner;
  // Pas de cache et réponse lente : on attend vraiment le réseau.
  try {
    return await network;
  } catch (e) {
    return Response.error();
  }
}

async function precache() {
  const cache = await caches.open(CACHE);
  await Promise.all(CORE.map(async (path) => {
    try {
      const url = new URL(path, SCOPE).href;
      const response = await fetch(new Request(url, { cache: 'reload' }));
      if (isCacheable(response)) await cache.put(url, response);
    } catch (e) { /* fichier absent ou réseau coupé : ignoré */ }
  }));
}

async function cacheUrls(urls) {
  const cache = await caches.open(CACHE);
  await Promise.all(urls.map(async (raw) => {
    try {
      const url = new URL(raw);
      url.hash = '';
      const href = url.href;
      if (url.origin !== self.location.origin || !href.startsWith(SCOPE)) return;
      const key = href === SCOPE || href.startsWith(SCOPE + '?') ? SCOPE : href;
      if (await cache.match(key, { ignoreVary: true })) return;
      const response = await fetch(href);
      if (isCacheable(response)) await cache.put(key, response);
    } catch (e) { /* ignoré */ }
  }));
}
