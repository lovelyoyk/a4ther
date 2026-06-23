#!/usr/bin/env node
/* eslint-disable */
/**
 * inject.js — A4ther FFScanner anti-tampering injector.
 *
 * Splices the runtime guard (security/guard.js) into already-built artifacts:
 *
 *   dist/index.html      (browser profile)
 *   dist/a4ther-ios.js   (scriptable profile)
 *
 * Pipeline position: runs AFTER obfuscate.js + html-minifier (i.e. last, so it
 * signs the *shipped* bytes). build.sh calls it as step 6.
 *
 * What it does
 * ------------
 *  1. Reads each target's shipped code.
 *  2. Computes SHA-256 of a configurable set of "critical functions" found in
 *     that code (matched by a marker comment the source carries, see below),
 *     producing the `sigs` map the guard verifies at runtime.
 *  3. Obfuscates guard.js with control-flow flattening + self-defending +
 *     string-array (so the checks read as ordinary flattened code) and renames
 *     the `__A4G__` entry to a per-build hex identifier.
 *  4. Wraps it: <hexId>({profile, sigs, onTamper}); and splices it in:
 *       - HTML: just before </body> in its own <script>.
 *       - JS  : prepended to the file so it runs before anything else.
 *  5. Writes a manifest (dist/security-manifest.json) with the sigs + the
 *     guard SHA so the build is reproducible/auditable.
 *
 * "Critical functions" are identified WITHOUT touching the obfuscated source:
 * the injector signs whole-artifact regions delimited by stable anchors. For
 * the guard's runtime check to line up, we sign *named globals the host code
 * already exposes*. In this codebase the obfuscator runs with renameGlobals:
 * false, so top-level `function VERSION...`-style names survive. We therefore
 * sign by re-reading the function source the SAME way the runtime does
 * (Function.prototype.toString → normalize → sha256), executed here in Node by
 * loading the artifact in a sandbox. If a target exposes no signable globals,
 * signature verification is simply skipped for that target (anti-debug + memory
 * sealing still apply) and a warning is logged.
 *
 * Usage:
 *   node security/inject.js                 # inject into dist/
 *   FF_GUARD_LEVEL=max node security/inject.js
 *   node security/inject.js --self-test     # false-positive + perf harness
 *
 * Env:
 *   FF_DIST          dist dir            (default ../dist relative to this file)
 *   FF_GUARD_LEVEL   high | max          (default high)
 *   FF_GUARD_SIGN    "fnA,fnB"           globals to sign (default: auto/none)
 */

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

let JsObf;
try {
  JsObf = require('javascript-obfuscator');
} catch (e) {
  console.error('[inject] Missing dependency "javascript-obfuscator". Run: npm install');
  process.exit(1);
}

const HERE = __dirname;
const DIST = path.resolve(process.env.FF_DIST || path.join(HERE, '..', 'dist'));
const LEVEL = (process.env.FF_GUARD_LEVEL || 'high').toLowerCase();
const GUARD_SRC = path.join(HERE, 'guard.js');

function log() { console.log.apply(console, ['[inject]'].concat([].slice.call(arguments))); }
function warn() { console.warn.apply(console, ['[inject] WARN'].concat([].slice.call(arguments))); }
function die(m) { console.error('[inject] ERROR:', m); process.exit(1); }

// ---------------------------------------------------------------------------
// Signature helpers — MUST match guard.js normSrc()/sha256 byte-for-byte.
// ---------------------------------------------------------------------------
function normSrc(fnSource) {
  return String(fnSource).replace(/\s+/g, ' ').trim();
}
function sha256hex(s) {
  return crypto.createHash('sha256').update(s, 'binary').digest('hex');
}

