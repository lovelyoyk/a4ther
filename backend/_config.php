<?php
/* ============================================================
 *  A4ther Backend Config — LS Aluguel · lspainel.com.br
 *  Copie este arquivo pro servidor e ajuste DB credentials.
 * ============================================================ */

// Database — MySQL/MariaDB (ajuste para seu painel)
const DB_HOST    = 'localhost';
const DB_NAME    = 'lspainel_a4ther';   // criar database/schema antes
const DB_USER    = 'lspainel_user';     // ajustar
// P1: segredo via env A4_DB_PASS (fallback p/ retrocompat). Em prod NÃO hardcodar —
// setar A4_DB_PASS (SetEnv do Apache ou .env fora do webroot); o fonte (repo público) nunca leva o valor real.
define('DB_PASS', getenv('A4_DB_PASS') ?: 'CHANGE_ME');
const DB_CHARSET = 'utf8mb4';

// Admin token pra submit/admin endpoints. P1: via env A4_ADMIN_TOKEN (fallback p/
// retrocompat). Em prod setar A4_ADMIN_TOKEN (SetEnv/.env) e rotacionar — nunca hardcodar.
define('ADMIN_TOKEN', getenv('A4_ADMIN_TOKEN') ?: 'CHANGE_ME_SECRET_TOKEN_32_CHARS_MINIMUM');

// CORS — origins permitidos (Apple Safari precisa de listagem explícita)
const ALLOWED_ORIGINS = [
    'https://lovelyoyk.github.io',
    'https://a4ther.lspainel.com.br',
    'https://lspainel.com.br',
    'http://localhost:5173',     // dev
    'http://192.168.1.145:5173', // LAN dev
];

// Rate limiting (anti-spam) — req por IP por minuto
const RATE_LIMIT_PER_MIN = 60;

// Logging — true em prod pra audit trail
const ENABLE_AUDIT_LOG = true;
const AUDIT_LOG_PATH   = __DIR__ . '/_logs/audit.log';

/* ============================================================
 *  HELPERS GLOBAIS
 * ============================================================ */
function db() {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=" . DB_CHARSET;
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        } catch (PDOException $e) {
            // P1: falha de CONEXÃO é crítica (infra) e a mensagem do PDOException de
            // conexão costuma conter o DSN (host/dbname/user). NUNCA logar getMessage()
            // aqui — só o código. Relança genérico pra o endpoint não vazar o DSN.
            error_log('[a4ther][CRITICAL] db_connect falhou code=' . $e->getCode());
            throw new RuntimeException('db_unavailable', 0);
        }
    }
    return $pdo;
}

function cors_headers() {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    if (in_array($origin, ALLOWED_ORIGINS, true)) {
        header("Access-Control-Allow-Origin: $origin");
    }
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Token');
    header('Access-Control-Max-Age: 86400');
    header('Vary: Origin');
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function json_response($data, $code = 200) {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function audit($action, $payload = []) {
    if (!ENABLE_AUDIT_LOG) return;
    @mkdir(dirname(AUDIT_LOG_PATH), 0750, true);
    $line = date('c') . " | " . ($_SERVER['REMOTE_ADDR'] ?? '?') . " | $action | "
          . json_encode($payload, JSON_UNESCAPED_UNICODE);
    @file_put_contents(AUDIT_LOG_PATH, $line . "\n", FILE_APPEND);
}

function check_admin_token() {
    $token = $_SERVER['HTTP_X_ADMIN_TOKEN']
          ?? ($_SERVER['HTTP_AUTHORIZATION']
                ? trim(str_replace('Bearer', '', $_SERVER['HTTP_AUTHORIZATION']))
                : '');
    if (!hash_equals(ADMIN_TOKEN, (string)$token)) {
        json_response(['error' => 'unauthorized'], 401);
    }
}

function rate_limit_check() {
    $key = 'rl_' . md5(($_SERVER['REMOTE_ADDR'] ?? 'unknown') . ':' . date('YmdHi'));
    $dir = sys_get_temp_dir();
    $file = "$dir/$key";
    $count = is_file($file) ? (int)file_get_contents($file) : 0;
    if ($count >= RATE_LIMIT_PER_MIN) {
        json_response(['error' => 'rate_limit_exceeded'], 429);
    }
    @file_put_contents($file, $count + 1);
}

function normalize_hwid($raw) {
    return strtoupper(preg_replace('/[^a-zA-Z0-9\-]/', '', (string)$raw));
}
