# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este projeto

A4ther Systems — **scanner anti-cheat para Free Fire (Garena)**, multiplataforma. NÃO é
o APK Android: este é o repo do **engine + web + backend** (`lovelyoyk/a4ther`). O APK
nativo é um repo **SEPARADO** (`ssonato/a4ther-scanner-apk`) que apenas **dirige o
`a4ther.sh` via ADB Wi-Fi** — ver a seção "APK (repo separado)" no fim.

Versão atual: **4.4.95** (fonte da verdade = `const VERSION` no `index.html`, lido pelo
`build.sh`; o `a4ther.sh` carrega seu próprio `VERSION="4.4.95"`).

Alvos suportados (todos rodam a MESMA lógica de detecção, exceto o iOS-web):

- **Android (Termux)** — `a4ther.sh` rodado no Termux; one-liner `curl … | sh`. Privilégio
  típico = usuário comum; quando dirigido pelo APK/ADB roda como **uid 2000 (shell)**, que
  destrava serial/HWID/dumpsys e leitura de `/proc/<outro-pid>` (grupo `readproc`), sem root.
- **iOS jailbroken (SSH)** — o MESMO `a4ther.sh` por SSH num device JB (palera1n/Dopamine/
  unc0ver/checkra1n). Ele auto-detecta `Darwin` + paths de JB e roda as ~9 seções iOS.
- **iOS sem jailbreak** — **DOIS motores JS próprios** (não compartilham código com o
  `a4ther.sh`), mantidos em paralelo com a MESMA base de detecção:
  - **Scriptable** — `a4ther-ios.js`, rodado dentro do app Scriptable
    (`scriptable:///add?url=…`); usa `FileManager` e analisa Sysdiagnose no próprio device.
  - **Browser/PWA** — engine inline do `index.html` (`handleSysdiagnose`): o usuário sobe a
    pasta/`.tar.gz` do Sysdiagnose e a análise roda 100% no navegador (Passes 1-9,
    ps/taskinfo/swcutil, perfis/CA, blacklist…).
- **Web PWA** — `index.html` (+ `service-worker.js`, `manifest.webmanifest`, ícones) NÃO é só
  UI: é o cliente que (a) dá parse e render no `.txt` do `a4ther.sh` (Android), (b) extrai e
  analisa o `bugreport.zip` Android no navegador, (c) roda o engine iOS-web acima e (d)
  consulta a blacklist + monta veredito/Device Card.
- **Backend** — `backend/` (PHP) e `backend-workers/`: blacklist, ingestão de scan-report
  e telemetria do ecossistema (consumido pelo APK e pelo site).

> **Fonte única das seções shell:** o `a4ther.sh` é o engine ÚNICO de todos os alvos que
> rodam shell — Termux, APK (via ADB) e iOS-SSH. NÃO duplique detecção shell em outro lugar.
> **iOS-web é a exceção**: dois motores JS próprios (`a4ther-ios.js` Scriptable + engine inline
> do `index.html`), mantidos em paralelo e sincronizados pela `DETECTION DATA` (topo do
> `index.html`, marcada "sincronizado com a4ther-ios.js"). Editou regra/lista iOS? Toque OS DOIS.

## Arquivos principais

- **`a4ther.sh`** (~5800 linhas) — o engine. Android (36 seções) + iOS-SSH (9 seções),
  auto-detecção por `uname`/paths. Cabeçalho declara `VERSION` e o banner.
- **`a4ther-adb.sh`** — **driver/coletor ADB Wi-Fi** (Termux). NÃO tem detecção própria:
  baixa o `a4ther.sh` do raw do GitHub, faz `adb push` pro device, roda como uid 2000
  (`A4_VERBOSE=1 … sh a4ther.sh`), captura a saída e monta UM `.txt` único de upload +
  um RESUMO na tela parseando as linhas `●  ALERTA`/`●  AVISO`. Paridade de detecção é
  AUTOMÁTICA (ele executa o mesmo `a4ther.sh`) — ao adicionar detecção, basta manter os
  **5 literais de versão** dele em dia (banner/UI/relatório).
- **`a4ther-ios.js`** (+ `a4ther-wasm-loader.js`, `a4ther-ios.wasm`) — motor iOS-web da versão
  **Scriptable**. Bundle minificado gigante (~225k tokens): edite por busca, não leia inteiro.
- **`index.html`** (~6400 linhas) — o cliente web INTEIRO: parser do `.txt` do `a4ther.sh`,
  extrator de `bugreport.zip`, engine iOS-web in-browser (`handleSysdiagnose`), consulta de
  blacklist e Device Card. `const VERSION` aqui é a FONTE DA VERDADE de versão.
- **`service-worker.js`** — PWA: cacheia app-shell + CDN (jsdelivr lenis/pako); dá **bypass** em
  `/api/` e em `lspainel.com.br` (API/blacklist NUNCA são cacheadas). OFUSCADO no repo,
  `CACHE_VERSION` embutido. `manifest.webmanifest`/ícones completam o PWA.
