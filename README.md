# A4ther Systems — Free Fire Anti-Cheat Scanner

Scanner anti-cheat para Free Fire. Auto-detecta **Android** (Termux) ou **iOS jailbroken** (SSH) e roda os checks específicos da plataforma.

## Como rodar

### 🤖 Android (via Termux)

1. Instala o **Termux** (F-Droid recomendado — o do Play Store está abandonado)
2. Abre o Termux e cola o one-liner:

```bash
pkg update -y && pkg install -y curl && rm -f a4ther.sh && curl -L -o a4ther.sh https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh && chmod +x a4ther.sh && sh a4ther.sh
```

Ou passo a passo:

```bash
pkg install -y curl
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

### 🚫 iOS sem jailbreak

**Não suportado** pelo a4ther.sh — iOS regular não permite executar shell scripts arbitrários. Alternativas que **existem** na comunidade FF:

- **KellerSS-iOS** ou **PantherSS-iOS** — scripts `.js` que rodam no app **Scriptable** (gratuito na App Store) e analisam o **App Privacy Report** exportado pelo iOS
- Workflow alternativo: player exporta `App Privacy Report` (Settings → Privacy → App Privacy Report) e envia o `.ndjson` pro admin analisar

Não trabalhamos esses cenários aqui — usa as ferramentas existentes da comunidade.

### 🧪 Modo de teste (forçar plataforma)

Pra testar a lógica iOS no seu Mac/Linux antes de rodar no iPhone real:

```bash
FORCE_PLATFORM=ios sh a4ther.sh
```

Forca o script a rodar o branch iOS independente do `uname`. Útil pra validar sintaxe e ver formato da saída. No Mac vai marcar como "device jailbroken" (porque o Mac tem `/usr/sbin/sshd` etc.) — comportamento esperado.

Também funciona com `FORCE_PLATFORM=android` (rodando bash com sudo + paths fake).

### Saída

Console colorido com banner FIGlet, section headers e dots coloridos. Relatório em texto puro salvo em `~/FFScanner_reports/scan_AAAAMMDD_HHMMSS.txt`. Exit code:
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

## Síntese de fontes

Detecções consolidadas a partir de 6 scanners open-source + 18 forks/variantes:
- `kellerzz/KellerSS-Android` (binário Go)
- `CardozoServer/OlhosDoCapeta-Android` (binário Go)
- `Streakxit/TiziXit-AntiCheat` (bash 2364 linhas)
- `thxrlk00/Scanner` (PHP 2198 linhas)
- `thzzSS/scanner-brevent` (bash)
- `zacksevenSS/ZackSS` (bash)
- `kellerzz/KellerSS-iOS`, `ynwkxshii/PantherSS-IOS` (JS Scriptable)
- `susuzadas-a11y/Pinguim` (bash)

## Saída

- Console colorido (ANSI) com banner FIGlet + section headers + dots coloridos
- Relatório em texto puro salvo em `~/FFScanner_reports/scan_AAAAMMDD_HHMMSS.txt`
- Exit code: `0` = LIMPO, `1` = REVISAR, `2` = SUSPEITO

## Limitações honestas

- Cheats em **kernel** (KernelSU + Shamiko + susfs bem configurado) podem ficar invisíveis
- Cheats por **hardware externo** (mouse/teclado convertor, máquina espelhando tela) não detectáveis via shell
- iOS sem jailbreak não roda bash — precisa de scanner JavaScript no Safari (fora do escopo)
- Sem root, alguns checks (logcat, /data/tombstones, /proc/kallsyms) ficam limitados

---

A4ther Systems v3.4.0 | LS Aluguel
