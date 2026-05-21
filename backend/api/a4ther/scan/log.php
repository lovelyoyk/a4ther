<?php
/* ============================================================
 *  POST /api/a4ther/scan/log
 *  Body JSON: { verdict, alertsCount, warningsCount, mode, hwid?, ts }
 *  Telemetria opcional — não bloqueia se falhar
 * ============================================================ */
require_once __DIR__ . '/../../../_config.php';
cors_headers();
rate_limit_check();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['error' => 'method_not_allowed'], 405);
}

$raw = file_get_contents('php://input');
$body = json_decode($raw, true);
if (!is_array($body)) {
    json_response(['error' => 'invalid_body'], 400);
}

$verdict = $body['verdict'] ?? '';
if (!in_array($verdict, ['W.O', 'REVISAR', 'LIMPO'], true)) {
    $verdict = 'LIMPO';
}

try {
    $stmt = db()->prepare('
        INSERT INTO scan_log (verdict, alerts_count, warnings_count, mode, hwid, ip, ua)
        VALUES (:verdict, :alerts, :warns, :mode, :hwid, :ip, :ua)
    ');
    $stmt->execute([
        ':verdict' => $verdict,
        ':alerts'  => (int)($body['alertsCount']   ?? 0),
        ':warns'   => (int)($body['warningsCount'] ?? 0),
        ':mode'    => substr((string)($body['mode'] ?? 'unknown'), 0, 32),
        ':hwid'    => $body['hwid'] ? normalize_hwid($body['hwid']) : null,
        ':ip'      => $_SERVER['REMOTE_ADDR']        ?? null,
        ':ua'      => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
    ]);
    json_response(['ok' => true]);
} catch (Throwable $e) {
    error_log('[scan/log] ' . $e->getMessage());
    json_response(['error' => 'internal'], 500);
}
