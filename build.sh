#!/bin/sh
# build.sh — A4ther FFScanner secure build pipeline.
#
# Pipeline:
#   1. Obfuscate all .js files          -> node obfuscate.js (dist/)
#   2. Encrypt bash/sh scripts          -> AES-256 via openssl (dist/*.sh.enc)
#   3. Minify HTML                       -> html-minifier-terser (dist/*.html)
#   4. Copy remaining static assets      -> dist/
#   5. Inject anti-tampering guard       -> node security/inject.js (dist/)
#   6. Package final archive             -> a4ther-scanner-v<VERSION>.(zip|tar.gz)
#
# Guard env overrides:
#   FF_SKIP_GUARD   set to 1 to skip anti-tampering injection
#   FF_GUARD_LEVEL  high | max         obfuscation strength for the guard
#   FF_GUARD_SIGN   "fnA,fnB,..."      top-level functions to code-sign
#
# POSIX-portable: pure /bin/sh, no bashisms, no arrays, no `case` inside $(),
# no process substitution. Tested under dash/ash/bash --posix.
#
# Usage:
#   sh ./build.sh
#
# Env overrides:
#   FF_PASSPHRASE   passphrase used to AES-encrypt shell scripts
#                   (default: read from FF_PASSPHRASE_FILE, else prompt-free
#                    random — printed once at end of run)
#   FF_LEVEL        obfuscation level passed through to obfuscate.js
#   FF_SKIP_ENCRYPT set to 1 to skip script encryption

set -eu

# ---------------------------------------------------------------------------
# Resolve script directory (POSIX-safe, no readlink -f dependency).
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

DIST="$SCRIPT_DIR/dist"

