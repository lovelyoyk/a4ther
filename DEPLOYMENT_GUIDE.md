# A4ther FFScanner — Deployment Guide (v4.4.95)

## 🎯 Dois Fluxos Disponíveis

### Fluxo 1: COMPATÍVEL (Padrão — Recomendado para Usuários Atuais)

**Status:** ✅ Em Produção  
**Segurança:** Código aberto (legível) — use para compatibilidade com workflows existentes

```bash
# Termux / SSH
curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh | sh
```

**Arquivos:**
- `a4ther.sh` — Scanner principal (limpo, legível)
- `a4ther-adb.sh` — Coletor ADB (limpo, legível)
- `a4ther-ios.js` — iOS Scriptable (raw URL)
- `index.html` — PWA Web (raw URL)

---

### Fluxo 2: PROTEGIDO (Segurança Máxima — Apenas para Usuários Avançados)

**Status:** 🔒 Disponível  
**Segurança:** Criptografado AES-256-CBC + Ofuscado

**Requer:** Passphrase (fornecida via `.env` / CI/CD secrets)

```bash
# Termux / SSH (com criptografia)
export FF_PASSPHRASE="[chave-segura-fornecida-separadamente]"
curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/decrypt.sh | sh decrypt.sh a4ther.sh.enc | sh
```

**Arquivos:**
- `a4ther.sh.enc` — Script criptografado (AES-256-CBC)
- `a4ther-adb.sh.enc` — Script criptografado
- `decrypt.sh` — Helper de descriptografia
- `a4ther-ios.js` — Obfuscado + WASM loader
- `index.html` — Minificado + ofuscado + anti-tampering
- `service-worker.js` — Obfuscado
- `BUILD_MANIFEST.json` — Checksums e versão
- `security-manifest.json` — Guard signatures

---

## 🔐 Distribuição da Passphrase (Fluxo Protegido)

A passphrase **NUNCA** é commitada no GitHub (`.env.local` é gitignored).

### Para Usuários Finais:
```bash
# Solicite via canal seguro (Signal, WhatsApp, etc)
# Ou armazene em:
# - GitHub Secrets (CI/CD)
# - Environment variable local (.bashrc, .zshrc)
# - Password manager (1Password, Bitwarden, etc)
```

### Para CI/CD (GitHub Actions):
```yaml
- name: Decrypt Scanner
  env:
    FF_PASSPHRASE: ${{ secrets.FF_PASSPHRASE }}
  run: |
    curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/decrypt.sh | sh decrypt.sh a4ther.sh.enc | sh
```

---

## 📊 Comparação

| Aspecto | Fluxo 1 (Compatível) | Fluxo 2 (Protegido) |
|--------|-------------------|-------------------|
| **Tamanho** | 274 KB | 105 KB enc (.enc) |
| **Segurança** | Código aberto | AES-256-CBC + Ofuscação |
| **Compatibilidade** | Máxima | Requer passphrase |
| **Performance** | Imediato | +2-4ms decrypt |
| **Resistência Reversa** | Fraca | Forte |

---

## 🚀 Recomendação por Caso de Uso

| Caso | Fluxo |
|------|-------|
| **Integração com ferramentas** | Fluxo 1 (compatível) |
| **Produção / CI-CD privado** | Fluxo 2 (protegido) |
| **Distribuição pública** | Fluxo 1 (compatível) |
| **Proteção contra reverse eng** | Fluxo 2 (protegido) |
| **Usuários finais** | Fluxo 1 (compatível) |

---

## 🔧 Restauração de Compatibilidade

Se o Fluxo 2 quebrar / passphrase comprometida:

```bash
# Reverta para Fluxo 1 (compatível)
curl -s https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh | sh
```

---

## 📝 Versão

- **v4.4.95-HYBRID**
- Última atualização: 2026-06-20
- Ambos fluxos garantidos em `main`
