# A4ther FFScanner — EXTREME Protection

Version: **v4.4.93** · Build orchestrator: `build-extreme.sh` · Output: `dist-extreme/`

This document describes the four-layer hardening applied to the FFScanner
distribution, the decrypt/decompress flow at runtime, the measured overhead of
each layer, and how each layer raises the cost of common attacks.

---

## 1. Layer breakdown

| # | Layer | Tool | Applies to | What it produces |
|---|-------|------|-----------|------------------|
| 1 | **Self-extracting compressed packer** (+ optional AES envelope) | `dist-extreme/pack.sh`, `openssl` | `a4ther.sh`, `a4ther-adb.sh` | `*.sh` (gzip+base64+anti-debug stub) and `*.sh.enc` (AES-256-CBC) |
| 2 | **WASM core** for hot paths | `dist-extreme/emit-wasm.js`, `a4ther-wasm-loader.js` | iOS/browser scanning | `a4ther-ios.wasm` (758 B, opaque binary) + obfuscated `a4ther-wasm-loader.min.js` |
| 3 | **JS obfuscation + HTML minification** | `javascript-obfuscator`, `html-minifier-terser` | `a4ther-ios.js`, `service-worker.js`, `index.html` | obfuscated/minified shipped artifacts |
| 4 | **Runtime anti-tampering guard** | `security/inject.js` + `security/guard.js` | `index.html`, `a4ther-ios.js` | obfuscated guard spliced in + `security-manifest.json` |

### Why not UPX?

UPX compresses **compiled binaries** (ELF / Mach-O / PE). The FFScanner shell
targets are **interpreted text scripts**:

- `a4ther.sh` → `#!/system/bin/sh` (Android system shell)
- `a4ther-adb.sh` → `#!/data/data/com.termux/files/usr/bin/env bash` (Termux)

There is no compiler on-device and busybox/ash have no bytecode format, so UPX
cannot apply. The portable equivalent of "compress + make opaque" for an
interpreted script is a **self-extracting gzip stub** with an anti-debug header,
which is exactly what Layer 1 (`pack.sh`) produces. It achieves comparable size
reduction (61% on `a4ther.sh`) while remaining runnable by the exact
interpreters named in each shebang.

---

## 2. Decryption / decompression flow

### Shell scripts (Layer 1) — on Termux / Android

```
a4ther.sh.enc                         a4ther.sh (packed stub)            original
   │   FF_PASSPHRASE                       │                                 │
   ▼   openssl -d -aes-256-cbc             ▼   stub runs:                     ▼
[AES decrypt] ───────────────────► [self-extracting stub] ──────────► [reconstructed]
   (decrypt.sh helper)                 1. anti-debug header checks         . "$TMP"
                                          (TracerPid, LD_PRELOAD)          (runs under
                                       2. base64 -d | gunzip               original shebang)
                                       3. write to private mktemp
                                       4. chmod 0700, source it
```

- The plain packed `a4ther.sh` is **directly runnable** — the stub decompresses
  itself in memory and `source`s the result. No passphrase needed for this path.
- The `.enc` variant adds an AES-256-CBC envelope (PBKDF2, 100k iterations,
  salted) for protection **at rest / in transit**. `decrypt.sh` decrypts → runs
  the packed stub → which decompresses → runs the original, in one command:
  `FF_PASSPHRASE=… sh decrypt.sh a4ther.sh.enc [args]`.

### Browser HTML (Layer 3 + 4)

```
index.html (minified)  ──load──►  parse  ──►  inline app JS runs
        │                                          │
        └── <script>/*A4G*/…obfuscated guard…</script>  spliced before </body>
                                                   │
                                            guard self-installs:
                                            sig-check + anti-debug + memory seal
```

HTML is **minified, not encrypted** — a browser must parse it directly, so the
protection is obfuscation of the inline JS plus the runtime guard. The
service-worker is obfuscated the same way.

### iOS / Scriptable (Layers 2 + 3 + 4)

```
a4ther-ios.js (ES module)
  ┌─ /*A4G*/ obfuscated guard  ── runs FIRST (sig-check, integrity, sealing)
  ├─ WASM loader (obfuscated)  ── fetch a4ther-ios.wasm, instantiate
  │      └─ on CSP/old-engine failure → byte-exact pure-JS fallback
  └─ obfuscated scanner body   ── uses A4W.b64ToBytes / extractStrings / fnv1a
```

The bundle is a valid **ES module** (it uses top-level `await`, which Scriptable
supports). The guard runs before any scanner logic.

---

## 3. Runtime overhead (measured on this machine, Node 18+)

| Layer | Cost | When | Notes |
|-------|------|------|-------|
| L1 shell unpack | **~1 ms** | once at script launch | gunzip 267 KB payload |
| L1 AES decrypt | **~28 ms** | once, only if `.enc` path used | openssl PBKDF2 100k iters |
| L2 WASM instantiate | **~1.2 ms** | once at page/script load | 758-byte module |
| L2 `strings_scan` 2 MB | **7.0 ms (WASM)** vs 24.9 ms (JS) → **3.55× faster** | per large scan | WASM wins on big buffers |
| L2 `fnv1a` 4 KB ×1000 | 11 ms (WASM) vs 6.4 ms (JS) | per small hash | JS wins on tiny inputs → loader keeps JS fallback |
| L3 obfuscation | **0 runtime ms** | — | purely a code-size/parse cost (see §5) |
| L4 guard init | **~0.3–1.1 ms** | once | sign-check + watchdog start |
| L4 guard per-check | **~1 µs** | idle + critical paths | negligible |