// Extract a top-level `function NAME(...) { ... }` declaration's full source
// text from the artifact by brace-matching. Returns null if not found or not a
// top-level (depth-0) declaration. This is EXECUTION-FREE, so artifacts that
// use top-level `await`, DOM APIs, or Scriptable globals sign cleanly.
//
// The extracted text is exactly what `Function.prototype.toString` yields at
// runtime for that declaration ("function NAME(...){...}"), which is what the
// guard re-hashes. We additionally re-evaluate the extracted text in isolation
// and compare toString() to be certain the bytes line up before trusting them.
function extractTopLevelFunction(code, name) {
  const decl = 'function ' + name;
  let from = 0;
  for (;;) {
    const at = code.indexOf(decl, from);
    if (at === -1) return null;
    // Must be a word boundary on both sides of the name.
    const before = code[at - 1];
    const after = code[at + decl.length];
    const boundaryOk =
      (at === 0 || /[\s;{}()*]/.test(before)) &&
      (after === '(' || after === ' ' || after === '\t' || after === '\n');
    if (!boundaryOk) { from = at + decl.length; continue; }

    // Walk back over any modifiers/markers that `Function.prototype.toString`
    // INCLUDES in its output, so the signed bytes match the runtime read:
    //   - "async function NAME"      => keep the "async " prefix
    //   - "function* NAME" / "*NAME" => the '*' sits between function and name,
    //     so `decl` ("function NAME") wouldn't match a generator anyway; we
    //     handle the common async case here.
    let start = at;
    // skip back over whitespace, then check for the `async` keyword.
    let p = at - 1;
    while (p >= 0 && /\s/.test(code[p])) p--;
    if (p >= 4 && code.slice(p - 4, p + 1) === 'async') {
      start = p - 4;
    }

    // Verify depth-0 (global) by STRING-AWARE brace balance up to `start`.
    // Must skip braces inside string/template literals or a single literal
    // like "}" earlier in the (minified) file corrupts the count and we'd
    // wrongly reject a genuinely top-level function.
    let depth = 0, s = null, e = false;
    for (let i = 0; i < start; i++) {
      const c = code[i];
      if (s) {
        if (e) { e = false; }
        else if (c === '\\') { e = true; }
        else if (c === s) { s = null; }
        continue;
      }
      if (c === '"' || c === "'" || c === '`') { s = c; continue; }
      if (c === '{') depth++;
      else if (c === '}') depth--;
    }
    if (depth !== 0) { from = at + decl.length; continue; }

    // Find the opening brace of the body, then brace-match to its close,
    // honoring string/template literals and escapes.
    const open = code.indexOf('{', at);
    if (open === -1) return null;
    let d = 0, i = open, inStr = null, esc = false;
    for (; i < code.length; i++) {
      const c = code[i];
      if (inStr) {
        if (esc) { esc = false; }
        else if (c === '\\') { esc = true; }
        else if (c === inStr) { inStr = null; }
        continue;
      }
      if (c === '"' || c === "'" || c === '`') { inStr = c; continue; }
      if (c === '{') d++;
      else if (c === '}') { d--; if (d === 0) { i++; break; } }
    }
    return code.slice(start, i);
  }
}

function computeSigs(code, profile, names) {
  const sigs = {};
  if (!names.length) return sigs;
  for (const name of names) {
    const src = extractTopLevelFunction(code, name);
    if (src == null) {
      warn('signable top-level function not found, skipping:', name, '(' + profile + ')');
      continue;
    }
    // CRITICAL: the signed bytes MUST equal what the runtime's
    // Function.prototype.toString will return, or every client false-positives
    // and bricks. We verify by re-evaluating the extracted text as a function
    // expression and confirming toString() round-trips to the same normalized
    // form. If it doesn't, we SKIP signing that function (better to lose one
    // signature than to ship a guaranteed-trip signature).
    let canonical;
    try {
      const fn = vm.runInNewContext('(' + src + ')');
      if (typeof fn !== 'function') throw new Error('not a function');
      canonical = Function.prototype.toString.call(fn);
      if (normSrc(canonical) !== normSrc(src)) {
        // toString gave back something different from our extraction. The hash
        // must follow toString (that's what the runtime uses), so trust it —
        // but only if it still references the right name.
        if (canonical.indexOf(name) === -1) {
          throw new Error('round-trip lost function name');
        }
      }
    } catch (e) {
      warn('skip signing', name, '- could not verify round-trip:', e.message);
      continue;
    }
    sigs[name] = sha256hex(normSrc(canonical));
    log('  signed', name, '=>', sigs[name].slice(0, 16) + '…');
  }
  return sigs;
}

