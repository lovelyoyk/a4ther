<?php
/* ============================================================
 *  GET /api/a4ther/blacklist/check?hwid=<HWID>
 *  Resposta JSON:
 *  {
 *    "banned": true|false,
 *    "hwid":   "XXXX",
 *    "reason": "cheats|proxy|sideload|...",
 *    "date":   "2026-05-20",
 *    "motivos":["MCProfileEvents 10 profiles opacos","..."],
 *    "source": "a4ther-web"
 *  }
 * ============================================================ */
require_once __DIR__ . '/../../../_config.php';
cors_headers();
rate_limit_check();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['error' => 'method_not_allowed'], 405);
}

$hwid = normalize_hwid($_GET['hwid'] ?? '');
if (!$hwid || strlen($hwid) < 8) {
    json_response(['error' => 'invalid_hwid'], 400);
}

try {
    $stmt = db()->prepare('
        SELECT hwid, reason, motivos, banned_at, source, active
        FROM blacklist
        WHERE hwid = :hwid AND active = 1
        LIMIT 1
    ');
    $stmt->execute([':hwid' => $hwid]);
    $row = $stmt->fetch();

    if ($row) {
        json_response([
            'banned'  => true,
            'hwid'    => $row['hwid'],
            'reason'  => $row['reason'],
            'date'    => substr($row['banned_at'], 0, 10),
            'motivos' => $row['motivos'] ? explode("\n", $row['motivos']) : [],
            'source'  => $row['source'],
        ]);
    }
    json_response([
        'banned' => false,
        'hwid'   => $hwid,
    ]);
} catch (Throwable $e) {
    error_log('[blacklist/check] ' . $e->getMessage());
    json_response(['error' => 'internal'], 500);
}
