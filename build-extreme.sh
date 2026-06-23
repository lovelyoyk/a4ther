#!/bin/sh
# build-extreme.sh — A4ther FFScanner EXTREME protection build pipeline.
#
# Orchestrates ALL FOUR protection layers, in sequence, into dist-extreme/:
#
#   LAYER 1  Self-extracting packer for shell scripts
#            (pack.sh: gzip -9 | base64 | obfuscated anti-debug stub).
#            NOTE: UPX is intentionally NOT used — these targets are
#            interpreted /system/bin/sh + Termux bash *text* scripts, not
#            compiled ELF/Mach-O/PE binaries. UPX cannot touch them. The
#            equivalent "compress + opaque" treatment for interpreted scripts
#            is the self-extracting gzip stub produced by pack.sh.
#
#   LAYER 2  WASM core for the iOS/browser hot paths
#            (emit-wasm.js -> a4ther-ios.wasm; a4ther-wasm-loader.min.js binds
#            it with a byte-exact pure-JS fallback for CSP/old engines).
#
#   LAYER 3  JS obfuscation of the iOS scanner + loader
#            (javascript-obfuscator: control-flow flattening, string array,
#            self-defending) and HTML minification.
#
#   LAYER 4  Runtime anti-tampering guard
#            (security/inject.js splices the obfuscated security/guard.js into
#            the shipped HTML + iOS JS: SHA-256 code-signing, anti-debug,
#            memory sealing).
#
#   PACKAGE  Reproducible archive a4ther-scanner-extreme-v<VERSION>.zip +
#            SHA-256, DEPLOY_CHECKLIST, and a build manifest.
#
# POSIX-portable: pure /bin/sh, no bashisms, no arrays, no `case` inside $(),
# no process substitution. Mirrors the constraints of the legacy build.sh.
#
# Usage:
#   sh ./build-extreme.sh
#
# Env overrides:
#   FF_PASSPHRASE     AES passphrase for *.sh.enc (else random, printed once)
#   FF_GUARD_LEVEL    high | max     guard obfuscation strength (default high)
#   FF_SKIP_PACK      1 = skip layer 1 (script packing)
#   FF_SKIP_WASM      1 = skip layer 2 (WASM regen)
#   FF_SKIP_GUARD     1 = skip layer 4 (anti-tampering injection)
#   FF_SKIP_ENCRYPT   1 = skip the extra AES envelope on packed scripts

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

DIST="$SCRIPT_DIR/dist-extreme"
SEC="$SCRIPT_DIR/security"

