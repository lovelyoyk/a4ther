-- ============================================================
-- A4ther Backend Schema · LS Aluguel · lspainel.com.br
-- Rodar 1x no MySQL/MariaDB do servidor antes de subir os endpoints.
--
--   mysql -u root -p < _schema.sql
--
-- ============================================================

CREATE DATABASE IF NOT EXISTS `lspainel_a4ther`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `lspainel_a4ther`;

-- ────────────────────────────────────────────────────────────
-- TABELA: blacklist
-- HWIDs banidos. Lookup primário do scanner via /blacklist/check
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `blacklist` (
    `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `hwid`      VARCHAR(128) NOT NULL,
    `reason`    VARCHAR(64)  NOT NULL DEFAULT 'unknown',  -- cheats|proxy|sideload|reinstall|profile
    `motivos`   TEXT NULL,                                -- lista detalhada (JSON ou texto)
    `evidence`  JSON NULL,                                -- evidência completa (alerts/warnings dump)
    `source`    VARCHAR(32)  NOT NULL DEFAULT 'manual',   -- manual|a4ther-web|a4ther-sh|admin
    `banned_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `banned_by` VARCHAR(64)  NULL,                        -- admin username
    `notes`     TEXT NULL,
    `active`    TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_hwid` (`hwid`),
    KEY `idx_active` (`active`),
    KEY `idx_banned_at` (`banned_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
-- TABELA: scan_log
-- Histórico de todos os scans rodados (telemetria opcional)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `scan_log` (
    `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `verdict`        ENUM('W.O', 'REVISAR', 'LIMPO') NOT NULL,
    `alerts_count`   INT UNSIGNED NOT NULL DEFAULT 0,
    `warnings_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `mode`           VARCHAR(32) NULL,    -- targz|sysdiag|ndjson|profile|android
    `hwid`           VARCHAR(128) NULL,
    `ip`             VARCHAR(45)  NULL,
    `ua`             VARCHAR(255) NULL,
    `ts`             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ts` (`ts`),
    KEY `idx_verdict` (`verdict`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
-- TABELA: threat_intel
-- IOCs (cheat bundles/domains/ips/patterns) servidos via /intel/feed
-- Permite atualizar threat intel sem deploy do frontend
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `threat_intel` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `kind`         ENUM('bundle','domain','ip','pattern','tld') NOT NULL,
    `value`        VARCHAR(255) NOT NULL,
    `name`         VARCHAR(128) NULL,
    `category`     VARCHAR(32)  NULL,      -- CHEAT|SIDELOAD|CLEANER|PROXY|VPN|DNS|...
    `severity`     ENUM('CRITICAL','HIGH','MEDIUM','LOW') NOT NULL DEFAULT 'HIGH',
    `description`  TEXT NULL,
    `source`       VARCHAR(64)  NULL,      -- onde foi descoberto
    `added_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `added_by`     VARCHAR(64)  NULL,
    `active`       TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_kind_value` (`kind`, `value`),
    KEY `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
-- Seeds iniciais — IOCs confirmados via dump real
-- ────────────────────────────────────────────────────────────
INSERT IGNORE INTO `threat_intel` (`kind`, `value`, `name`, `category`, `severity`, `description`, `source`) VALUES
('domain', 'purplevioleto.com',               'Proxy MITM FF Max',  'PROXY',    'CRITICAL', 'version.ffmax.purplevioleto.com substitui CDN Garena',      'dump-2026-05-20'),
('domain', 'version.ffmax.purplevioleto.com', 'Proxy MITM endpoint','PROXY',    'CRITICAL', 'Endpoint version-check FALSO',                                'dump-2026-05-20'),
('domain', 'easebot.app',                     'EaseBot',            'CHEAT',    'HIGH',     'Botware suspeito (api2/ecloud subdomains)',                   'dump-2026-05-20'),
('domain', 'linkcdn.cc',                      'linkcdn.cc',         'CHEAT',    'MEDIUM',   'TLD .cc + name CDN suspeito',                                 'dump-2026-05-20'),
('ip',     '154.223.134.14',                  'CDS Cloud BR cheat', 'PROXY',    'HIGH',     'IP hardcoded em IPA FF modded',                               'dump-2026-05-20'),
('ip',     '154.223.134.24',                  'CDS Cloud BR cheat', 'PROXY',    'HIGH',     'IP hardcoded em IPA FF modded',                               'dump-2026-05-20'),
('ip',     '154.223.134.20',                  'CDS Cloud BR cheat', 'PROXY',    'HIGH',     'IP hardcoded em IPA FF modded',                               'dump-2026-05-20'),
('ip',     '154.223.134.23',                  'CDS Cloud BR cheat', 'PROXY',    'HIGH',     'IP hardcoded em IPA FF modded',                               'dump-2026-05-20'),
('bundle', 'com.kdt.livecontainer',           'LiveContainer',      'SIDELOAD', 'CRITICAL', 'Vetor stealth 2026 — IPAs ilimitados num app slot',           'threat-intel-2026'),
('bundle', 'com.fluorite.app',                'Fluorite Cheat',     'CHEAT',    'CRITICAL', 'Cheat pago Fluorite (fluorite.store)',                        'threat-intel-2026'),
('bundle', 'com.cheto.freefire',              'Cheto Cheat',        'CHEAT',    'CRITICAL', 'Cheat pago Cheto (chetoshop.com)',                            'threat-intel-2026');

-- ────────────────────────────────────────────────────────────
-- Index check
-- ────────────────────────────────────────────────────────────
SHOW TABLES;
SELECT COUNT(*) AS intel_seeded FROM threat_intel;
