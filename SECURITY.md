# A4ther FFScanner — Security Hardening (v4.4.94 EXTREME)

## 🔐 Multi-Layer Protection Strategy

This build includes **4 independent security layers**, each designed to defeat different attack vectors:

### Layer 1: Script Encryption (AES-256-CBC)
- **Files:** `a4ther.sh.enc`, `a4ther-adb.sh.enc`
- **Method:** AES-256-CBC with PBKDF2 (100,000 iterations) + salt
- **Decryption:** `FF_PASSPHRASE=... sh decrypt.sh a4ther.sh.enc | sh`
- **Protection:** Prevents static analysis, code theft, reverse engineering

### Layer 2: WebAssembly Compilation (WASM)
- **File:** `a4ther-ios.wasm` (758 bytes)
- **Loader:** `a4ther-wasm-loader.js` (28 KB minified)
- **Method:** Performance-critical anti-cheat logic compiled to WebAssembly bytecode
- **Protection:** Bytecode is machine-generated, impossible to decompile to source

### Layer 3: JavaScript Obfuscation + HTML Minification
- **Control-flow flattening:** Makes code control flow unreadable
- **Dead-code injection:** Adds decoy logic to confuse static analysis
- **String array encoding:** All string literals hidden in encoded arrays
- **Identifier mangling:** Variable/function names reduced to `_0x...`
- **HTML minification:** CSS compressed, HTML optimized
- **Protection:** Decompilation extremely difficult; reverse engineering time → ∞

### Layer 4: Anti-Tampering Guards
- **Runtime integrity checks:** SHA256 signatures of critical functions verified at load time
- **Anti-debugging:** Detects Chrome DevTools, debugger attachments, Proxy hooks
- **Memory sealing:** Sensitive data overwritten after use; objects frozen
- **Obfuscated checks:** The checks themselves are control-flow flattened
- **Protection:** Execution aborts if tamper/hook/debugger detected

## 📊 Security Manifest

See `BUILD_MANIFEST.json` and `security-manifest.json` for:
- SHA256 checksums of all artifacts (verify integrity)
- Guard function signatures (runtime verification)
- Layer composition and version info

## 🚀 Deployment

### For Termux / SSH
```bash
export FF_PASSPHRASE="[stored in .env.local]"
sh decrypt.sh a4ther.sh.enc | sh
```

### For iOS / Scriptable
Raw GitHub URL will serve obfuscated `a4ther-ios.js` + WASM loader automatically.

### For Web PWA
`index.html` loads with all 4 layers active:
- CSS minified, JS obfuscated
- Service worker handles offline caching (also obfuscated)
- WASM module loaded on first anticheat call

## ⚠️ Security Notices

### Passphrase Storage
- **NEVER commit `.env.local`** to version control (already in `.gitignore`)
- Store passphrase in CI/CD secrets, `.bash_profile`, or password manager
- Rotate passphrase if compromised

### Old Passphrase Compromise
- Previous passphrase (`A4ther-FFScanner-2026-...`) was exposed in git history
- **DO NOT USE** — all `.enc` files re-encrypted with new passphrase
- Git history has been sanitized; old `.enc` files are unusable

### Threat Model
This build protects against:
- ✅ Source code theft / corporate espionage
- ✅ Reverse engineering via static analysis
- ✅ Runtime code injection / monkey-patching
- ✅ Debugger-based inspection
- ✅ Automated decompilation tools

Does NOT protect against:
- ❌ Extremely determined adversaries with weeks/months (all obfuscation can be broken given time)
- ❌ Compromised host OS / rooted device
- ❌ Man-in-the-middle (use HTTPS + SRI for CDN resources)

## 🔧 Rebuild Process

To rebuild after code changes:
```bash
source .env.local  # Load FF_PASSPHRASE
sh build.sh        # Triggers full obfuscation + encryption pipeline
```

The `build.sh` script orchestrates all 4 protection layers automatically.

## 📝 Version History

- **v4.4.93 EXTREME** — Multi-layer protection (AES-256 + WASM + JS obfuscation + anti-tampering)
- **v4.4.92** — Initial obfuscation + encrypted script alternatives
- **v4.4.91** — Last public pre-hardening release

---

For support or to report security issues: [contact]

**Last Updated:** 2026-06-17
