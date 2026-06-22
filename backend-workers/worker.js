/**
 * A4ther Backend · Cloudflare Workers + D1
 * ----------------------------------------------------------------
 * Deploy: wrangler deploy
 * Routes:
 *   GET  /api/a4ther/blacklist/check?hwid=X
 *   POST /api/a4ther/blacklist/submit       (admin: X-Admin-Token header)
 *   GET  /api/a4ther/intel/feed.json
 *   POST /api/a4ther/scan/log
 *
 * Env bindings (definidos em wrangler.toml):
 *   - DB             — D1 Database (SQLite)
 *   - ADMIN_TOKEN    — secret (wrangler secret put ADMIN_TOKEN)
 *   - ALLOWED_ORIGINS — comma-separated (env var)
 * ---------------------------------------------------------------- */

const RATE_LIMIT_PER_MIN = 60;

/* ─── Helpers ─── */
const json = (data, init = {}) => new Response(
    JSON.stringify(data),
    {
        status: init.status || 200,
        headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': init.cache || 'no-store',
            ...(init.headers || {}),
        }
    }
);

const corsHeaders = (origin, allowed) => {
    const allow = (allowed || []).includes(origin) ? origin : '';
    return {
        'Access-Control-Allow-Origin':  allow,
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Token, Authorization',
        'Access-Control-Max-Age':       '86400',
        'Vary':                          'Origin',
    };
};

const normalizeHwid = (raw) =>
    String(raw || '').replace(/[^a-zA-Z0-9-]/g, '').toUpperCase();

