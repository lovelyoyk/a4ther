<?php
/* ============================================================
 *  POST /api/a4ther/blacklist/submit
 *  Header:  X-Admin-Token: <token>
 *  Body JSON:
 *  {
 *    "hwid":     "XXXX",
 *    "reason":   "cheats|proxy|sideload|reinstall|profile",
 *    "motivos":  ["motivo 1","motivo 2",...],
 *    "evidence": {...alerts/warnings dump...},
 *    "source":   "a4ther-web|a4ther-sh|admin",
 *    "banned_by":"admin_username"
 *  }
 * ============================================================ */
require_once __DIR__ . '/../../../_config.php';
cors_headers();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(['error' => 'method_not_allowed'], 405);
}
check_admin_token();
rate_limit_check();

$raw = file_get_contents('php://input');
$body = json_decode($raw, true);
if (!is_array($body)) {
    json_response(['error' => 'invalid_body'], 400);
}

$hwid = normalize_hwid($body['hwid'] ?? '');
if (!$hwid || strlen($hwid) < 8) {
    json_response(['error' => 'invalid_hwid'], 400);
}

$reason   = substr((string)($body['reason']   ?? 'unknown'), 0, 64);
$motivos  = is_array($body['motivos'] ?? null)
    ? implode("\n", array_slice($body['motivos'], 0, 50))
    : '';
$evidence = isset($body['evidence']) ? json_encode($body['evidence'], JSON_UNESCAPED_UNICODE) : null;
$source   = substr((string)($body['source']    ?? 'a4ther-web'), 0, 32);
$bannedBy = substr((string)($body['banned_by'] ?? 'system'), 0, 64);

try {
    $stmt = db()->prepare('
        INSERT INTO blacklist (hwid, reason, motivos, evidence, source, banned_by, active)
        VALUES (:hwid, :reason, :motivos, :evidence, :source, :banned_by, 1)
        ON DUPLICATE KEY UPDATE
            reason    = VALUES(reason),
            motivos   = VALUES(motivos),
            evidence  = VALUES(evidence),
            source    = VALUES(source),
            banned_by = VALUES(banned_by),
            active    = 1
    ');
    $stmt->execute([
        ':hwid'      => $hwid,
        ':reason'    => $reason,
        ':motivos'   => $motivos,
        ':evidence'  => $evidence,
        ':source'    => $source,
        ':banned_by' => $bannedBy,
    ]);
    audit('blacklist_submit', ['hwid' => $hwid, 'reason' => $reason]);
    json_response([
        'ok'     => true,
        'hwid'   => $hwid,
        'banned' => true,
    ]);
} catch (Throwable $e) {
    error_log('[blacklist/submit] ' . $e->getMessage());
    json_response(['error' => 'internal'], 500);
}