log()  { printf '[extreme] %s\n' "$*"; }
step() { printf '\n[extreme] === %s ===\n' "$*"; }
die()  { printf '[extreme] ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have node    || die "node not found in PATH"
have openssl || die "openssl not found in PATH"
have gzip    || die "gzip not found in PATH"

# ---------------------------------------------------------------------------
# Version (const VERSION = "x.y.z" or <span id="version">vX.Y.Z</span>).
# ---------------------------------------------------------------------------
VERSION=$(sed -n 's/.*const VERSION = "\([^"]*\)".*/\1/p' index.html | head -n 1)
if [ -z "$VERSION" ]; then
  VERSION=$(sed -n 's/.*id="version">v\([0-9][0-9.]*\)<.*/\1/p' index.html | head -n 1)
fi
[ -n "$VERSION" ] || VERSION="unknown"
log "version v$VERSION  | guard level ${FF_GUARD_LEVEL:-high}"

# ---------------------------------------------------------------------------
# Dependencies.
# ---------------------------------------------------------------------------
if [ ! -d "$SCRIPT_DIR/node_modules/javascript-obfuscator" ]; then
  log "installing npm dependencies..."
  npm install --no-audit --no-fund
fi

# ---------------------------------------------------------------------------
# Clean & recreate dist-extreme, preserving the build tools that live in it
# (pack.sh, emit-wasm.js, a4ther-wasm-loader.js source).
# ---------------------------------------------------------------------------
step "preparing dist-extreme/"
mkdir -p "$DIST"
# Remove only generated artifacts; keep the tooling sources.
for f in a4ther.sh a4ther-adb.sh a4ther.sh.enc a4ther-adb.sh.enc \
         a4ther-ios.js a4ther-ios.wasm a4ther-ios.wat \
         a4ther-wasm-loader.min.js index.html service-worker.js \
         decrypt.sh security-manifest.json BUILD_MANIFEST.json; do
  rm -f "$DIST/$f"
done
[ -f "$DIST/pack.sh" ]      || die "missing layer-1 tool dist-extreme/pack.sh"
[ -f "$DIST/emit-wasm.js" ] || die "missing layer-2 tool dist-extreme/emit-wasm.js"

# ===========================================================================
# LAYER 1 — self-extracting compressed packer for the shell scripts.
# ===========================================================================
if [ "${FF_SKIP_PACK:-0}" = "1" ]; then
  step "LAYER 1/4  script packing SKIPPED (FF_SKIP_PACK=1)"
  cp a4ther.sh "$DIST/a4ther.sh"
  cp a4ther-adb.sh "$DIST/a4ther-adb.sh"
else
  step "LAYER 1/4  packing shell scripts (gzip + base64 + anti-debug stub)"
  # Pack a4ther.sh (system sh) and a4ther-adb.sh (Termux bash), preserving
  # each one's ORIGINAL shebang so the unpacked script runs under the right
  # interpreter on-device.
  SB_MAIN=$(head -n 1 a4ther.sh)
  SB_ADB=$(head -n 1 a4ther-adb.sh)
  sh "$DIST/pack.sh" a4ther.sh     "$DIST/a4ther.sh"     "$SB_MAIN"
  sh "$DIST/pack.sh" a4ther-adb.sh "$DIST/a4ther-adb.sh" "$SB_ADB"
  log "  packed a4ther.sh     $(wc -c <a4ther.sh) -> $(wc -c <"$DIST/a4ther.sh") bytes"
  log "  packed a4ther-adb.sh $(wc -c <a4ther-adb.sh) -> $(wc -c <"$DIST/a4ther-adb.sh") bytes"

  # Self-verify: each packed stub must decompress byte-identical to source.
  node - "$DIST/a4ther.sh" a4ther.sh <<'VERIFY_EOF'
const fs=require("fs"), zlib=require("zlib");
const [,, packed, src]=process.argv;
const m=fs.readFileSync(packed,"utf8").match(/__P=([A-Za-z0-9+/=]+)/);
if(!m){console.error("[extreme] pack verify: no payload in "+packed);process.exit(1);}
const out=zlib.gunzipSync(Buffer.from(m[1],"base64"));
const want=fs.readFileSync(src);
if(!out.equals(want)){console.error("[extreme] pack verify FAILED: "+packed+" != "+src);process.exit(1);}
console.log("[extreme]   verify OK: "+packed+" round-trips to source");
VERIFY_EOF
fi

# Optional extra AES envelope on the packed stubs (defence in depth at rest).
if [ "${FF_SKIP_ENCRYPT:-0}" = "1" ]; then
  log "  AES envelope skipped (FF_SKIP_ENCRYPT=1)"
else
  PASS=""
  if [ -n "${FF_PASSPHRASE:-}" ]; then
    PASS="$FF_PASSPHRASE"
  else
    PASS=$(openssl rand -hex 24)
    GENERATED_PASS="$PASS"
  fi
  for base in a4ther.sh a4ther-adb.sh; do
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
      -in "$DIST/$base" -out "$DIST/$base.enc" -pass pass:"$PASS"
    log "  AES envelope -> dist-extreme/$base.enc"
  done
  # Decrypt helper.
  cat > "$DIST/decrypt.sh" <<'DECRYPT_EOF'
#!/bin/sh
# decrypt.sh — recover an AES-enveloped, packed A4ther script, then RUN it.
# Usage: FF_PASSPHRASE=... sh decrypt.sh a4ther.sh.enc [args...]
set -eu
[ $# -ge 1 ] || { echo "usage: FF_PASSPHRASE=... sh decrypt.sh <file.enc> [args]" >&2; exit 1; }
[ -n "${FF_PASSPHRASE:-}" ] || { echo "FF_PASSPHRASE not set" >&2; exit 1; }
ENC="$1"; shift
TMP=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.a4dec_$$")
trap 'rm -f "$TMP" 2>/dev/null' EXIT INT TERM
openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
  -in "$ENC" -out "$TMP" -pass pass:"$FF_PASSPHRASE"
chmod 0700 "$TMP" 2>/dev/null || true
sh "$TMP" "$@"
DECRYPT_EOF
  log "  wrote dist-extreme/decrypt.sh helper"
fi

# ===========================================================================
# LAYER 2 — regenerate the WASM core deterministically.
# ===========================================================================
if [ "${FF_SKIP_WASM:-0}" = "1" ]; then
  step "LAYER 2/4  WASM regen SKIPPED (FF_SKIP_WASM=1)"
else
  step "LAYER 2/4  regenerating WASM core (emit-wasm.js)"
  node "$DIST/emit-wasm.js"
  # Validate + functional smoke test of all three exports.
  node - "$DIST/a4ther-ios.wasm" <<'WASM_EOF'
const fs=require("fs");
const wasm=fs.readFileSync(process.argv[2]);
if(!WebAssembly.validate(wasm)){console.error("[extreme] WASM invalid");process.exit(1);}
const ex=new WebAssembly.Instance(new WebAssembly.Module(wasm),{}).exports;
const u8=new Uint8Array(ex.mem.buffer);
// b64_decode
const b="SGVsbG8=";for(let i=0;i<b.length;i++)u8[i]=b.charCodeAt(i);
let n=ex.b64_decode(0,b.length,1000),s="";for(let i=0;i<n;i++)s+=String.fromCharCode(u8[1000+i]);
if(s!=="Hello"){console.error("[extreme] b64_decode FAIL "+s);process.exit(1);}
// fnv1a
const hb=[72,101,108,108,111];for(let i=0;i<hb.length;i++)u8[2000+i]=hb[i];
let h=ex.fnv1a(2000,hb.length)>>>0,r=0x811c9dc5;for(const x of hb){r^=x;r=Math.imul(r,0x01000193);}r>>>=0;
if(h!==r){console.error("[extreme] fnv1a FAIL");process.exit(1);}
// strings_scan
const inp=[97,98,0,104,101,108,108,111,1,119,111,114,108,100];for(let i=0;i<inp.length;i++)u8[3000+i]=inp[i];
let m=ex.strings_scan(3000,inp.length,4,4000),o="";for(let i=0;i<m;i++)o+=String.fromCharCode(u8[4000+i]);
if(!(o.includes("hello")&&o.includes("world"))){console.error("[extreme] strings_scan FAIL");process.exit(1);}
console.log("[extreme]   WASM valid + 3/3 exports correct ("+wasm.length+" bytes)");
WASM_EOF
fi

# ===========================================================================
# LAYER 3 — obfuscate JS (iOS scanner + loader) and minify HTML.
# ===========================================================================
step "LAYER 3/4  obfuscating JS + minifying HTML"

# 3a. Minify + obfuscate the WASM loader.
node - "$DIST" <<'LOADER_EOF'
const fs=require("fs"), path=require("path");
const DIST=process.argv[2];
const JsObf=require("javascript-obfuscator");
const src=fs.readFileSync(path.join(DIST,"a4ther-wasm-loader.js"),"utf8");
const res=JsObf.obfuscate(src,{
  compact:true, controlFlowFlattening:true, controlFlowFlatteningThreshold:0.75,
  deadCodeInjection:true, deadCodeInjectionThreshold:0.2, selfDefending:true,
  simplify:true, stringArray:true, stringArrayEncoding:["base64"],
  stringArrayThreshold:0.8, numbersToExpressions:true,
  identifierNamesGenerator:"hexadecimal", renameGlobals:false, target:"browser",
});
fs.writeFileSync(path.join(DIST,"a4ther-wasm-loader.min.js"),res.getObfuscatedCode());
console.log("[extreme]   obfuscated loader -> a4ther-wasm-loader.min.js ("+res.getObfuscatedCode().length+" bytes)");
LOADER_EOF

# 3b. Build the WASM-accelerated iOS bundle = obfuscated(loader) + obfuscated
#     iOS scanner body, re-using the existing minified loader header marker.
#     We obfuscate the canonical iOS source (a4ther-ios.js) and prepend the
#     minified loader so the WASM hot-paths are available (A4W.*), with the
#     pure-JS fallback intact.
if [ -f "$SCRIPT_DIR/a4ther-ios.js" ]; then
  node - "$SCRIPT_DIR" "$DIST" <<'IOS_EOF'
const fs=require("fs"), path=require("path");
const [,,SRC,DIST]=process.argv;
const JsObf=require("javascript-obfuscator");
const loader=fs.readFileSync(path.join(DIST,"a4ther-wasm-loader.min.js"),"utf8");
const iosSrc=fs.readFileSync(path.join(SRC,"a4ther-ios.js"),"utf8");
const obf=JsObf.obfuscate(iosSrc,{
  compact:true, controlFlowFlattening:true, controlFlowFlatteningThreshold:0.6,
  deadCodeInjection:true, deadCodeInjectionThreshold:0.2, selfDefending:true,
  simplify:true, stringArray:true, stringArrayEncoding:["base64"],
  stringArrayThreshold:0.75, numbersToExpressions:true,
  identifierNamesGenerator:"hexadecimal", renameGlobals:false, target:"node",
}).getObfuscatedCode();
const header="/* a4ther-ios (WASM-accelerated build) — loader + opaque a4ther-ios.wasm core */\n";
fs.writeFileSync(path.join(DIST,"a4ther-ios.js"), header+loader+"\n"+obf);
console.log("[extreme]   built WASM iOS bundle -> a4ther-ios.js ("+(header.length+loader.length+obf.length)+" bytes)");
IOS_EOF
else
  log "  a4ther-ios.js source absent; keeping existing dist-extreme bundle"
fi

# 3c. Minify HTML (browser profile).
MINIFIER="$SCRIPT_DIR/node_modules/.bin/html-minifier-terser"
if [ -f "$SCRIPT_DIR/index.html" ]; then
  if [ -x "$MINIFIER" ]; then
    "$MINIFIER" --collapse-whitespace --remove-comments --minify-css true \
      --minify-js false --remove-redundant-attributes \
      --remove-script-type-attributes -o "$DIST/index.html" index.html
    log "  minified -> dist-extreme/index.html ($(wc -c <"$DIST/index.html") bytes)"
  else
    cp index.html "$DIST/index.html"
    log "  (minifier missing) copied index.html"
  fi
fi
# Carry the service worker if present (obfuscated lightly).
if [ -f "$SCRIPT_DIR/service-worker.js" ]; then
  node - "$SCRIPT_DIR" "$DIST" <<'SW_EOF'
const fs=require("fs"), path=require("path");
const [,,SRC,DIST]=process.argv;
const JsObf=require("javascript-obfuscator");
const src=fs.readFileSync(path.join(SRC,"service-worker.js"),"utf8");
const out=JsObf.obfuscate(src,{compact:true,stringArray:true,stringArrayThreshold:0.75,
  identifierNamesGenerator:"hexadecimal",renameGlobals:false,target:"browser"}).getObfuscatedCode();
fs.writeFileSync(path.join(DIST,"service-worker.js"),out);
console.log("[extreme]   obfuscated -> service-worker.js");
SW_EOF
fi
# Static web assets.
for asset in manifest.webmanifest icon.svg apple-touch-icon.png icon-192.png icon-512.png; do
  [ -f "$SCRIPT_DIR/$asset" ] && cp "$SCRIPT_DIR/$asset" "$DIST/$asset"
done

# ===========================================================================
# LAYER 4 — inject the obfuscated runtime anti-tampering guard.
# ===========================================================================
if [ "${FF_SKIP_GUARD:-0}" = "1" ]; then
  step "LAYER 4/4  anti-tampering injection SKIPPED (FF_SKIP_GUARD=1)"
else
  step "LAYER 4/4  injecting anti-tampering guard"
  : "${FF_GUARD_SIGN:=runPrivacyReport,runSysdiagnoseAnalyzer,detect,buildTextReport,checkBlacklist,submitToBlacklist,fetchThreatIntel,applyRemoteIntel}"
  export FF_GUARD_SIGN
  FF_DIST="$DIST" node "$SEC/inject.js"
fi

# ===========================================================================
# PACKAGE — reproducible archive + checksum + manifest + checklist.
# ===========================================================================
step "packaging extreme archive"
ARCHIVE_BASE="a4ther-scanner-extreme-v$VERSION"
rm -f "$SCRIPT_DIR/$ARCHIVE_BASE.zip" "$SCRIPT_DIR/$ARCHIVE_BASE.tar.gz"

# Build manifest of every shipped artifact + its SHA-256.
node - "$DIST" "$VERSION" "${FF_GUARD_LEVEL:-high}" <<'MAN_EOF'
const fs=require("fs"), path=require("path"), crypto=require("crypto");
const [,,DIST,VERSION,LEVEL]=process.argv;
const skip=new Set(["pack.sh","emit-wasm.js","a4ther-wasm-loader.js","BUILD_MANIFEST.json"]);
const files=fs.readdirSync(DIST).filter(f=>!skip.has(f)&&fs.statSync(path.join(DIST,f)).isFile());
const out={product:"A4ther FFScanner — EXTREME build",version:VERSION,guardLevel:LEVEL,
  generatedAt:new Date().toISOString(),layers:["1:script-pack(gzip+base64+antidebug)","2:wasm-core","3:js-obfuscation+html-minify","4:antitamper-guard"],
  artifacts:{}};
for(const f of files.sort()){
  const b=fs.readFileSync(path.join(DIST,f));
  out.artifacts[f]={bytes:b.length,sha256:crypto.createHash("sha256").update(b).digest("hex")};
}
fs.writeFileSync(path.join(DIST,"BUILD_MANIFEST.json"),JSON.stringify(out,null,2));
console.log("[extreme]   wrote BUILD_MANIFEST.json ("+files.length+" artifacts)");
MAN_EOF

if have zip; then
  ( cd "$DIST" && zip -r -q -9 "$SCRIPT_DIR/$ARCHIVE_BASE.zip" . \
      -x 'pack.sh' -x 'emit-wasm.js' -x 'a4ther-wasm-loader.js' )
  ARCHIVE="$SCRIPT_DIR/$ARCHIVE_BASE.zip"
else
  ( cd "$DIST" && tar --exclude=pack.sh --exclude=emit-wasm.js \
      --exclude=a4ther-wasm-loader.js -czf "$SCRIPT_DIR/$ARCHIVE_BASE.tar.gz" . )
  ARCHIVE="$SCRIPT_DIR/$ARCHIVE_BASE.tar.gz"
fi
# Archive checksum.
if have shasum; then shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256";
elif have sha256sum; then sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"; fi
log "archive -> $ARCHIVE"
[ -f "$ARCHIVE.sha256" ] && log "checksum -> $ARCHIVE.sha256"

# ---------------------------------------------------------------------------
# Summary.
# ---------------------------------------------------------------------------
if [ -n "${GENERATED_PASS:-}" ]; then
  printf '\n[extreme] NOTE: random AES passphrase generated for the .sh.enc envelope.\n'
  printf '[extreme]       Store it securely; required to decrypt the packed scripts:\n\n'
  printf '      FF_PASSPHRASE=%s\n\n' "$GENERATED_PASS"
fi
log "EXTREME build complete: v$VERSION"
