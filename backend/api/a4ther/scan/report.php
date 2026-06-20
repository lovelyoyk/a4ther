<?php
/* ============================================================
 *  POST /api/a4ther/scan/report
 *  Submissão COMPLETA de scan do APP (a4ther-apk).
 *
 *  PÚBLICA (sem X-Admin-Token) e NÃO bane: só arquiva a evidência
 *  em `scan_report` com status='pendente' pro screener revisar no
 *  painel. Banir continua sendo /blacklist/submit (admin).
 *
 *  Body JSON:
 *  {
 *    "serial": "ABC123", "hwid": "A1B2C3...",
 *    "verdict": "W.O|REVISAR|LIMPO", "alertsCount": 3, "warningsCount": 5,
 *    "model": "POCO X7", "appVersion": "0.1.0", "engineVersion": "4.4.94",
 *    "evidence": { "device": {...}, "alerts": [...], "warnings": [...], "native": {...} }
 *  }
 *  Resposta: { "ok": true, "id": <id> }
 * ============================================================ */
require_once __DIR__ . '/../../../_config.php';
cors_headers();
rate_limit_check();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['error' => 'method_not_allowed'], 405);
}

// Cap anti-abuso (endpoint sem token): rejeita payloads gigantes antes de parsear.
$maxBytes = 1024 * 1024; // 1 MB
$raw = file_get_contents('php://input');
if (strlen($raw) > $maxBytes) {
    json_response(['error' => 'payload_too_large'], 413);
}

$body = json_decode($raw, true);
if (!is_array($body)) {
    json_response(['error' => 'invalid_body'], 400);
}

// Veredito do scan (triagem no painel) — fora do enum vira LIMPO por segurança.
$verdict = $body['verdict'] ?? '';
if (!in_array($verdict, ['W.O', 'REVISAR', 'LIMPO'], true)) {
    $verdict = 'LIMPO';
}

// serial: fiel (o screener lê) · hwid: normalizado (correlaciona com a blacklist).
$serial   = substr((string)($body['serial'] ?? ''), 0, 128) ?: null;
$hwid     = $body['hwid'] ? normalize_hwid($body['hwid']) : null;
$evidence = isset($body['evidence']) ? json_encode($body['evidence'], JSON_UNESCAPED_UNICODE) : null;

try {
    $stmt = db()->prepare('
        INSERT INTO scan_report
            (serial, hwid, verdict, alerts_count, warnings_count, model,
             evidence, app_version, engine_version, source, status, ip, ua)
        VALUES
            (:serial, :hwid, :verdict, :alerts, :warns, :model,
             :evidence, :app_version, :engine_version, :source, :status, :ip, :ua)
    ');
    $stmt->execute([
        ':serial'         => $serial,
        ':hwid'           => $hwid,
        ':verdict'        => $verdict,
        ':alerts'         => (int)($body['alertsCount']   ?? 0),
        ':warns'          => (int)($body['warningsCount'] ?? 0),
        ':model'          => (substr((string)($body['model'] ?? ''), 0, 64) ?: null),
        ':evidence'       => $evidence,
        ':app_version'    => (substr((string)($body['appVersion'] ?? ''), 0, 32) ?: null),
        ':engine_version' => (substr((string)($body['engineVersion'] ?? ''), 0, 16) ?: null),
        ':source'         => 'a4ther-apk',
        ':status'         => 'pendente',
        ':ip'             => $_SERVER['REMOTE_ADDR'] ?? null,
        ':ua'             => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
    ]);
    json_response(['ok' => true, 'id' => (int) db()->lastInsertId()]);
} catch (Throwable $e) {
    error_log('[scan/report] ' . $e->getMessage());
    json_response(['error' => 'internal'], 500);
}
