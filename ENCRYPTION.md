# FFScanner — Encrypted Alternatives

## Encrypted Bash Scripts

Para proteger contra roubo de código, versões criptografadas dos scripts estão disponíveis:

- `a4ther.sh.enc` — Versão criptografada do scanner principal
- `a4ther-adb.sh.enc` — Versão criptografada do módulo ADB
- `decrypt.sh` — Helper para descriptografar em tempo de execução

### Como usar

```bash
# Defina a passphrase antes de executar
export FF_PASSPHRASE="A4ther-FFScanner-2026-vRz7Qk9mZ2pLxN8wTbY6"

# Descriptografe e execute
sh decrypt.sh a4ther.sh.enc | sh

# Ou salve em arquivo temporário
sh decrypt.sh a4ther.sh.enc > /tmp/a4ther.sh
sh /tmp/a4ther.sh
```

### Segurança

- **Criptografia:** AES-256-CBC com PBKDF2 (100.000 iterações)
- **Passphrase:** Guarde com segurança em variáveis de ambiente
- **Originais:** Os arquivos `a4ther.sh` e `a4ther-adb.sh` permanecem para compatibilidade com scripts/integrações existentes

### Ofuscação Web

- `index.html` — Minificado com JavaScript ofuscado (control-flow flattening, dead-code injection)
- `a4ther-ios.js` — Obfuscado para máxima proteção de código
- `service-worker.js` — Ofuscado (PWA cache strategy)

---

**Build Infrastructure:**
- `obfuscate.js` — Script de ofuscação JavaScript
- `build.sh` — Pipeline de build POSIX-portable
- `package.json` — Dependências (javascript-obfuscator, html-minifier-terser)
