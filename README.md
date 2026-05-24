# A4ther Systems — Free Fire Anti-Cheat Scanner

Scanner anti-cheat para Free Fire. Auto-detecta **Android** (Termux) ou **iOS jailbroken** (SSH) e roda os checks específicos da plataforma.

## Como rodar

### 🤖 Android (via Termux)

1. Instala o **Termux** (F-Droid recomendado — o do Play Store está abandonado)
2. Abre o Termux e cola o one-liner:

```bash
pkg upgrade -y && pkg install -y curl && rm -f a4ther.sh && curl -L -o a4ther.sh https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh && chmod +x a4ther.sh && sh a4ther.sh
```

> ⚠️ Importante: `pkg upgrade -y` no início garante que o Termux esteja atualizado. Sem isso, o `curl` pode dar erro **"cannot locate symbol ngtcp2_crypto_get_path_challenge_data_cb"** (dependência quebrada por updates parciais).

Ou passo a passo:

```bash
pkg upgrade -y && pkg install -y curl
curl -L -o a4ther.sh https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh
chmod +x a4ther.sh
sh a4ther.sh
```

### 🍎 iOS jailbroken (via SSH)

Funciona em devices com **palera1n / Dopamine / Unc0ver / Taurine / Checkra1n**. Player precisa:

1. **No iPhone:** instalar **OpenSSH** pelo Sileo / Cydia / Zebra
2. **No iPhone:** conferir IP local em Settings → Wi-Fi → (i) ao lado da rede
3. **Conectar iPhone e PC/admin no mesmo Wi-Fi**

No PC do admin (Linux/Mac/Termux):

```bash
# Conecta no iPhone (senha padrão de JB antigo: alpine — peça pro player a dele)
ssh root@IP_DO_IPHONE

# Dentro do iPhone via SSH:
curl -L -o /tmp/a4ther.sh https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh
chmod +x /tmp/a4ther.sh
sh /tmp/a4ther.sh
```

O script auto-detecta `Darwin` + paths de JB (`/var/jb`, `/Applications/Cydia.app`, etc.) e roda as **9 seções iOS**: jailbreak detection, Configuration Profiles, Substrate/tweaks, Frida iOS, sideload (TrollStore/AltStore/iGameGod), Free Fire bundle ID + App Store signature, processos suspeitos, HWID via `ioreg`.

### 🍏 iOS sem jailbreak (via Scriptable) — 3 modos

Para iPhone normal (sem JB), use o **`a4ther-ios.js`** — script JavaScript que roda no app **Scriptable** (gratuito na App Store).

**Setup uma vez:**

1. App Store → instala **Scriptable**
2. Safari → cole: `scriptable:///add?url=https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther-ios.js`
3. Scriptable abre, confirma importar

**Roda o script, escolhe o modo:**

#### 🆕 Modo 1 — Sysdiagnose (RECOMENDADO, mais completo)

Analisa o diagnóstico completo do sistema iOS — apps, profiles, network, install history, processos e crashes:

```
1. iPhone: aperta Vol+ + Vol- + Side simultaneamente por 1 seg
   (sente vibrar de leve confirmando)
2. Aguarda ~5min (continua usando o iPhone normalmente)
3. Settings → Privacy & Security → Analytics & Improvements
   → Analytics Data → procura "sysdiagnose_AAAAMMDD_HHMMSS_*.tar.gz"
4. Toca → Share → "Save to Files"
5. No Files app: toca no .tar.gz → iOS extrai NATIVAMENTE (vira pasta)
6. Volta no Scriptable → Run a4ther-ios → "Sysdiagnose"
7. Folder picker → seleciona a pasta extraída
8. Aguarda análise (~10-30 seg)
```

