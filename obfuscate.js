#!/usr/bin/env node
/**
 * obfuscate.js — A4ther FFScanner JS obfuscation build step.
 *
 * Recursively finds every *.js file under the project root, obfuscates it with
 * javascript-obfuscator, and writes the result to dist/ while preserving the
 * original directory structure.
 *
 * Usage:
 *   node obfuscate.js
 *
 * Env overrides:
 *   FF_SRC   source root           (default: script directory)
 *   FF_DIST  output directory      (default: <src>/dist)
 *   FF_LEVEL obfuscation level      low | medium | high   (default: high)
 */

'use strict';

const fs = require('fs');
const path = require('path');

let JavaScriptObfuscator;
try {
  JavaScriptObfuscator = require('javascript-obfuscator');
} catch (e) {
  console.error('[obfuscate] Missing dependency "javascript-obfuscator".');
  console.error('[obfuscate] Run:  npm install');
  process.exit(1);
}

const SRC = path.resolve(process.env.FF_SRC || __dirname);
const DIST = path.resolve(process.env.FF_DIST || path.join(SRC, 'dist'));
const LEVEL = (process.env.FF_LEVEL || 'high').toLowerCase();

// Directories we never descend into.
const SKIP_DIRS = new Set([
  'node_modules',
  'dist',
  '.git',
  '.claude',
  'backend',         // PHP backend — not JS we ship to clients
  'backend-workers', // deploy these via wrangler separately, not obfuscated here
]);

// Files we copy verbatim instead of obfuscating (already minified / vendor).
function isVendorOrMin(file) {
  return /\.min\.js$/i.test(file) || /(^|\/)vendor(\/|$)/i.test(file);
}

// Build-time scripts that must never ship inside dist/.
const EXCLUDE_BASENAMES = new Set(['obfuscate.js', 'build.js']);
function isBuildScript(file) {
  return EXCLUDE_BASENAMES.has(path.basename(file));
}

const PRESETS = {
  low: {
    compact: true,
    controlFlowFlattening: false,
    deadCodeInjection: false,
    stringArray: true,
    stringArrayThreshold: 0.5,
  },
  medium: {
    compact: true,
    controlFlowFlattening: true,
    controlFlowFlatteningThreshold: 0.5,
    deadCodeInjection: false,
    stringArray: true,
    stringArrayEncoding: ['base64'],
    stringArrayThreshold: 0.75,
    numbersToExpressions: true,
    simplify: true,
  },
  high: {
    compact: true,
    controlFlowFlattening: true,
    controlFlowFlatteningThreshold: 0.75,
    deadCodeInjection: true,
    deadCodeInjectionThreshold: 0.4,
    debugProtection: false, // keep false: breaks PWA/service-worker debugging
    disableConsoleOutput: false,
    identifierNamesGenerator: 'hexadecimal',
    numbersToExpressions: true,
    renameGlobals: false, // false so window/global hooks (SW events) survive
    selfDefending: true,
    simplify: true,
    splitStrings: true,
    splitStringsChunkLength: 8,
    stringArray: true,
    stringArrayEncoding: ['base64'],
    stringArrayThreshold: 1,
    transformObjectKeys: true,
    unicodeEscapeSequence: false,
  },
};

const baseOptions = PRESETS[LEVEL] || PRESETS.high;

/** Recursively collect *.js files under dir, honoring SKIP_DIRS. */
function collectJs(dir, acc) {
  acc = acc || [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (e) {
    return acc;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      collectJs(full, acc);
    } else if (entry.isFile() && /\.js$/i.test(entry.name)) {
      acc.push(full);
    }
  }
  return acc;
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function main() {
  console.log('[obfuscate] src   :', SRC);
  console.log('[obfuscate] dist  :', DIST);
  console.log('[obfuscate] level :', LEVEL);

  // Never let dist nest into itself; clean prior output.
  if (fs.existsSync(DIST)) {
    fs.rmSync(DIST, { recursive: true, force: true });
  }
  ensureDir(DIST);

  const files = collectJs(SRC);
  if (files.length === 0) {
    console.warn('[obfuscate] No .js files found. Nothing to do.');
    return;
  }

  let obfuscated = 0;
  let copied = 0;
  let failed = 0;

  let skipped = 0;

  for (const file of files) {
    const rel = path.relative(SRC, file);

    if (isBuildScript(file)) {
      skipped++;
      console.log('[obfuscate] skip  ', rel, '(build script)');
      continue;
    }

    const out = path.join(DIST, rel);
    ensureDir(path.dirname(out));

    let source;
    try {
      source = fs.readFileSync(file, 'utf8');
    } catch (e) {
      console.error('[obfuscate] read failed:', rel, '-', e.message);
      failed++;
      continue;
    }

    if (isVendorOrMin(rel)) {
      fs.writeFileSync(out, source);
      copied++;
      console.log('[obfuscate] copy  ', rel);
      continue;
    }

    try {
      const result = JavaScriptObfuscator.obfuscate(source, baseOptions);
      fs.writeFileSync(out, result.getObfuscatedCode());
      obfuscated++;
      console.log('[obfuscate] obf   ', rel);
    } catch (e) {
      // Fall back to copying so the build never silently drops a file.
      console.error('[obfuscate] FAILED', rel, '-', e.message, '(copied raw)');
      fs.writeFileSync(out, source);
      failed++;
    }
  }

  console.log(
    `[obfuscate] done. obfuscated=${obfuscated} copied=${copied} skipped=${skipped} failed=${failed} total=${files.length}`
  );

  if (failed > 0) process.exitCode = 2;
}

main();
