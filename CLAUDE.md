# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este projeto

A4ther Systems — **scanner anti-cheat para Free Fire (Garena)**, multiplataforma. NÃO é
o APK Android: este é o repo do **engine + web + backend** (`lovelyoyk/a4ther`). O APK
nativo é um repo **SEPARADO e privado** que é um **COLETOR HÍBRIDO**: coleta o
grosso em Kotlin nativo (pacote `collector/`) e roda o `a4ther.sh` via ADB Wi-Fi só nas seções
deep/forenses (fase 2) — ver a seção "APK (repo separado)" no fim.

Versão atual: **4.4.99** (fonte da verdade = `const VERSION` no `index.html`, lido pelo
`build.sh`; o `a4ther.sh` carrega seu próprio `VERSION="4.4.99"`. Features recentes marcadas até `# v4.4.100`.

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
- **Backend (split pós-pivô)** — a **a4zll** (`PANEL_BASE`) serve login vendável +
  ingestão de scan-report (autenticado por Bearer); a **lspainel** (`API_BASE`) serve a blacklist;
  o `ENGINE_URL` é o raw `main/a4ther.sh`. Runtimes PHP (`backend/`) + Worker (`backend-workers/`).

> **Fonte única das seções shell:** o `a4ther.sh` é o engine ÚNICO de todos os alvos que
> rodam shell — Termux, APK (via ADB) e iOS-SSH. NÃO duplique detecção shell em outro lugar.
> O `a4ther-ios.js` (iOS-web) é a exceção: motor próprio, mantido em paralelo.

## Deploy — SEMPRE via branch + PR (nunca commit direto no `main`)

O GitHub Pages publica do `main` em produção (`lovelyoyk.github.io/a4ther`) **na hora** —
ou seja, `main` = site AO VIVO. **REGRA: nunca commitar/pushar direto no `main`.**

Fluxo obrigatório para QUALQUER mudança (web, engine ou docs):
1. `git checkout -b fix/...` (ou `feat/...`, `docs/...`) — uma branch separada.
2. Commitar e testar na branch (preview local, `sh -n`, etc.).
3. `gh pr create` — abrir um PR para o `main` (a revisão do diff acontece aí).
4. Só fazer **merge** no `main` depois de revisar/testar. **O merge no `main` É o deploy.**

Motivo: deploy direto, sem essa etapa, já quebrou produção (tela preta / "Page
Unresponsive") sem chance de revisar antes. A branch + PR é o portão de revisão antes do ar.

## Regras de trabalho (como o Claude deve operar neste repo)

Valem para TODA interação, junto com o fluxo de deploy acima:

1. **Teste lógico antes de cada alteração.** Avalie criticamente se a mudança faz sentido de
   ser feita ANTES de fazê-la — nunca altere "no automático". Se algo não fizer sentido,
   contradisser outra parte do sistema, ou não couber no runtime (ex.: sugerir um logger
   Node como Winston/Pino num backend PHP), levante isso e discuta ANTES de aplicar.
2. **Pergunte antes de QUALQUER commit.** Nunca commitar/pushar sem confirmação explícita do
   usuário. Prepare na branch, mostre o diff, explique, e só commite/abra PR após o "pode".
3. **Explique sempre.** Diga o que está fazendo e, para CADA parte alterada, o que ela
   PASSA A FAZER depois da mudança (o comportamento novo) — não só o que mudou.

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
  versão atual (`v4.4.100`); NÃO bumpe os `# v4.4.xx:` históricos (descrevem versões passadas).

## Backend (`backend/`)

Backend **dividido no pivô**: a **a4zll** (`PANEL_BASE`) faz login vendável + ingestão do
scan-report (autenticado por **Bearer**; o bug do Apache comendo o header `Authorization` já foi
corrigido); a **lspainel** (`API_BASE`) faz a blacklist por serial/HWID. É consumido pelo APK (repo
separado) e pelo site. Confirmar o **roteamento real do host** (`.htaccess`) antes de fixar URLs nos clientes.

## APK (repo SEPARADO — não está aqui)

O APK (repo separado e privado; Kotlin/Compose, package `com.a4ther.scanner`) é um projeto
à parte. Ele coleta o grosso em **Kotlin nativo** (pacote `collector/`: SystemCollector/KernelCollector/
StorageCollector/FreeFireCollector/NativeCollector/ScanOrchestrator) e usa o `a4ther.sh` via ADB Wi-Fi
(loopback SPAKE2, uid 2000) só nas **seções deep/forenses (fase 2)**, subindo um JSON pro painel. **Não edite o APK a partir deste repo** — a dependência é o **contrato** da fase-2 shell (formato
`●  ALERTA`/`●  AVISO`, `$FF_PID`, banner de veredito) e o `ENGINE_URL` que serve o `a4ther.sh` deste
repo; o grosso da coleta é **nativo Kotlin** no repo do APK.

## Convenções

- pt-BR em comentários/logs/mensagens.
- `a4ther.sh` = fonte única das seções shell; `a4ther-ios.js` = motor iOS-web próprio.
- Verificações obrigatórias após editar um `.sh`: `sh -n` sem erro; line endings **LF**
  (`tr -cd '\r' < arq | wc -c` = 0); UTF-8 preservado; re-gerar o `.enc` + provar round-trip.
- NUNCA `… | sh` de payload decifrado durante validação local — leia o plaintext direto.