- **`a4ther.sh.enc`** / **`a4ther-adb.sh.enc`** — versões CRIPTOGRAFADAS (ver "Cripto").
  Re-gerar SEMPRE que o `.sh` correspondente mudar.
- **`backend/`** (PHP) e **`backend-workers/`** — endpoints do ecossistema.
- Docs: `README.md` (uso por plataforma + lista de seções), `DEPLOYMENT_GUIDE.md` (fluxo
  COMPATÍVEL=plaintext × PROTEGIDO=`.enc`), `SECURITY.md`/`SECURE_DEPLOYMENT.md`,
  `BUILD_MANIFEST.json`/`security-manifest.json`.

## Comandos (rodar / dev / build)

Sem suíte de testes automatizada. Node ≥18 só é necessário p/ build (ofuscação/minificação).

- **Preview local do PWA** (serve a raiz; SW + uploads funcionam): `node .claude/serve.cjs`
  (http://localhost:8765, `Cache-Control: no-store`) — ou `python3 -m http.server 8765`
  (config em `.claude/launch.json`).
- **Zip de deploy WEB (Windows)**: `powershell -ExecutionPolicy Bypass -File .\build-zip.ps1`
  → `..\a4ther-scanner-v<VERSION>.zip` com os 7 arquivos web (index/SW/manifest/ícones); a
  versão sai do `const VERSION` do `index.html`.
- **Build seguro completo**: `sh ./build.sh` (= `npm run build`). ⚠️ O passo de guard chama
  `node security/inject.js`, que **não está versionado neste repo** — p/ build local passe
  `FF_SKIP_GUARD=1` (e `FF_SKIP_ENCRYPT=1` sem a passphrase). Avulsos: `npm run obfuscate`,
  `npm run clean`.
- **Decifrar `.enc`**: `FF_PASSPHRASE=… sh decrypt.sh a4ther.sh.enc > a4ther.sh`.
- **Validar `.sh`**: `sh -n a4ther.sh` + checagem LF/UTF-8 (ver Convenções).

## Build (`build.sh`) — pipeline seguro

`sh ./build.sh` (POSIX puro, `/bin/sh`, sem bashisms). Lê a versão de `const VERSION` no
`index.html`. Saída em `dist/`. Passos:

1. **Ofusca** todo `.js` → `node obfuscate.js`.
2. **Criptografa** cada `.sh` de topo → `dist/<nome>.sh.enc` (AES-256-CBC; ver abaixo).
   Pula o próprio `build.sh`. Emite também um `dist/decrypt.sh` helper.
3. **Minifica** HTML → `html-minifier-terser`.
4. **Copia** assets estáticos (`manifest.webmanifest`, ícones, `icon.svg`, …).
5. **Injeta** o guard anti-tampering nos artefatos finais → `node security/inject.js`
   (assina por código as funções de `FF_GUARD_SIGN`). `FF_SKIP_GUARD=1` pula.
6. **Empacota** `a4ther-scanner-v<VERSION>.(zip|tar.gz)`.

Env úteis: `FF_PASSPHRASE` (senão lê de `FF_PASSPHRASE_FILE`, senão gera randômica e
imprime no fim), `FF_SKIP_ENCRYPT=1`, `FF_LEVEL`, `FF_GUARD_LEVEL`, `FF_GUARD_SIGN`.
`package.json`: `npm run build` chama o `build.sh`; deps de build = `javascript-obfuscator`
+ `html-minifier-terser` (Node ≥18). Não há suíte de testes automatizada.

## Cripto dos `.sh` (re-gerar no fim de toda edição)

Esquema (idêntico ao `build.sh` e ao `decrypt.sh`):
`openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64`, com `-pass pass:"<PASSPHRASE>"`.
A passphrase de produção **nunca** é commitada (vem de `.env.local`/secrets). Recuperar:
`FF_PASSPHRASE=… sh decrypt.sh a4ther.sh.enc > a4ther.sh`.

Ao editar `a4ther.sh` e/ou `a4ther-adb.sh`, **re-gere o `.enc` correspondente** e **prove o
round-trip** (decifrar | `cmp` com o plaintext → byte-idêntico). DEPLOYMENT_GUIDE descreve
os dois fluxos: COMPATÍVEL (serve o `.sh` legível por raw URL) × PROTEGIDO (serve o `.enc`).

## Bump de versão — toque TODOS estes pontos

Fonte da verdade: `const VERSION` no `index.html`. Os demais são literais SOLTOS (não derivados):
- `a4ther.sh`: `VERSION="…"` (linha 16) + banner (linha 3) — re-cifre o `.enc`.
- `a4ther-adb.sh`: **5 literais** (banner/UI/relatório) — re-cifre o `.enc`.
- `service-worker.js`: `CACHE_VERSION` (OFUSCADO; sem bump, o visitante fica preso no cache antigo).
- `package.json` `version`, `BUILD_MANIFEST.json`, e strings `vX.Y.Z` no `index.html`
  (ex.: "A4ther bugreport parser vX.Y.Z").

⚠️ Confira drift: já houve `package.json` e `service-worker.js` ATRÁS do `index.html`.

## Idiomas de detecção do `a4ther.sh` (o contrato com o ecossistema)

- **Helpers de saída** (`alert`/`warn`/`ok`/`info`/`header`): use SEMPRE, nunca `echo -e
  "\e[..."` cru. O parser do ecossistema (site + `a4ther-adb.sh` + APK) SÓ conta linhas no
  formato exato **`●  ALERTA  <msg>`** (crítico, via `alert`) e **`●  AVISO   <msg>`**
  (suspeito, via `warn`). Forma com colchete `[ALERTA]` **NÃO** conta. `ok`/`info` são
  informativos e não pesam no veredito.
- **Contadores**: globais `ALERTS`/`WARNINGS`/`CLEAN` (incrementados pelos helpers) decidem
  o veredito; os `*_HITS` por módulo (`KERNEL_HITS`, `DFIR_HITS`, `REMOTE_HITS`, …) são
  tallies LOCAIS, usados só pra imprimir a linha "sem indícios" de cada seção. Escolha o
  `*_HITS` do módulo onde a detecção mora.
- **Veredito / RESUMO** (seção final): `ALERTS>0` → banner **`S U S P E I T O`** (exit 2);
  senão `WARNINGS>0` → **`R E V I S A R`** (exit 1); senão **`L I M P O`** (exit 0). Banner
  ausente = scan truncado (o ecossistema então NÃO trata como "limpo"). A contagem real sai
  de acumuladores em arquivo (`$A4_CRIT_FILE`/`$A4_WARN_FILE`) porque `… | while` roda em
  subshell e perderia os contadores.
- **`$FF_PID`**: PID do Free Fire via `pidof com.dts.freefireth` (fallback `…freefiremax`).
  Sob uid 2000 + grupo `readproc` dá pra ler `/proc/$FF_PID/{status,maps,mountinfo,task,…}`
  de OUTRO processo SEM root (ex.: TracerPid, libs injetadas, magic-mount de namespace).
  Se `$FF_PID` vazio → `warn` pedindo abrir o FF; NUNCA dê "limpo" por não ter inspecionado.
- **Degradação honesta**: sem rede/sem permissão/leitura barrada → `warn`/`info`
  ("inconclusivo"), **nunca** um falso `ok`. Root (`su`) só como FALLBACK e checado com
  `have su` — nunca assuma que existe.
- **tmpdir Android**: `/data/local/tmp` (NUNCA `/tmp`); prefira variáveis/pipes a arquivos
  temporários soltos. Comentários, logs e mensagens em **pt-BR**.
- **Versão**: `VERSION=` + banner (linha 3). Marque comentários de features novas com a
  versão atual (`v4.4.95`); NÃO bumpe os `# v4.4.xx:` históricos (descrevem versões passadas).

## Backend & rede do cliente web

- **Deploy do PWA**: GitHub Pages, `https://lovelyoyk.github.io/a4ther/` (sem `CNAME`; `scope`
  relativo). Origin importa por CORS — servir de `file://` ou domínio fora da allowlist quebra
  blacklist/telemetria (vira `Failed to fetch`/`AbortError` no cliente).
- **O cliente web fala com `lspainel.com.br`**, não com o `backend/` deste repo direto. Em
  `index.html` (`BLACKLIST_CONFIG`, timeout 6 s/lookup): `API_BASE =
  https://lspainel.com.br/api/a4ther` (submit/intel/scan-log) e a **blacklist** em
  `https://lspainel.com.br/api/public/a4ther-blacklist-check` (Supabase `blacklist_serials`).
- **DOIS backends de blacklist**: o do painel acima (Supabase) **≠** o PHP deste repo
  (`backend/api/a4ther/blacklist/check.php`, MySQL `blacklist`). CORS do PHP em
  `backend/_config.php` (`ALLOWED_ORIGINS`: github.io, lspainel.com.br, localhost). `backend-workers/`
  = Cloudflare Worker. Confirme o roteamento real do host (`.htaccess`) antes de fixar URLs.

## APK (repo SEPARADO — não está aqui)

O `ssonato/a4ther-scanner-apk` (Kotlin/Compose, package `com.a4ther.scanner`) é um projeto
à parte. Ele NÃO reimplementa detecção: pareia via ADB Wi-Fi (loopback SPAKE2), roda o
`a4ther.sh` como uid 2000 e sobe um JSON pro painel. **Não edite o APK a partir deste repo**
— a única dependência é o **contrato** acima (formato `●  ALERTA`/`●  AVISO`, `$FF_PID`,
banner de veredito) e o `ENGINE_URL` que serve o `a4ther.sh` deste repo.

## Convenções

- pt-BR em comentários/logs/mensagens.
- `a4ther.sh` = fonte única das seções shell; iOS-web = dois motores JS (`a4ther-ios.js`
  Scriptable + engine inline do `index.html`), sincronizados pela `DETECTION DATA`.
- Verificações obrigatórias após editar um `.sh`: `sh -n` sem erro; line endings **LF**
  (`tr -cd '\r' < arq | wc -c` = 0); UTF-8 preservado; re-gerar o `.enc` + provar round-trip.
- NUNCA `… | sh` de payload decifrado durante validação local — leia o plaintext direto.
