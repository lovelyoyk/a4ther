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
- **iOS sem jailbreak (web/Scriptable)** — `a4ther-ios.js`, **motor PRÓPRIO em JavaScript**
  (não compartilha código com o `a4ther.sh`): analisa Sysdiagnose / App Privacy Report
  (`.ndjson`) dentro do app Scriptable. É o ÚNICO alvo com lógica separada.
- **Web PWA** — `index.html` (+ `service-worker.js`, `manifest.webmanifest`, ícones): a
  interface web/instalável onde o usuário sobe o `.txt` do scan ou roda o fluxo iOS-web.
- **Backend** — `backend/` (PHP) e `backend-workers/`: blacklist, ingestão de scan-report
  e telemetria do ecossistema (consumido pelo APK e pelo site).

> **Fonte única das seções shell:** o `a4ther.sh` é o engine ÚNICO de todos os alvos que
> rodam shell — Termux, APK (via ADB) e iOS-SSH. NÃO duplique detecção shell em outro lugar.
> O `a4ther-ios.js` (iOS-web) é a exceção: motor próprio, mantido em paralelo.

## Arquivos principais

- **`a4ther.sh`** (~5800 linhas) — o engine. Android (36 seções) + iOS-SSH (9 seções),
  auto-detecção por `uname`/paths. Cabeçalho declara `VERSION` e o banner.
- **`a4ther-adb.sh`** — **driver/coletor ADB Wi-Fi** (Termux). NÃO tem detecção própria:
  baixa o `a4ther.sh` do raw do GitHub, faz `adb push` pro device, roda como uid 2000
  (`A4_VERBOSE=1 … sh a4ther.sh`), captura a saída e monta UM `.txt` único de upload +
  um RESUMO na tela parseando as linhas `●  ALERTA`/`●  AVISO`. Paridade de detecção é
  AUTOMÁTICA (ele executa o mesmo `a4ther.sh`) — ao adicionar detecção, basta manter os
  **5 literais de versão** dele em dia (banner/UI/relatório).
- **`a4ther-ios.js`** (+ `a4ther-wasm-loader.js`, `a4ther-ios.wasm`) — motor iOS-web.
- **`index.html`** / `service-worker.js` / `manifest.webmanifest` / ícones — PWA web.
- **`a4ther.sh.enc`** / **`a4ther-adb.sh.enc`** — versões CRIPTOGRAFADAS (ver "Cripto").
  Re-gerar SEMPRE que o `.sh` correspondente mudar.
- **`backend/`** (PHP) e **`backend-workers/`** — endpoints do ecossistema.
- Docs: `README.md` (uso por plataforma + lista de seções), `DEPLOYMENT_GUIDE.md` (fluxo
  COMPATÍVEL=plaintext × PROTEGIDO=`.enc`), `SECURITY.md`/`SECURE_DEPLOYMENT.md`,
  `BUILD_MANIFEST.json`/`security-manifest.json`.

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

## Backend (`backend/`)

Endpoints PHP do ecossistema (blacklist por serial/HWID, ingestão do scan-report do APK,
telemetria). É consumido pelo APK (repo separado) e pelo site. Confirmar o **roteamento real
do host** (`.htaccess`) antes de fixar URLs nos clientes.

## APK (repo SEPARADO — não está aqui)

O `ssonato/a4ther-scanner-apk` (Kotlin/Compose, package `com.a4ther.scanner`) é um projeto
à parte. Ele NÃO reimplementa detecção: pareia via ADB Wi-Fi (loopback SPAKE2), roda o
`a4ther.sh` como uid 2000 e sobe um JSON pro painel. **Não edite o APK a partir deste repo**
— a única dependência é o **contrato** acima (formato `●  ALERTA`/`●  AVISO`, `$FF_PID`,
banner de veredito) e o `ENGINE_URL` que serve o `a4ther.sh` deste repo.

## Convenções

- pt-BR em comentários/logs/mensagens.
- `a4ther.sh` = fonte única das seções shell; `a4ther-ios.js` = motor iOS-web próprio.
- Verificações obrigatórias após editar um `.sh`: `sh -n` sem erro; line endings **LF**
  (`tr -cd '\r' < arq | wc -c` = 0); UTF-8 preservado; re-gerar o `.enc` + provar round-trip.
- NUNCA `… | sh` de payload decifrado durante validação local — leia o plaintext direto.
