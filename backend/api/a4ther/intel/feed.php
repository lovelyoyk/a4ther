<?php
/* ============================================================
 *  GET /api/a4ther/intel/feed.json
 *  Retorna IOCs dinâmicos pro scanner (sobrepostos ao hardcoded)
 *  Resposta JSON:
 *  {
 *    "version":          "2026-05-21T14:00Z",
 *    "cheat_apps":       { "com.bundle.id": { sev, name, cat, desc } },
 *    "cheat_infra":      { "domain.com": "descrição" },
 *    "cheat_ips":        { "1.2.3.4": "descrição" },
 *    "substring_patterns":[ { needle, name, cat, sev, desc } ]
 *  }
 * ============================================================ */
require_once __DIR__ . '/../../../_config.php';
cors_headers();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_response(['error' => 'method_not_allowed'], 405);
}

try {
    $stmt = db()->prepare('
        SELECT kind, value, name, category, severity, description
        FROM threat_intel
        WHERE active = 1
        ORDER BY added_at DESC
    ');
    $stmt->execute();
    $rows = $stmt->fetchAll();

    $out = [
        'version'            => date('c'),
        'cheat_apps'         => new stdClass(),
        'cheat_infra'        => new stdClass(),
        'cheat_ips'          => new stdClass(),
        'substring_patterns' => [],
        'tlds'               => [],
    ];

    foreach ($rows as $r) {
        switch ($r['kind']) {
            case 'bundle':
                $out['cheat_apps']->{$r['value']} = [
                    'sev'  => $r['severity'],
                    'name' => $r['name']     ?: $r['value'],
                    'cat'  => $r['category'] ?: 'CHEAT',
                    'desc' => $r['description'] ?: '',
                ];
                break;
            case 'domain':
                $out['cheat_infra']->{$r['value']} = $r['description'] ?: ($r['name'] ?: 'cheat infra');
                break;
            case 'ip':
                $out['cheat_ips']->{$r['value']} = $r['description'] ?: ($r['name'] ?: 'cheat IP');
                break;
            case 'pattern':
                $out['substring_patterns'][] = [
                    'needle' => $r['value'],
                    'name'   => $r['name']     ?: $r['value'],
                    'cat'    => $r['category'] ?: 'CHEAT',
                    'sev'    => $r['severity'],
                    'desc'   => $r['description'] ?: '',
                ];
                break;
            case 'tld':
                $out['tlds'][] = $r['value'];
                break;
        }
    }

    /* Cache-Control: 1h público + revalidação opportunista */
    header('Cache-Control: public, max-age=3600, stale-while-revalidate=86400');
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
} catch (Throwable $e) {
    error_log('[intel/feed] ' . $e->getMessage());
    json_response(['error' => 'internal'], 500);
}
