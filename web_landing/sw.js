const CACHE_NAME = 'imoney-v5';
const ASSETS = [
    './',
    './index.html',
    './style.css',
    './main.js',
    './manifest.json',
    './assets/logo.png',
    './assets/hero.png',
    './assets/dashboard.png',
    './assets/voice.png',
    './assets/transactions.png'
];

self.addEventListener('install', (e) => {
    e.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
    );
});

self.addEventListener('fetch', (e) => {
    e.respondWith(
        caches.match(e.request).then((res) => res || fetch(e.request))
    );
});
