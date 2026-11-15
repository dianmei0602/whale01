/* ============================================================
   sw.js — 《山河战纪》PWA 离线缓存
   仅缓存同源资源，无外链；数据亦本地缓存，离线可完整阅读。
   ============================================================ */

const CACHE = 'shj-cache-v11';

const PRECACHE = [
  './',
  './index.html',
  './privacy.html',
  './clan/',
  './clan/index.html',
  './manifest.webmanifest',
  './css/base.css',
  './css/layout.css',
  './css/timeline.css',
  './css/detail.css',
  './css/search.css',
  './css/map.css',
  './css/generals.css',
  './css/factions.css',
  './css/graph.css',
  './css/legend.css',
  './css/atlas.css',
  './css/favorites.css',
  './css/replays.css',
  './css/stategraph.css',
  './css/onboarding.css',
  './css/refine.css',
  './css/replay.css',
  './css/motion.css',
  './css/clan.css',
  './css/stats.css',
  './js/app.js',
  './js/router.js',
  './js/data.js',
  './js/store.js',
  './js/ui.js',
  './js/ink.js',
  './js/timeline.js',
  './js/detail.js',
  './js/search.js',
  './js/filter.js',
  './js/more.js',
  './js/placeholders.js',
  './js/map.js',
  './js/generals.js',
  './js/factions.js',
  './js/graph.js',
  './js/legend.js',
  './js/atlas.js',
  './js/favorites.js',
  './js/replays.js',
  './js/stategraph.js',
  './js/onboarding.js',
  './js/motion.js',
  './js/replay.js',
  './js/stats.js',
  './js/china-geo.js',
  './js/pwa.js',
  './js/territory.js',
  './js/research.js',
  './js/clan.js',
  './assets/noise.svg',
  './assets/paper.svg',
  './assets/huiwen.svg',
  './assets/cloud-band.svg',
  './assets/mountains.svg',
  './assets/standard-map.jpg',
  './assets/favicon.svg',
  './assets/apple-touch-icon-180.png',
  './assets/icon-180.png',
  './assets/icon-192.png',
  './assets/icon-512.png',
  './assets/icon-512-maskable.png',
  './data/eras.json',
  './data/era-01.json',
  './data/era-02.json',
  './data/era-03.json',
  './data/era-04.json',
  './data/era-05.json',
  './data/era-06.json',
  './data/era-07.json',
  './data/era-08.json',
  './data/era-09.json',
  './data/era-10.json',
  './data/era-11.json',
  './data/era-12.json',
  './data/generals.json',
  './data/factions.json',
  './data/relations.json',
  './data/replays.json',
  './data/powers.json',
  './data/territories.json',
  './data/clans.json',
  './data/china-provinces.json',
  './data/state-relations.json',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      // 逐项缓存：个别资源缺失不影响整体离线能力
      .then((cache) => Promise.allSettled(PRECACHE.map((url) => cache.add(url))))
      .then(() => self.skipWaiting())
      .catch(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  let url;
  try {
    url = new URL(request.url);
  } catch (err) {
    return;
  }
  if (url.origin !== self.location.origin) return;

  // 页面导航：网络优先，离线回退到缓存的首页（hash 路由不需要服务端路径）
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put('./index.html', copy));
          return response;
        })
        .catch(() => caches.match('./index.html'))
    );
    return;
  }

  // 数据文件：网络优先（内容更新后能拿到新数据），离线回退缓存
  if (url.pathname.indexOf('/data/') !== -1) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => caches.match(request))
    );
    return;
  }

  // 静态资源与数据：缓存优先，后台更新
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;
      return fetch(request)
        .then((response) => {
          if (response && response.ok && response.type === 'basic') {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => cached);
    })
  );
});
