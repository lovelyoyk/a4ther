'use strict';
/**
 * guard.viewport-test.js — regressao da classe de FALSO-POSITIVO geometrico do
 * guard anti-tamper (security/guard.js) que hard-lockava usuarios reais no
 * Safari iOS.
 *
 * POR QUE ISTO EXISTE: o `inject.js --self-test` testa a janela do browser com
 * `outerWidth===innerWidth` (gap ZERO) — estruturalmente incapaz de pegar o FP
 * do `devtoolsOpen()` (`outer-inner > 160px`), que dispara pela barra do Safari
 * mobile (+ notch) e ai executa o trip() destrutivo (apaga documento + loop
 * infinito). Este teste simula um viewport MOBILE real (coarse pointer + gap
 * grande) e afirma que a pagina NAO e' brickada.
 *
 * RODAR: node security/guard.viewport-test.js   (exit 0 = tudo verde)
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const GUARD = fs.readFileSync(path.join(__dirname, 'guard.js'), 'utf8');

function makeEnv(opts) {
  const doc = {
    documentElement: { innerHTML: '<app-intact>' },
    hidden: false,
    addEventListener: function () {},
  };
  const warned = [];
  const win = {
    outerWidth: opts.outerW, innerWidth: opts.innerW,
    outerHeight: opts.outerH, innerHeight: opts.innerH,
    matchMedia: function (q) { return { matches: /coarse/.test(q) ? !!opts.coarse : false }; },
    setTimeout: function (fn, ms) { return setTimeout(fn, ms); },
    setInterval: function () { return 0; },   // stub: sem watchdog persistente
    addEventListener: function () {},
  };
  win.window = win;                            // invariante window===window.window
  if (opts.touch) win.ontouchstart = null;     // 'ontouchstart' in window
  const sandbox = {
    window: win, document: doc,
    navigator: { maxTouchPoints: opts.touch ? 5 : 0 },
    console: { warn: function (m) { warned.push(String(m)); }, log: function () {} },
    localStorage: { removeItem: function () {}, getItem: function () { return null; }, setItem: function () {} },
    setTimeout: win.setTimeout, setInterval: win.setInterval, clearTimeout: clearTimeout,
    Date: Date, Math: Math, Object: Object, Function: Function, Array: Array, RegExp: RegExp,
  };
  return { sandbox, doc, warned: function () { return warned; } };
}

function run(name, opts, assert) {
  const env = makeEnv(opts);
  const tripped = [];
  vm.createContext(env.sandbox);
  vm.runInContext(GUARD + '\nthis.__A4G__ = __A4G__;', env.sandbox);
  // hook em Function.prototype.toString DENTRO do sandbox = tamper real (detectHooks).
  if (opts.hookToString) {
    vm.runInContext('Function.prototype.toString = function(){ return "hooked"; };', env.sandbox);
  }
  // onTamper capturador: evita o for(;;) do hard-lock default no teste, mas PROVA
  // que o caminho destrutivo foi ACIONADO (o guard chama cfg.onTamper e retorna).
  const cfg = { profile: 'web', sigs: {} };
  if (opts.captureTrip) cfg.onTamper = function (r) { tripped.push(String(r)); };
  env.sandbox.__A4G__(cfg);
  return new Promise(function (resolve) {
    setTimeout(function () {
      const bricked = env.doc.documentElement.innerHTML.indexOf('Integridade comprometida') !== -1;
      const ok = assert({ bricked: bricked, warned: env.warned(), tripped: tripped });
      console.log((ok ? 'PASS' : 'FAIL') + ' — ' + name +
        '  [bricked=' + bricked + ', trip=' + JSON.stringify(tripped) + ', soft=' + JSON.stringify(env.warned()) + ']');
      resolve(ok);
    }, 220);   // > 120ms do debounce do devtools
  });
}

(async function () {
  const r = [];
  // 1) iPhone real: coarse pointer + gap enorme (outer-inner=400) = o FP exato.
  r.push(await run('iOS mobile (coarse + gap 400) => NAO brica',
    { touch: true, coarse: true, outerW: 390, innerW: 390, outerH: 844, innerH: 444 },
    function (s) { return s.bricked === false; }));
  // 2) Desktop com devtools docado (gap 400, sem touch): agora SOFT — loga, nao brica.
  r.push(await run('desktop devtools (gap 400) => SOFT nota, NAO brica',
    { touch: false, coarse: false, outerW: 1920, innerW: 1920, outerH: 1080, innerH: 680 },
    function (s) { return s.bricked === false && s.warned.some(function (w) { return /devtools/.test(w); }); }));
  // 3) Desktop normal (gap 0): nada dispara.
  r.push(await run('desktop normal (gap 0) => nada',
    { touch: false, coarse: false, outerW: 1280, innerW: 1280, outerH: 800, innerH: 800 },
    function (s) { return s.bricked === false && s.warned.length === 0; }));
  // 4) TAMPER REAL (toString hookado) => AINDA aciona o trip destrutivo (prova que
  //    o fix nao gutou a seguranca; so as heuristicas soft viraram nao-destrutivas).
  r.push(await run('tamper real (hook toString) => AINDA trip (hard)',
    { touch: false, coarse: false, outerW: 1280, innerW: 1280, outerH: 800, innerH: 800, hookToString: true, captureTrip: true },
    function (s) { return s.tripped.indexOf('hook-tostring') !== -1; }));

  const pass = r.filter(Boolean).length;
  console.log('\n' + pass + '/' + r.length + ' verdes.');
  process.exit(pass === r.length ? 0 : 1);
})();
