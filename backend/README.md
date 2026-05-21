# A4ther Backend · LS Aluguel

Backend PHP + MySQL pra rodar dentro do **lspainel.com.br** servindo:
- ✅ Blacklist lookup (`GET /api/a4ther/blacklist/check?hwid=X`)
- ✅ Blacklist submit (`POST /api/a4ther/blacklist/submit`) — admin-only
- ✅ Threat intel feed (`GET /api/a4ther/intel/feed.json`)
- ✅ Scan log telemetria (`POST /api/a4ther/scan/log`)

---

## 🚀 Deploy em 5 minutos

### 1. Subir arquivos pro servidor

Estrutura final no servidor:
```
lspainel.com.br/
├── _config.php           ← ajustar credenciais
├── _schema.sql           ← rodar 1x no MySQL
├── _logs/                ← criar (chmod 750, dono www-data)
├── .htaccess             ← URLs limpas + bloqueio de config
└── api/
    └── a4ther/
        ├── blacklist/
        │   ├── check.php
        │   └── submit.php
        ├── intel/
        │   └── feed.php
        └── scan/
            └── log.php
```

Upload via SFTP/SSH ou Git pull:
```bash
# Na pasta do panel (ex: /var/www/lspainel.com.br/)
rsync -avz backend/ user@lspainel.com.br:/var/www/lspainel.com.br/
```

### 2. Configurar `_config.php`

Edite no servidor:
```php
const DB_HOST    = 'localhost';
const DB_NAME    = 'lspainel_a4ther';
const DB_USER    = 'lspainel_user';
const DB_PASS    = 'SENHA_FORTE_AQUI';

const ADMIN_TOKEN = 'gere_um_token_aleatorio_32_chars';  // openssl rand -hex 32
```

**Gere um token admin forte:**
```bash
openssl rand -hex 32
# cola no ADMIN_TOKEN
```

### 3. Criar database + schema

```bash
mysql -u root -p < _schema.sql
```

Cria:
- Database `lspainel_a4ther`
- Tabela `blacklist` (HWIDs banidos)
- Tabela `scan_log` (telemetria)
- Tabela `threat_intel` (IOCs dinâmicos)
- Seeds com IOCs do dump real (purplevioleto, 154.223.134.x, LiveContainer, etc.)

### 4. Criar usuário MySQL com privilégios

```sql
CREATE USER 'lspainel_user'@'localhost' IDENTIFIED BY 'SENHA_FORTE_AQUI';
GRANT SELECT, INSERT, UPDATE, DELETE ON lspainel_a4ther.* TO 'lspainel_user'@'localhost';
FLUSH PRIVILEGES;
```

### 5. Testar endpoints

```bash
# Health check — deve retornar JSON
curl -s 'https://lspainel.com.br/api/a4ther/intel/feed.json' | jq .

# Blacklist check
curl -s 'https://lspainel.com.br/api/a4ther/blacklist/check?hwid=TESTE123' | jq .

# Submit (precisa de admin token)
curl -X POST 'https://lspainel.com.br/api/a4ther/blacklist/submit' \
     -H 'X-Admin-Token: SEU_TOKEN' \
     -H 'Content-Type: application/json' \
     -d '{"hwid":"TESTE123","reason":"cheats","motivos":["LiveContainer","Profile opaco"]}'
```

### 6. Configurar CORS (.htaccess já cuida)

O scanner em `https://lovelyoyk.github.io/a4ther/` precisa origin permitido. Lista já tá em `_config.php` `ALLOWED_ORIGINS`.

---

## 📊 Como integrar com o dashboard atual

Sua página atual `lspainel.com.br/dashboard/blacklist` é HTML — ela pode ler/escrever na MESMA tabela `blacklist` deste backend.

Exemplo PHP no dashboard pra listar HWIDs banidos:
```php
require __DIR__ . '/_config.php';
$stmt = db()->query('SELECT * FROM blacklist WHERE active = 1 ORDER BY banned_at DESC LIMIT 100');
while ($row = $stmt->fetch()) {
    echo "<tr><td>{$row['hwid']}</td><td>{$row['reason']}</td><td>{$row['banned_at']}</td></tr>";
}
```

Pra remover do banlist:
```php
db()->prepare('UPDATE blacklist SET active=0 WHERE hwid=?')->execute([$hwid]);
```

Pra adicionar IOC novo no threat intel:
```php
db()->prepare('INSERT IGNORE INTO threat_intel (kind,value,name,category,severity,description) VALUES (?,?,?,?,?,?)')
   ->execute(['domain', 'cheatnovo.com', 'Cheat XYZ', 'CHEAT', 'CRITICAL', 'Descrição']);
```

Os scanners (web + iOS Scriptable + Android sh) puxam esse intel automaticamente a cada 6h.

---

## 🔒 Segurança

- ✅ CORS allowlist (não é `*`)
- ✅ Rate limit 60 req/min/IP
- ✅ Admin token pra submit/admin
- ✅ Audit log em `_logs/audit.log`
- ✅ `.htaccess` bloqueia acesso a `_config.php` / `_schema.sql` / `_logs/`
- ✅ Prepared statements (SQL injection-proof)
- ✅ HWID normalizado (regex `[a-zA-Z0-9\-]`)

---

## 🧪 Testando localmente

```bash
cd backend
php -S 0.0.0.0:8080
# Endpoints em http://localhost:8080/api/a4ther/...
```

Use SQLite em vez de MySQL pra dev (ajuste `db()` em `_config.php`).
