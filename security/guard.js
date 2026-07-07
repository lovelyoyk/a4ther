/* eslint-disable */
/**
 * guard.js — A4ther FFScanner runtime self-protection guard (SOURCE).
 *
 * This is the *readable* source for the anti-tampering layer. It is never
 * shipped as-is: security/inject.js runs it through javascript-obfuscator
 * (control-flow flattening + self-defending + string-array) and then splices
 * the obfuscated result into:
 *
 *   - index.html      (browser profile  — DevTools/console/proxy detection)
 *   - a4ther-ios.js   (scriptable profile — no DOM; integrity + timing only)
 *
 * Design goals
 * ------------
 *  1. Code-signature verification  — SHA-256 of critical function sources,
 *     re-checked at runtime; abort on mismatch (patched/hooked).
 *  2. Anti-debugging               — DevTools size gap, console-getter trap,
 *     timing trap, Function.prototype.toString hook detection.
 *  3. Memory sealing               — wipe passphrase / key strings after use,
 *     Object.freeze critical objects, non-enumerable poison props.
 *  4. Obfuscated checks            — the checks are emitted *inside* the
 *     control-flow-flattened bundle so they look like ordinary code to a
 *     decompiler; no string literal says "antiDebug" in the shipped artifact.
 *
 * Environment detection is runtime, so a SINGLE guard body works in both the
 * browser (index.html) and Scriptable (a4ther-ios.js). The injector only
 * decides which `profile` flag to bake in.
 *
 * The whole thing is wrapped by inject.js into an IIFE that receives a config
 * object:  __A4G__({ profile, sigs, onTamper })
 *   profile  : "web" | "ios"
 *   sigs     : { "<fnName>": "<sha256hex>" }   expected signatures
 *   onTamper : function(reason) -> void        (default: hard-lock)
 */

'use strict';