O sysdiagnose analyzer faz:
- **summaries/Applications.txt** → lista todos bundle IDs instalados → cruza com 105 cheat apps catalogados
- **Managed_Configuration_Profiles/** → analisa TODOS os profiles instalados (VPN, Proxy, CA Root, DNS, MDM, Restrictions, Screen Time)
- **mobile_installation_logs/** → install/uninstall history de FF e cheats
- **summaries/network_state.txt** → VPN ativa (utun/ppp/ipsec), HTTPProxy, HTTPSProxy, DNS, KNOWN_CHEAT_INFRA matches
- **taskinfo.txt / ps.txt** → processos rodando (Frida, Cycript, gdb, Substrate, TrollStore, iSH, Cydia)
- **crashes_and_spins/** → crashes do FF/cheat + conteúdo com strings de injeção (DYLD_INSERT, libsubstrate)

#### Modo 2 — Privacy Report (.ndjson)

**Setup legado (uma vez só):**

1. **Instala o Scriptable** na App Store → https://apps.apple.com/app/scriptable/id1405459188
2. **Liga o App Privacy Report** no iPhone:
   `Settings` → `Privacy & Security` → `App Privacy Report` → **toggle ON**
3. **Joga Free Fire** por alguns minutos pra popular o log (ou usa o aparelho normalmente — o report captura TUDO que apps acessam)

**Cada scan:**

4. Em `Settings` → `Privacy & Security` → `App Privacy Report`, toca em **"Save App Privacy Report"** → escolhe onde salvar (Files / iCloud Drive)
5. Abre o **Scriptable**, toca no `+` (canto superior direito) pra criar novo script
6. Cola o código de [a4ther-ios.js](a4ther-ios.js) (ou importa via URL — ver abaixo)
7. Roda o script (botão ▶ no canto inferior direito)
8. Quando pedir, **seleciona o arquivo `.ndjson`** salvo no passo 4
9. Vê o resultado na tela do Scriptable

**Atalho — importar direto via URL no Scriptable:**

```
scriptable:///add?url=https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther-ios.js
```

Cole isso no Safari do iPhone — o Scriptable abre automaticamente e oferece importar.

**O que o JS detecta:**

- 9 bundle IDs de cheat FF confirmados (`com.34306.espff`, `com.dts.freefireth.externalesp`, `com.quyhoang.fxy`, `com.phuc.aimlock`, etc.)
- 26 bundles de jailbreak / sideloader (Dopamine, TrollStore, Sileo, AltStore, iSH, Filza, iFunBox)
- 25 bundles de proxy / VPN (Potatso, Shadowrocket, NordVPN, ProtonVPN, Quantumult, etc.)
- 9 domínios de cheat hardcoded
- 18 TLDs suspeitos (`.netlify.app`, `.workers.dev`, `.xyz`, `.gq`, etc.)
- 42 keywords pra heurística por padrão de nome
- FF conectando em domínios fora dos servidores oficiais Garena
- Bundles com "freefire" no nome que não são os 6 oficiais (re-sign)
- Opção de salvar relatório TXT em `iCloud Drive/Scriptable/a4ther_scan_*.txt`

**Limitações JS vs bash:**

- ✅ Detecta cheat **apps instalados** que tiveram network activity (visível no Privacy Report)
- ✅ Detecta **proxy/VPN ativos** (capturados pelo Privacy Report)
- ✅ Detecta **domínios suspeitos** acessados
- ❌ NÃO detecta tweaks de Substrate (precisa JB)
- ❌ NÃO detecta Frida (precisa JB)
- ❌ NÃO lê filesystem (sandbox)
- ❌ NÃO inspeciona apps que não tiveram atividade durante o período do log

### 🧪 Modo de teste (forçar plataforma)

Pra testar a lógica iOS no seu Mac/Linux antes de rodar no iPhone real:

```bash
FORCE_PLATFORM=ios sh a4ther.sh
```

Forca o script a rodar o branch iOS independente do `uname`. Útil pra validar sintaxe e ver formato da saída. No Mac vai marcar como "device jailbroken" (porque o Mac tem `/usr/sbin/sshd` etc.) — comportamento esperado.

Também funciona com `FORCE_PLATFORM=android` (rodando bash com sudo + paths fake).

### Saída

Console colorido com banner FIGlet, section headers e dots coloridos. Relatório em texto puro salvo em `~/a4ther_reports/scan_AAAAMMDD_HHMMSS.txt`. Exit code:
- `0` = LIMPO (verde)
- `1` = REVISAR (amarelo) — avisos a checar manualmente
- `2` = SUSPEITO (vermelho) — alertas críticos detectados

## O que detecta

**Android (36 seções):**
- Boot / kernel / SELinux / suSFS (Magisk Hide moderno)
- Root / Magisk / KernelSU / APatch + módulos suspeitos
- Frameworks de hook (Frida, Xposed, LSPosed, LSPatch, Substrate)
- Privilege escalation sem-root (Shizuku, Brevent, Hunter)
- Integrity bypass (PlayIntegrityFix, TrickyStore, nativecheck, duckdetector)
- Free Fire — verificação Play Store (`com.android.vending`) obrigatória
- Histórico install/uninstall via `batterystats` `pkgunin=`
- OBB **escondida** fora de `/sdcard/Android/obb/` (vetor MIUI/sound_recorder/fm_rec)
- Shaders UnityFS signature check (wallhack visual)
- Replays MReplays com análise temporal (Access > Modify, JSON vs BIN, etc.)
- ~80 packages de cheat catalogados + heurística por padrão de nome
- Memory editors (GameGuardian real: `catch_.me_.if_.you_.can_`)
- Macros / autoclicker / keymappers (Tasker, MacroDroid, Mantis, Gamesir, etc.)
- File managers + histórico de uso (quando ZArchiver, MyFiles etc. foram abertos)
- Spoofers GPS/DeviceID/IMEI
- VPNs e apps de bypass de rede
- Proxy / sniffer / MITM + CAs do usuário
- DNS / Private DNS custom
- ESP / overlay / accessibility services
- `/data` e `/sdcard` deep scan + arquivos ocultos + symlinks
- Arquivos apagados (`.trashed-*` Android 11+ + lixeiras de FM)
- **Proxy cheats** — `/proc/<ff_pid>/net/tcp` para detectar FF conectando em localhost ou IPs de cheat conhecidos (Fatality, Polar Bear, etc.)
- Cheat infra (domínios hardcoded + TLDs free-hosting suspeitos)
- Device admins / VPN profiles / Wi-Fi proxy por SSID
- Persistent logs (`/data/anr`, `/data/tombstones`, `/data/system/dropbox`, kernel ramoops)
- Termux typosquat (alias git hijack)

**iOS (9 seções):**
- Info do sistema via `SystemVersion.plist`
- Jailbreak (Cydia, Sileo, Zebra, TrollStore, rootless palera1n/Dopamine)
- **Configuration Profiles** (`.mobileconfig`) com VPN/Proxy/CA root/Web filter
- Substrate / tweak frameworks (rootful + rootless)
- Frida / debuggers iOS
- Sideload (AltStore, Scarlet, iGameGod, GameGem)
- Free Fire iOS — verificação App Store via `embedded.mobileprovision`
- Processos e HWID via `ioreg`

## Sobre

A4ther Systems - Free Fire Anti-Cheat Scanner
Desenvolvido por LS Aluguel.


## Saída

- Console colorido (ANSI) com banner FIGlet + section headers + dots coloridos
- Relatório em texto puro salvo em `~/a4ther_reports/scan_AAAAMMDD_HHMMSS.txt`
- Exit code: `0` = LIMPO, `1` = REVISAR, `2` = SUSPEITO

## Limitações honestas

- Cheats em **kernel** (KernelSU + Shamiko + susfs bem configurado) podem ficar invisíveis
- Cheats por **hardware externo** (mouse/teclado convertor, máquina espelhando tela) não detectáveis via shell
- iOS sem jailbreak não roda bash — precisa de scanner JavaScript no Safari (fora do escopo)
- Sem root, alguns checks (logcat, /data/tombstones, /proc/kallsyms) ficam limitados

---

A4ther Systems v3.3.0 | LS Aluguel
