/* A4ther Service Worker — PWA offline cache
   Strategy:
   - HTML/JS/CSS (app shell) → cache-first com revalidate em background
   - Fontes Google → cache-first eterno
   - Lenis CDN → cache-first eterno
   - Tudo mais → network-first com fallback cache
   ----------------------------------------------------------- */

const CACHE_VERSION = "a4ther-v4.4.90";
const APP_SHELL = [
    "./",
    "./index.html",
    "./manifest.webmanifest",
    "./icon.svg",
    "./apple-touch-icon.png",
    "./icon-192.png",
    "./icon-512.png",
];
const CDN_URLS = [
    "https://cdn.jsdelivr.net/npm/lenis@1.1.20/dist/lenis.min.js",
    "https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako_inflate.min.js",
];

self.addEventListener("install", (event) => {
    event.waitUntil(
        caches.open(CACHE_VERSION).then((cache) => {
            // App shell precisa estar em cache pra offline
            return cache.addAll(APP_SHELL).catch(() => {});
        }).then(() => self.skipWaiting())
    );
});

self.addEventListener("activate", (event) => {
    event.waitUntil(
        caches.keys().then((keys) => {
            // Remove caches velhos
            return Promise.all(
                keys.filter(k => k !== CACHE_VERSION).map(k => caches.delete(k))
            );
        }).then(() => self.clients.claim()).then(async () => {
            // Avisa todos os clients que uma nova versão foi ativada — o index.html
            // mostra um banner "Atualizar" pro user clicar e dar reload (sem F5 manual).
            try {
                const clients = await self.clients.matchAll({ type: 'window' });
                for (const client of clients) {
                    client.postMessage({ type: 'SW_UPDATED', cacheVersion: CACHE_VERSION });
                }
            } catch { /* ignora */ }
        })
    );
});

self.addEventListener("fetch", (event) => {
    const { request } = event;
    if (request.method !== "GET") return;

    const url = new URL(request.url);

    // NUNCA cachear chamadas pra API do panel (sempre fresh)
    if (url.hostname.includes("lspainel.com.br") || url.pathname.startsWith("/api/")) {
        return; // deixa o browser decidir (network)
    }

    // App shell + CDNs: cache-first com revalidate
    const isShell = APP_SHELL.some(p => url.pathname.endsWith(p.replace("./", "/")) || url.pathname === "/");
    const isCDN  = CDN_URLS.includes(request.url);

    if (isShell || isCDN || url.host === "fonts.googleapis.com" || url.host === "fonts.gstatic.com") {
        event.respondWith(
            caches.match(request).then((cached) => {
                const fetchPromise = fetch(request).then((res) => {
                    if (res && res.ok) {
                        const clone = res.clone();
                        caches.open(CACHE_VERSION).then(c => c.put(request, clone));
                    }
                    return res;
                }).catch(() => cached);
                return cached || fetchPromise;
            })
        );
        return;
    }

    // Tudo mais: network-first com fallback ao cache
    event.respondWith(
        fetch(request).then((res) => {
            if (res && res.ok) {
                const clone = res.clone();
                caches.open(CACHE_VERSION).then(c => c.put(request, clone));
            }
            return res;
        }).catch(() => caches.match(request))
    );
});

/* Mensagens (ex: skipWaiting on demand) */
self.addEventListener("message", (event) => {
    if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});