// ---------------------------------------------------------------------------
// Guard obfuscation.
// ---------------------------------------------------------------------------
const OBF_OPTS = {
  high: {
    compact: true,
    controlFlowFlattening: true,
    controlFlowFlatteningThreshold: 1,
    deadCodeInjection: true,
    deadCodeInjectionThreshold: 0.3,
    selfDefending: true,
    simplify: true,
    splitStrings: true,
    splitStringsChunkLength: 6,
    stringArray: true,
    stringArrayEncoding: ['base64'],
    stringArrayThreshold: 1,
    transformObjectKeys: true,
    numbersToExpressions: true,
    identifierNamesGenerator: 'hexadecimal',
    renameGlobals: false,
    reservedNames: ['^__A4G__$'],
    target: 'browser',
  },
  max: {
    compact: true,
    controlFlowFlattening: true,
    controlFlowFlatteningThreshold: 1,
    deadCodeInjection: true,
    deadCodeInjectionThreshold: 0.5,
    selfDefending: true,
    simplify: true,
    splitStrings: true,
    splitStringsChunkLength: 4,
    stringArray: true,
    stringArrayEncoding: ['rc4'],
    stringArrayThreshold: 1,
    stringArrayWrappersCount: 3,
    stringArrayWrappersType: 'function',
    transformObjectKeys: true,
    numbersToExpressions: true,
    identifierNamesGenerator: 'mangled-shuffled',
    renameGlobals: false,
    reservedNames: ['^__A4G__$'],
    target: 'browser',
  },
};

function obfuscateGuard(srcBody, hexId) {
  const opts = OBF_OPTS[LEVEL] || OBF_OPTS.high;
  const res = JsObf.obfuscate(srcBody, opts);
  let out = res.getObfuscatedCode();
  // Rename the reserved entry to the per-build hex id (whole-word).
  out = out.replace(/\b__A4G__\b/g, hexId);
  return out;
}

// Strip the CommonJS export tail so it doesn't run in the browser/Scriptable.
function guardBodyForShipping(src) {
  const marker = "if (typeof module !== 'undefined' && module.exports) {";
  const idx = src.indexOf(marker);
  return idx === -1 ? src : src.slice(0, idx).trimEnd() + '\n';
}

// onTamper bodies per profile (kept tiny + literal so they survive splicing).
function onTamperFor(profile) {
  if (profile === 'ios') {
    // Scriptable: present an alert if available, then abort the run.
    return "function(r){try{if(typeof Alert!=='undefined'){var a=new Alert();" +
      "a.title='A4ther';a.message='Integridade comprometida ('+r+'). " +
      "Reinstale a partir da fonte oficial.';a.addAction('OK');a.present();}}" +
      "catch(e){}try{if(typeof Script!=='undefined')Script.complete();}catch(e){}" +
      "throw new Error('A4G:'+r);}";
  }
  // web: default destructive lock lives in the guard; pass undefined to use it.
  return null;
}

function buildInvocation(hexId, profile, sigs) {
  const cfg = {
    profile: profile,
    sigs: sigs,
  };
  let cfgStr = JSON.stringify(cfg);
  const ot = onTamperFor(profile);
  if (ot) {
    // Inject the function expression into the JSON-ish config literal.
    cfgStr = cfgStr.replace(/}$/, ',"onTamper":' + ot + '}');
  }
  return hexId + '(' + cfgStr + ');';
}