log() { printf '[build] %s\n' "$*"; }
die() { printf '[build] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Tool checks.
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

have node    || die "node not found in PATH"
have openssl || die "openssl not found in PATH"

# ---------------------------------------------------------------------------
# Read VERSION from index.html (const VERSION = "x.y.z").
# Avoid `case` inside $(); use sed only.
# ---------------------------------------------------------------------------
VERSION=$(sed -n 's/.*const VERSION = "\([^"]*\)".*/\1/p' index.html | head -n 1)
if [ -z "$VERSION" ]; then
  VERSION="unknown"
fi
log "version v$VERSION"

# ---------------------------------------------------------------------------
# Ensure dependencies are installed.
# ---------------------------------------------------------------------------
if [ ! -d "$SCRIPT_DIR/node_modules/javascript-obfuscator" ]; then
  log "installing npm dependencies..."
  npm install --no-audit --no-fund
fi

# ===========================================================================
# Step 0 — lint anti-regressão (P0): detecção shell NUNCA pode usar a forma
# `emit "[ALERTA]"` (colchete) — ela NÃO conta no veredito (ALERTS/WARNINGS),
# virando falso negativo. Toda detecção vai por alert()/warn(). Falha o build
# se a forma com colchete reaparecer.
# ===========================================================================
log "step 0/6  lint anti-regressao (sem [ALERTA]/[AVISO]/[CRITICAL] crus)"
for _sh in a4ther.sh a4ther-adb.sh; do
  [ -f "$_sh" ] || continue
  if grep -nE 'emit .*\[(ALERTA|AVISO|CRITICAL)\]' "$_sh" >/dev/null 2>&1; then
    grep -nE 'emit .*\[(ALERTA|AVISO|CRITICAL)\]' "$_sh" >&2
    die "$_sh: deteccao com colchete [ALERTA]/[AVISO]/[CRITICAL] — use alert()/warn() (colchete nao conta no veredito)"
  fi
done

# ===========================================================================
# Step 1 — obfuscate JS into dist/
# ===========================================================================
log "step 1/6  obfuscating JavaScript"
node obfuscate.js

# ===========================================================================
# Step 2 — encrypt shell scripts (AES-256-CBC, salted, base64).
# ===========================================================================
if [ "${FF_SKIP_ENCRYPT:-0}" = "1" ]; then
  log "step 2/6  encryption skipped (FF_SKIP_ENCRYPT=1)"
else
  log "step 2/6  encrypting shell scripts"

  # Resolve passphrase. Priority: env > file > generated.
  PASS=""
  if [ -n "${FF_PASSPHRASE:-}" ]; then
    PASS="$FF_PASSPHRASE"
  elif [ -n "${FF_PASSPHRASE_FILE:-}" ] && [ -f "${FF_PASSPHRASE_FILE:-}" ]; then
    PASS=$(cat "$FF_PASSPHRASE_FILE")
  else
    PASS=$(openssl rand -hex 24)
    GENERATED_PASS="$PASS"
  fi

  # Encrypt each top-level .sh script. find + while-read is POSIX-safe.
  find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' | while IFS= read -r sh_file; do
    base=$(basename "$sh_file")
    # Skip this build script itself.
    if [ "$base" = "build.sh" ]; then
      continue
    fi
    out="$DIST/$base.enc"
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
      -in "$sh_file" -out "$out" -pass pass:"$PASS"
    log "  encrypted -> dist/$base.enc"
  done

  # Emit a POSIX decrypt helper so the client can recover scripts at runtime.
  cat > "$DIST/decrypt.sh" <<'DECRYPT_EOF'
#!/bin/sh
# decrypt.sh — recover an encrypted A4ther script.
# Usage: FF_PASSPHRASE=... sh decrypt.sh a4ther.sh.enc > a4ther.sh
set -eu
[ $# -ge 1 ] || { echo "usage: FF_PASSPHRASE=... sh decrypt.sh <file.enc>" >&2; exit 1; }
[ -n "${FF_PASSPHRASE:-}" ] || { echo "FF_PASSPHRASE not set" >&2; exit 1; }
openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
  -in "$1" -pass pass:"$FF_PASSPHRASE"
DECRYPT_EOF
  log "  wrote dist/decrypt.sh helper"
fi

# ===========================================================================
# Step 3 — minify HTML into dist/
# ===========================================================================
log "step 3/6  minifying HTML"

MINIFIER="$SCRIPT_DIR/node_modules/.bin/html-minifier-terser"
find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.html' | while IFS= read -r html_file; do
  base=$(basename "$html_file")
  out="$DIST/$base"
  if [ -x "$MINIFIER" ]; then
    "$MINIFIER" \
      --collapse-whitespace \
      --remove-comments \
      --minify-css true \
      --minify-js false \
      --remove-redundant-attributes \
      --remove-script-type-attributes \
      -o "$out" "$html_file"
    log "  minified -> dist/$base"
  else
    cp "$html_file" "$out"
    log "  (minifier missing) copied -> dist/$base"
  fi
done

# ===========================================================================
# Step 4 — copy remaining static deploy assets.
# ===========================================================================
log "step 4/6  copying static assets"

# Web deploy assets that are not JS/SH/HTML.
for asset in manifest.webmanifest icon.svg apple-touch-icon.png \
             icon-192.png icon-512.png; do
  if [ -f "$SCRIPT_DIR/$asset" ]; then
    cp "$SCRIPT_DIR/$asset" "$DIST/$asset"
    log "  asset -> dist/$asset"
  fi
done

# ===========================================================================
# Step 5 — inject runtime anti-tampering guard into shipped artifacts.
#          Runs AFTER obfuscation + minify so it signs the final bytes.
# ===========================================================================
if [ "${FF_SKIP_GUARD:-0}" = "1" ]; then
  log "step 5/6  guard injection skipped (FF_SKIP_GUARD=1)"
else
  log "step 5/6  injecting anti-tampering guard"
  # Default set of critical functions to code-sign. Web vs iOS names differ;
  # the injector signs whichever exist in each target and skips the rest.
  : "${FF_GUARD_SIGN:=runPrivacyReport,runSysdiagnoseAnalyzer,detect,buildTextReport,checkBlacklist,submitToBlacklist,fetchThreatIntel,applyRemoteIntel}"
  export FF_GUARD_SIGN
  FF_DIST="$DIST" node "$SCRIPT_DIR/security/inject.js"
fi

# ===========================================================================
# Step 6 — package final archive (prefer zip, fall back to tar.gz).
# ===========================================================================
log "step 6/6  packaging archive"

ARCHIVE_BASE="a4ther-scanner-v$VERSION"
rm -f "$SCRIPT_DIR/$ARCHIVE_BASE.zip" "$SCRIPT_DIR/$ARCHIVE_BASE.tar.gz"

if have zip; then
  # zip needs to run from inside dist/ so paths are relative.
  ( cd "$DIST" && zip -r -q -9 "$SCRIPT_DIR/$ARCHIVE_BASE.zip" . )
  ARCHIVE="$SCRIPT_DIR/$ARCHIVE_BASE.zip"
else
  log "  zip not found; using tar.gz"
  ( cd "$DIST" && tar -czf "$SCRIPT_DIR/$ARCHIVE_BASE.tar.gz" . )
  ARCHIVE="$SCRIPT_DIR/$ARCHIVE_BASE.tar.gz"
fi

log "archive -> $ARCHIVE"

# ---------------------------------------------------------------------------
# Final summary.
# ---------------------------------------------------------------------------
if [ -n "${GENERATED_PASS:-}" ]; then
  printf '\n'
  log "NOTE: a random encryption passphrase was generated for this build."
  log "      Store it securely; it is required to decrypt the .sh.enc files:"
  printf '\n      FF_PASSPHRASE=%s\n\n' "$GENERATED_PASS"
fi

log "build complete: v$VERSION"