// The exported entry. inject.js renames this to a hex identifier and calls it
// immediately with the baked config.
function __A4G__(cfg) {
  cfg = cfg || {};
  var PROFILE = cfg.profile || 'web';
  var SIGS = cfg.sigs || {};
  var tripped = false;

  // -------------------------------------------------------------------------
  // Environment capability probe (no literal env names survive obfuscation).
  // -------------------------------------------------------------------------
  var G = (function () {
    try { return (0, eval)('this'); } catch (_) { return {}; }
  })() || {};
  var hasDOM =
    typeof G.document !== 'undefined' &&
    typeof G.window !== 'undefined' &&
    typeof G.navigator !== 'undefined';
  var hasCryptoSubtle =
    typeof G.crypto !== 'undefined' &&
    G.crypto &&
    typeof G.crypto.subtle !== 'undefined';

  // -------------------------------------------------------------------------
  // Tamper response. Default behavior is intentionally destructive but
  // recoverable by reload: clear sensitive state, then loop/abort.
  // -------------------------------------------------------------------------
  function trip(reason) {
    if (tripped) return;
    tripped = true;
    try {
      if (typeof cfg.onTamper === 'function') {
        cfg.onTamper(reason);
        return;
      }
    } catch (_) {}
    // Default hard-lock.
    try {
      if (hasDOM) {
        // Nuke any in-memory secrets we can reach, blank the document, stop JS.
        try { G.localStorage && G.localStorage.removeItem('ff_session'); } catch (_) {}
        try {
          G.document.documentElement.innerHTML =
            '<body style="background:#07060d;color:#ff4d6d;font:600 16px/1.6 ' +
            "system-ui;display:grid;place-items:center;height:100vh;margin:0\">" +
            'Integridade comprometida. Recarregue a partir da fonte oficial.</body>';
        } catch (_) {}
        // Soft-freeze the event loop on a tamper to defeat single-stepping.
        for (;;) { if (Date.now() < 0) break; }
      } else {
        // Scriptable / non-DOM: just throw to abort the script run.
        throw new Error('A4G:' + (reason || 'tamper'));
      }
    } catch (e) {
      throw e;
    }
  }

  // Soft signal: a LOW-confidence heuristic (timing jitter, viewport-gap) must
  // NEVER hard-lock a legitimate user. A false positive that blanks + freezes
  // the page is strictly worse than the (client-side, trivially-bypassed) attack
  // it guesses at — and real integrity is moving server-side. Reserve the
  // destructive trip() for HIGH-signal tamper (hooked toString, signature
  // mismatch). Soft signals only leave a breadcrumb for telemetry.
  function note(reason) {
    try { if (G.console && G.console.warn) G.console.warn('A4G:soft:' + reason); } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // 1) CODE-SIGNATURE VERIFICATION
  //    SHA-256 over Function.prototype.toString() of a named global function.
  //    Re-verified at runtime; mismatch => the function body was patched.
  // -------------------------------------------------------------------------

  // Tiny synchronous SHA-256 (used when crypto.subtle is unavailable, e.g.
  // Scriptable older runtimes, and to keep the check off the async path so a
  // breakpoint on `await` cannot stall it). Standard FIPS-180-4.
  function sha256hex(ascii) {
    function rr(n, x) { return (x >>> n) | (x << (32 - n)); }
    var maxWord = Math.pow(2, 32);
    var i, j;
    var result = '';
    var words = [];
    var asciiBitLength = ascii.length * 8;
    var hash = sha256hex.h = sha256hex.h || [];
    var k = sha256hex.k = sha256hex.k || [];
    var primeCounter = k.length;
    var isComposite = {};
    for (var candidate = 2; primeCounter < 64; candidate++) {
      if (!isComposite[candidate]) {
        for (i = 0; i < 313; i += candidate) isComposite[i] = candidate;
        hash[primeCounter] = (Math.pow(candidate, 0.5) * maxWord) | 0;
        k[primeCounter++] = (Math.pow(candidate, 1 / 3) * maxWord) | 0;
      }
    }
    ascii += '\x80';
    while (ascii.length % 64 - 56) ascii += '\x00';
    for (i = 0; i < ascii.length; i++) {
      j = ascii.charCodeAt(i);
      if (j >> 8) return '';
      words[i >> 2] |= j << ((3 - i) % 4) * 8;
    }
    words[words.length] = (asciiBitLength / maxWord) | 0;
    words[words.length] = asciiBitLength;
    for (j = 0; j < words.length;) {
      var w = words.slice(j, j += 16);
      var oldHash = hash;
      hash = hash.slice(0, 8);
      for (i = 0; i < 64; i++) {
        var w15 = w[i - 15], w2 = w[i - 2];
        var a = hash[0], e = hash[4];
        var temp1 = hash[7] +
          (rr(6, e) ^ rr(11, e) ^ rr(25, e)) +
          ((e & hash[5]) ^ (~e & hash[6])) +
          k[i] +
          (w[i] = i < 16 ? w[i] : (
            w[i - 16] +
            (rr(7, w15) ^ rr(18, w15) ^ (w15 >>> 3)) +
            w[i - 7] +
            (rr(17, w2) ^ rr(19, w2) ^ (w2 >>> 10))
          ) | 0);
        var temp2 = (rr(2, a) ^ rr(13, a) ^ rr(22, a)) +
          ((a & hash[1]) ^ (a & hash[2]) ^ (hash[1] & hash[2]));
        hash = [(temp1 + temp2) | 0].concat(hash);
        hash[4] = (hash[4] + temp1) | 0;
      }
      for (i = 0; i < 8; i++) hash[i] = (hash[i] + oldHash[i]) | 0;
    }
    for (i = 0; i < 8; i++) {
      for (j = 3; j + 1; j--) {
        var b = (hash[i] >> (j * 8)) & 255;
        result += ((b < 16) ? '0' : '') + b.toString(16);
      }
    }
    return result;
  }

  // Normalize a function's source so trivial engine-formatting differences
  // (which DON'T change semantics) do not cause false positives, while real
  // body edits still do.
  function normSrc(fn) {
    var s;
    try { s = Function.prototype.toString.call(fn); } catch (_) { return null; }
    if (typeof s !== 'string') return null;
    // Collapse all runs of whitespace to a single space; trim. Keeps tokens.
    return s.replace(/\s+/g, ' ').trim();
  }

  function verifySignatures() {
    var names = [];
    for (var n in SIGS) if (Object.prototype.hasOwnProperty.call(SIGS, n)) names.push(n);
    for (var i = 0; i < names.length; i++) {
      var name = names[i];
      var fn = G[name];
      if (typeof fn !== 'function') {
        // A critical export vanished => stripped/renamed by a patcher.
        trip('sig-missing');
        return false;
      }
      var src = normSrc(fn);
      if (src == null) { trip('sig-unreadable'); return false; }
      var got = sha256hex(src);
      if (got !== SIGS[name]) {
        trip('sig-mismatch');
        return false;
      }
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // 2) ANTI-DEBUGGING
  // -------------------------------------------------------------------------

  // 2a. Detect that Function.prototype.toString / console / timers have been
  //     replaced by a hook (Frida, devtools overrides, monkeypatch). Native
  //     functions stringify to "[native code]".
  function isNative(fn) {
    try {
      return /\{\s*\[native code\]\s*\}/.test(
        Function.prototype.toString.call(fn)
      );
    } catch (_) { return false; }
  }

  function detectHooks() {
    // toString itself must be native; if it was hooked, signature checks lie.
    // This is the single highest-signal, lowest-false-positive hook check:
    // a real instrumentation framework (Frida, devtools eval-overrides) that
    // wants to read/patch function bodies has to defeat toString, and a naive
    // override leaves a non-native toString behind.
    //
    // NOTE: we deliberately do NOT check console.* — legitimate browser
    // extensions (React/Redux/Vue DevTools, ad blockers, password managers)
    // routinely wrap console methods, so that check is a false-positive
    // factory and adds no real security over the toString guard above.
    if (!isNative(Function.prototype.toString)) return 'hook-tostring';
    if (hasDOM) {
      // Proxy-trap detection: a Proxy wrapping window leaks via self-identity.
      // window.window must be window; a Proxy that forwards `get` will usually
      // return the *proxy* (not the raw target) and break this invariant.
      try {
        if (G.window !== G.window.window) return 'proxy-window';
      } catch (_) { return 'proxy-window'; }
    }
    return null;
  }

  // 2b. Timing trap: a debugger paused on a breakpoint inflates wall time
  //     across a no-op loop. Tuned high to avoid GC-pause false positives.
  function timingTrap() {
    var t0 = Date.now();
    var x = 0;
    for (var i = 0; i < 1000; i++) { x += i; }
    var dt = Date.now() - t0;
    // 1000 trivial adds take <1ms everywhere. >250ms == a human is stepping
    // or an inspector is attached. Generous threshold => near-zero false pos.
    void x;
    return dt > 250 ? 'timing' : null;
  }

  // 2c. DevTools-open heuristic (browser only): outer/inner viewport gap.
  //     Mirrors the existing 160px check already in the vault project.
  function devtoolsOpen() {
    if (!hasDOM) return null;
    try {
      var w = G.window;
      // Mobile/touch browsers have NO local Web Inspector (it needs a tethered
      // desktop), and their outer/inner viewport gap is just the browser chrome
      // (URL bar, tab bar, notch/safe-area) which routinely exceeds any desktop
      // threshold. That chrome collapsing/expanding on scroll/rotate is what made
      // this heuristic fire INTERMITTENTLY on iOS Safari and hard-lock real users
      // (the check has 0% true-positive on mobile anyway). Viewport-gap is a
      // desktop-only signal — skip it entirely on coarse pointers.
      var nav = G.navigator || {};
      var coarse = (nav.maxTouchPoints || 0) > 0 ||
                   ('ontouchstart' in w) ||
                   (typeof w.matchMedia === 'function' &&
                    w.matchMedia('(pointer: coarse)').matches);
      if (coarse) return null;
      var thresh = 160;
      var wGap = w.outerWidth - w.innerWidth > thresh;
      var hGap = w.outerHeight - w.innerHeight > thresh;
      // Either gap alone fires on docked panels; require it to persist by
      // returning the signal and letting the caller debounce.
      return (wGap || hGap) ? 'devtools' : null;
    } catch (_) { return null; }
  }

  // -------------------------------------------------------------------------
  // 3) MEMORY SEALING
  // -------------------------------------------------------------------------

  // Overwrite a string's backing where the engine lets us. JS strings are
  // immutable, so the real mitigation is: (a) drop the only reference, and
  // (b) for typed buffers / arrays, zero them in place.
  function wipe(ref, holder, key) {
    try {
      if (ref instanceof Uint8Array || ref instanceof ArrayBuffer) {
        var view = ref instanceof ArrayBuffer ? new Uint8Array(ref) : ref;
        if (G.crypto && G.crypto.getRandomValues) G.crypto.getRandomValues(view);
        view.fill(0);
      }
    } catch (_) {}
    // Drop the reference and poison the slot so a later read can't recover it.
    if (holder && key != null) {
      try { holder[key] = '\x00'.repeat(64); } catch (_) {}
      try { holder[key] = null; } catch (_) {}
      try { delete holder[key]; } catch (_) {}
    }
  }

  // Deep-freeze a critical object graph so a runtime patcher can't swap
  // methods (e.g. replace a verify() with a no-op).
  function seal(obj, depth) {
    depth = depth == null ? 2 : depth;
    if (!obj || typeof obj !== 'object' || depth < 0) return obj;
    try {
      var keys = Object.getOwnPropertyNames(obj);
      for (var i = 0; i < keys.length; i++) {
        var v = obj[keys[i]];
        if (v && (typeof v === 'object' || typeof v === 'function')) {
          seal(v, depth - 1);
        }
      }
      Object.freeze(obj);
    } catch (_) {}
    return obj;
  }

  // -------------------------------------------------------------------------
  // 4) ORCHESTRATION (the part inject.js wraps in control-flow flattening)
  //    Returns a small API the host code can call at sensitive moments.
  // -------------------------------------------------------------------------

  function fullCheck(stage) {
    if (tripped) return false;
    var r;
    r = detectHooks();              if (r) { trip(r); return false; }
    r = timingTrap();               if (r) { note(r); }   // soft: never hard-lock
    if (PROFILE === 'web') {
      // Debounce devtools: must read open twice ~120ms apart. SOFT signal only
      // (note, never trip) — a viewport-gap heuristic misfires on mobile chrome
      // and must never brick a real user. See devtoolsOpen() + note().
      r = devtoolsOpen();
      if (r) {
        if (hasDOM) {
          G.setTimeout(function () {
            if (devtoolsOpen()) note('devtools');
          }, 120);
        } else {
          note('devtools');
        }
      }
    }
    if (stage === 'critical') {
      if (!verifySignatures()) return false;
    }
    return true;
  }

  // Continuous watchdog (browser): low-frequency so perf impact is negligible.
  function startWatchdog() {
    if (!hasDOM || PROFILE !== 'web') return;
    var jitter = 1500 + Math.floor(Math.random() * 1500); // 1.5–3s
    G.setInterval(function () { fullCheck('idle'); }, jitter);
    // Re-arm on visibility change (a paused tab is a classic debug pattern).
    try {
      G.document.addEventListener('visibilitychange', function () {
        if (!G.document.hidden) fullCheck('idle');
      });
    } catch (_) {}
  }

  var api = {
    check: fullCheck,            // call before sensitive ops: api.check('critical')
    wipe: wipe,                  // api.wipe(secretBuf, holderObj, 'passphrase')
    seal: seal,                  // api.seal(criticalObj)
    sha256: sha256hex,
    _tripped: function () { return tripped; },
  };

  // Run an initial pass + start the watchdog, but never throw out of init in
  // the web profile (a thrown init would white-screen on a false positive;
  // trip() already handles the real response).
  try {
    fullCheck('critical');
    startWatchdog();
  } catch (_) {}

  // Seal the API itself so it can't be neutered.
  seal(api, 1);
  // Best-effort: hide it from enumeration on the global.
  try {
    Object.defineProperty(G, '__a4g', {
      value: api, enumerable: false, configurable: false, writable: false,
    });
  } catch (_) { try { G.__a4g = api; } catch (__) {} }

  return api;
}

// CommonJS export for the injector + unit tests; harmless in the browser.
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { __A4G__: __A4G__ };
}