// ---------------------------------------------------------------------------
// Splicers.
// ---------------------------------------------------------------------------
// Remove any previously-injected guard <script>/*A4G*/…</script> blocks so a
// re-run re-signs against the CURRENT shipped code instead of aborting. The
// guard is always emitted as a single self-contained inline <script> whose body
// begins with the /*A4G*/ marker, so we can excise each such block precisely by
// walking from the marker back to its <script ...> open and forward to the
// matching </script>. This makes injection idempotent even when the source HTML
// (or a prior build) already carries a guard.
function stripExistingGuards(html) {
  let removed = 0;
  for (;;) {
    const marker = html.indexOf('/*A4G*/');
    if (marker === -1) break;
    const open = html.lastIndexOf('<script', marker);
    const close = html.indexOf('</script>', marker);
    if (open === -1 || close === -1) {
      // Marker without a recognizable enclosing script — strip just the marker
      // token to guarantee forward progress and avoid an infinite loop.
      html = html.slice(0, marker) + html.slice(marker + '/*A4G*/'.length);
      continue;
    }
    html = html.slice(0, open) + html.slice(close + '</script>'.length);
    removed++;
  }
  return { html, removed };
}

function injectHtml(htmlPath, guardSrc) {
  let html = fs.readFileSync(htmlPath, 'utf8');
  if (html.indexOf('/*A4G*/') !== -1) {
    const r = stripExistingGuards(html);
    html = r.html;
    log('  removed', r.removed, 'stale guard block(s) before re-injection');
  }
  const code = extractInlineScripts(html);
  const namesEnv = process.env.FF_GUARD_SIGN;
  const names = namesEnv ? namesEnv.split(',').map(s => s.trim()).filter(Boolean) : [];
  const sigs = computeSigs(code, 'web', names);
  if (!names.length) warn('no FF_GUARD_SIGN names for web; signature verification disabled (anti-debug + sealing still active)');

  const hexId = '_0x' + crypto.randomBytes(4).toString('hex');
  const body = guardBodyForShipping(guardSrc);
  const obf = obfuscateGuard(body, hexId);
  const invoke = buildInvocation(hexId, 'web', sigs);
  const blob = '<script>/*A4G*/' + obf + invoke + '</script>';

  // Splice immediately before </body> (case-insensitive, last occurrence).
  const idx = html.toLowerCase().lastIndexOf('</body>');
  if (idx === -1) {
    // No body tag (shouldn't happen) — append.
    html = html + blob;
  } else {
    html = html.slice(0, idx) + blob + html.slice(idx);
  }
  fs.writeFileSync(htmlPath, html);
  return { sigs, guardSha: sha256hex(obf), hexId, bytes: blob.length };
}

// The JS guard is prepended as `/*A4G*/<obfuscated>…<hexId>({…});\n`. On a
// re-run we excise the previously-prepended block (marker → end of its trailing
// invocation `});`) so the bundle is re-signed against current bytes instead of
// being skipped. The guard body is a single IIFE-style blob followed by exactly
// one `<hexId>({...});` call and a newline, so we strip from the marker up to
// and including the first `});\n` that closes that invocation.
function stripExistingJsGuard(js) {
  let removed = 0;
  for (;;) {
    const marker = js.indexOf('/*A4G*/');
    if (marker === -1) break;
    // The injected blob always ends with the invocation terminator `});\n`.
    const end = js.indexOf('});\n', marker);
    if (end === -1) {
      js = js.slice(0, marker) + js.slice(marker + '/*A4G*/'.length);
      continue;
    }
    js = js.slice(0, marker) + js.slice(end + '});\n'.length);
    removed++;
  }
  return { js, removed };
}

function injectJs(jsPath, guardSrc) {
  let js = fs.readFileSync(jsPath, 'utf8');
  if (js.indexOf('/*A4G*/') !== -1) {
    const r = stripExistingJsGuard(js);
    js = r.js;
    log('  removed', r.removed, 'stale JS guard block(s) before re-injection');
  }
  const namesEnv = process.env.FF_GUARD_SIGN;
  const names = namesEnv ? namesEnv.split(',').map(s => s.trim()).filter(Boolean) : [];
  const sigs = computeSigs(js, 'ios', names);
  if (!names.length) warn('no FF_GUARD_SIGN names for ios; signature verification disabled (integrity-of-self + sealing still active)');

  const hexId = '_0x' + crypto.randomBytes(4).toString('hex');
  const body = guardBodyForShipping(guardSrc);
  const obf = obfuscateGuard(body, hexId);
  const invoke = buildInvocation(hexId, 'ios', sigs);
  // Prepend so the guard runs before the rest of the Scriptable program.
  const blob = '/*A4G*/' + obf + invoke + '\n';
  js = blob + js;
  fs.writeFileSync(jsPath, js);
  return { sigs, guardSha: sha256hex(obf), hexId, bytes: blob.length };
}