const checkAdmin = (req, adminToken) => {
    const token = req.headers.get('X-Admin-Token')
              || (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
    return token && token === adminToken;
};

/* Simple in-memory rate limit per Worker isolate (fallback; D1 KV se quiser global) */
const _rateBuckets = new Map();
const rateLimited = (ip) => {
    const key = `${ip}|${Math.floor(Date.now() / 60000)}`;
    const cur = (_rateBuckets.get(key) || 0) + 1;
    _rateBuckets.set(key, cur);
    if (_rateBuckets.size > 500) _rateBuckets.clear();
    return cur > RATE_LIMIT_PER_MIN;
};

/* ─── Route handlers ─── */

async function handleBlacklistCheck(request, env, hwid) {
    if (!hwid || hwid.length < 8) return json({ error: 'invalid_hwid' }, { status: 400 });
    const row = await env.DB.prepare(`
        SELECT hwid, reason, motivos, banned_at, source
        FROM blacklist
        WHERE hwid = ? AND active = 1
        LIMIT 1
    `).bind(hwid).first();

    if (row) {
        return json({
            banned: true,
            hwid:    row.hwid,
            reason:  row.reason,
            date:    String(row.banned_at).slice(0, 10),
            motivos: row.motivos ? row.motivos.split('\n') : [],
            source:  row.source,
        });
    }
    return json({ banned: false, hwid });
}

async function handleBlacklistSubmit(request, env) {
    if (!checkAdmin(request, env.ADMIN_TOKEN)) {
        return json({ error: 'unauthorized' }, { status: 401 });
    }
    const body = await request.json().catch(() => null);
    if (!body || typeof body !== 'object') return json({ error: 'invalid_body' }, { status: 400 });

    const hwid = normalizeHwid(body.hwid);
    if (!hwid || hwid.length < 8) return json({ error: 'invalid_hwid' }, { status: 400 });

    const reason   = String(body.reason   || 'unknown').slice(0, 64);
    const motivos  = Array.isArray(body.motivos) ? body.motivos.slice(0, 50).join('\n') : '';
    const evidence = body.evidence ? JSON.stringify(body.evidence) : null;
    const source   = String(body.source    || 'a4ther-web').slice(0, 32);
    const bannedBy = String(body.banned_by || 'system').slice(0, 64);

    await env.DB.prepare(`
        INSERT INTO blacklist (hwid, reason, motivos, evidence, source, banned_by, active)
        VALUES (?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(hwid) DO UPDATE SET
            reason    = excluded.reason,
            motivos   = excluded.motivos,
            evidence  = excluded.evidence,
            source    = excluded.source,
            banned_by = excluded.banned_by,
            active    = 1
    `).bind(hwid, reason, motivos, evidence, source, bannedBy).run();

    return json({ ok: true, hwid, banned: true });
}

async function handleIntelFeed(env) {
    const { results } = await env.DB.prepare(`
        SELECT kind, value, name, category, severity, description
        FROM threat_intel
        WHERE active = 1
        ORDER BY added_at DESC
    `).all();

    const out = {
        version: new Date().toISOString(),
        cheat_apps:         {},
        cheat_infra:        {},
        cheat_ips:          {},
        substring_patterns: [],
        tlds:               [],
    };

    for (const r of (results || [])) {
        if (r.kind === 'bundle') {
            out.cheat_apps[r.value] = {
                sev:  r.severity,
                name: r.name     || r.value,
                cat:  r.category || 'CHEAT',
                desc: r.description || '',
            };
        } else if (r.kind === 'domain') {
            out.cheat_infra[r.value] = r.description || r.name || 'cheat infra';
        } else if (r.kind === 'ip') {
            out.cheat_ips[r.value] = r.description || r.name || 'cheat IP';
        } else if (r.kind === 'pattern') {
            out.substring_patterns.push({
                needle: r.value,
                name:   r.name     || r.value,
                cat:    r.category || 'CHEAT',
                sev:    r.severity,
                desc:   r.description || '',
            });
        } else if (r.kind === 'tld') {
            out.tlds.push(r.value);
        }
    }

    return json(out, { cache: 'public, max-age=3600, stale-while-revalidate=86400' });
}

async function handleScanLog(request, env) {
    const body = await request.json().catch(() => null);
    if (!body || typeof body !== 'object') return json({ error: 'invalid_body' }, { status: 400 });

    const verdict = ['W.O','REVISAR','LIMPO'].includes(body.verdict) ? body.verdict : 'LIMPO';
    const alerts  = Number.isFinite(+body.alertsCount)   ? +body.alertsCount   : 0;
    const warns   = Number.isFinite(+body.warningsCount) ? +body.warningsCount : 0;
    const mode    = String(body.mode || 'unknown').slice(0, 32);
    const hwid    = body.hwid ? normalizeHwid(body.hwid) : null;
    const ip      = request.headers.get('CF-Connecting-IP') || '';
    const ua      = (request.headers.get('User-Agent') || '').slice(0, 255);

    await env.DB.prepare(`
        INSERT INTO scan_log (verdict, alerts_count, warnings_count, mode, hwid, ip, ua)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `).bind(verdict, alerts, warns, mode, hwid, ip, ua).run();

    return json({ ok: true });
}

/* ─── Router principal ─── */
export default {
    async fetch(request, env, ctx) {
        const url    = new URL(request.url);
        const origin = request.headers.get('Origin') || '';
        const allowedOrigins = (env.ALLOWED_ORIGINS || '')
            .split(',').map(s => s.trim()).filter(Boolean);

        // CORS preflight
        if (request.method === 'OPTIONS') {
            return new Response(null, { status: 204, headers: corsHeaders(origin, allowedOrigins) });
        }

        // Rate limit (skip pra intel/feed que é público + cacheado)
        const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
        if (!url.pathname.endsWith('/intel/feed.json') && rateLimited(ip)) {
            return json({ error: 'rate_limit_exceeded' }, { status: 429, headers: corsHeaders(origin, allowedOrigins) });
        }

        let response;
        try {
            if (request.method === 'GET' && url.pathname === '/api/a4ther/blacklist/check') {
                const hwid = normalizeHwid(url.searchParams.get('hwid'));
                response = await handleBlacklistCheck(request, env, hwid);
            } else if (request.method === 'POST' && url.pathname === '/api/a4ther/blacklist/submit') {
                response = await handleBlacklistSubmit(request, env);
            } else if (request.method === 'GET' && url.pathname === '/api/a4ther/intel/feed.json') {
                response = await handleIntelFeed(env);
            } else if (request.method === 'POST' && url.pathname === '/api/a4ther/scan/log') {
                response = await handleScanLog(request, env);
            } else if (url.pathname === '/' || url.pathname === '/api/a4ther') {
                response = json({
                    name: 'A4ther Backend',
                    version: '1.0.0',
                    routes: [
                        'GET  /api/a4ther/blacklist/check?hwid=X',
                        'POST /api/a4ther/blacklist/submit (admin)',
                        'GET  /api/a4ther/intel/feed.json',
                        'POST /api/a4ther/scan/log',
                    ],
                });
            } else {
                response = json({ error: 'not_found' }, { status: 404 });
            }
        } catch (e) {
            // P2: NUNCA vazar detalhe interno (fragmento de SQL, nome de coluna, valor
            // de bind como hwid) na resposta ao cliente. O detalhe vai SÓ pro log
            // server-side, agora estruturado em JSON (indexável no Logpush/Tail).
            console.error(JSON.stringify({
                level: 'error', msg: 'unhandled',
                route: url.pathname, method: request.method,
                name: e?.name, error: String(e?.message || e), stack: e?.stack,
            }));
            response = json({ error: 'internal' }, { status: 500 });
        }

        // Merge CORS headers
        const newHeaders = new Headers(response.headers);
        for (const [k, v] of Object.entries(corsHeaders(origin, allowedOrigins))) {
            newHeaders.set(k, v);
        }
        return new Response(response.body, {
            status: response.status,
            headers: newHeaders,
        });
    },
};