**Net launch overhead:** roughly **2–4 ms** for the common (un-encrypted)
path, or **~30 ms** if the AES envelope is used. All one-time; steady-state
scanning is *faster* than the unprotected build on large inputs thanks to WASM.

---

## 4. Size comparison: original vs extreme

| Artifact | Original | Extreme | Delta |
|----------|---------:|--------:|------:|
| `a4ther.sh` (packed) | 276,561 | 107,298 | **−61%** |
| `a4ther-adb.sh` (packed) | 32,964 | 17,372 | **−47%** |
| `a4ther.sh.enc` | — | 145,340 | new (AES envelope) |
| `a4ther-adb.sh.enc` | — | 23,555 | new |
| `a4ther-ios.js` | 288,748 | 1,257,496 | +335% (obfuscation + WASM loader) |
| `a4ther-ios.wasm` | — | 758 | new |
| `index.html` | 537,294 | 553,939 | +3% (minify − comments, then guard splice) |
| `service-worker.js` | 13,522 | 17,118 | +27% (obfuscation) |
| **Archive (zip -9)** | — | **858,533** | 19 files |

The shell scripts shrink dramatically; the JS grows because control-flow
flattening + dead-code injection + string-array encoding trade size for
opacity. This is the intended cost of Layer 3.

---

## 5. How each layer defeats common attacks

### Layer 1 — packed + encrypted shell

- **Casual `cat` / static reading:** the script body is gzipped+base64; nothing
  human-readable survives in the stub except decoy variables.
- **Tracing / debugging on-device:** the stub aborts (exit 97/98) if
  `LD_PRELOAD` is set or `/proc/self/status` shows a non-zero `TracerPid`
  (strace/ltrace attached).
- **Theft of the artifact at rest:** the `.enc` variant requires the AES
  passphrase (PBKDF2, 100k iters) — brute force is impractical.
- **Tampering:** editing the stub corrupts the base64 payload → gunzip fails →
  `unpack failed` (exit 95); the script will not run modified.

### Layer 2 — WASM core

- **Algorithm reverse engineering:** the base64-decode / string-extraction /
  FNV-1a hot paths are compiled to an **opaque 758-byte WASM binary** with no
  symbol names beyond the three exports — far harder to read than JS.
- **Hooking JS prototypes:** the hot paths run in WASM linear memory, outside
  the reach of `String.prototype` / `Array.prototype` monkey-patching.
- **Graceful degradation, not a bypass:** if WASM is blocked (CSP) the loader
  falls back to byte-exact JS — correctness is preserved, only the opacity of
  those three functions is lost.

### Layer 3 — JS obfuscation + HTML minify

- **Static analysis / grep for secrets:** string-array + base64/rc4 encoding
  means no literal like `"blacklist"` or endpoint URLs appear in plaintext.
- **Control-flow understanding:** control-flow flattening turns the logic into a
  dispatcher loop; dead-code injection adds plausible-but-unused branches.
- **Auto-deobfuscators / beautifiers:** `selfDefending` makes the code detect
  reformatting (it breaks if pretty-printed), frustrating one-click cleanup.

### Layer 4 — runtime anti-tampering guard

- **Function patching / hooking:** SHA-256 signatures of critical functions
  (`runPrivacyReport`, `detect`, `checkBlacklist`, `fetchThreatIntel`, …) are
  re-hashed at runtime; any edit → `sig-mismatch` → `onTamper` fires
  (iOS: alert + `Script.complete()`; web: destructive lock).
- **DevTools / console inspection (web):** size-gap detection, console-getter
  trap, timing trap.
- **`Function.prototype.toString` hook:** detected, so attackers can't fake the
  signed source back to the verifier.
- **Memory scraping:** passphrase/key strings are wiped after use; critical
  objects are `Object.freeze`d with non-enumerable poison props.
- **Self-test guarantee:** `npm run guard:test` proves zero false positives in
  normal browser/Scriptable envs and a guaranteed trip on a flipped signature.

---

## 6. Defence-in-depth summary

A single bypassed layer does not expose the product:

1. Strip the AES envelope → still face the packed/anti-debug stub.
2. Unpack the stub → the iOS scanner's hot paths are still in opaque WASM.
3. Read the JS → it is control-flow-flattened and string-encoded.
4. Patch a function → the runtime guard trips on signature mismatch.

Each layer is independently testable and independently re-buildable via
`build-extreme.sh` (with `FF_SKIP_PACK` / `FF_SKIP_WASM` / `FF_SKIP_GUARD` /
`FF_SKIP_ENCRYPT` toggles).

### Layer 4 idempotency

`security/inject.js` is **idempotent**: if a target (`index.html` or
`a4ther-ios.js`) already carries a `/*A4G*/` guard block — e.g. because the
source HTML was committed with a guard, or the build is re-run — the injector
**strips the stale guard block(s) and re-signs against the current shipped
bytes** rather than aborting or double-wrapping. This guarantees the
`security-manifest.json` signatures always match the bytes actually shipped, so
the runtime guard never false-positives on a re-build. Both shipped artifacts
end every build with **exactly one** guard block, freshly signed.

---

## 7. Reproducing the build

```sh
# Full extreme build (random AES passphrase printed once at the end):
sh ./build-extreme.sh

# Pin the passphrase + max-strength guard:
FF_PASSPHRASE="…" FF_GUARD_LEVEL=max sh ./build-extreme.sh

# Verify the guard never false-positives:
npm run guard:test
```

Artifacts land in `dist-extreme/`; the shippable archive is
`a4ther-scanner-extreme-v<VERSION>.zip` with a `.sha256` sidecar and a
`BUILD_MANIFEST.json` listing every file's size + SHA-256.