// Pull inline <script>...</script> bodies (excludes src= scripts).
function extractInlineScripts(html) {
  const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
  let m, out = '';
  while ((m = re.exec(html))) out += m[1] + '\n;\n';
  return out;
}

// ---------------------------------------------------------------------------
// Self-test harness (false positives + performance).
// ---------------------------------------------------------------------------
function selfTest() {
  log('SELF-TEST: false-positive + performance harness');
  const guardSrc = fs.readFileSync(GUARD_SRC, 'utf8');
  // Load guard in a clean Node sandbox emulating a non-DOM (Scriptable-like)
  // and a fake-DOM (browser-like) environment; assert no trip under normal run.
  const results = [];

  function runEnv(label, extraGlobals) {
    const sandbox = Object.assign({
      Date, Math, Object, Function, Array, String, JSON, RegExp, Error,
      console: { log() {}, clear() {}, table() {} },
      module: { exports: {} },
    }, extraGlobals || {});
    const ctx = vm.createContext(sandbox);
    let tamper = null;
    sandbox.__report = function (r) { tamper = r; };
    const harness = guardSrc + `
      ;var __api = __A4G__({ profile: ${JSON.stringify(extraGlobals && extraGlobals.window ? 'web' : 'ios')},
                             sigs: {}, onTamper: function(r){ __report(r); } });
    `;
    const t0 = process.hrtime.bigint();
    try {
      vm.runInContext(harness, ctx, { timeout: 5000 });
    } catch (e) {
      tamper = tamper || ('throw:' + e.message);
    }
    const t1 = process.hrtime.bigint();
    const ms = Number(t1 - t0) / 1e6;
    results.push({ env: label, tripped: tamper, initMs: +ms.toFixed(3) });

    // Performance: 1000 critical checks back-to-back.
    if (sandbox.__a4g && sandbox.__a4g.check) {
      const p0 = process.hrtime.bigint();
      for (let i = 0; i < 1000; i++) sandbox.__a4g.check('idle');
      const p1 = process.hrtime.bigint();
      results[results.length - 1].per1000ChecksMs =
        +(Number(p1 - p0) / 1e6).toFixed(3);
      results[results.length - 1].perCheckUs =
        +((Number(p1 - p0) / 1e6 / 1000) * 1000).toFixed(3);
    }
  }

  // ENV 1: Scriptable-like (no document/window/navigator).
  runEnv('scriptable-no-dom', {
    Alert: function () { return { addAction() {}, present() {} }; },
    Script: { complete() {} },
  });

  // ENV 2: Browser-like with a sane viewport (no devtools gap).
  const fakeWin = {};
  fakeWin.window = fakeWin;
  fakeWin.outerWidth = 1440; fakeWin.innerWidth = 1440;
  fakeWin.outerHeight = 900; fakeWin.innerHeight = 900;
  fakeWin.setTimeout = function () { return 0; };
  fakeWin.setInterval = function () { return 0; };
  runEnv('browser-normal', {
    window: fakeWin,
    document: {
      addEventListener() {}, hidden: false,
      documentElement: { innerHTML: '' },
    },
    navigator: { userAgent: 'mozilla' },
    crypto: { getRandomValues(a){return a;}, subtle: {} },
    localStorage: { removeItem() {} },
    setTimeout: fakeWin.setTimeout,
    setInterval: fakeWin.setInterval,
    outerWidth: 1440, innerWidth: 1440, outerHeight: 900, innerHeight: 900,
  });

  // ENV 3: signature self-consistency — sign a fn here, verify guard agrees.
  (function sigConsistency() {
    function sample(a, b) { return (a + b) * 2; }
    const expect = sha256hex(normSrc(Function.prototype.toString.call(sample)));
    const sandbox = {
      Date, Math, Object, Function, Array, String, JSON, RegExp, Error,
      console: { log() {}, clear() {}, table() {} },
      module: { exports: {} },
      sample,
    };
    const ctx = vm.createContext(sandbox);
    let tamper = null;
    sandbox.__report = function (r) { tamper = r; };
    const harness = guardSrc + `
      ;var g=(function(){try{return (0,eval)('this');}catch(_){return {};}})();
      g.sample = sample;
      var __api = __A4G__({ profile:'ios', sigs:{ sample: ${JSON.stringify(expect)} },
                            onTamper:function(r){__report(r);} });
      __api.check('critical');
    `;
    try { vm.runInContext(harness, ctx, { timeout: 5000 }); }
    catch (e) { tamper = tamper || ('throw:' + e.message); }
    results.push({ env: 'sig-consistency(valid)', tripped: tamper });

    // Now flip the expected sig => MUST trip.
    let tamper2 = null;
    sandbox.__report = function (r) { tamper2 = r; };
    const bad = expect.replace(/^./, c => (c === 'a' ? 'b' : 'a'));
    const harness2 = guardSrc + `
      ;var g=(function(){try{return (0,eval)('this');}catch(_){return {};}})();
      g.sample = sample;
      var __api = __A4G__({ profile:'ios', sigs:{ sample: ${JSON.stringify(bad)} },
                            onTamper:function(r){__report(r);} });
      __api.check('critical');
    `;
    try { vm.runInContext(harness2, vm.createContext(Object.assign({}, sandbox, { __report: sandbox.__report })), { timeout: 5000 }); }
    catch (e) { tamper2 = tamper2 || ('throw:' + e.message); }
    results.push({ env: 'sig-consistency(tampered)', tripped: tamper2, expectTrip: true });
  })();

  console.log(JSON.stringify({ selfTest: results }, null, 2));
  // Exit non-zero if any "normal" env tripped, or tampered didn't.
  const normalTripped = results.some(r =>
    /normal|no-dom|valid/.test(r.env) && r.tripped);
  const tamperedMissed = results.some(r =>
    r.expectTrip && !r.tripped);
  if (normalTripped || tamperedMissed) process.exitCode = 1;
}

// ---------------------------------------------------------------------------
// Main.
// ---------------------------------------------------------------------------
function main() {
  if (process.argv.indexOf('--self-test') !== -1) return selfTest();

  if (!fs.existsSync(GUARD_SRC)) die('guard.js not found at ' + GUARD_SRC);
  const guardSrc = fs.readFileSync(GUARD_SRC, 'utf8');
  log('level:', LEVEL, '| dist:', DIST);

  const manifest = { level: LEVEL, generatedAt: new Date().toISOString(), targets: {} };

  const htmlTarget = path.join(DIST, 'index.html');
  if (fs.existsSync(htmlTarget)) {
    log('injecting -> dist/index.html');
    const r = injectHtml(htmlTarget, guardSrc);
    if (r) manifest.targets['index.html'] = r;
  } else warn('dist/index.html not found; skipping');

  const jsTarget = path.join(DIST, 'a4ther-ios.js');
  if (fs.existsSync(jsTarget)) {
    log('injecting -> dist/a4ther-ios.js');
    const r = injectJs(jsTarget, guardSrc);
    if (r) manifest.targets['a4ther-ios.js'] = r;
  } else warn('dist/a4ther-ios.js not found; skipping');

  const manPath = path.join(DIST, 'security-manifest.json');
  fs.writeFileSync(manPath, JSON.stringify(manifest, null, 2));
  log('manifest ->', path.relative(process.cwd(), manPath));
  log('done.');
}

main();
