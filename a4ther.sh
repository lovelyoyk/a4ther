#!/system/bin/sh
# ============================================================
#  A4ther Systems v4.4.98 | LS Aluguel
#  Anti-Cheat Scanner para Free Fire (Android + iOS auto-detect).
#  Verifica:
#   - Plataforma (Android via Termux ou iOS via SSH em device jailbroken)
#   - Free Fire / Free Fire Max instalados via Play Store / App Store oficial
#   - Cheats: root/jailbreak, frida, mods, tweaks, etc.
#
#  Uso no Termux:
#     pkg install -y curl
#     curl -L -o a4ther.sh <URL_RAW>
#     chmod +x a4ther.sh && sh a4ther.sh
# ============================================================

VERSION="4.4.98"

# ── Versões ESPERADAS do Free Fire (ajuste manual a cada nova OB) ──────────────
# v4.4.89 comparava EXATO; v4.4.91 faz match por OB (major.minor via ${VER%.*},
# ignora o patch — a Garena solta hotfix de patch e o exato quebrava a cada release).
# Pode manter o patch aqui (ex. .1): ele é ignorado. Atualize quando a OB (o número
# do meio) virar; o patch não importa mais.
EXPECTED_FF_VER="1.126.3"       # com.dts.freefireth   (versionName real lido do device — confirmado 2026-06-24)
EXPECTED_FFMAX_VER="2.126.3"    # com.dts.freefiremax  (versionName real lido do device — confirmado 2026-06-24)

# ---------- Cores (NÃO usar R G Y B C W N como vars de loop!) ----------
if [ -t 1 ]; then
    CR=$(printf '\033[1;31m'); CG=$(printf '\033[1;32m'); CY=$(printf '\033[1;33m')
    CB=$(printf '\033[1;34m'); CC=$(printf '\033[1;36m'); CW=$(printf '\033[1m')
    CN=$(printf '\033[0m')
else
    CR=''; CG=''; CY=''; CB=''; CC=''; CW=''; CN=''
fi

# ---------- Relatório ----------
# v4.4.68: salva na pasta pública DOWNLOAD (/storage/emulated/0/Download/a4ther_audits)
# pra o .txt aparecer no Gerenciador de Arquivos normal do celular (o cliente pega e
# sobe no site). O $HOME do Termux só é visível dentro do Termux. Só cai pro HOME se
# o storage não estiver acessível (sem termux-setup-storage / sem permissão).
TS=$(date '+%Y%m%d_%H%M%S' 2>/dev/null)
[ -z "$TS" ] && TS="scan"
REPORT=""
REPORT_DIR_TRIED=""
for D in /storage/emulated/0/Download /sdcard/Download "$HOME/storage/shared/Download" /storage/emulated/0 /sdcard "$HOME/storage/shared" "$HOME" /data/local/tmp /tmp .; do
    REPORT_DIR_TRIED="$REPORT_DIR_TRIED $D"
    [ -d "$D" ] || mkdir -p "$D" 2>/dev/null
    [ -d "$D" ] && [ -w "$D" ] || continue
    if mkdir -p "$D/a4ther_audits" 2>/dev/null; then
        REPORT="$D/a4ther_audits/scan_${TS}.txt"
        : > "$REPORT" 2>/dev/null && break
        REPORT=""
    fi
done
[ -z "$REPORT" ] && REPORT="/dev/null"

# v4.4.69 (performance): raiz ÚNICA do armazenamento. /sdcard e /storage/emulated/0
# são a MESMA árvore (symlink), então varrer as duas no `find` duplicava o trabalho
# em todo o cartão. Escolhe uma só — corta pela metade os scans de storage inteiro.
SDCARD=/sdcard; [ -d "$SDCARD" ] || SDCARD=/storage/emulated/0

ALERTS=0
WARNINGS=0
CLEAN=0
# v4.4.95: RC default = 1 (fail-closed). Se o scan truncar/abortar ANTES do RESUMO
# (que seta RC=0/1/2), o exit NUNCA mente "LIMPO" (0) — sai REVISAR (1).
RC=1

# v4.4.88: TERMINAL SILENCIOSO + LOG VERBOSO.
#   QUIET=1 (default, run direto no Termux): a TELA recebe só progresso por seção
#   + o painel final (críticos/suspeitos). TODO o detalhe bruto vai pro $REPORT —
#   acaba com o estouro de scrollback do Termux.
#   QUIET=0 (A4_VERBOSE=1, setado pelo coletor ADB): imprime tudo no stdout. O
#   wrapper captura num arquivo e renderiza UM painel só (sem duplicação).
QUIET=1; [ "${A4_VERBOSE:-0}" = "1" ] && QUIET=0

# v4.4.88: acumuladores de críticos/suspeitos em ARQUIVO — sobrevivem a subshells
# (um `... | while` roda em subshell e perderia variáveis de contador). O painel
# final lê DAQUI, então sai UMA vez e com a contagem REAL.
A4_TMPD=$(pwd 2>/dev/null); [ -n "$A4_TMPD" ] || A4_TMPD=/tmp
for _d in "${TMPDIR:-}" /data/local/tmp "$HOME" /tmp; do
    [ -n "$_d" ] && [ -d "$_d" ] && [ -w "$_d" ] && { A4_TMPD="$_d"; break; }
done
A4_CRIT_FILE="$A4_TMPD/.a4_crit_$$"
A4_WARN_FILE="$A4_TMPD/.a4_warn_$$"
: > "$A4_CRIT_FILE" 2>/dev/null; : > "$A4_WARN_FILE" 2>/dev/null
trap 'rm -f "$A4_CRIT_FILE" "$A4_WARN_FILE" 2>/dev/null' EXIT INT TERM

strip_color() { sed -E 's/\x1B\[[0-9;]*[mK]//g' 2>/dev/null; }

# emit = canal de DETALHE → sempre no $REPORT; no stdout só em modo verboso.
emit() {
    [ "$QUIET" = "0" ] && printf '%s\n' "$*"
    [ "$REPORT" != "/dev/null" ] && printf '%s\n' "$*" | strip_color >> "$REPORT" 2>/dev/null
    return 0
}
# screen = canal de TELA (progresso/painel) → stdout só em modo silencioso (em
# verboso o emit já cobre o stdout; evita linha duplicada).
screen() { [ "$QUIET" = "1" ] && printf '%s\n' "$*"; return 0; }
# show = pertence à TELA e ao ARQUIVO, exatamente uma vez no stdout.
show()   { screen "$*"; emit "$*"; }

alert()  { emit "  ${CR}●  ALERTA  ${CN}$*"; printf '%s\n' "$*" | strip_color >> "$A4_CRIT_FILE" 2>/dev/null; ALERTS=$((ALERTS+1));     }
warn()   { emit "  ${CY}●  AVISO   ${CN}$*"; printf '%s\n' "$*" | strip_color >> "$A4_WARN_FILE" 2>/dev/null; WARNINGS=$((WARNINGS+1)); }
ok()     { emit "  ${CG}●  OK      ${CN}$*"; CLEAN=$((CLEAN+1));       }
info()   { emit "  ${CC}○  info    ${CN}$*"; }
# v4.4.98: contagem do acumulador crit+warn (arquivo) — usada p/ a "linha-limpo" por-seção
# ser HONESTA mesmo quando o alert/warn roda em subshell (|while), onde o contador local
# se perdia e a seção imprimia "limpo" tendo alertado. Snapshot no início × fim da seção.
_hits_count() { cat "$A4_CRIT_FILE" "$A4_WARN_FILE" 2>/dev/null | wc -l | tr -d ' '; }
header() {
    emit ""
    emit "${CB}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    emit "${CW}${CB} ◆  $*${CN}"
    emit "${CB}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    screen "  ${CC}▸${CN} $*"
}

# ---------- Helpers ----------
have()   { command -v "$1" >/dev/null 2>&1; }
gp()     { getprop "$1" 2>/dev/null; }
exists() { [ -e "$1" ]; }
pkg_installed() {
    have pm && pm path "$1" 2>/dev/null | grep -q '^package:'
}
# ── v4.4.99: NOME (label) do app + PRELOAD OEM (anti-FP de sideload) ──────────
# Objetivo forense: (a) mostrar o NOME de biblioteca ao lado do pacote no relatório
# — "com.dts.freefireth (Free Fire)" — dispensando um "lib checker" externo; (b) ZERAR
# o falso-positivo de sideload em apps de FÁBRICA (Samsung/Xiaomi/Redmi/Oppo/Realme/
# Vivo/Moto/Honor/etc.) SEM abrir brecha p/ cheat disfarçado — a liberação usa SÓ sinais
# de sistema NÃO-FORJÁVEIS (partição de sistema / pkgFlags SYSTEM / lista `pm -s`), nunca o
# namespace ou o installerPackageName (ambos forjáveis por app de usuário). O namespace OEM
# SEM lastro de sistema é tratado como DISFARCE (detecção), não liberação. Ver [[forense.md]].

# namespace de vendor OEM conhecido — usado p/ DETECTAR disfarce (app com nome de fábrica mas
# SEM lastro de sistema), NUNCA p/ liberar. Ver o loop SIDELOAD GLOBAL.
is_oem_ns() {
    case "$1" in
        com.samsung.*|com.sec.*|com.miui.*|com.xiaomi.*|com.mi.*|com.redmi.*|com.oplus.*|\
        com.oppo.*|com.coloros.*|com.realme.*|com.heytap.*|com.oneplus.*|com.vivo.*|\
        com.bbk.*|com.iqoo.*|com.motorola.*|com.moto.*|com.lenovo.*|com.zui.*|com.huawei.*|\
        com.hihonor.*|com.honor.*|com.transsion.*|com.infinix.*|com.tecno.*|com.itel.*|\
        com.asus.*|com.sonymobile.*|com.sony.*|com.lge.*|com.tcl.*|com.nothing.*|com.fih.*) return 0 ;;
    esac
    return 1
}
# is_oem_preload $pkg $installer $apath → 0 (benigno = preload de fábrica) / 1 (sideload real).
# v4.4.99 (hardening pós-review adversarial): SÓ libera com sinais NÃO-FORJÁVEIS por app de
# usuário sem root. NÃO usa namespace nem installerPackageName como âncora — ambos são forjáveis
# (`adb install -i <loja>` seta qualquer installer; renomear o pacote p/ com.samsung.* é trivial).
# O namespace OEM sem lastro vira DETECÇÃO (disfarce), não liberação — ver o loop SIDELOAD GLOBAL.
is_oem_preload() {
    _p="$1"; _ap="$3"
    # (1) APK em partição de sistema/OEM = preload de fábrica (sem root não se escreve lá)
    case "$_ap" in
        /system/*|/system_ext/*|/product/*|/vendor/*|/apex/*|/odm/*|/oem/*|/oob/*|\
        /prism/*|/optics/*|/preload/*|/cust/*|/my_*/*|/product_h/*|/region/*|/carrier/*) return 0 ;;
    esac
    # (2) FLAG SYSTEM/UPDATED_SYSTEM_APP no dumpsys = system app MESMO já atualizado p/ /data/app
    #     (só a imagem de sistema seta; app de usuário não forja). Pega o Samsung Tips atualizado.
    if have dumpsys; then
        case "$(dumpsys package "$_p" 2>/dev/null | grep -m1 'pkgFlags=')" in
            *SYSTEM*) return 0 ;;
        esac
    fi
    # (3) classificação SYSTEM do próprio PackageManager (`pm list packages -s`, pré-computada em
    #     $_SYS_PKGS) — inclui updated-system-apps realocados p/ /data/app. Match de LINHA EXATA
    #     (grep -qxF) p/ não casar prefixo de outro pacote do mesmo vendor. Não-forjável sem root.
    printf '%s\n' "$_SYS_PKGS" | grep -qxF "package:$_p" && return 0
    return 1
}
# pkg_label $pkg → NOME humano (mapa curado → aapt real → vazio). pkg_show → "pkg (Nome)".
pkg_label() {
    case "$1" in
        com.dts.freefireth) echo "Free Fire"; return ;;
        com.dts.freefiremax) echo "Free Fire MAX"; return ;;
        com.garena.game.kgvn|com.garena.game.kgid|com.garena.game.kgtw|com.garena.game.kgth) echo "Free Fire (Garena regional)"; return ;;
        com.proxy.free) echo "ProxyFree — CHEAT root Trade-In"; return ;;
        com.ffh4x*) echo "FFH4X — mod menu/cheat FF"; return ;;
        com.panelff.app) echo "Panel FF — painel de cheat"; return ;;
        com.op999.injector) echo "OP999 Injector — cheat FF"; return ;;
        com.teambot.injector) echo "TeamBot Injector — cheat FF"; return ;;
        com.tb71.injector) echo "TB71 Injector — cheat FF"; return ;;
        com.ng.injector) echo "NG Injector — cheat FF"; return ;;
        com.novaesp) echo "Nova ESP — wallhack FF"; return ;;
        tn.loukious.fakerunlocker) echo "Fake Run Locker — cheat FF"; return ;;
        com.ff.injector) echo "FF Injector — painel de cheat FF"; return ;;
        com.anydesk.anydeskandroid) echo "AnyDesk — controle remoto"; return ;;
        com.carriez.flutter_hbb) echo "RustDesk — controle remoto"; return ;;
        com.koushikdutta.vysor) echo "Vysor — espelhamento/controle"; return ;;
        com.teamviewer.quicksupport.market|com.teamviewer.teamviewer.market.mobile) echo "TeamViewer — controle remoto"; return ;;
        com.sand.airdroid|com.sand.airmirror) echo "AirDroid/AirMirror — controle remoto"; return ;;
        com.apowersoft.mirror) echo "ApowerMirror — espelhamento"; return ;;
        com.splashtop.remote.pad.v2) echo "Splashtop — controle remoto"; return ;;
        com.lbe.parallel*|com.parallel.space*) echo "Parallel Space — clonador de app"; return ;;
        com.ludashi.dualspace) echo "Dual Space — clonador de app"; return ;;
        com.excelliance.dualaid) echo "Dual App — clonador"; return ;;
        io.virtualapp|com.icecold.gomultiple|com.cloneapp*) echo "VirtualApp — clonador"; return ;;
        com.topjohnwu.magisk|io.github.huskydg.magisk) echo "Magisk — root/hide"; return ;;
        org.lsposed.manager|io.github.lsposed.manager) echo "LSPosed — framework de hook"; return ;;
        moe.shizuku.privileged.api) echo "Shizuku — foothold ADB/shell"; return ;;
        com.termux) echo "Termux — terminal Linux"; return ;;
        ru.zdevs.zarchiver) echo "ZArchiver — gerenciador de arquivos"; return ;;
    esac
    # aapt/aapt2 do APK real — só quando a ferramenta existe (Termux nativo com `pkg install aapt`)
    if have aapt2 || have aapt; then
        _lp=$(pm path "$1" 2>/dev/null | sed -n 's/^package://p' | head -1)
        if [ -n "$_lp" ] && [ -r "$_lp" ]; then
            _bd=$(aapt2 dump badging "$_lp" 2>/dev/null || aapt dump badging "$_lp" 2>/dev/null)
            _lbl=$(printf '%s\n' "$_bd" | sed -n "s/^application-label:'\(.*\)'.*/\1/p" | head -1)
            [ -n "$_lbl" ] && { echo "$_lbl"; return; }
        fi
    fi
    echo ""
}
pkg_show() { _pl=$(pkg_label "$1"); if [ -n "$_pl" ]; then printf '%s (%s)' "$1" "$_pl"; else printf '%s' "$1"; fi; }
# v4.4.102: tok_grep — grep -i ANCORADO por fronteira: o token só casa no INÍCIO de uma "palavra"
# (início de linha OU precedido por não-[a-zA-Z0-9_]), com o prefixo `lib` de biblioteca OPCIONAL,
# NUNCA no meio de outra palavra. Mata a CLASSE de FP-por-substring que queimou o projeto:
# `xposed`↔`system_e[xposed]_libraries` (libs ArcSoft = crítico falso), `ksu`↔`journal_che[cksu]m`
# (root-hide falso em todo ext4), `gadget`↔HAL MTK — SEM perder os casos legítimos `lib<token>`
# (libsubstrate, libxposed) nem variantes de cheat (xposedmod). Uso: echo "$TXT" | tok_grep "$TOK"
tok_grep() { grep -iE "(^|[^a-zA-Z0-9_])(lib)?(${1})"; }
# ─────────────────────────────────────────────────────────────────────────────
# v4.4.70: KB → tamanho legível (GB/MB/KB). Usado no cálculo do tamanho REAL do FF
# (APK + OBB + Data somados).
human_kb() {
    _k=${1:-0}; case "$_k" in ''|*[!0-9]*) _k=0 ;; esac
    if   [ "$_k" -ge 1048576 ]; then awk -v k="$_k" 'BEGIN{printf "%.2f GB", k/1048576}'
    elif [ "$_k" -ge 1024 ];    then awk -v k="$_k" 'BEGIN{printf "%.0f MB", k/1024}'
    else printf '%s KB' "$_k"; fi
}

# v4.4.32: SELF_PID + SELF_FILTER pra evitar que o próprio scanner caia no
# ps -A | grep "scarlet|trollstore|cheat|hack". O bug: o argv do shell rodando
# o script contém o path "a4ther.sh", então quando o script lista esses tokens
# em arrays de string, eles aparecem no comando — e a varredura captura como
# se fossem processos reais. Solução: filtra o PID do script, processo pai e
# filhos diretos, mais qualquer linha que cite o nome do script.
SELF_PID=$$
SELF_PPID=$(cat /proc/$$/stat 2>/dev/null | awk '{print $4}')
SELF_SCRIPT="a4ther"
# v4.4.79 (A3): caminho/nome ABSOLUTO do próprio script, pra self-exclusion por PATH
# (não por glob de nome). Antes excluía 'a4ther*'/'A4THER*'/'scan_*' por NOME — um
# cheat nomeado a4ther_x.lua / scan_evil.js escapava do scan de holograma. Agora só
# o arquivo REAL do script (qualquer nome que ele tenha) + a pasta a4ther_audits +
# o relatório master do coletor ADB são excluídos.
SELF_PATH=$0
case "$SELF_PATH" in /*) ;; *) SELF_PATH="$(pwd 2>/dev/null)/$SELF_PATH" ;; esac
SELF_BASE=$(basename "$SELF_PATH" 2>/dev/null); [ -n "$SELF_BASE" ] || SELF_BASE="a4ther.sh"
# clean_procs: remove linhas que sejam o próprio script (pid/ppid/nome).
# Uso: PROCS=$(ps -A 2>/dev/null | clean_procs)
clean_procs() {
    awk -v me="$SELF_PID" -v parent="$SELF_PPID" -v name="$SELF_SCRIPT" '
        {
            pid=$2;
            # campo pid varia por ps: BusyBox = $1, Android toybox -A = $2
            for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/ && $i!=0) { pid=$i; break }
            if (pid==me || pid==parent) next
            if (index($0, name)>0) next
            print
        }'
}

# v4.4.32: fs_has_nanos PATH — retorna 0 (yes) se filesystem suporta resolução
# de nanossegundos, 1 (no) caso contrário. Crítico antes de cravar timestomping
# em FAT32/sdcardfs/exfat — esses fs SEMPRE retornam nanos zerados ou inválidos,
# e o scanner antigo gerava ALERTA crítico em 100% dos casos.
#
# Estratégia:
#  1. Detecta tipo de fs via stat -f -c '%T' ou findmnt/mount
#  2. Whitelist de fs com nanos (ext4, f2fs, btrfs, xfs)
#  3. Blacklist de fs sem nanos (vfat, exfat, msdos)
#  4. Fallback: cria um arquivo temp e mede a resolução
fs_has_nanos() {
    [ -z "$1" ] && return 1
    _FS=""
    # método 1: stat -f
    if have stat; then
        _FS=$(stat -f -c '%T' "$1" 2>/dev/null)
    fi
    # método 2: mount/findmnt
    if [ -z "$_FS" ]; then
        _MP=$(df "$1" 2>/dev/null | tail -1 | awk '{print $NF}')
        [ -n "$_MP" ] && _FS=$(awk -v mp="$_MP" '$2==mp {print $3; exit}' /proc/mounts 2>/dev/null)
    fi
    case "$_FS" in
        # Sem suporte a nanos (resolução 2s ou pior):
        vfat|fat|msdos|exfat|sdfat|fuseblk|fuse|sdcardfs)
            return 1 ;;
        # Suporta nanos:
        ext4|f2fs|btrfs|xfs|ext3|ext2)
            return 0 ;;
        # Desconhecido: assume YES pra não suprimir alertas reais
        *)
            return 0 ;;
    esac
}

# v4.4.3: settings get com filtro de erro. No Android moderno o `settings`
# command falha pra apps non-privileged com "cmd: Failure calling service
# settings: Failed transaction (2147483646)" — o script tratava essa mensagem
# como se fosse VALOR válido (ex: "proxy ativo: cmd: Failure..."). Agora
# retornamos string vazia quando detectamos erro.
#   uso:  $(setting_get global http_proxy)
#         $(setting_get secure enabled_accessibility_services)
setting_get() {
    have settings || { echo ""; return 0; }
    _v=$(settings get "$1" "$2" 2>/dev/null)
    # Filtra mensagens de erro do Android moderno
    case "$_v" in
        ""|"null"|"NULL")              echo "" ;;
        cmd:*|*"Failure calling"*)     echo "" ;;
        *"Failed transaction"*)        echo "" ;;
        *"Permission Denial"*)         echo "" ;;
        *"Exception"*|*"Error:"*)      echo "" ;;
        *) echo "$_v" ;;
    esac
}

# ---------- Banner ----------
show ""
show "${CW}${CC}    ╭──────────────────────────────────────────────────────╮${CN}"
show "${CW}${CC}    │                                                      │${CN}"
show "${CW}${CC}    │    █████╗ ██╗  ██╗████████╗██╗  ██╗███████╗██████╗   │${CN}"
show "${CW}${CC}    │   ██╔══██╗██║  ██║╚══██╔══╝██║  ██║██╔════╝██╔══██╗  │${CN}"
show "${CW}${CC}    │   ███████║███████║   ██║   ███████║█████╗  ██████╔╝  │${CN}"
show "${CW}${CC}    │   ██╔══██║╚════██║   ██║   ██╔══██║██╔══╝  ██╔══██╗  │${CN}"
show "${CW}${CC}    │   ██║  ██║     ██║   ██║   ██║  ██║███████╗██║  ██║  │${CN}"
show "${CW}${CC}    │   ╚═╝  ╚═╝     ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  │${CN}"
show "${CW}${CC}    │                                                      │${CN}"
show "${CW}${CC}    │${CN}      ${CW}S Y S T E M S${CN}  ${CY}▪${CN}  ${CW}v${VERSION}${CN}  ${CY}▪${CN}  ${CW}LS Aluguel${CN}         ${CW}${CC}│${CN}"
show "${CW}${CC}    │${CN}      ${CC}Free Fire Anti-Cheat Scanner${CN}                    ${CW}${CC}│${CN}"
show "${CW}${CC}    │                                                      │${CN}"
show "${CW}${CC}    ╰──────────────────────────────────────────────────────╯${CN}"
show ""
show "  ${CC}›${CN} Relatório: $REPORT"
# v4.4.88: em modo silencioso a TELA mostra só progresso + painel final; o detalhe
# completo do scan vai pro arquivo acima. Use-o pra perícia profunda.
[ "$QUIET" = "1" ] && show "  ${CC}›${CN} ${CW}Tela = resumo${CN}; detalhe completo no .txt acima."
# v4.4.2: avisa se caiu pra /dev/null (nenhum dir writable encontrado)
if [ "$REPORT" = "/dev/null" ]; then
    show "  ${CR}!${CN} ATENÇÃO: nenhum diretório writable encontrado pro relatório."
    show "  ${CY}›${CN} Tentados: $REPORT_DIR_TRIED"
    show "  ${CY}›${CN} No Termux moderno (Android 11+) rode antes:"
    show "      ${CW}termux-setup-storage${CN}  (vai pedir permissão de armazenamento)"
    show "  ${CY}›${CN} Depois rode o a4ther.sh de novo — o .txt vai pra /sdcard/a4ther/"
fi
show ""

# Pre-cache: lista de pacotes (usado por várias seções)
ALL_PKGS=""
have pm && ALL_PKGS=$(pm list packages 2>/dev/null)
# v4.4.100: lista SYSTEM computada UMA vez (âncora NÃO-FORJÁVEL do is_oem_preload) — reusada no
# SIDELOAD e nos portões de overlay/accessibility. Inclui updated-system-apps realocados p/ /data/app.
_SYS_PKGS=""
have pm && _SYS_PKGS=$(pm list packages -s 2>/dev/null)

FF_PKGS="com.dts.freefireth com.dts.freefiremax com.garena.game.kgvn com.garena.game.kgid com.garena.game.kgtw com.garena.game.kgth"

# Free Fire iOS bundle IDs
FF_IOS_BUNDLES="com.garena.global.freefire com.garena.global.ffmax com.garena.freefire.br com.garena.freefire.kr com.dts.freefireth com.dts.freefiremax"

# ============================================================
#  DETECÇÃO DE PLATAFORMA (Android / iOS / outro)
# ============================================================
detect_platform() {
    # Override via env var: FORCE_PLATFORM=ios sh a4ther.sh  (modo teste)
    if [ -n "$FORCE_PLATFORM" ]; then
        PLATFORM="$FORCE_PLATFORM"
        OS_NAME="(forced=$FORCE_PLATFORM)"
        # v4.4.32: marca quando o force é em Darwin REAL (não device iOS).
        # Várias seções usam IS_REAL_IOS=1 pra suprimir paths que existem em
        # macOS comum (/usr/bin/ssh, /usr/sbin/sshd, sftp-server, lldb).
        IS_REAL_IOS=0
        if [ "$FORCE_PLATFORM" = "ios" ]; then
            if [ -d /var/mobile ] || [ -d /private/var/mobile ] \
               || [ -d /var/jb ] || [ -d /private/var/jb ]; then
                IS_REAL_IOS=1
            fi
        fi
        return
    fi
    OS_NAME=$(uname -s 2>/dev/null)
    case "$OS_NAME" in
        Linux*)
            if [ -f /system/build.prop ] || command -v getprop >/dev/null 2>&1 \
               || [ -d /system/app ] || [ -d /data/data ]; then
                PLATFORM="android"
            else
                PLATFORM="linux"
            fi
            ;;
        Darwin*)
            if [ -d /var/mobile ] || [ -d /private/var/mobile ] \
               || [ -d /Applications/Cydia.app ] || [ -d /Applications/Sileo.app ] \
               || [ -d /Applications/Zebra.app ] \
               || [ -d /var/jb ] || [ -d /private/var/jb ] \
               || [ -f /usr/libexec/cydia/firmware.sh ]; then
                PLATFORM="ios"
                IS_REAL_IOS=1
            elif [ -d /System/Library/CoreServices ] && [ -d /Users ]; then
                PLATFORM="macos"
                IS_REAL_IOS=0
            else
                PLATFORM="darwin"
                IS_REAL_IOS=0
            fi
            ;;
        *)
            PLATFORM="unknown"
            IS_REAL_IOS=0
            ;;
    esac
}
IS_REAL_IOS=0
detect_platform

emit "Plataforma detectada: ${CW}$PLATFORM${CN}  (uname=$OS_NAME)"
emit ""

# Se for plataforma não-suportada, encerra com aviso
case "$PLATFORM" in
    android|ios) ;;
    *)
        warn "Plataforma '$PLATFORM' não é Android nem iOS."
        warn "FFScanner suporta: Android (via Termux) ou iOS jailbroken (via SSH)."
        warn "Continuando com checks genéricos limitados..."
        ;;
esac

# ============================================================
#  ====== A PARTIR DAQUI: BLOCO ANDROID ==========
# ============================================================
if [ "$PLATFORM" = "android" ]; then

# ============================================================
#  0. WIFI DEBUG PROMPT (v4.4.52)
#  Antes do scan, detecta se já tem ADB conectado. Se não tem, mostra setup
#  de depuração WiFi pro user parear e dar permissão a dados privilegiados
#  (bugreport completo, dumpsys, tombstones). Sem isso, Termux pula tudo
#  que precisa de root/shell uid e o relatório fica fraco.
#
#  Skipa o prompt automaticamente quando:
#    - SKIP_WIFI_PROMPT=1 (env var, pra rodadas headless)
#    - ADB já está pareado e conectado
#    - Device claramente é root (UID 0) — não precisa de ADB
# ============================================================
header "CONTEXTO DE EXECUÇÃO (privilégio)"

# v4.4.57: o que importa pra ter ACESSO ELEVADO não é a porta 5555 estar
# aberta — é o UID em que o SCRIPT roda. Parear a depuração WiFi só abre a
# porta; se o usuário continua rodando no Termux (uid 10xxx), o scan continua
# sem acesso a serial/dumpsys/tombstones. SÓ destrava rodando VIA adb shell
# (uid 2000) ou root (uid 0).
_CUR_UID=$(id -u 2>/dev/null)
[ -z "$_CUR_UID" ] && _CUR_UID=99999
_IS_ROOT=0;  [ "$_CUR_UID" = "0" ] && _IS_ROOT=1
_IS_SHELL=0; [ "$_CUR_UID" = "2000" ] && _IS_SHELL=1

# Detecta Termux (app não-privilegiado — uid >= 10000 + namespace com.termux)
_IS_TERMUX=0
case "$PREFIX" in
    *com.termux*) _IS_TERMUX=1 ;;
esac
[ -d /data/data/com.termux ] && [ "$_CUR_UID" -ge 10000 ] 2>/dev/null && _IS_TERMUX=1
case "$HOME" in
    *com.termux*) _IS_TERMUX=1 ;;
esac

# Porta 5555 (ADB WiFi) em LISTEN — sinal de que JÁ pareou, mas NÃO garante
# que o scan está rodando com uid elevado.
_ADB_WIFI=0
if [ -r /proc/net/tcp ]; then
    awk '{print $2}' /proc/net/tcp 2>/dev/null | grep -qE ':15B3$' && _ADB_WIFI=1
fi
[ "$_ADB_WIFI" = "0" ] && [ -r /proc/net/tcp6 ] && \
    awk '{print $2}' /proc/net/tcp6 2>/dev/null | grep -qE ':15B3$' && _ADB_WIFI=1

_DEV_ENABLED=0
if have settings; then
    [ "$(settings get global development_settings_enabled 2>/dev/null)" = "1" ] && _DEV_ENABLED=1
fi

# === Decisão baseada em UID, não em porta ===
if [ "$_IS_ROOT" = "1" ]; then
    ok "Rodando como ROOT (UID 0) — acesso total. HWID/dumpsys/tombstones disponíveis."
elif [ "$_IS_SHELL" = "1" ]; then
    ok "Rodando via ADB SHELL (UID 2000) — acesso elevado ✓"
    ok "dumpsys (Widevine ID), getprop serial e tombstones acessíveis."
elif [ -n "$SKIP_WIFI_PROMPT" ]; then
    info "SKIP_WIFI_PROMPT=1 — pulando setup de depuração WiFi"
else
    # v4.4.86: instruções verbosas de pareamento WiFi REMOVIDAS (o usuário já
    # roda via ADB). Aviso de uma linha, sem passo-a-passo nem pausa interativa.
    warn "Sem privilégio elevado (UID $_CUR_UID) — serial/dumpsys/tombstones podem faltar. Rode via 'adb shell sh ...' p/ acesso completo."
fi

# ============================================================
#  1. INFO DO SISTEMA
# ============================================================
header "INFO DO SISTEMA"

BRAND=$(gp ro.product.brand)
MODEL=$(gp ro.product.model)
DEVICE=$(gp ro.product.device)
HARDWARE=$(gp ro.hardware)
ABI=$(gp ro.product.cpu.abi)

info "Marca/Modelo: $BRAND $MODEL"
info "Device:       $DEVICE"
info "Hardware:     $HARDWARE"
info "ABI:          $ABI"
info "Android:      $(gp ro.build.version.release) (SDK $(gp ro.build.version.sdk))"
info "Build:        $(gp ro.build.display.id)"
info "Fingerprint:  $(gp ro.build.fingerprint)"
info "Kernel:       $(uname -r 2>/dev/null)"

# === REGIÃO / LOCALE / PLAY STORE (v4.4.30) ===
LOCALE=$(gp ro.product.locale)
[ -z "$LOCALE" ] && LOCALE=$(gp persist.sys.locale)
[ -z "$LOCALE" ] && LOCALE=$(gp ro.product.locale.language)
COUNTRY=$(gp ro.product.locale.region)
[ -z "$COUNTRY" ] && COUNTRY=$(gp ro.csc.countryiso_code)
[ -z "$COUNTRY" ] && COUNTRY=$(gp persist.sys.country)
[ -z "$COUNTRY" ] && [ -n "$LOCALE" ] && COUNTRY=$(echo "$LOCALE" | sed -nE 's/.*[-_]([A-Z]{2}).*/\1/p')
TIMEZONE=$(gp persist.sys.timezone)
[ -z "$TIMEZONE" ] && TIMEZONE=$(have date && date +%Z 2>/dev/null)
# Play Store country — vem de Google Services account ou geo da SIM
PLAY_COUNTRY=$(gp ro.com.google.gmsversion 2>/dev/null | sed -nE 's/.*_([A-Z]{2}).*/\1/p')
# fallback: gservices.country ou SIM country
[ -z "$PLAY_COUNTRY" ] && PLAY_COUNTRY=$(gp gsm.operator.iso-country 2>/dev/null | tr '[:lower:]' '[:upper:]')
[ -z "$PLAY_COUNTRY" ] && PLAY_COUNTRY=$(gp gsm.sim.operator.iso-country 2>/dev/null | tr '[:lower:]' '[:upper:]')

info "Locale:       ${LOCALE:-?}"
info "Country:      ${COUNTRY:-?}"
info "Timezone:     ${TIMEZONE:-?}"
info "Play Store:   ${PLAY_COUNTRY:-?}"

UPTIME=0
[ -r /proc/uptime ] && UPTIME=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
[ -z "$UPTIME" ] && UPTIME=0
if [ "$UPTIME" -lt 3600 ] 2>/dev/null; then
    alert "Uptime $((UPTIME/60)) min < 60 min - reboot recente (bypass clássico)"
else
    ok "Uptime: $((UPTIME/60)) min"
fi

USB=$(gp sys.usb.state)
case "$USB" in
    *mtp*) warn "USB em modo MTP ($USB)" ;;
    "")    info "USB state: indisponível" ;;
    *)     ok "USB state: $USB" ;;
esac

if have settings; then
    AT=$(setting_get global auto_time)
    ATZ=$(setting_get global auto_time_zone)
    [ "$AT" = "0" ]  && alert "auto_time DESLIGADO (manipulação de data/hora)" || [ -n "$AT" ] && ok "auto_time=$AT"
    [ "$ATZ" = "0" ] && warn "auto_time_zone DESLIGADO" || [ -n "$ATZ" ] && ok "auto_time_zone=$ATZ"
    [ "$(setting_get global adb_enabled)" = "1" ] && warn "ADB habilitado"
    [ "$(setting_get global development_settings_enabled)" = "1" ] && warn "Opções de dev habilitadas"
    [ "$(setting_get global install_non_market_apps)" = "1" ] && warn "Fontes desconhecidas habilitadas"
    [ "$(setting_get secure mock_location)" = "1" ] && alert "Mock location HABILITADO"
fi

ADB_TCP=$(gp persist.adb.tcp.port)
[ -n "$ADB_TCP" ] && [ "$ADB_TCP" != "0" ] && alert "persist.adb.tcp.port=$ADB_TCP (ADB wifi persistente)"

info "Data/hora: $(date 2>/dev/null)"

# UID atual (running as shell ADB? = 2000)
CURRENT_UID=$(id -u 2>/dev/null)
[ "$CURRENT_UID" = "2000" ] && info "Rodando como UID 2000 (shell/adb)"

# ============================================================
#  2. BOOT / KERNEL / SELINUX / suSFS
# ============================================================
header "BOOT / KERNEL / SELINUX / suSFS"

KERNEL_HITS=0

VBOOT=$(gp ro.boot.verifiedbootstate)
case "$VBOOT" in
    green)         ok "Bootloader: GREEN (locked)" ;;
    yellow)        warn "Bootloader: YELLOW (assinado pelo usuário)" ;;
    orange|red)    alert "Bootloader: $VBOOT (UNLOCKED)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    "")            info "verifiedbootstate: indisponível" ;;
esac

case "$(gp ro.boot.vbmeta.device_state)" in
    locked)   ok "vbmeta: locked" ;;
    unlocked) alert "vbmeta: UNLOCKED"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac

case "$(gp ro.boot.flash.locked)" in
    1) ok "flash.locked=1" ;;
    0) alert "flash.locked=0 (bootloader liberado)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac

# warranty bit (Knox e similares)
WARR=$(gp ro.boot.warranty_bit)
[ -z "$WARR" ] && WARR=$(gp ro.warranty_bit)
[ "$WARR" = "1" ] && alert "Knox/warranty bit acionado (histórico de tampering)"

# AVB version (1 = old, 2 = newer)
AVB=$(gp ro.boot.avb_version)
[ -n "$AVB" ] && info "AVB version: $AVB"

# ── dm-verity + cross-check prop×cmdline (v4.4.95) ────────────────────────
# COMO O ATACANTE USA: desligar dm-verity (veritymode=disabled) libera montar
# /system,/vendor adulterados (patch systemless de libs do FF). E 'resetprop'
# falsifica ro.boot.* p/ esconder bootloader liberado/verity off.
# POR QUE DETECTA: (1) veritymode — por AOSP, só 'disabled' = verity OFF (ALERTA).
# 'enforcing'/'eio'/'restart_on_corruption' MANTÊM verity ATIVO e protetor (só muda
# a ação no erro: eio retorna I/O error); 'logging' verifica mas PERMITE a corrupção
# (só registra) → estado FRACO = warn, não verity-off. (2) a prop resolvida divergir
# do /proc/cmdline REAL do kernel = spoof de prop (cmdline não é reescrito por
# resetprop). HONESTIDADE: cmdline sem o campo → sem cross-check (não inocenta).
# v4.4.97: corrigido FP — antes 'eio'/'logging' (verity ATIVO) viravam ALERTA crítico
# → SUSPEITO falso em device limpo. Fonte: AOSP dm-verity; MAGISK_DETECTION_GAPS §4.4/§4.5.
A4_VMODE=$(gp ro.boot.veritymode)
case "$A4_VMODE" in
    enforcing|eio|restart_on_corruption|"") : ;;
    disabled) alert "dm-verity DESLIGADO (veritymode=disabled) — /system adulterável"
              KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    logging)  warn "dm-verity em modo 'logging' (verifica mas PERMITE corrupção — só registra) — revisar"
              KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    *)        warn "dm-verity veritymode='$A4_VMODE' (não-enforcing desconhecido) — revisar"
              KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac
A4_CMDLINE=$(cat /proc/cmdline 2>/dev/null)
case "$A4_CMDLINE" in
    *androidboot.enable_dm_verity=0*)
        alert "cmdline: enable_dm_verity=0 (verity desligado no boot)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac
A4_CMD_VBS=$(printf '%s' "$A4_CMDLINE" | grep -o 'androidboot\.verifiedbootstate=[^ ]*' | cut -d= -f2)
if [ -n "$VBOOT" ] && [ -n "$A4_CMD_VBS" ] && [ "$VBOOT" != "$A4_CMD_VBS" ]; then
    alert "verifiedbootstate DIVERGENTE: prop='$VBOOT' × cmdline='$A4_CMD_VBS' (resetprop/spoof)"
    KERNEL_HITS=$((KERNEL_HITS+1))
fi

# force_normal_boot — v4.4.31: rebaixado pra info pq é PADRÃO em Android 10+
# (boot flow normal vs recovery). Em Android <10 era IOC, hoje é o caminho normal.
case "$(gp ro.boot.force_normal_boot)" in
    1) info "ro.boot.force_normal_boot=1 (normal em Android 10+)" ;;
esac

# bootstate
BSTATE=$(gp ro.boot.bootstate)
[ -n "$BSTATE" ] && [ "$BSTATE" != "" ] && info "boot state: $BSTATE"

# SELinux
SE_MODE=""
if [ -r /sys/fs/selinux/enforce ]; then
    SE_RAW=$(cat /sys/fs/selinux/enforce 2>/dev/null)
    [ "$SE_RAW" = "1" ] && SE_MODE="Enforcing"
    [ "$SE_RAW" = "0" ] && SE_MODE="Permissive"
elif have getenforce; then
    SE_MODE=$(getenforce 2>/dev/null)
fi
case "$SE_MODE" in
    Enforcing)  ok "SELinux: Enforcing" ;;
    Permissive) alert "SELinux: PERMISSIVE (KernelSU/custom kernel)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    Disabled)   alert "SELinux: DISABLED"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    *)          info "SELinux: indeterminado" ;;
esac

# Kernel name suspeito
KVER=$(uname -r 2>/dev/null)
case "$KVER" in
    *KSU*|*kernelsu*|*KernelSU*|*APatch*|*apatch*|*Magisk*|*magisk*|*-perf+*|*custom*|*ksu*)
        alert "Kernel suspeito: $KVER"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac
# v4.4.63 (KellerSS-tier): kernels CUSTOM nomeados. Não são cheat por si só,
# mas indicam device fortemente modificado (flash de kernel → root/SUSFS/GKI).
case "$KVER" in
    *arter97*|*Arter97*|*sultan*|*Sultan*|*lychee*|*Lychee*|*chronos*|*Chronos*|*alucard*|*Alucard*|*RealKing*|*QuantumX*)
        warn "Kernel CUSTOM nomeado: $KVER — device modificado (kernel flashado)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    *kali*|*Kali*|*nethunter*|*NetHunter*)
        alert "Kernel Kali/NetHunter: $KVER — ROM de pentest (tooling avançado)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac

# v4.4.94: kernel "-dirty" = árvore com mudanças NÃO-commitadas (patch/custom).
case "$KVER" in *-dirty*)
    alert "Kernel '-dirty' ($KVER): árvore modificada/patchada"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac
case "$(cat /proc/version 2>/dev/null)" in *-dirty*)
    alert "/proc/version contém '-dirty' (kernel patchado)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac

# Paths kernel-level
for P in /data/adb/ksu /data/adb/ksud /data/adb/ksunext /data/adb/ksu/bin/ksud \
         /data/adb/ap /data/adb/apd \
         /data/adb/zygisk /data/adb/post-fs-data.d /data/adb/service.d \
         /data/adb/magisk.db /data/adb/magisk \
         /system/bin/kernelsu /system/bin/ksud \
         /data/adb/lspd /data/adb/modules_update \
         /dev/_ksu /dev/ksu /dev/.magisk /dev/.magisk_unblock; do
    exists "$P" && { alert "Root persistente: $P"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done

# suSFS (Magisk Hide moderno - mascara TUDO)
for P in /proc/sys/fs/susfs /sys/kernel/security/susfs /data/adb/susfs; do
    exists "$P" && { alert "suSFS detectado: $P (Magisk Hide moderno)"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done

# v4.4.99: adbd em modo ROOT via Trade-In Mode — 2a sessao adb-root INDEPENDENTE.
# COMO O ATACANTE USA: cheat (ex. ProxyFree/com.proxy.free) embute cliente ADB
# (libadb-android/SPAKE2) e ganha shell ROOT via exploit Trade-In Mode:
#   adbd --root_seclabel=u:r:su:s0 --tim_seclabel=u:r:adbd_tradeinmode:s0
# CALIBRACAO (corrige FP de device real, v4.4.99): em device LOCKED Xiaomi/MTK o PROPRIO acesso
# adb do operador/scanner pode passar por adbd em modo Trade-In — esse e' o adbd que SERVE a
# nossa sessao (ANCESTRAL do scan), NAO o cheat. Cheat e scanner compartilham o mesmo adbd, entao
# o cmdline do adbd NAO diferencia: antes dava CRITICO falso em todo device acessado via adb-root.
# Agora AUTO-EXCLUI a nossa arvore de processos (o adbd ancestral) e so flagra um adbd-root que
# esteja FORA dela (uma 2a sessao adb-root independente). O sinal PRIMARIO do cheat segue sendo o
# PACOTE (com.proxy.free no CHEAT_PKGS). uid 2000 le o cmdline do adbd.
_ANC=" $$ "; _ap=$$
while [ "$_ap" -gt 1 ] 2>/dev/null; do
    _app=$(awk '{print $4}' "/proc/$_ap/stat" 2>/dev/null)
    { [ -z "$_app" ] || [ "$_app" = "$_ap" ]; } && break
    case "$_ANC" in *" $_app "*) break ;; esac
    _ANC="$_ANC$_app "; _ap=$_app
done
for _d in /proc/[0-9]*; do
    _pid=${_d##*/}
    case "$_ANC" in *" $_pid "*) continue ;; esac   # pula a PROPRIA arvore (incl. nosso adbd)
    case "$(tr '\0' ' ' < "$_d/cmdline" 2>/dev/null)" in
        *adbd*tradeinmode*|*adbd*root_seclabel=u:r:su:s0*)
            alert "adbd em modo ROOT/Trade-In FORA da sessao do scanner (2a sessao adb-root independente — possivel cheat) PID $_pid"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    esac
done

# v4.4.95: APatch kpatch + su_path configurável (§12.4 do doc / APTest/hiapatch).
# COMO O ATACANTE USA: APatch (root via patch de kernel) instala o binário 'kpatch'
# e guarda o caminho do su num arquivo /data/adb/ap/su_path — o usuário RENOMEIA o
# su pra escondê-lo, e esse arquivo aponta ONDE ele está. O scanner já cobre
# /data/adb/ap mas não o kpatch nem o su_path. HONESTIDADE: /data/adb é 0700 root →
# sob uid 2000 em geral dá "não existe" (degrada quieto); vetor real de APatch sob
# uid 2000 segue sendo kallsyms/mount. Aqui é reforço barato quando há leitura.
for P in /data/adb/kpatch /data/adb/ap/kpatch /data/adb/ap/bin/kpatch; do
    exists "$P" && { alert "APatch kpatch: $P"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done
if [ -r /data/adb/ap/su_path ]; then
    SU_PATH=$(head -1 /data/adb/ap/su_path 2>/dev/null)
    [ -n "$SU_PATH" ] && { alert "APatch su_path → su escondido em: $SU_PATH"
        exists "$SU_PATH" && alert "  → confirmado: $SU_PATH"; KERNEL_HITS=$((KERNEL_HITS+1)); }
fi

# (v4.4.95) Detecção de EMULADOR DE PC (qemu/goldfish/native.bridge) foi AVALIADA
# e OMITIDA de propósito: o a4ther roda em device FÍSICO (ADB Wi-Fi/Termux), então
# essas props sempre dariam "limpo" (peso morto); os emuladores de cheat reais
# (LDPlayer/BlueStacks/Mumu/MEmu) SPOOFAM as props de AVD; e o único sinal robusto
# (lib de tradução de ISA carregada no FF) JÁ é pego no scan de /proc/$FF_PID/maps
# (token libhoudini/libndk_translation, adiante). O caso MOBILE que importa —
# Free Fire num container de virtual-space (VMOS/X8) — é tratado no bloco DFIR.

# ════════════════════════════════════════════════════════════════════════
#  MÓDULO 1 (v4.4.91) — Auditoria de Propriedades EXTRA (getprop)
#  ADITIVO: cobre só os 2 props que o scanner AINDA não vê. NÃO re-checa
#  ro.debuggable / ro.secure / verifiedbootstate (já tratados em 470-504 e
#  689-691) — re-checar duplicaria alerta e inflaria KERNEL_HITS/ALERTS.
# ════════════════════════════════════════════════════════════════════════

# ── 1A) ro.kernel.ksu — vazamento de propriedade do KernelSU ──────────────
# COMO O ATACANTE USA: KernelSU (KSU) é root RESIDENTE NO KERNEL. Ele não
# joga um "su" no /system/xbin nem exige app gerenciador, então escapa das
# checagens clássicas de userland — por isso é o root favorito pra cheat de
# FF (passa em anti-cheat que só olha o espaço de usuário).
# POR QUE DETECTA: certos kernels com KSU compilado embutido (ou forks/
# managers mal configurados) VAZAM a flag `ro.kernel.ksu`. Se ela aparece,
# é tell direto de kernel KSU.
# HONESTIDADE: ausência NÃO inocenta — KSU bem feito não seta prop nenhuma.
# Detectores PRIMÁRIOS de KSU seguem sendo os arquivos (/data/adb/ksu*,
# bloco "Paths kernel-level") e o /proc/kallsyms. Isto aqui é reforço barato.
KSU_PROP=$(gp ro.kernel.ksu)
case "$KSU_PROP" in
    1|true|TRUE)
        alert "ro.kernel.ksu=$KSU_PROP (KernelSU exposto via propriedade)"
        KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac

# v4.4.95: variantes de prop de root-manager + PlayIntegrityFix (§4.7 do doc).
# ro.kernel.ksu já tratado acima; aqui as variantes de VERSÃO (KSU/APatch) que
# certos kernels/managers vazam, + o bloco persist.sys.* do PlayIntegrityFix (PIF).
# PIF spoofa o device como Pixel pra passar no Play Integrity — é quase onipresente
# em device de FF com root OCULTO, então é um indicador forte de "tem root escondido
# aqui". HONESTIDADE: ausência NÃO inocenta (KSU/PIF bem feito não seta prop).
for K in ro.ksu.version ro.kernel.apatch ro.apatch.version ro.kernel.kpatch; do
    V=$(gp "$K"); [ -n "$V" ] && { alert "Prop de root-manager: $K=$V"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done
for K in persist.sys.spoof.gms persist.sys.pihooks.disable.gms persist.sys.pihooks_BRAND \
         persist.sys.pihooks_MODEL persist.sys.pixelprops.gms persist.sys.pixelprops.pi; do
    V=$(gp "$K"); [ -n "$V" ] && { warn "PlayIntegrityFix prop ($K=$V) — bypass de atestação (device com root oculto)"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done

# ── 1B) ro.adb.secure=0 — autenticação do ADB DESLIGADA ───────────────────
# COMO O ATACANTE USA: em device de fábrica ro.adb.secure=1 → toda conexão
# ADB exige o usuário APROVAR a chave RSA (o popup "Permitir depuração?").
# Com =0 (builds eng/userdebug ou ROM adulterada) esse portão cai: qualquer
# host vira shell uid 2000 SEM aprovação. uid 2000 é justamente o nível que
# habilita auto-elevação, sideload silencioso e injeção assistida.
# POR QUE DETECTA: lê a prop direto. É IRMÃ de ro.secure (690) e
# service.adb.root (691), mas distinta — cobre o ADB aceitar conexão não
# autorizada mesmo com ro.secure=1. Severidade = warn (igual ro.secure=0),
# pois há device eng legítimo; promova a alert se quiser rígido.
case "$(gp ro.adb.secure)" in
    0) warn "ro.adb.secure=0 (ADB sem autenticação RSA — build eng/adulterada)" ;;
esac
# ════════════════════════════ FIM MÓDULO 1 ═══════════════════════════════

# ════════════════════════════════════════════════════════════════════════
#  MÓDULO 2 (v4.4.91) — Auditoria de MOUNTS (root-hide / magic-mount)
#  ADITIVO: o scanner só lia /proc/mounts pra TIPO de FS (~linha 176).
#  Aqui varremos /proc/mounts E /proc/self/mountinfo atrás dos rastros que
#  Magisk / KernelSU / APatch deixam ao se montar por cima do sistema.
#
#  COMO O ATACANTE USA: pra ter root sem reflashar partição, esses frameworks
#  fazem BIND-MOUNT / overlay por cima de /system, /vendor etc. (a "magic
#  mount" do Magisk; overlayfs de módulos no KSU). Assim injetam su/módulos e
#  ESCONDEM o root — mas todo mount aparece na tabela de mounts do kernel.
#  POR QUE 2 ARQUIVOS: /proc/mounts é o alvo nº1 de spoof (susfs FILTRA ele
#  pra sumir com as linhas). /proc/self/mountinfo é mais rico (mount-id,
#  parent-id, fonte do mount, relação de bind) e mais difícil de limpar 100%
#  de forma consistente — um rastro some de um e sobra no outro. Lemos OS DOIS.
# ════════════════════════════════════════════════════════════════════════
header "MOUNTS / MAGIC-MOUNT (root-hide)"

# Assinaturas de mount dos frameworks de root-hide:
#   magisk         → mounts/worker dirs do Magisk
#   ksud / KSU     → daemon e overlay de módulos do KernelSU
#   overlayfs_loop → overlay de módulos via loop device (KSU/moderno)
#   .magic_mount   → diretório-fonte da "magic mount" do Magisk
#   patch_hw       → fonte de mount de frameworks de patch (APatch & cia).
#                    É a assinatura MAIS ambígua (alguns OEM têm mount "hw_*"):
#                    se um device limpo cair aqui por causa dela, mova patch_hw
#                    pra um tier de AVISO em vez de ALERTA.
# v4.4.95: 'ksu' ancorado com borda à DIREITA — `ksu([^[:alnum:]_]|$)` — porque o
#   token cru `KSU` sob `grep -iE` casava a substring 'ksu' DENTRO de 'journal_checksum'
#   (opção de mount ext4 PADRÃO), gerando "root-hide" FALSO em QUALQUER device ext4
#   limpo (Samsung etc.) e reprovando-o como SUSPEITO. A borda à direita exclui
#   'che(cksu)m' mas MANTÉM 'KSU', '/data/adb/ksu', 'zygisksu', 'ksu ' como fonte etc.
MNT_SIG='magisk|ksud|overlayfs_loop|ksu([^[:alnum:]_]|$)|\.magic_mount|patch_hw|meta_hybird|meta-hybrid'
MNT_FOUND=0; MNT_READ=0
for MF in /proc/mounts /proc/self/mountinfo; do
    [ -r "$MF" ] || continue
    MNT_READ=1
    # sem -a de propósito: os dois são texto puro; -a quebra em toybox antigo
    # e, com o 2>/dev/null, mataria o check silenciosamente.
    HITS=$(grep -iE "$MNT_SIG" "$MF" 2>/dev/null | head -n 4)
    if [ -n "$HITS" ]; then
        MNT_FOUND=1
        echo "$HITS" | while IFS= read -r LN; do
            [ -n "$LN" ] && alert "mount root-hide ($MF): $(echo "$LN" | cut -c1-120)"
        done
    fi
done
if   [ "$MNT_FOUND" = "1" ]; then KERNEL_HITS=$((KERNEL_HITS+1))
elif [ "$MNT_READ"  = "1" ]; then ok "Mounts limpos (sem rastro de magic-mount/overlay de root)"
else info "Tabela de mounts indisponível"; fi

# v4.4.94: Meta-Hybrid Mount / hide-mount framework (mais novo que Magisk Hide).
for P in /dev/meta_hybird_mnt /run/staging /run/stash /run/workdir; do
    [ -e "$P" ] && { alert "Meta-Hybrid/hide-mount framework: $P"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done
# ════════════════════════════ FIM MÓDULO 2 ═══════════════════════════════

# ════════════════════════════════════════════════════════════════════════
#  MÓDULO 3 (v4.4.91) — Blacklist forense de PATHS (cheat tools / loaders)
#  ADITIVO: paths em DISCO que os loops existentes não cobrem (eles pegam
#  su/ksu/magisk em /data/adb e os apps por PACOTE). Aqui é por arquivo.
#
#  COMO O ATACANTE USA: cada um é o rastro em disco de uma ferramenta:
#   Shizuku (dá poderes de ADB a apps sem root), HyperCeiler (mod de HyperOS),
#   WechatXposed (hook Xposed), Lucky Patcher (patch/bypass), APatch (root).
#  LIMITAÇÃO TERMUX — alcance REAL de cada path sob uid 2000 (shell ADB):
#   • /data/local/tmp/*   → uid 2000 lê/stat normalmente             (ok)
#   • /storage/emulated/0 → shared storage, uid 2000 lê              (ok)
#   • /data/local/luckys  → /data/local é 0751 (x p/ outros): stat ok (ok)
#   • /data/adb/*         → 0700 root:root → SEM root o check SEMPRE
#     dá "não existe". Só vale rodando COMO ROOT; aqui o APatch é
#     reforço redundante (/data/adb/ap já está na linha 540). Os vetores
#     reais de APatch são kallsyms + mount (Módulo 2).
# ════════════════════════════════════════════════════════════════════════
header "BLACKLIST DE PATHS (cheat tools / loaders)"

BL3_HITS=0
for ENTRY in \
    "/data/local/tmp/shizuku|Shizuku (escalonamento via ADB sem root)" \
    "/data/local/tmp/HyperCeiler|HyperCeiler (mod framework HyperOS/MIUI)" \
    "/storage/emulated/0/WechatXposed|WechatXposed (hook Xposed)" \
    "/data/local/luckys|Lucky Patcher / loader (patch/bypass)" \
    "/data/local/tmp/simpleHook|simpleHook (loader de hook nativo)" \
    "/data/local/tmp/byyang|byyang (loader de cheat)" \
    "/storage/emulated/0/xzr.hkf|xzr.hkf (config de cheat)" \
    "/storage/emulated/0/meow_detector.log|meow_detector (log de cheat/detector)" \
    "/data/adb/apatch|APatch (root via patch de kernel — só visível c/ root)"; do
    P=${ENTRY%%|*}; LBL=${ENTRY#*|}
    [ -e "$P" ] && { alert "Path blacklist: $P → $LBL"; BL3_HITS=$((BL3_HITS+1)); }
done
[ "$BL3_HITS" = "0" ] && ok "Nenhum path da blacklist de cheat-tools presente"
# ════════════════════════════ FIM MÓDULO 3 ═══════════════════════════════

# Módulos no /sys/module
if [ -d /sys/module ]; then
    # v4.4.103: 'ksu' ancorado (era grep cru → casava xt_CHECKSUM, módulo netfilter REAL do
    # alvo iptables/nft CHECKSUM, carregável em qualquer kernel GKI — 'che[cksu]m' sem fronteira).
    SUS_MODS=$(ls /sys/module 2>/dev/null | grep -iE '(^|[^a-zA-Z0-9_])(lib)?(frida|inject|hide|ksu|apatch|magisk|susfs)' | head -n 5)
    [ -n "$SUS_MODS" ] && echo "$SUS_MODS" | while IFS= read -r M; do
        [ -n "$M" ] && alert "Módulo kernel: /sys/module/$M"
    done
fi

# /proc/kallsyms (símbolos kernel - revela KernelSU/APatch ativo)
if [ -r /proc/kallsyms ]; then
    KALLSYMS_HITS=$(grep -wE 'apatch|ksu|ksu_init|susfs' /proc/kallsyms 2>/dev/null | head -n 3)
    if [ -n "$KALLSYMS_HITS" ]; then
        echo "$KALLSYMS_HITS" | while IFS= read -r L; do
            [ -n "$L" ] && alert "kallsyms: $L"
        done
        KERNEL_HITS=$((KERNEL_HITS+1))
    fi
fi

# dmesg (logs do kernel mencionam root)
if have dmesg; then
    DMESG_HITS=$(dmesg 2>/dev/null | grep -iE 'apatch|magisk|kernelsu|ksu_load' | head -n 3)
    if [ -n "$DMESG_HITS" ]; then
        echo "$DMESG_HITS" | while IFS= read -r L; do
            [ -n "$L" ] && alert "dmesg: $(echo "$L" | head -c 140)"
        done
        KERNEL_HITS=$((KERNEL_HITS+1))
    fi
    # v4.4.95: AVC denials de domínio root no log do kernel (§12.3 / Hunter
    # checkRootFromAVCLog). A TRANSIÇÃO de domínio de um processo root deixa rastro
    # de auditoria SELinux ('avc: denied' com scontext/tcontext de magisk/su/ksu)
    # difícil de limpar — pega root ATIVO mesmo com binário escondido. Ortogonal ao
    # grep por nome acima. Tokens curtos ANCORADOS p/ não casar substring benigna:
    # 'ksu' (:ksu:/ksu_file, não 'journal_checksum') e 'u:r:su:' (com ':' final — o
    # tipo SELinux é sempre seguido de ':s0' — p/ não casar 'u:r:surfaceflinger:s0',
    # onipresente no AVC de device limpo). Mesma classe de FP do PR #17/#18.
    DMESG_AVC=$(dmesg 2>/dev/null | grep -iE 'avc:[[:space:]]*denied' \
                | grep -iE 'magisk|kernelsu|:ksu:|ksu_file|u:r:su:|supolicy' | head -n 3)
    if [ -n "$DMESG_AVC" ]; then
        echo "$DMESG_AVC" | while IFS= read -r L; do
            [ -n "$L" ] && alert "AVC denied (domínio root no kernel log): $(echo "$L" | head -c 140)"
        done
        KERNEL_HITS=$((KERNEL_HITS+1))
    fi
fi

# yama ptrace
if [ -r /proc/sys/kernel/yama/ptrace_scope ]; then
    YAMA=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null)
    case "$YAMA" in
        0) alert "yama.ptrace_scope=0 (injeção liberada)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
        *) ok "yama.ptrace_scope=$YAMA" ;;
    esac
fi

# MIUI / HyperOS tampering
MIUI_VER=$(gp ro.miui.ui.version.name)
HOS_VER=$(gp ro.build.hyperos.version)
[ -n "$MIUI_VER" ] && info "MIUI version: $MIUI_VER"
[ -n "$HOS_VER" ] && info "HyperOS version: $HOS_VER"
[ "$(gp ro.miui.disable_dm_verity)" = "1" ] && alert "ro.miui.disable_dm_verity=1 (tampering MIUI)"
[ "$(gp persist.miui.disable_dm_verity)" = "1" ] && alert "persist.miui.disable_dm_verity=1"

[ "$KERNEL_HITS" = "0" ] && ok "Bootloader/kernel sem indícios"

# ============================================================
#  3. ROOT / SU / SUPERUSER (userland)
# ============================================================
header "ROOT / SU / SUPERUSER"

ROOT_HITS=0

# Paths su (todas variantes conhecidas + DuckDetector findings)
for P in /system/bin/su /system/xbin/su /sbin/su /system/sbin/su \
         /vendor/bin/su /su/bin/su /system/sd/xbin/su /data/magisk \
         /system/app/Superuser.apk /system/etc/init.d/99SuperSUDaemon \
         /cache/su /dev/su /system/usr/we-need-root /system/usr/we-need-root/su-backup \
         /system/xbin/daemonsu /system/xbin/busybox /system/bin/busybox \
         /system/bin/.ext /system/bin/.ext/.su /system/etc/.has_su_daemon /system/bin/.has_su \
         /system/bin/failsafe/su /system/su /system/xbin/mu \
         /data/local/bin/su /data/local/su /data/local/xbin/su /data/adb/su \
         /data/adb/ksu/bin/su /data/adb/ksu/ksud \
         /data/adb/ap/apd /data/adb/apd /data/adb/ap/bin/su \
         /data/adb/magisk/su /data/adb/magisk/.magisk/su \
         /data/adb/magisk/magiskd /data/adb/magiskd; do
    exists "$P" && { alert "Caminho su/root: $P"; ROOT_HITS=$((ROOT_HITS+1)); }
done

# Nomes de binário "su" disfarçado
for SU_VAR in su64 su32 su-back __su off.su Bksu susu su.sh supersu; do
    for D in /system/bin /system/xbin /sbin /vendor/bin /data/adb /data/local/tmp; do
        if exists "$D/$SU_VAR"; then
            alert "su disfarçado: $D/$SU_VAR"
            ROOT_HITS=$((ROOT_HITS+1))
        fi
    done
done

# Pacotes de root manager (lista expandida via DuckDetector 1.9.10)
for PKG in com.topjohnwu.magisk io.github.vvb2060.magisk io.github.huskydg.magisk \
           com.kingroot.kinguser com.kingo.root eu.chainfire.supersu \
           com.koushikdutta.superuser com.noshufou.android.su com.thirdparty.superuser \
           com.zachspong.temprootremovejb me.weishu.kernelsu com.rifsxd.ksunext \
           com.sukisu.ultra com.smedialink.oneclickroot \
           me.bmax.apatch com.dergoogler.mmrl \
           com.formyhm.hideroot com.devadvance.rootcloak com.devadvance.rootcloakplus \
           com.amphoras.hidemyroot com.amphoras.hidemyrootadfree com.yellowes.su \
           ru.fond3.installer stericson.busybox \
           com.zhiqupk.root.global org.checkroot.checkroot \
           com.googleplay.ndkvs \
           com.tsng.hidemyapplist com.tsng.pzyhrx.hma com.topmiaohan.hidebllist \
           com.houvven.guise com.houvven.impad com.lerist.fakelocation \
           com.zhufucyd.motion_emulator com.yuanwofei.cardemulator.pro \
           com.luckyzyx.luckytool com.mio.kitchen com.modify.installer com.junge.algorithmAidePro \
           com.fankes.tsbattery com.demo.serendipity com.didjdk.adbhelper \
           com.fkzhang.wechatxposed com.fuck.android.rimet com.hchai.rescueplan \
           com.hchen.appretention com.hchen.switchfreeform com.kooritea.fcmfix \
           com.nnnen.plusne com.omarea.vtools com.padi.hook.hookqq com.parallelc.micts \
           com.qq.qcxm com.rkg.IAMRKG com.sevtinge.hyperceiler com.syyf.quickpay \
           com.tencent.JYNB com.tencent.jingshi com.twifucker.hachidori com.wei.vip \
           com.wn.app.np com.xayah.databackup.foss com.apocalua.run com.byyoung.setting \
           com.bug.hookvip com.cshlolss.vipkill com.dna.tools com.coderstory.toolkit \
           com.chelpus.lackypatch \
           me.bingyue.IceCore me.gm.cleaner me.hd.wauxv me.iacn.biliroaming \
           me.teble.xposed.autodaily \
           io.github.libxposed io.github.qauxv io.va.exposed \
           io.github.a13e300.ksuwebui io.github.Retmon403.oppotheme \
           io.chaldeaprjkt.gamespace \
           com.elderdrivers.riru.edxp; do
    # v4.4.95: me.piebridge.brevent saiu desta lista (era ALERTA). Brevent virou
    # AVISO/REVISAR, tratado só no bloco PRIVILEGE ESCALATION (paridade c/ Shizuku).
    pkg_installed "$PKG" && { alert "App de root/hide/hook: $PKG"; ROOT_HITS=$((ROOT_HITS+1)); }
done

WHICH_SU=$(command -v su 2>/dev/null)
# v4.4.31: whitelist do `su` wrapper do Termux. Esse binário NÃO dá root real —
# é só um stub que chama `setpriv`/`exec` e falha em device stock. Só ajuda
# scripts a chamar comandos privilegiados QUANDO o device JÁ é rooted. Reportar
# como ROOT é falso positivo clássico — milhares de devices têm Termux instalado.
if [ -n "$WHICH_SU" ] && [ "$WHICH_SU" != "/usr/bin/su" ]; then
    case "$WHICH_SU" in
        /data/data/com.termux/files/usr/bin/su|*/com.termux/files/usr/bin/su)
            info "su wrapper do Termux em $WHICH_SU (não dá root, só stub)" ;;
        *)
            alert "Binário 'su' no PATH: $WHICH_SU"; ROOT_HITS=$((ROOT_HITS+1)) ;;
    esac
fi

case "$(gp ro.build.tags)" in
    *test-keys*) alert "build.tags=test-keys"; ROOT_HITS=$((ROOT_HITS+1)) ;;
esac

[ "$(gp ro.debuggable)" = "1" ] && warn "ro.debuggable=1"
[ "$(gp ro.secure)" = "0" ]     && warn "ro.secure=0"
[ "$(gp service.adb.root)" = "1" ] && alert "service.adb.root=1 (ADB com root!)"

[ "$ROOT_HITS" = "0" ] && ok "Sem sinal de root userland"

# ============================================================
#  4. MAGISK / LSPOSED MODULES (lista de módulos)
# ============================================================
header "MAGISK / LSPOSED / KSU MODULES"

MOD_HITS=0
for MODDIR in /data/adb/modules /data/adb/ksu/modules /data/adb/ap/modules; do
    if [ -d "$MODDIR" ]; then
        MODS=$(ls "$MODDIR" 2>/dev/null)
        [ -z "$MODS" ] && continue
        info "Módulos em $MODDIR:"
        echo "$MODS" | while IFS= read -r M; do
            [ -z "$M" ] && continue
            case "$M" in
                .core|core|.disable|update|.update|disable) ;;
                *shamiko*|*hide*|*denylist*|*frida*|*inject*|*lsposed*|*riru*|*zygisk*|*ssl*|*pinning*|*magiskhide*|*safetynet*|*tricky*|*pif*|*susfs*|*vector*|*hma_oss*|*playintegrityfork*|*zygisk_assist*|*zygisk_next*|*rezygisk*|*fakerunlocker*)
                    alert "Módulo suspeito: $M" ;;
                *) warn "Módulo: $M" ;;
            esac
        done
        MOD_HITS=1
    fi
done
# LSPosed modules.list
for L in /data/adb/lspd/config/modules.list /data/misc/lspd/config/modules.list; do
    if [ -r "$L" ]; then
        info "LSPosed modules ($L):"
        cat "$L" 2>/dev/null | while IFS= read -r LN; do
            [ -n "$LN" ] && warn "  $LN"
        done
        MOD_HITS=1
    fi
done
[ "$MOD_HITS" = "0" ] && ok "Sem módulos Magisk/LSPosed/KSU"

# TrickyStore keybox.xml — assinatura forte de Strong Integrity bypass (2026 threat intel)
for KBX in /data/adb/tricky_store/keybox.xml /data/adb/modules/tricky_store/keybox.xml \
           /data/adb/tricky_store/keybox /data/adb/tricky_store/persist; do
    if [ -r "$KBX" ] 2>/dev/null; then
        alert "TrickyStore keybox.xml detectado em $KBX"
        alert "Indicador forte de bypass PlayIntegrity Strong Integrity"
    fi
done

# Vector module (LSPosed rename 2026)
for VEC in /data/adb/modules/vector /data/adb/modules/jingmatrix_vector; do
    [ -d "$VEC" ] && alert "Vector module (LSPosed rename + Dobby) em $VEC"
done

# FFH4X / Panel FF / Teambot caches — Android cheat injectors 2026
for FFC in /sdcard/FFH4X /sdcard/Panel /sdcard/Teambot /sdcard/MSTeam /sdcard/NG_Injector /sdcard/TB71 /sdcard/OP999; do
    if [ -d "$FFC" ] 2>/dev/null; then
        alert "Cache de cheat injector: $FFC"
    fi
done

# Custom ROM detection (DuckDetector findings — ROMs custom = kernel modificável)
ROM_FRAMEWORKS="/system/framework/co.aospa.framework-res.apk /system/framework/crdroid-res.apk
                /system/framework/org.lineageos.platform-res.apk /system/framework/org.evolution.framework-res.apk
                /system/framework/org.pixelexperience.platform-res.apk
                /system/framework/oat/arm64/org.lineageos.platform.odex"
for RF in $ROM_FRAMEWORKS; do
    if exists "$RF"; then
        case "$RF" in
            *crdroid*)        warn "Custom ROM detectada: crDroid ($RF)" ;;
            *aospa*)          warn "Custom ROM detectada: AOSPA / Paranoid Android ($RF)" ;;
            *lineageos*)      warn "Custom ROM detectada: LineageOS ($RF)" ;;
            *evolution*)      warn "Custom ROM detectada: Evolution X ($RF)" ;;
            *pixelexperience*) warn "Custom ROM detectada: PixelExperience ($RF)" ;;
        esac
    fi
done

# Scene daemon (do DuckDetector — performance tweaker, sinal de ROM modificada)
for SCENE in /dev/scene /dev/cpuset/scene-daemon /dev/memcg/scene_active /dev/memcg/scene_idle; do
    exists "$SCENE" && warn "Scene daemon ativo: $SCENE (ROM tweaker)"
done

# MT Manager 2 / NP Manager paths (DuckDetector — reverse eng tools cache)
for MTNPDIR in /sdcard/MT2 /sdcard/NP /sdcard/xinhao /sdcard/Download/advanced; do
    if [ -d "$MTNPDIR" ] 2>/dev/null; then
        warn "Reverse eng cache dir: $MTNPDIR (MT/NP Manager footprint)"
    fi
done

# MIUI Backup hide vector (DG7 SS finding — Xiaomi backup folder = vetor de esconder cheats)
MIUI_BACKUP="/sdcard/MIUI/backup/AllBackup"
if [ -d "$MIUI_BACKUP" ] 2>/dev/null; then
    MIUI_FILES=$(find "$MIUI_BACKUP" -type f 2>/dev/null | wc -l)
    [ "$MIUI_FILES" -gt 0 ] && warn "MIUI Backup folder com $MIUI_FILES arquivos — possível vetor hide"
    # Binários suspeitos no backup
    SUS_BIN=$(find "$MIUI_BACKUP" -type f \( -iname "*.so" -o -iname "*.bin" -o -iname "*.dat" \) 2>/dev/null | head -5)
    [ -n "$SUS_BIN" ] && {
        alert "Binários suspeitos em MIUI Backup:"
        echo "$SUS_BIN" | while IFS= read -r LN; do alert "  $LN"; done
    }
    # Nomes suspeitos no backup
    # v4.4.98: tokens curtos genéricos (gg/mod/menu/esp/panel) casavam logging/.ogg/model/
    #   main_menu/settings_panel/response em backup LIMPO → SUSPEITO falso em todo MIUI.
    #   Mantidos só os inequívocos + idioma 'mod menu' e 'esp' ancorado (classe do #17/#18).
    SUS_NAMES=$(find "$MIUI_BACKUP" -type f 2>/dev/null | grep -iE 'cheat|hack|inject|aimbot|ffh4x|holograma|hologram|gameguardian|mod[_ -]?menu|modmenu|(^|[^a-z])esp([^a-z]|$)' | head -5)
    [ -n "$SUS_NAMES" ] && {
        alert "Arquivos com nome suspeito em MIUI Backup:"
        echo "$SUS_NAMES" | while IFS= read -r LN; do alert "  $LN"; done
    }
fi

# ============================================================
#  5. FRAMEWORKS DE HOOK (Frida / Xposed / LSPosed / LSPatch / Substrate)
# ============================================================
header "FRAMEWORKS DE HOOK"

HOOK_HITS=0
for P in /data/local/tmp/frida-server /data/local/tmp/re.frida.server \
         /data/local/tmp/frida /data/local/tmp/.frida \
         /system/lib/libfrida-gadget.so /system/lib64/libfrida-gadget.so \
         /data/local/tmp/libfrida-gadget.so /data/local/tmp/gadget.so \
         /data/local/tmp/frida-gadget.config; do
    exists "$P" && { alert "Frida: $P"; HOOK_HITS=$((HOOK_HITS+1)); }
done

if have ps; then
    # v4.4.95: removido o token cru 'gadget' do grep de PROCESSO — casava
    #   'android.hardware.usb.gadget-…' (HAL USB padrão MediaTek/AOSP) → CRÍTICO
    #   "Processo Frida" FALSO em todo device MTK (verdict-flipping). frida-gadget
    #   é LIB injetada, não processo: já é pega no scan de /proc/$FF_PID/maps
    #   (~l.1124). 'frida' cobre frida/frida-server/re.frida.server. Paridade c/ iOS.
    FPROC=$(ps -A 2>/dev/null | grep -i frida | grep -v grep)
    [ -z "$FPROC" ] && FPROC=$(ps 2>/dev/null | grep -i frida | grep -v grep)
    [ -n "$FPROC" ] && echo "$FPROC" | head -n 3 | while IFS= read -r L; do
        [ -n "$L" ] && alert "Processo Frida: $L"
    done
fi

if have netstat; then
    FPORT=$(netstat -an 2>/dev/null | grep -E ':27042|:27043|:27044|:27045')
    [ -n "$FPORT" ] && alert "Porta Frida em LISTEN"
fi

# Porta Frida via /proc/net/tcp (não precisa netstat)
if [ -r /proc/net/tcp ]; then
    # 27042 = 0xA992, 27043 = 0xA993
    FRIDA_HEX=$(awk '{print $2}' /proc/net/tcp 2>/dev/null | grep -E ':A99[2345]$' | head -n 1)
    [ -n "$FRIDA_HEX" ] && alert "Porta Frida em LISTEN (via /proc/net/tcp)"
fi

for PKG in de.robv.android.xposed.installer org.lsposed.manager \
           io.github.lsposed.manager org.meowcat.edxposed.manager \
           com.solohsu.android.edxp.manager org.lsposed.lspatch.manager \
           org.lsposed.lspatch com.saurik.substrate \
           io.github.mhmrdd.libxposed.ps.passit \
           com.frida.server com.github.iadb; do
    pkg_installed "$PKG" && { alert "Hook framework: $PKG"; HOOK_HITS=$((HOOK_HITS+1)); }
done

for P in /system/framework/XposedBridge.jar /system/lib/libxposed_art.so \
         /system/lib64/libxposed_art.so /data/misc/lspd /data/adb/lspd \
         /data/adb/modules/riru_lsposed /data/adb/modules/zygisk_lsposed \
         /system/lib/libsubstrate.so /system/lib64/libsubstrate.so; do
    exists "$P" && { alert "Path hook: $P"; HOOK_HITS=$((HOOK_HITS+1)); }
done

# Scripts Frida (.js) em /sdcard
if have find; then
    FJS=$(find /sdcard 2>/dev/null -maxdepth 4 -type f -name '*.js' 2>/dev/null | head -n 20)
    [ -n "$FJS" ] && echo "$FJS" | while IFS= read -r J; do
        [ -z "$J" ] && continue
        if grep -lqE 'Java\.perform|Interceptor\.attach|Module\.findExportByName|Frida' "$J" 2>/dev/null; then
            alert "Script Frida: $J"
        fi
    done
fi

[ "$HOOK_HITS" = "0" ] && ok "Sem framework de hook"

# ============================================================
#  5.5 DFIR DEEP FORENSICS (process inspection)
#  proc/maps, sockets, dumpsys, dropbox, comm/cmdline spoof
# ============================================================
header "DFIR DEEP — Process / Memory / Sockets / Crashes"

DFIR_HITS=0
FF_PID=$(pidof com.dts.freefireth 2>/dev/null);  FF_PKG_OPEN="com.dts.freefireth (normal)"
[ -z "$FF_PID" ] && { FF_PID=$(pidof com.dts.freefiremax 2>/dev/null); FF_PKG_OPEN="com.dts.freefiremax (MAX)"; }
# v4.4.98: status CLARO de Free Fire aberto/fechado — cobre normal (com.dts.freefireth)
# E max (com.dts.freefiremax). As varreduras em MEMÓRIA (maps/mountinfo/attr/status/net
# do PID) só valem com o jogo ABERTO; as de disco rodam de qualquer jeito. Contrato: se
# fechado, AVISA pra abrir — nunca dá "limpo" por não ter inspecionado a memória.
if [ -n "$FF_PID" ]; then
    ok "Free Fire ABERTO: $FF_PKG_OPEN — PID $FF_PID (varredura em memória habilitada)"
else
    warn "Free Fire FECHADO — ABRA o jogo (normal OU MAX) para a varredura em memória (maps/mountinfo/attr/status); os checks de disco seguem normalmente"
fi

# v4.4.94: Free Fire sob ptrace (debugger/Frida anexado ao processo do jogo).
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/status" ]; then
    TP=$(grep -m1 '^TracerPid:' "/proc/$FF_PID/status" 2>/dev/null | awk '{print $2}')
    case "$TP" in
        ""|0) ok "Free Fire não está sob ptrace (TracerPid=0)" ;;
        *)    alert "Free Fire TRACED por PID $TP ($(cat /proc/$TP/comm 2>/dev/null)) — debugger/Frida anexado"; DFIR_HITS=$((DFIR_HITS+1)) ;;
    esac
fi

# v4.4.95: Contexto SELinux do PROCESSO do FF — domínio de root é flagrante.
# COMO O ATACANTE USA: root (Magisk/KSU/APatch) que injeta no FF pode deixar o
# processo do jogo num domínio SELinux privilegiado (u:r:su:s0, *magisk*,
# *kernelsu*) em vez do esperado u:r:untrusted_app*. Permissive idem.
# POR QUE DETECTA: lê /proc/$FF_PID/attr/current (uid 2000 + grupo readproc) —
# ANTES o scanner só via o getenforce GLOBAL, nunca o contexto do processo do FF.
# HONESTIDADE/FP: contextos legítimos (untrusted_app/platform/priv/isolated/
# system) → silêncio; contexto DESCONHECIDO → só AVISO (revisar), não alerta.
# Fonte: docs/MAGISK_DETECTION_GAPS.md §4.3 (Duck su/self_process_ioc).
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/attr/current" ]; then
    FFCTX=$(tr -d '\0' < "/proc/$FF_PID/attr/current" 2>/dev/null)
    case "$FFCTX" in
        u:r:untrusted_app*|u:r:platform_app*|u:r:priv_app*|u:r:isolated_app*|u:r:system_app*|"") : ;;
        *:su:*|*magisk*|*kernelsu*|*adbroot*|*permissive*)
            alert "FF em contexto SELinux de ROOT: $FFCTX"; DFIR_HITS=$((DFIR_HITS+1)) ;;
        *)  warn "FF em contexto SELinux inesperado: $FFCTX (revisar)"; DFIR_HITS=$((DFIR_HITS+1)) ;;
    esac
fi

# v4.4.95: Free Fire rodando DENTRO de virtual-space (VMOS/X8/VPhoneGaGa/Parallel).
# COMO O ATACANTE USA: rodar o FF num CONTAINER de virtualização (app que clona/
# isola outro app) num celular REAL — roda GameGuardian/mods e multi-conta SEM
# root, escapando de detecção baseada em device. ESTE é o "emulador" que importa
# no mobile (≠ emulador de PC). A seção CLONE (adiante) acha o data-dir clonado EM
# DISCO; isto vê pela ÓTICA DO PROCESSO do FF (mountinfo/maps).
# POR QUE DETECTA: o FF virtualizado roda sob o data-path do HOST (ex.:
# /data/data/<host>/virtual/.../com.dts.freefireth) e carrega libs do virtualizador
# (libva++.so, libNimsWrap). HONESTIDADE/FP: Parallel/Island/dual-app têm uso
# legítimo (multi-conta de WhatsApp); por isso NÃO flagramos a mera presença do
# app — só o FF de fato rodando sob o data-path do host (sem uso legítimo) → ALERTA.
# Fonte: docs/MAGISK_DETECTION_GAPS.md §12.2 (VirtualApp/com.lody.virtual).
if [ -n "$FF_PID" ]; then
    VS_HIT=""
    if [ -r "/proc/$FF_PID/mountinfo" ]; then
        VS_HIT=$(grep -oE '/data/(data|user/[0-9]+)/[a-z0-9._]+' "/proc/$FF_PID/mountinfo" 2>/dev/null \
                 | grep -iE 'virtualapp|lody\.virtual|/virtual/|vphonegaga|lbe\.parallel|dualspace|x8zs|vmos|gspace|multiparallel' \
                 | sort -u | head -3)
    fi
    if [ -z "$VS_HIT" ] && [ -r "/proc/$FF_PID/maps" ]; then
        grep -qiE 'libva\+\+\.so|libNimsWrap|libhookzz|/virtual/data/' "/proc/$FF_PID/maps" 2>/dev/null \
            && VS_HIT="lib de virtual-space no maps do FF"
    fi
    [ -n "$VS_HIT" ] && { alert "Free Fire rodando DENTRO de virtual-space (não-físico): $(echo "$VS_HIT" | cut -c1-100)"; DFIR_HITS=$((DFIR_HITS+1)); }
fi

# ════════════════════════════════════════════════════════════════════════
#  v4.4.95 — MAGIC-MOUNT / NAMESPACE SPOOFING (visão isolada do FF × global)
#
#  COMO O ATACANTE USA: o Magisk "magic mount" (e KSU/APatch) NÃO reflasham
#  partição — eles fazem BIND/overlay POR CIMA de libs gráficas, do /system ou
#  da pasta do jogo, mas SÓ dentro do mount-namespace do processo-alvo. Assim o
#  FF carrega .so adulterada (wallhack/chams/shaders) enquanto o resto do sistema
#  enxerga os arquivos originais — o cheat fica invisível pra qualquer check da
#  visão GLOBAL. O Módulo 2 (linha ~605) varre a tabela GLOBAL (/proc/mounts,
#  /proc/self/mountinfo); ISTO é o complemento: compara a visão do FF com a
#  global e flagra o que SÓ existe no namespace do jogo.
#
#  SINAL PRIMÁRIO (o diff): mounts presentes em /proc/$FF_PID/mountinfo e AUSENTES
#  na visão global (/proc/1/mountinfo do init; fallback /proc/self/mountinfo) =
#  injetados via mount-namespace. Chaveamos por "mount-point + fonte" (campos 5 e
#  do tip/source após o separador " - "), que sobrevive a mount-id/parent-id
#  diferentes entre namespaces. Foco em mount SUSPEITO: overlay/bind sobre libs/
#  shaders/.so/system ou sobre a pasta de dados/obb do FF, e linhas batendo as
#  assinaturas de root-hide.
#  SINAL SECUNDÁRIO (assinatura): linha do mountinfo do FF batendo as keywords —
#  vale mesmo sem conseguir a visão global pra diff.
#
#  SEM ROOT PRIMEIRO: lê /proc/$FF_PID/mountinfo DIRETO (uid 2000 + grupo readproc,
#  igual o TracerPid acima). Root (se EXISTIR — checado com `have su`, nunca
#  assumido) entra só como ENRIQUECIMENTO: re-lê o mountinfo do FF via `su` caso o
#  uid 2000 tenha sido barrado por hidepid. Degrada com elegância: sem conseguir
#  ler → warn/info, NUNCA um "ok/limpo" falso.
# ════════════════════════════════════════════════════════════════════════
if [ -z "$FF_PID" ]; then
    warn "Namespace do FF não inspecionado — jogo fechado; ABRA o Free Fire para a varredura de magic-mount em memória"
elif [ -r "/proc/$FF_PID/mountinfo" ] || { have su && su -c "test -r /proc/$FF_PID/mountinfo" >/dev/null 2>&1; }; then
    # Assinaturas de mount de root-hide (paridade c/ o MNT_SIG do Módulo 2, +
    # caminhos do FF/libs gráficas que um overlay de cheat visual mira).
    # v4.4.95: 'ksu' ancorado à direita (mesmo motivo do MÓDULO 2 ~l.633: não casar
    #   mais 'ksu' dentro de 'journal_checksum'). '/data/adb' continua substring.
    NS_SIG='magisk|ksud|overlayfs_loop|ksu([^[:alnum:]_]|$)|\.magic_mount|patch_hw|meta_hybird|meta-hybrid|/data/adb'
    # Lê o mountinfo do FF SEM root; se vier vazio (hidepid) e houver su, re-lê c/ root.
    FF_MNT=$(cat "/proc/$FF_PID/mountinfo" 2>/dev/null)
    NS_SRC="uid 2000"
    if [ -z "$FF_MNT" ] && have su; then
        FF_MNT=$(su -c "cat /proc/$FF_PID/mountinfo" 2>/dev/null); NS_SRC="root (su)"
    fi
    # Visão GLOBAL p/ o diff: o init (PID 1) é o namespace-raiz; cai pro self se 1
    # não for legível sob uid 2000.
    GLOBAL_MI=/proc/1/mountinfo; [ -r "$GLOBAL_MI" ] || GLOBAL_MI=/proc/self/mountinfo

    if [ -z "$FF_MNT" ]; then
        warn "Não foi possível inspecionar o namespace do FF (mountinfo ilegível mesmo via $NS_SRC) — hidepid/SELinux; resultado INCONCLUSIVO, não 'limpo'"
    else
        # Chave estável por linha: "<mount-point> <- <source>" (campo 5 = ponto de
        # montagem; o token após " - <fstype> " = fonte). Imune a mount-id/parent
        # diferirem entre namespaces. Vira a "impressão digital" do mount p/ o diff.
        mi_keys() { awk '{ mp=$5; src="?"; for(i=6;i<=NF;i++) if($i=="-"){ src=(i+2<=NF?$(i+2):"?"); break } print mp" <- "src }' 2>/dev/null; }
        GLOBAL_KEYS=$(printf '%s\n' "$(cat "$GLOBAL_MI" 2>/dev/null)" | mi_keys | sort -u)

        # DIFF: linhas (chaves) do FF ausentes na global = injetadas no namespace.
        NS_ONLY=$(printf '%s\n' "$FF_MNT" | mi_keys | sort -u | { [ -n "$GLOBAL_KEYS" ] && grep -vxF "$GLOBAL_KEYS" || cat; })
        # Dentre as exclusivas do FF, fica só com as SUSPEITAS: overlay/bind sobre
        # libs/.so/shaders/system OU sobre a pasta do FF OU batendo root-hide.
        # v4.4.95: EXCLUI re-mounts BENIGNOS do namespace per-app — os dados/perfis do
        # PRÓPRIO FF vindos do MESMO storage real (/dev/block/dm-*/mmcblk*/sd*/ufs*) são
        # bind content-IDÊNTICO: o zygote isola cada app em mount-namespace e freezers
        # (ex.: Brevent) bindam o data dir. Mesma fonte real = mesmo conteúdo = NÃO
        # injeta nada. Injeção real vem de tmpfs/overlay/loop/arquivo//data/adb (segue
        # flagada). Sem isto, a pasta de dados LEGÍTIMA do FF caía como "magic-mount".
        NS_BENIGN='^/data/(data|user|user_de|misc/profiles)[^ ]*com\.dts\.freefire[^ ]* <- /dev/block/(dm-|mmcblk|sd|ufs)'
        NS_SUS=$(printf '%s\n' "$NS_ONLY" \
            | grep -iE "$NS_SIG|overlay|\.so( |\$)|/lib|shader|com\.dts\.freefire|/system/|/vendor/" \
            | grep -viE "$NS_BENIGN" \
            | grep -v '^[[:space:]]*$' | head -n 8)

        if [ -n "$NS_SUS" ] && [ -n "$GLOBAL_KEYS" ]; then
            alert "Magic-Mount: FF (PID $FF_PID) enxerga mount(s) AUSENTE(s) na visão global — injeção via mount-namespace [$NS_SRC]:"
            printf '%s\n' "$NS_SUS" | while IFS= read -r L; do [ -n "$L" ] && alert "  → ns-only: $(printf '%s' "$L" | cut -c1-120)"; done
            DFIR_HITS=$((DFIR_HITS+1))
        elif [ -z "$GLOBAL_KEYS" ]; then
            info "Visão global de mounts indisponível sob uid 2000 — diff de namespace pulado (usando só assinatura abaixo)"
        fi

        # SINAL SECUNDÁRIO: assinatura nas linhas do mountinfo do FF (independe do diff).
        NS_HITS=$(printf '%s\n' "$FF_MNT" | grep -iE "$NS_SIG" | head -n 4)
        if [ -n "$NS_HITS" ]; then
            alert "Mount de root-hide no namespace do FF (PID $FF_PID) [$NS_SRC]:"
            printf '%s\n' "$NS_HITS" | while IFS= read -r L; do [ -n "$L" ] && alert "  → $(printf '%s' "$L" | cut -c1-120)"; done
            DFIR_HITS=$((DFIR_HITS+1))
        fi

        # Só declara limpo quando REALMENTE deu pra comparar (global lida E sem hit).
        [ -z "$NS_SUS" ] && [ -z "$NS_HITS" ] && [ -n "$GLOBAL_KEYS" ] && \
            ok "Namespace do FF idêntico à visão global (sem magic-mount/overlay injetado) [$NS_SRC]"
    fi
else
    warn "Namespace do FF não inspecionado — /proc/$FF_PID/mountinfo ilegível sob uid 2000 e sem root; INCONCLUSIVO, não 'limpo'"
fi

# /proc/<FF>/maps — libs injetadas (Frida gadget, Substrate, Dobby, xhook, sandhook)
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/maps" ]; then
    # v4.4.102: `gadget` cru casava a HAL USB do MediaTek (Frida falso) → `frida-gadget`.
    INJECTED=$(grep -iE '(frida|frida-gadget|substrate|libdobby|libxhook|libgum|libwhale|libsandhook|libepic|libDexposed|libsubstitute|libellekit|libhooker)' "/proc/$FF_PID/maps" 2>/dev/null | awk '{print $6}' | sort -u | head -10)
    if [ -n "$INJECTED" ]; then
        alert "Libs INJETADAS no processo FF (PID $FF_PID):"
        echo "$INJECTED" | while IFS= read -r L; do [ -n "$L" ] && alert "  → $L"; done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
    # Sections com RWX (JIT inject típico de Frida/Substrate)
    RWX_COUNT=$(grep -c ' rwx[ps]' "/proc/$FF_PID/maps" 2>/dev/null || echo 0)
    if [ "$RWX_COUNT" -gt 5 ] 2>/dev/null; then
        warn "FF tem $RWX_COUNT sections RWX (JIT inject ou cheat dynamic patcher)"
        DFIR_HITS=$((DFIR_HITS+1))
    fi
    # Libs fora dos paths legítimos (sideload manual)
    SUS_LIB_PATHS=$(awk '$6!="" && $6!~/\/(system|apex|vendor|data\/app|data\/dalvik-cache|memfd|dev)/ {print $6}' "/proc/$FF_PID/maps" 2>/dev/null | sort -u | head -5)
    if [ -n "$SUS_LIB_PATHS" ]; then
        warn "Libs de paths não-legítimos no FF:"
        echo "$SUS_LIB_PATHS" | while IFS= read -r L; do [ -n "$L" ] && warn "  → $L"; done
    fi
    # v4.4.95: Zygisk/Riru/magic-mount + tradução de ISA (emulador) NO espaço do FF.
    # O regex acima (hooks clássicos) NÃO cobria zygisk/riru/libhoudini; e a lib
    # executável DELETADA (unlink pós-mmap) é persistência de injeção que escapa de
    # qualquer check por nome de arquivo. Fonte: docs/MAGISK_DETECTION_GAPS.md §4.2/§4.1.
    ZINJ=$(grep -iE 'libzygisk|zygisk_loader|libriru|riru_|/\.magisk/|/sbin/\.magisk|libhoudini|libndk_translation|libnb\.so' "/proc/$FF_PID/maps" 2>/dev/null | awk '{print $6}' | sort -u | head -8)
    if [ -n "$ZINJ" ]; then
        alert "Zygisk/Riru/tradução-ISA mapeado no FF (PID $FF_PID):"
        echo "$ZINJ" | while IFS= read -r L; do [ -n "$L" ] && alert "  → $L"; done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
    # Lib executável DELETADA = AVISO (FP raro em update de app mid-sessão), não alerta.
    DELX=$(awk '$2 ~ /x/ && /\.so \(deleted\)$/ {print $6}' "/proc/$FF_PID/maps" 2>/dev/null | sort -u | head -5)
    if [ -n "$DELX" ]; then
        warn "Lib executável DELETADA no FF (possível injeção residente pós-unlink):"
        echo "$DELX" | while IFS= read -r L; do [ -n "$L" ] && warn "  → $L"; done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
    # v4.4.95: Integridade do runtime Unity (libil2cpp.so). FF é Unity; GG/cheats
    # DUMPAM ou SUBSTITUEM a libil2cpp. NÃO flagramos a PRESENÇA (é runtime normal —
    # o scan de injeção acima a exclui de propósito); flagramos TAMPER: path anômalo
    # (fora do APK oficial) ou DUPLICATA. Ausência = só AVISO (timing: FF carregando).
    # Fonte: docs/MAGISK_DETECTION_GAPS.md §12.1.
    IL2=$(awk '/libil2cpp\.so$/{print $6}' "/proc/$FF_PID/maps" 2>/dev/null | sort -u)
    if [ -z "$IL2" ]; then
        # FP real-device: só vira AVISO se o FF estiver de fato carregado como Unity (libunity
        # mapeada) mas SEM il2cpp = anomalia real; senão é só timing (FF abrindo) → info silencioso.
        if grep -qE 'libunity\.so' "/proc/$FF_PID/maps" 2>/dev/null; then
            warn "FF com libunity.so mas SEM libil2cpp.so — runtime Unity possivelmente adulterado"
        else
            info "FF sem libil2cpp.so mapeada (jogo ainda carregando ou não em primeiro plano)"
        fi
    else
        echo "$IL2" | grep -vqE '/data/app/.*com\.dts\.freefire' \
            && { alert "libil2cpp.so de path ANÔMALO no FF: $(echo $IL2)"; DFIR_HITS=$((DFIR_HITS+1)); }
        [ "$(echo "$IL2" | grep -c .)" -gt 1 ] \
            && { alert "Múltiplas libil2cpp.so no FF (runtime Unity substituído): $(echo $IL2)"; DFIR_HITS=$((DFIR_HITS+1)); }
    fi
fi

# /proc/net/unix — abstract socket @frida (signature estável Frida server)
FRIDA_SOCKETS=$(cat /proc/net/unix 2>/dev/null | grep -iE '@(frida|gum-js|linjector)' | head -5)
if [ -n "$FRIDA_SOCKETS" ]; then
    alert "Frida abstract socket ATIVO em /proc/net/unix:"
    echo "$FRIDA_SOCKETS" | while IFS= read -r L; do alert "  $L"; done
    DFIR_HITS=$((DFIR_HITS+1))
fi

# Threads do FF com nomes Frida (gum-js-loop, gmain, pool-frida-*)
if [ -n "$FF_PID" ] && [ -d "/proc/$FF_PID/task" ]; then
    FRIDA_THREADS=$(for T in /proc/$FF_PID/task/*/comm; do cat "$T" 2>/dev/null; done | grep -iE '^(gum-js-loop|gmain|pool-frida|linjector|frida)' | head -5)
    if [ -n "$FRIDA_THREADS" ]; then
        alert "Threads de Frida/Gum encontradas no FF:"
        echo "$FRIDA_THREADS" | sort -u | while IFS= read -r L; do alert "  thread=$L"; done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
fi

# /proc/<pid>/comm vs cmdline spoof check (MagiskHide-style hidden processes)
SPOOF_PROCS=""
for P in /proc/[0-9]*; do
    [ -r "$P/comm" ] || continue
    COMM=$(cat "$P/comm" 2>/dev/null)
    CMD=$(cat "$P/cmdline" 2>/dev/null | tr '\0' ' ' | awk '{print $1}')
    [ -z "$COMM" ] || [ -z "$CMD" ] && continue
    CMD_BIN=$(basename "$CMD" 2>/dev/null)
    # FP real-device: comm benignos do Android — zygote/app_process usam comm 'main';
    # serviços de sistema (statsd/netd/…) renomeiam o líder p/ 'binder:PID_N'/'HwBinder:…'.
    # Sem isto, zygote/zygote64/statsd/netd caíam como "spoof" em TODO scan limpo.
    case "$COMM" in
        main|Binder:[0-9]*|binder:[0-9]*|HwBinder:[0-9]*|hwbinder:[0-9]*) continue ;;
    esac
    # Mismatch: comm não é SUBSTRING do cmdline binname.
    # FP real-device (v4.4.99): o kernel limita comm a 15 chars (TASK_COMM_LEN) e o Android
    # costuma deixar os ÚLTIMOS 15 do nome do pacote — ex.: cmd=com.instagram.android →
    # comm=stagram.android; com.anydesk.anydeskandroid → .anydeskandroid; com.android.htmlviewer:remote
    # → mlviewer:remote. Como comm vira SUFIXO (não prefixo) do cmdline, o antigo "$COMM"* não
    # casava → falso "spoof". Agora comm é benigno se for SUBSTRING do cmdline (prefixo/sufixo/meio
    # = só truncamento). Spoof real tem comm que NÃO aparece no cmdline (continua flagrado).
    case "$CMD_BIN" in
        *"$COMM"*|kworker*|kthread*|init|swapper*|systemd*) ;;
        *) [ "${#COMM}" -gt 3 ] && [ "${#CMD_BIN}" -gt 3 ] && \
           SPOOF_PROCS="$SPOOF_PROCS
pid=$(basename $P) comm=$COMM cmd=$CMD_BIN" ;;
    esac
done
SPOOF_LIST=$(echo "$SPOOF_PROCS" | head -5 | grep -v '^$')
if [ -n "$SPOOF_LIST" ]; then
    echo "$SPOOF_LIST" | while IFS= read -r L; do
        [ -n "$L" ] && warn "Process comm≠cmdline (spoof?): $L"
    done
fi

# /proc/<pid>/cgroup — cheat process executando em uid_2000 (adb shell)
ADB_PROCS=$(grep -l 'uid_2000' /proc/[0-9]*/cgroup 2>/dev/null | head -5)
if [ -n "$ADB_PROCS" ]; then
    echo "$ADB_PROCS" | while IFS= read -r CGFILE; do
        PID=$(echo "$CGFILE" | sed 's|/proc/||;s|/cgroup||')
        CMD=$(cat "/proc/$PID/cmdline" 2>/dev/null | tr '\0' ' ' | head -c 120)
        [ -z "$CMD" ] && continue
        # FP real-device (v4.4.99): daemons de SISTEMA rodam em uid_2000 por design (MTK/Xiaomi:
        # connsyslogger/emdlogger/lbs_dbg_ext/netdiag em /system_ext/bin), e o PRÓPRIO scanner/
        # adb-shell roda 'sh' em uid_2000. Antes flagrava todos → falso positivo em massa. Agora
        # só flagra binário FORA das partições do sistema e que não seja shell/scanner — ex.:
        # cheat dropado em /data/local/tmp e executado como shell uid 2000.
        CMD0=${CMD%% *}
        case "$CMD0" in
            /system/*|/system_ext/*|/vendor/*|/apex/*|/product/*|/odm/*|/oem/*) continue ;;
            sh|*/sh|mksh|*/mksh|toybox|*/toybox|toolbox|*/toolbox|*a4ther*) continue ;;
        esac
        warn "Process em uid_2000 (ADB shell forked): pid=$PID cmd=$CMD"
    done
fi

# Dropbox crash history (persiste mais que tombstones)
if [ -d /data/system/dropbox ]; then
    DROPBOX_CHEAT=$(ls /data/system/dropbox/system_app_*crash* /data/system/dropbox/system_app_*anr* 2>/dev/null | head -10 | while IFS= read -r F; do
        [ -z "$F" ] && continue
        grep -lE '(libfrida|libsubstrate|libdobby|libxhook|libgum|libsandhook|libwhale)' "$F" 2>/dev/null
    done)
    if [ -n "$DROPBOX_CHEAT" ]; then
        echo "$DROPBOX_CHEAT" | while IFS= read -r F; do
            [ -n "$F" ] && alert "Crash histórico (dropbox) com libs cheat: $(basename $F)"
        done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
fi

# logcat ring buffer crash (window curto mas alta confidence)
if have logcat; then
    LOGCAT_CHEAT=$(timeout 5 logcat -d -b crash 2>/dev/null | grep -iE '(libfrida|libsubstrate|libdobby|libxhook|gum-js|FATAL.*com\.dts\.freefire|injector\.so|tweak\.so)' | head -5)
    if [ -n "$LOGCAT_CHEAT" ]; then
        echo "$LOGCAT_CHEAT" | while IFS= read -r L; do alert "logcat crash: $(echo "$L" | head -c 150)"; done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
fi

# dumpsys window — overlays ativos POR CIMA do FF (ESP/aimbot draw)
if have dumpsys; then
    OVERLAYS=$(dumpsys window windows 2>/dev/null | awk '/Window #/,/mOwnerUid/' | grep -E '(mPackage|TYPE_APPLICATION_OVERLAY|TYPE_PHONE)' 2>/dev/null | head -20)
    if [ -n "$OVERLAYS" ]; then
        # v4.4.103: 'mod' cru → 'modmenu' (linha traz mPackage=com.pacote.completo; 'mod'
        # cru casaria com.motorola.mod*/modulemetadata como overlay suspeito).
        SUS_OVR=$(echo "$OVERLAYS" | grep -iE 'panel|injector|ffh4x|modmenu|cheat|esp|gameguardian|teambot|vipkill|fatality' | head -3)
        [ -n "$SUS_OVR" ] && echo "$SUS_OVR" | while IFS= read -r L; do alert "Overlay SUSPEITO: $L"; done
    fi
    # appops SYSTEM_ALERT_WINDOW granted pra apps random (não-system)
    APPOPS_DRAW=$(dumpsys appops 2>/dev/null | awk '/SYSTEM_ALERT_WINDOW: allow/' RS= ORS= | grep -B5 'SYSTEM_ALERT_WINDOW: allow' 2>/dev/null | head -30)
    if [ -n "$APPOPS_DRAW" ]; then
        # Lista os pacotes com permissão
        PKGS_WITH_OVERLAY=$(dumpsys appops 2>/dev/null | grep -B100 'SYSTEM_ALERT_WINDOW: allow' | grep -E '^[a-zA-Z0-9_\.]+\s*:\s*\(uid=' 2>/dev/null | awk '{print $1}' | sort -u | head -10)
        echo "$PKGS_WITH_OVERLAY" | while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            # v4.4.100: era whitelist de NAMESPACE cru (com.miui.*/com.samsung.*...), FORJÁVEL —
            # cheat renomeado p/ com.miui.overlay casava e escapava (mesma classe do fix Fable-5/
            # sideload). Agora libera só preload de sistema NÃO-FORJÁVEL (is_oem_preload: partição /
            # pkgFlags SYSTEM / `pm -s`); OEM real segue benigno, disfarce cai no warn.
            case "$PKG" in
                com.dts.freefiremax|com.dts.freefireth|android) ;;   # FF + framework
                *)
                    is_oem_preload "$PKG" "" "$(pm path "$PKG" 2>/dev/null | head -1 | sed 's/^package://')" \
                        || warn "App com permissão SYSTEM_ALERT_WINDOW (overlay): $PKG" ;;
            esac
        done
    fi
    # v4.4.55: MANAGE_EXTERNAL_STORAGE granted pra apps non-system — vetor
    # principal do Holograma e cheats de "patch in-place" do FF (precisam dessa
    # permissão pra editar arquivos em /sdcard/Android/data/<FF>/ e /obb/).
    # Android 11+ marcou essa permissão como "sensitive" — usuário tem que ir
    # em Settings → Special access → All files access pra habilitar. Whitelist
    # só inclui apps que tem motivo legítimo (file managers, editores).
    APPOPS_STORAGE=$(dumpsys appops 2>/dev/null | grep -B100 'MANAGE_EXTERNAL_STORAGE: allow' | grep -E '^[a-zA-Z0-9_\.]+\s*:\s*\(uid=' 2>/dev/null | awk '{print $1}' | sort -u | head -20)
    if [ -n "$APPOPS_STORAGE" ]; then
        echo "$APPOPS_STORAGE" | while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            # v4.4.101: file managers/editores 3rd-party LEGÍTIMOS (não-system) por NOME EXATO.
            case "$PKG" in
                com.mi.android.globalFileexplorer|com.alphainventor.filemanager|\
                com.amaze.filemanager|com.simplemobiletools.filemanager|com.android.documentsui|\
                com.termux|org.lsposed.manager|me.zhanghai.android.files|\
                org.jellyfin.mobile|org.videolan.vlc|com.estrongs.android.pop|\
                com.lonelycatgames.Xplore|com.solidexplorer2) continue ;;
            esac
            # v4.4.101: a whitelist de NAMESPACE OEM crua (com.miui.*/com.samsung.android.*...) era
            # FORJÁVEL e SOMBREAVA o alerta de cheat conhecido (com.miui.hologram era liberado ANTES
            # do *hologram*). Agora: preload de sistema REAL (is_oem_preload) libera — rodando ANTES
            # dos tokens de cheat, protege app de sistema legítimo do *panel*/*hologram*; disfarce
            # em namespace de fábrica (/data, sem lastro) cai no alerta/warn abaixo.
            is_oem_preload "$PKG" "" "$(pm path "$PKG" 2>/dev/null | head -1 | sed 's/^package://')" && continue
            case "$PKG" in
                # Cheat-related KNOWN: alert imediato (não mais sombreado pela whitelist OEM)
                *holograma*|*hologram*|*ffh4x*|*aimbot*|*cheat*|*injector*|*modbibi*|*xyzapk*|*modcombo*|*panel*)
                    alert "App SUSPEITO com MANAGE_EXTERNAL_STORAGE (edita /Android/data do FF): $PKG" ;;
                # Outros 3rd party não-system: warn (pode ser legítimo, mas atípico)
                *)
                    warn "App não-system com MANAGE_EXTERNAL_STORAGE: $PKG (verifica se edita pasta do FF)" ;;
            esac
        done
    fi
fi

# /data/system/usagestats — qual app antes/depois do FF (sequence forense)
if [ -d /data/system/usagestats/0/daily ]; then
    SUS_RECENT=$(ls -t /data/system/usagestats/0/daily/ 2>/dev/null | head -3 | while IFS= read -r F; do
        strings "/data/system/usagestats/0/daily/$F" 2>/dev/null
    done | grep -iE '(gameguardian|catch.me.if.you.can|lulubox|virtualxposed|panel|injector|ffh4x|mod.menu|cheat.panel|lsposed|magisk)' | sort -u | head -10)
    if [ -n "$SUS_RECENT" ]; then
        echo "$SUS_RECENT" | while IFS= read -r L; do alert "Usagestats — app cheat usado recentemente: $L"; done
        DFIR_HITS=$((DFIR_HITS+1))
    fi
fi

# pm dump installerPackageName + initiatingPackageName (Android 11+ revela installer real)
for PKG in com.dts.freefireth com.dts.freefiremax; do
    if pkg_installed "$PKG"; then
        DUMP_INST=$(pm dump "$PKG" 2>/dev/null | grep -E 'installerPackageName|initiatingPackageName|originatingPackageName')
        if [ -n "$DUMP_INST" ]; then
            INITIATING=$(echo "$DUMP_INST" | grep initiatingPackageName | sed 's/.*=//')
            INSTALLER=$(echo "$DUMP_INST" | grep installerPackageName | sed 's/.*=//')
            # Real installer (initiating) deve ser Play Store
            case "$INITIATING" in
                com.android.vending|com.google.market) ok "  $PKG initiatingPackageName: $INITIATING (Play Store legit)" ;;
                ""|"null") warn "  $PKG initiatingPackageName VAZIO" ;;
                *) alert "  $PKG REAL installer (initiating): $INITIATING ≠ Play Store" ;;
            esac
            # Spoof check: installer != initiating = renomeado
            if [ -n "$INSTALLER" ] && [ -n "$INITIATING" ] && [ "$INSTALLER" != "$INITIATING" ]; then
                alert "  $PKG installerPackageName ($INSTALLER) ≠ initiatingPackageName ($INITIATING) — REAL installer foi spoofed"
            fi
        fi
        # MD5 do APK base — flag se diferir da release oficial Garena (allowlist no scanner)
        APK_BASE=$(pm path "$PKG" 2>/dev/null | head -1 | sed 's|package:||')
        if [ -f "$APK_BASE" ] && have md5sum; then
            APK_MD5=$(md5sum "$APK_BASE" 2>/dev/null | awk '{print $1}')
            info "  $PKG APK MD5: $APK_MD5 ($APK_BASE)"
            # NOTE: pra production manter allowlist de MD5 oficial Garena por release
        fi
    fi
done

# /data/misc/profiles/cur/0/com.dts.freefireth/primary.prof — execution profile alterado
for PKG in com.dts.freefireth com.dts.freefiremax; do
    PROFFILE="/data/misc/profiles/cur/0/$PKG/primary.prof"
    if [ -r "$PROFFILE" ]; then
        PROF_MOD=$(stat -c '%Y' "$PROFFILE" 2>/dev/null)
        APK_BASE_PATH=$(pm path "$PKG" 2>/dev/null | head -1 | sed 's|package:||')
        if [ -n "$PROF_MOD" ] && [ -f "$APK_BASE_PATH" ]; then
            APK_MOD=$(stat -c '%Y' "$APK_BASE_PATH" 2>/dev/null)
            if [ -n "$APK_MOD" ]; then
                # Profile mais recente que APK por > 1 dia = AOT rewritten (mod alterou hot methods)
                DIFF_DAYS=$(( (PROF_MOD - APK_MOD) / 86400 ))
                if [ "$DIFF_DAYS" -gt 1 ] 2>/dev/null; then
                    warn "  $PKG primary.prof reescrito $DIFF_DAYS dias após APK install (AOT profile altered)"
                fi
            fi
        fi
    fi
done

[ "$DFIR_HITS" = "0" ] && ok "DFIR deep: sem libs/sockets/crashes de hook"

# ============================================================
#  6. ESCALAÇÃO DE PRIVILÉGIO sem-root (Shizuku / Brevent / Hunter)
# ============================================================
header "PRIVILEGE ESCALATION (Shizuku / Brevent / Hunter)"

PRIV_HITS=0
# Brevent - congela processos (pode mascarar detecção). v4.4.95: REVISAR (warn), não
# SUSPEITO — gerenciador via ADB/shell != cheat; paridade c/ Shizuku abaixo (decisão do dono).
for PKG in com.oasisfeng.brevent me.piebridge.brevent; do
    pkg_installed "$PKG" && { warn "Brevent (freeze de processos — pode mascarar detecção): $PKG"; PRIV_HITS=$((PRIV_HITS+1)); }
done
exists /data/local/tmp/brevent.sh && { warn "Brevent script: /data/local/tmp/brevent.sh (revisar contexto)"; PRIV_HITS=$((PRIV_HITS+1)); }
exists /data/data/com.oasisfeng.brevent && { warn "Brevent data dir presente (revisar contexto)"; PRIV_HITS=$((PRIV_HITS+1)); }
exists /data/data/me.piebridge.brevent && { warn "Brevent (piebridge) data dir (revisar contexto)"; PRIV_HITS=$((PRIV_HITS+1)); }

# Shizuku - dá permissões de ADB pro app
for PKG in moe.shizuku.privileged.api com.shizuku.manager rikka.shizuku.api; do
    pkg_installed "$PKG" && { warn "Shizuku: $PKG (permite escalação)"; PRIV_HITS=$((PRIV_HITS+1)); }
done
# Porta Shizuku 6573
if [ -r /proc/net/tcp ]; then
    # 6573 = 0x19B5
    SHIZ_HEX=$(awk '{print $2}' /proc/net/tcp 2>/dev/null | grep -E ':19B5$' | head -n 1)
    [ -n "$SHIZ_HEX" ] && alert "Porta Shizuku 6573 em LISTEN"
fi
if have netstat; then
    SHIZ=$(netstat -an 2>/dev/null | grep -E '127\.0\.0\.1:6573')
    [ -n "$SHIZ" ] && alert "Shizuku LISTEN em 127.0.0.1:6573"
fi

# Hunter (Shizuku abuse para mod)
pkg_installed com.zhenxi.hunter && { alert "Hunter (abuso de Shizuku): com.zhenxi.hunter"; PRIV_HITS=$((PRIV_HITS+1)); }

# Hack & Debug (sisik)
pkg_installed eu.sisik.hackendebug && { alert "Hack & Debug: eu.sisik.hackendebug"; PRIV_HITS=$((PRIV_HITS+1)); }

# v4.4.95: daemon ROOT 'shelld' — NÃO é daemon AOSP padrão (init/vold/netd/logd/zygote…).
# Pode ser shell root persistente disfarçado. REVISAR (não confirma cheat). Triagem
# manual: binário em /proc/<pid>/exe e o init .rc que define o serviço
# (grep -rn shelld /system/etc/init /vendor/etc/init /odm/etc/init /system_ext/etc/init).
# FP real-device (v4.4.99): em Xiaomi/MIUI 'shelld' é daemon de SISTEMA (gestão de shell/power),
# com binário em partição de sistema E declarado por um init .rc OEM → benigno (dava AVISO falso
# em todo Xiaomi). uid 2000 NÃO lê /proc/<root>/exe, então resolvemos o caminho por cmdline e,
# como rede de segurança, vemos se algum init .rc de sistema declara o serviço. Só alerta se o
# binário estiver FORA das partições do sistema (ex.: /data/local/tmp = shell root disfarçado).
SHELLD_PIDS=$(ps -A 2>/dev/null | awk '$1=="root" && $NF=="shelld"{print $2}')
[ -z "$SHELLD_PIDS" ] && SHELLD_PIDS=$(ps 2>/dev/null | awk '$1=="root" && $NF=="shelld"{print $2}')
SHELLD_RC=$(grep -rl shelld /system/etc/init /system_ext/etc/init /vendor/etc/init /odm/etc/init /product/etc/init 2>/dev/null | head -1)
for SP in $SHELLD_PIDS; do
    SP_PATH=$(readlink "/proc/$SP/exe" 2>/dev/null)
    [ -z "$SP_PATH" ] && { SP_PATH=$(tr '\0' ' ' < "/proc/$SP/cmdline" 2>/dev/null); SP_PATH=${SP_PATH%% *}; }
    case "$SP_PATH" in
        /system/*|/system_ext/*|/vendor/*|/odm/*|/product/*|/apex/*) continue ;;  # binário de sistema = OEM benigno
        /data/*|/sdcard/*|/storage/*) ;;                                          # fora do sistema = sempre alerta
        *) [ -n "$SHELLD_RC" ] && continue ;;                                      # caminho indeterminado: init .rc de sistema declara → benigno
    esac
    warn "Daemon root 'shelld' (PID $SP) — daemon de shell nao-padrao FORA de partição de sistema; revisar /proc/$SP/exe e o init .rc que o define"
    PRIV_HITS=$((PRIV_HITS+1))
done

[ "$PRIV_HITS" = "0" ] && ok "Sem ferramenta de escalação"

# ============================================================
#  7. INTEGRITY BYPASS (PIF / TrickyStore / detectors)
# ============================================================
header "INTEGRITY BYPASS (PIF / TrickyStore)"

PIF_HITS=0
for PKG in es.chiteroman.playintegrityfix com.chiteroman.playintegrityfix \
           io.github.vvb2060.mahoshojo \
           com.reveny.nativecheck com.studio.duckdetector \
           io.github.huskydg.memorydetector; do
    pkg_installed "$PKG" && { alert "Integrity bypass: $PKG"; PIF_HITS=$((PIF_HITS+1)); }
done
# v4.4.94: módulos de spoof de atestação (forjam locked/genuine p/ Play Integrity).
for ENTRY in \
    "/data/adb/modules/bootloaderspoofer|BootloaderSpoofer (forja bootloader LOCKED)" \
    "/data/adb/modules/keystoreinjector|KeystoreInjector (injeta keybox no Keystore)" \
    "/data/adb/keystoreinjector|KeystoreInjector (config)"; do
    P=${ENTRY%%|*}; LBL=${ENTRY#*|}
    [ -e "$P" ] && { alert "Spoof de atestação: $P → $LBL"; PIF_HITS=$((PIF_HITS+1)); }
done
[ "$PIF_HITS" = "0" ] && ok "Sem PIF/TrickyStore"

# ============================================================
#  8. FREE FIRE - INSTALAÇÃO + APK + WRAPPER/CRACKED
# ============================================================
header "FREE FIRE (instalação + APK + wrapper)"

FF_FOUND=0
for PKG in $FF_PKGS; do
    if pkg_installed "$PKG"; then
        FF_FOUND=1
        info "Instalado: $PKG"
        APK_PATH=$(pm path "$PKG" 2>/dev/null | head -n1 | sed 's/^package://')
        info "  APK: $APK_PATH"
        case "$APK_PATH" in
            /system/app/*|/system/priv-app/*) alert "  APK em /system (incomum)" ;;
            /data/app/*) ok "  APK em /data/app" ;;
        esac
        if have dumpsys; then
            DUMP=$(dumpsys package "$PKG" 2>/dev/null)
            VER=$(echo "$DUMP" | grep -m1 versionName | sed 's/.*versionName=//')
            VCODE=$(echo "$DUMP" | grep -m1 versionCode | awk '{print $1}' | sed 's/.*versionCode=//')
            FIRST=$(echo "$DUMP" | grep -m1 firstInstallTime | sed 's/.*firstInstallTime=//')
            UPD=$(echo "$DUMP" | grep -m1 lastUpdateTime | sed 's/.*lastUpdateTime=//')
            INST=$(echo "$DUMP" | grep -m1 installerPackageName | sed 's/.*installerPackageName=//')
            [ -n "$VER" ]   && info "  versão:    $VER ($VCODE)"
            [ -n "$FIRST" ] && info "  install:   $FIRST"
            [ -n "$UPD" ]   && info "  update:    $UPD"
            [ -n "$INST" ]  && info "  installer: $INST"
            # v4.4.91: match por OB. Compara só major.OB (${VER%.*} = tira o último
            # segmento .patch), pois a Garena solta hotfix de patch direto e o match
            # EXATO (v4.4.89) quebrava a cada release. OB diferente = jogo desatualizado
            # ou modificado → não passa como "ok". (${X%.*} = remove o MENOR sufixo
            # ".algo" do fim: "2.124.1" → "2.124"; usa % simples, não %% que daria "2".)
            if [ -n "$VER" ]; then
                _EXP=""
                case "$PKG" in
                    com.dts.freefiremax) _EXP="$EXPECTED_FFMAX_VER" ;;
                    com.dts.freefireth)  _EXP="$EXPECTED_FF_VER" ;;
                esac
                if [ -n "$_EXP" ]; then
                    if [ "${VER%.*}" = "${_EXP%.*}" ]; then
                        ok "  versão $VER (OB ${VER%.*}) == OB esperada (${_EXP%.*}) — atual"
                    else
                        warn "  versão $VER (OB ${VER%.*}) ≠ OB esperada (${_EXP%.*}) — FF desatualizado ou modificado (conferir Garena)"
                    fi
                fi
            fi
            # Verificação crítica: Free Fire deve vir da Play Store (com.android.vending)
            case "$INST" in
                com.android.vending)
                    ok "  origem: PLAY STORE (com.android.vending) - OFICIAL" ;;
                *vending*)
                    ok "  origem: Play Store (variante: $INST)" ;;
                *google*)
                    ok "  origem: Google ($INST)" ;;
                *xapk*|*apkpure*|*aptoide*|*uptodown*|*aurora*)
                    alert "  ORIGEM NAO OFICIAL: $INST - APK fora da Play Store (reprovar)" ;;
                bin.mt.plus)
                    alert "  ORIGEM = MT Manager - APK modificado/sideload (reprovar)" ;;
                *com.android.shell*|*adb*)
                    alert "  ORIGEM = adb shell - sideload via debug (reprovar)" ;;
                "null"|"")
                    alert "  ORIGEM = null - sideload manual, NAO veio da Play Store (reprovar)" ;;
                *)
                    alert "  ORIGEM DESCONHECIDA ($INST) - NAO eh Play Store (reprovar)" ;;
            esac
            # wrapper / cracked / modded / lsposed em dump (LSPatch e mods deixam pegada)
            WRAPPED=$(echo "$DUMP" | grep -iE 'wrapper|cracked|modded|lsposed|lspatch')
            if [ -n "$WRAPPED" ]; then
                echo "$WRAPPED" | head -n 3 | while IFS= read -r L; do
                    [ -n "$L" ] && alert "  Indício de modificação: $(echo "$L" | head -c 120)"
                done
            fi
        fi
        # tamanho real (v4.4.89): FF é App Bundle (SPLIT APKs) — base.apk tem só ~12-60MB.
        # SOMA todos os APKs do `pm path` (base + split_config.*) em BYTES (stat -c %s) +
        # a pasta OBB. SÓ acusa repack se Base+Splits+OBB < 1 GB (instalação real é multi-GB;
        # medir só o base.apk dava o falso "804MB = mod").
        FF_APK_DIR=$(dirname "$APK_PATH" 2>/dev/null)
        FF_OBB_DIR="/sdcard/Android/obb/$PKG";   [ -d "$FF_OBB_DIR" ]  || FF_OBB_DIR="/storage/emulated/0/Android/obb/$PKG"
        FF_DATA_DIR="/sdcard/Android/data/$PKG"; [ -d "$FF_DATA_DIR" ] || FF_DATA_DIR="/storage/emulated/0/Android/data/$PKG"
        APK_BYTES=0; SPLIT_N=0
        for _apk in $(pm path "$PKG" 2>/dev/null | sed 's|^package:||'); do
            [ -f "$_apk" ] || continue
            _sz=$(stat -c '%s' "$_apk" 2>/dev/null); case "$_sz" in ''|*[!0-9]*) _sz=0 ;; esac
            APK_BYTES=$((APK_BYTES + _sz)); SPLIT_N=$((SPLIT_N + 1))
        done
        OBB_KB=0; DATA_KB=0
        if have du; then
            [ -d "$FF_OBB_DIR" ]  && OBB_KB=$(du -sk "$FF_OBB_DIR"  2>/dev/null | awk '{print $1+0}')
            [ -d "$FF_DATA_DIR" ] && DATA_KB=$(du -sk "$FF_DATA_DIR" 2>/dev/null | awk '{print $1+0}')
        fi
        case "$OBB_KB"  in ''|*[!0-9]*) OBB_KB=0 ;;  esac
        case "$DATA_KB" in ''|*[!0-9]*) DATA_KB=0 ;; esac
        APK_KB=$((APK_BYTES / 1024))
        CORE_KB=$((APK_KB + OBB_KB))           # Base+Splits+OBB = critério do flag
        info "  tamanho: Base+Splits+OBB = $(human_kb "$CORE_KB")  (+Data $(human_kb "$DATA_KB"))  ·  ${SPLIT_N} APK(s)"
        info "    APKs(base+splits): $(human_kb "$APK_KB")  |  OBB: $(human_kb "$OBB_KB")  |  Data: $(human_kb "$DATA_KB")"
        # v4.4.91: tamanho NÃO é mais critério de repack. Sob uid 2000 + Scoped Storage
        # (Android 11+) o du do OBB sub-conta (permission-denied → soma só o que lê) e
        # /Android/data fica ilegível — e o FF guarda o BULK dos assets em Data, não no
        # OBB. Então "Base+Splits+OBB < 1GB" dava FALSO POSITIVO em FF legítimo (ex.: 372MB
        # num install real). Repack/mod fica com os detectores CONFIÁVEIS: metadata da lib
        # (regra 1981, abaixo) + assinatura + origem.
        if [ "$OBB_KB" -eq 0 ] && [ "$DATA_KB" -eq 0 ]; then
            info "  tamanho não conclusivo p/ repack (OBB/Data inacessíveis — Scoped Storage sem root)"
        else
            info "  tamanho registrado p/ forense (não é prova de repack: bulk do FF fica em Data)"
        fi
        # ── v4.4.75: AUDITORIA DE METADATA DA LIB (regra de 1981) — repack/mod detect ──
        # APK oficial: o ZIP do Android grava os .so da pasta lib com o epoch mínimo do
        # formato ZIP (1981-01-01). Se o mtime divergir e estiver RECENTE, o APK foi
        # descompactado, adulterado e recompilado (repack de cheat).
        # v4.4.75 (anti-FP): nem todo Android preserva o epoch 1981 na extração (alguns
        # usam wall-clock → TODA lib fica com data recente, inclusive de apps oficiais).
        # Antes de cravar repack, CALIBRA contra um app oficial garantido (Play Services/
        # Store): se a lib DELE é 1981, este device preserva o epoch → FF recente = repack;
        # se a lib dele também é recente, a regra não vale aqui → sem veredito (evita falso CRÍTICO).
        FF_LIB_DIR="$FF_APK_DIR/lib"
        if [ -d "$FF_LIB_DIR" ]; then
            _newest_so=$(find "$FF_LIB_DIR" -type f -name '*.so' 2>/dev/null | head -1)
            _ref_y=$(stat -c '%y' "${_newest_so:-$FF_LIB_DIR}" 2>/dev/null | cut -d' ' -f1)
            case "$_ref_y" in
                1981-*|1980-*|1979-*) ok "  lib metadata OK (epoch ZIP padrão $_ref_y — não repackado)" ;;
                "")                   info "  lib: sem leitura de mtime dos .so (sem root?)" ;;
                *)
                    # CALIBRAÇÃO: este device preserva o epoch 1981 na extração das libs?
                    _dev_1981=0; _calib_y=""
                    for _cand in com.google.android.gms com.android.vending com.google.android.gsf com.google.android.webview; do
                        _cp=$(pm path "$_cand" 2>/dev/null | head -1 | sed 's|^package:||')
                        [ -n "$_cp" ] || continue
                        _cl="$(dirname "$_cp")/lib"; [ -d "$_cl" ] || continue
                        _cs=$(find "$_cl" -type f -name '*.so' 2>/dev/null | head -1)
                        [ -n "$_cs" ] || continue
                        _calib_y=$(stat -c '%y' "$_cs" 2>/dev/null | cut -d' ' -f1)
                        case "$_calib_y" in 1981-*|1980-*|1979-*) _dev_1981=1 ;; esac
                        break
                    done
                    if [ "$_dev_1981" = "1" ]; then
                        alert "  Metadata da lib adulterada (Repack/Mod Detectado) - Data: $_ref_y (apps oficiais neste device mantêm 1981; o FF não → repack)"
                    elif [ -n "$_calib_y" ]; then
                        info "  lib do FF com data recente ($_ref_y), mas apps oficiais deste device também ($_calib_y → extração wall-clock) — regra de 1981 não aplicável, sem veredito"
                    else
                        warn "  lib do FF com data recente ($_ref_y) e sem app oficial p/ calibrar — revisar (possível repack, não confirmado)"
                    fi ;;
            esac
        else
            warn "  Diretório lib do FF ausente ($FF_LIB_DIR) — libs nativas não extraídas (repack/split incompleto?)"
        fi
    fi
done
[ "$FF_FOUND" = "0" ] && warn "Free Fire NÃO encontrado"

# ============================================================
#  8a-ter. FREE FIRE — INSTÂNCIAS SECUNDÁRIAS / CLONE (v4.4.79, A6)
#  Os checks específicos do FF miram user 0 (/data/data/com.dts.freefireth). FF rodando
#  em work-profile, 2º usuário, ou app de clonagem (parallel/dual space) escapa e serve
#  de bypass de ban por device. Aqui pegamos essas instâncias extras.
# ============================================================
header "FREE FIRE — INSTÂNCIAS SECUNDÁRIAS / CLONE"
_FF_EXTRA=0
# 1) usuários secundários (work profile / multi-user / clone via user 999)
if have pm; then
    for _u in $(pm list users 2>/dev/null | grep -oE '\{[0-9]+:' | grep -oE '[0-9]+'); do
        [ "$_u" = "0" ] && continue
        for _fp in $FF_PKGS; do
            if pm list packages --user "$_u" 2>/dev/null | grep -q "^package:${_fp}$"; then
                alert "Free Fire ($_fp) no usuário secundário $_u (work profile / multi-user / clone) — forense do user 0 não cobre"
                _FF_EXTRA=$((_FF_EXTRA+1))
            fi
        done
    done
fi
# 2) dados do FF dentro de apps de clonagem (parallel/dual space) ou /data/user/N (precisa root)
if have find; then
    for _root in /data/user/[0-9]* /data/data/com.lbe.parallel* /data/data/com.ludashi.dualspace \
                 /data/data/com.excelliance.dualaid /data/data/io.virtualapp /data/data/com.parallel.space* \
                 /data/data/com.icecold.gomultiple /data/data/com.cloneapp* /sdcard/Android/data/com.lbe.parallel*; do
        [ -e "$_root" ] || continue
        _CLONE_FF=$(find "$_root" 2>/dev/null -maxdepth 6 -type d -name 'com.dts.freefire*' 2>/dev/null | head -3)
        [ -n "$_CLONE_FF" ] && printf '%s\n' "$_CLONE_FF" | while IFS= read -r H; do
            [ -n "$H" ] && alert "Dados do Free Fire em espaço clonado/secundário: $H — instância paralela (provável bypass de ban por device)"
        done
    done
fi
[ "$_FF_EXTRA" = "0" ] && ok "Sem instância do FF em usuário secundário (user 0 apenas)"

# ============================================================
#  8a-bis. SIDELOAD GLOBAL — apps de TERCEIROS fora das lojas oficiais
#  (v4.4.75) `pm list packages -i -3`: lista pacote + installer, só apps de
#  terceiro (-3 exclui system). Flagga painéis/cheats disfarçados de app comum
#  instalados via packageinstaller / Chrome / gerenciador de arquivos / null.
# ============================================================
# v4.4.79 (fix portabilidade): a classificação do installer MORA nesta função —
# o `case` fica FORA de qualquer $(). `case` dentro de $(...) quebra o parser do
# bash < 4 (bug clássico: o ")" do padrão do case é confundido com o ")" que
# fecha o $()). Android (/system/bin/sh = mksh) e bash 5 rodam, mas extraindo
# pra função o script parseia em TODO shell (mksh, dash, bash 3.2, bash 5).
_sl_classify() {  # $1=pacote  $2=installer  → ecoa "pacote|installer" se for sideload
    # v4.4.88: ALLOWLIST OEM. Antes o catch-all `*)` acusava QUALQUER installer
    # fora da lista — incluindo apps de sistema Xiaomi/Samsung cujo installer é
    # um pacote OEM próprio (não-Play) → falso positivo em massa. Agora só acusa
    # origem EXPLICITAMENTE de sideload (null / installer manual / browser / file
    # manager / adb / loja de terceiros). Installer OEM desconhecido = NÃO acusa.
    case "$2" in
        # ── Allowlist: lojas oficiais (Play + OEMs) = legítimo, ignora ──
        com.android.vending|com.google.android.feedback|com.amazon.venezia|\
        com.sec.android.app.samsungapps|com.huawei.appmarket|com.xiaomi.mipicks|\
        com.heytap.market|com.oppo.market|com.vivo.appstore|com.bbk.appstore|\
        com.transsion.phoenix|com.hihonor.appmarket|com.honor.global|\
        com.lenovo.leos.appstore|com.zui.market|com.oneplus.market) ;;
        # ── Sideload EXPLÍCITO: null / instalador manual / browser / file manager
        #    / adb shell / loja de terceiro = SUSPEITO ──
        null|""|com.google.android.packageinstaller|com.android.packageinstaller|\
        com.android.chrome|*chrome*|com.google.android.gm|bin.mt.plus|\
        *com.android.shell*|*adb*|*apkpure*|*aptoide*|*uptodown*|*aurora*|*xapk*|\
        *filemanager*|*fileexplorer*|*zarchiver*|*documentsui*|*apps.nbu.files*|*mixplorer*)
            echo "$1|${2:-null}" ;;
        # ── Installer desconhecido (OEM-específico, etc.): NÃO acusa (mata FP) ──
        *) ;;
    esac
}
header "SIDELOAD GLOBAL (origem dos apps de terceiros)"
if have pm; then
    # v4.4.100: _SYS_PKGS agora é GLOBAL (computado 1x no topo, ~l.348) — reusado aqui e nos
    # portões de overlay/accessibility, evitando recomputar `pm list packages -s`.
    SIDELOADED=$(pm list packages -i -3 2>/dev/null | while IFS= read -r LINE; do
        APP=$(echo "$LINE"  | sed -n 's/^package:\([^ ]*\).*/\1/p')
        INST=$(echo "$LINE" | sed -n 's/.*installer=\([^ ]*\).*/\1/p')
        [ -z "$APP" ] && continue
        # v4.4.99 (hardening pós-review Fable 5): a DECISÃO de origem usa só sinal NÃO-FORJÁVEL.
        # (1) DISFARCE primeiro — app de 3rd-party vestindo NAMESPACE de fábrica (com.samsung.*/
        # com.miui.*/…). Só é benigno se tiver LASTRO de sistema (is_oem_preload: partição /
        # pkgFlags SYSTEM / lista `pm -s`). Sem lastro = masquerade, INDEPENDENTE do installer —
        # roda ANTES do _sl_classify p/ fechar o vetor "rename com.samsung.* + adb install -i
        # <installer inventado>" (que o _sl_classify descartaria como installer desconhecido).
        # Namespace OEM é controlado (Play barra publicar em domínio alheio) → FP ~nulo; e OEM
        # REAL nunca cai aqui (tem lastro → suprimido). O install pega o app OEM ATUALIZADO p/
        # /data/app (ex.: Samsung Tips) via pkgFlags/`pm -s`, que o check de partição só perdia.
        if is_oem_ns "$APP"; then
            APATH=$(pm path "$APP" 2>/dev/null | head -1 | sed 's/^package://')
            is_oem_preload "$APP" "$INST" "$APATH" && continue
            echo "D|$APP|${INST:-null}"
            continue
        fi
        # (2) Sideload comum — origem explícita fora de loja (via _sl_classify). Installer
        # desconhecido NÃO acusa (design v4.4.88 anti-FP-em-massa). Candidato ainda passa pela
        # supressão de preload OEM por sinal não-forjável (~1 dumpsys por candidato, no máx.).
        CAND=$(_sl_classify "$APP" "$INST")
        [ -z "$CAND" ] && continue
        APATH=$(pm path "$APP" 2>/dev/null | head -1 | sed 's/^package://')
        is_oem_preload "$APP" "$INST" "$APATH" && continue
        echo "S|$CAND"
    done | sort -u)
    if [ -n "$SIDELOADED" ]; then
        printf '%s\n' "$SIDELOADED" | while IFS='|' read -r KIND APP INST; do
            [ -z "$APP" ] && continue
            # v4.4.99: mostra o NOME do app da biblioteca junto do pacote (dispensa lib checker).
            _NM=$(pkg_label "$APP"); [ -z "$_NM" ] && _NM="nome não resolvido — ver na biblioteca de apps"
            case "$KIND" in
                # DISFARCE: namespace de fábrica sem lastro de sistema — sinal mais forte.
                D) warn "[SUSPEITO] Namespace de FÁBRICA sem lastro de sistema (possível DISFARCE de preload OEM): $APP  →  \"$_NM\"  (installer: ${INST:-null})" ;;
                *) warn "[SUSPEITO] App via Sideload (fora de loja/OEM): $APP  →  \"$_NM\"  (installer: ${INST:-null})" ;;
            esac
        done
    else
        ok "Nenhum app de terceiro com origem suspeita (todos via loja oficial/OEM)"
    fi
else
    info "pm indisponível — sideload global não verificado"
fi

# ============================================================
#  8b. FREE FIRE - HISTÓRICO DE INSTALAÇÃO / DESINSTALAÇÃO
# ============================================================
header "FREE FIRE - HISTÓRICO INSTALL/UNINSTALL (últimos 7 dias)"

# 1) Pacotes desinstalados conforme batterystats
#    dumpsys batterystats guarda registros 'pkgunin=' até batteria zerar
if have dumpsys; then
    UNINSTALLED=$(dumpsys batterystats 2>/dev/null | grep -oE 'pkgunin=[0-9]+:"[^"]+"' | sort -u)
    if [ -n "$UNINSTALLED" ]; then
        FF_REMOVED=$(echo "$UNINSTALLED" | grep -iE 'freefire|com\.dts\.freefire|com\.garena')
        if [ -n "$FF_REMOVED" ]; then
            alert "Free Fire FOI DESINSTALADO em algum momento (batterystats):"
            echo "$FF_REMOVED" | while IFS= read -r L; do
                [ -n "$L" ] && alert "  $L"
            done
        fi
        # outros uninstalls suspeitos
        # v4.4.103: token 'mod' cru trocado por 'modmenu' — 'mod' cru casa qualquer package
        # com essa substring (com.motorola.mod*, *.modulemetadata etc.); ancorar não resolve
        # porque a fronteira de package (.) já precede 'mod' nesses nomes legítimos.
        OTHER_REMOVED=$(echo "$UNINSTALLED" | grep -iE 'cheat|hack|modmenu|aimbot|esp|ffh4x|menu|injector|frida|magisk|brevent|shizuku|gameguardian|virtualapp|parallel|lulubox|luckypatcher|holograma|hologram')
        if [ -n "$OTHER_REMOVED" ]; then
            alert "Outros apps suspeitos desinstalados recentemente:"
            echo "$OTHER_REMOVED" | while IFS= read -r L; do
                [ -n "$L" ] && alert "  $L"
            done
        fi
        # listar TODOS uninstalls dos últimos dias (até 30 entries)
        TOTAL=$(echo "$UNINSTALLED" | wc -l)
        info "Total de uninstalls registrados em batterystats: $TOTAL"
        echo "$UNINSTALLED" | head -n 30 | while IFS= read -r L; do
            [ -n "$L" ] && info "  $L"
        done
    fi
fi

# 2) Para cada FF_PKG, install epoch + dias desde primeira instalação
if have dumpsys; then
    for PKG in $FF_PKGS; do
        pkg_installed "$PKG" || continue
        FIRST_MS=$(dumpsys package "$PKG" 2>/dev/null | grep -m1 firstInstallTime | grep -oE '[0-9]{10,}' | head -n1)
        UPDATE_MS=$(dumpsys package "$PKG" 2>/dev/null | grep -m1 lastUpdateTime | grep -oE '[0-9]{10,}' | head -n1)
        if [ -n "$FIRST_MS" ]; then
            # converte ms para s
            FIRST_S=$((FIRST_MS / 1000))
            NOW_S=$(date +%s 2>/dev/null)
            if [ -n "$NOW_S" ] && [ -n "$FIRST_S" ]; then
                AGE_DAYS=$(( (NOW_S - FIRST_S) / 86400 ))
                FIRST_DATE=$(date -d "@$FIRST_S" 2>/dev/null || date -r "$FIRST_S" 2>/dev/null)
                info "$PKG: 1a install $FIRST_DATE ($AGE_DAYS dias atrás)"
                if [ "$AGE_DAYS" -lt 7 ] 2>/dev/null; then
                    alert "  $PKG instalado há $AGE_DAYS dias (<7 = REINSTALL recente, possível limpeza de cheat)"
                fi
            fi
        fi
        if [ -n "$UPDATE_MS" ]; then
            UPD_S=$((UPDATE_MS / 1000))
            UPD_DATE=$(date -d "@$UPD_S" 2>/dev/null || date -r "$UPD_S" 2>/dev/null)
            info "  última atualização: $UPD_DATE"
        fi
        # compara com boot time - se firstInstall > boot, foi reinstalado após boot
        UPTIME_S=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
        if [ -n "$UPTIME_S" ] && [ -n "$NOW_S" ] && [ -n "$FIRST_S" ]; then
            BOOT_S=$((NOW_S - UPTIME_S))
            if [ "$FIRST_S" -gt "$BOOT_S" ] 2>/dev/null; then
                alert "  $PKG instalado DEPOIS do último boot (reinstalação para limpar)"
            fi
        fi
    done
fi

# 3) Eventos package_added / package_removed no logcat events buffer
if have logcat; then
    # v4.4.75: sort -u dedupa eventos idênticos repetidos no buffer (o logcat events
    # repete a mesma linha de pkg/job em loop) — antes floodava a saída.
    PKG_EVENTS=$(timeout 5 logcat -b events -d 2>/dev/null | grep -iE 'pkg_install|pkg_uninstall|package_added|package_removed|installer' | sort -u | head -n 30)
    if [ -n "$PKG_EVENTS" ]; then
        # filtrar FF e cheats
        # v4.4.103: 'mod' cru → 'modmenu' (logcat events buffer tem nomes de package
        # legítimos com 'mod' embutido, ex: com.motorola.mod*/modulemetadata).
        FF_LOGEV=$(echo "$PKG_EVENTS" | grep -iE 'freefire|dts\.freefire|garena|cheat|hack|modmenu|aimbot|esp|frida|magisk|holograma|hologram' | sort -u)
        if [ -n "$FF_LOGEV" ]; then
            alert "Eventos de pkg no logcat (FF/cheat relacionados):"
            echo "$FF_LOGEV" | head -n 10 | while IFS= read -r L; do
                [ -n "$L" ] && alert "  $(echo "$L" | head -c 180)"
            done
        fi
    fi
fi

# 4) Pacotes desinstalados via dumpsys (orphan data)
if have dumpsys; then
    # data dirs órfãos (app desinstalado mas /data/data ainda tem)
    if [ -d /data/data ]; then
        for PKG in $FF_PKGS; do
            if [ -d "/data/data/$PKG" ] && ! pkg_installed "$PKG"; then
                alert "Diretório /data/data/$PKG órfão (FF foi desinstalado mas dados ficaram)"
            fi
        done
    fi
fi

# ============================================================
#  9. FREE FIRE - DADOS INTERNOS (shared_prefs / cache / files)
# ============================================================
header "FREE FIRE - DADOS INTERNOS"

_FFDATA_H0=$(_hits_count)   # v4.4.98: baseline p/ linha-limpo honesta (alerts em subshell)
for PKG in $FF_PKGS; do
    PREFS="/data/data/$PKG/shared_prefs"
    CACHE="/data/data/$PKG/cache"
    FILES="/data/data/$PKG/files"
    if [ -d "$PREFS" ]; then
        ls "$PREFS" 2>/dev/null | while IFS= read -r F; do
            [ -z "$F" ] && continue
            case "$F" in
                # v4.4.54: + *holograma* / *hologram* / *holo* — cheat 'Holograma'
                # solta arquivos com esse prefix dentro da pasta do FF (data/obb).
                # v4.4.98: tirados os globs genéricos *mod*/*menu*/*esp*/*aim*/*holo* — casavam
                # claim_rewards/game_mode/login_response/main_menu/modules: prefs LEGÍTIMOS do FF
                # → SUSPEITO falso. Os nomes EXATOS de cheat (esp.cfg/mod.cfg/aim.cfg) seguem pegos
                # no find logo abaixo. Mantidos os idiomas inequívocos (modmenu/aimbot/ffh4x/etc).
                *cheat*|*hack*|*holograma*|*hologram*|*aimbot*|*aimlock*|*modmenu*|*mod_menu*|*ffh4x*|*wallhack*|*killaura*)
                    alert "prefs suspeito: $PREFS/$F" ;;
                *) info "  $PREFS/$F" ;;
            esac
        done
    fi
    if [ -d "$FILES" ] && have find; then
        ODD=$(find "$FILES" 2>/dev/null -maxdepth 3 -type f \( \
            -name '.modded' -o -name '*.modff' -o -name 'cheat.cfg' \
            -o -name 'aim.cfg' -o -name 'esp.cfg' -o -name 'mod.cfg' \
            -o -name 'menu.cfg' -o -name '*.lua' -o -name '*.hack' \
            -o -iname '*holograma*' -o -iname '*hologram*' -o -iname '.holo*' \
            -o -iname 'holo.*' -o -iname '*.holo' \) 2>/dev/null)
        [ -n "$ODD" ] && echo "$ODD" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Mod file em files/: $L"
        done
    fi
    if [ -d "$CACHE" ] && have find; then
        ODDC=$(find "$CACHE" 2>/dev/null -maxdepth 2 -type f \( -name '*.so' -o -name '*.dex' -o -name '*.jar' \) 2>/dev/null | head -n 10)
        [ -n "$ODDC" ] && echo "$ODDC" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Lib/dex em cache do FF: $L"
        done
        # v4.4.54: keyword holograma no cache também
        HOLO_CACHE=$(find "$CACHE" 2>/dev/null -maxdepth 3 -type f -iname '*holograma*' 2>/dev/null | head -10)
        [ -n "$HOLO_CACHE" ] && echo "$HOLO_CACHE" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Cheat 'Holograma' em cache do FF: $L"
        done
    fi
    # v4.4.54: scan recursivo TODA pasta /data/data/<FF> por holograma
    if [ -d "/data/data/$PKG" ] && have find; then
        HOLO_ALL=$(find "/data/data/$PKG" 2>/dev/null -maxdepth 5 -type f \
            \( -iname '*holograma*' -o -iname '*hologram*' \) 2>/dev/null | head -20)
        [ -n "$HOLO_ALL" ] && echo "$HOLO_ALL" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Cheat 'Holograma' em /data/data/$PKG: $L"
        done
    fi
    # v4.4.54: + /sdcard/Android/data/<FF>/ e /sdcard/Android/obb/<FF>/
    for FFEXT in "/sdcard/Android/data/$PKG" "/sdcard/Android/obb/$PKG" \
                 "/storage/emulated/0/Android/data/$PKG" "/storage/emulated/0/Android/obb/$PKG"; do
        [ -d "$FFEXT" ] || continue
        if have find; then
            HOLO_EXT=$(find "$FFEXT" 2>/dev/null -maxdepth 6 -type f \
                \( -iname '*holograma*' -o -iname '*hologram*' -o -iname '.holo*' \
                   -o -iname 'holo_*' -o -iname '*_holo.*' \) 2>/dev/null | head -20)
            [ -n "$HOLO_EXT" ] && echo "$HOLO_EXT" | while IFS= read -r L; do
                [ -n "$L" ] && alert "Cheat 'Holograma' em $FFEXT: $L"
            done
        fi
    done
done
[ "$(_hits_count)" = "$_FFDATA_H0" ] && ok "Dados internos FF sem indícios"

# ============================================================
#  9.5 HOLOGRAMA — IOCs do cheat real (v4.4.56)
#  Threat intel: github.com/Haqowsk92/ffxit (commit Feb/2026). Three.js script
#  que desenha BoxGeometry(1,2,1) vermelho na posição de cada inimigo.
#  Detect via:
#    1) Hash MD5 / SHA-256 do README do repo (qualquer arquivo no device com
#       esses hashes = cópia direta)
#    2) Strings únicas das funções (createHologram, updateHolograms, getEnemies)
#    3) Pattern THREE.BoxGeometry(1, 2, 1) + MeshBasicMaterial 0xff0000
#    4) Three.js dentro de /Android/data ou /obb do FF (red flag)
# ============================================================
header "HOLOGRAMA — Three.js ESP IOCs"

HOLO_HITS=0
HOLO_MD5="b788a1a60b3ddd8ec35b457321774c54"
HOLO_SHA="51811a5b6a44f2e37c7af28021ba505f9fe3029ccc2986324475ae35b51aedcf"

# Paths a vasculhar — pastas do FF + /sdcard onde dropam scripts antes de inject
HOLO_PATHS=""
for FFPKG in com.dts.freefireth com.dts.freefiremax; do
    for D in "/data/data/$FFPKG" \
             "/sdcard/Android/data/$FFPKG" \
             "/sdcard/Android/obb/$FFPKG" \
             "/storage/emulated/0/Android/data/$FFPKG" \
             "/storage/emulated/0/Android/obb/$FFPKG"; do
        [ -d "$D" ] && HOLO_PATHS="$HOLO_PATHS $D"
    done
done
# Também pastas de drop comuns
for D in /sdcard/Download /sdcard/Documents /sdcard/Holograma /sdcard/Hologram /sdcard/HOLO /sdcard/.holograma /sdcard/.hologram /data/local/tmp; do
    [ -d "$D" ] && HOLO_PATHS="$HOLO_PATHS $D"
done

if [ -n "$HOLO_PATHS" ] && have find; then
    info "Holograma deep scan em: $(echo "$HOLO_PATHS" | tr ' ' '\n' | wc -l) paths"

    # 1) HASH check — qualquer arquivo .js/.txt/.html/.md ≤ 100KB
    if have md5sum && have sha256sum; then
        # v4.4.70: self-exclusion — NÃO vasculha os próprios arquivos do a4ther
        # (o script vive em /sdcard/Download/a4ther.sh e contém as strings IOC; os
        # relatórios scan_*/A4THER_UPLOAD_SITE_* também). Senão o scanner se flagra.
        HOLO_CANDIDATES=$(find $HOLO_PATHS 2>/dev/null -maxdepth 6 -type f \
            ! -path "$SELF_PATH" ! -path '*/a4ther_audits/*' ! -name 'A4THER_UPLOAD_SITE_*' \
            \( -iname '*.js' -o -iname '*.txt' -o -iname '*.html' -o -iname '*.md' \
               -o -iname '*.json' -o -iname '*.lua' \) -size -100k 2>/dev/null | head -200)
        if [ -n "$HOLO_CANDIDATES" ]; then
            echo "$HOLO_CANDIDATES" | while IFS= read -r F; do
                [ -z "$F" ] || [ ! -r "$F" ] && continue
                _F_MD5=$(md5sum "$F" 2>/dev/null | awk '{print $1}')
                _F_SHA=$(sha256sum "$F" 2>/dev/null | awk '{print $1}')
                if [ "$_F_MD5" = "$HOLO_MD5" ] || [ "$_F_SHA" = "$HOLO_SHA" ]; then
                    alert "HOLOGRAMA — hash bate com Haqowsk92/ffxit: $F"
                    alert "  └─ MD5: $_F_MD5"
                    alert "  └─ SHA-256: $_F_SHA"
                    HOLO_HITS=$((HOLO_HITS+1))
                fi
            done
        fi
    fi

    # 2) STRING patterns — funções únicas do script
    if have grep; then
        # createHologram + updateHolograms + getEnemies juntos no mesmo arquivo
        STR_MATCH=$(grep -rlE --exclude="$SELF_BASE" --exclude='_scan_console.log' --exclude='A4THER_UPLOAD_SITE_*' --exclude-dir='a4ther_audits' --exclude-dir='a4ther' 'createHologram[[:space:]]*\(' $HOLO_PATHS 2>/dev/null | head -20)
        if [ -n "$STR_MATCH" ]; then
            echo "$STR_MATCH" | while IFS= read -r F; do
                [ -z "$F" ] || [ ! -r "$F" ] && continue
                # Confirma que tem mais de uma função do script (≥2 = quase certo)
                COUNT=0
                for PAT in 'createHologram' 'updateHolograms' 'getEnemies' 'hologram-' 'BoxGeometry'; do
                    grep -qE "$PAT" "$F" 2>/dev/null && COUNT=$((COUNT+1))
                done
                if [ "$COUNT" -ge 2 ] 2>/dev/null; then
                    alert "HOLOGRAMA — código Three.js ESP em: $F (assinaturas: $COUNT/5)"
                    HOLO_HITS=$((HOLO_HITS+1))
                fi
            done
        fi

        # Pattern crítico: BoxGeometry(1, 2, 1) + cor 0xff0000 = silhueta humanoide vermelha
        BOX_MATCH=$(grep -rlE --exclude="$SELF_BASE" --exclude='_scan_console.log' --exclude='A4THER_UPLOAD_SITE_*' --exclude-dir='a4ther_audits' --exclude-dir='a4ther' 'BoxGeometry[[:space:]]*\([[:space:]]*1[[:space:]]*,[[:space:]]*2[[:space:]]*,[[:space:]]*1[[:space:]]*\)' $HOLO_PATHS 2>/dev/null | head -10)
        if [ -n "$BOX_MATCH" ]; then
            echo "$BOX_MATCH" | while IFS= read -r F; do
                [ -z "$F" ] && continue
                # Confirma cor vermelha 0xff0000 também
                if grep -qE '0xff0000|0xFF0000' "$F" 2>/dev/null; then
                    alert "HOLOGRAMA — BoxGeometry(1,2,1) + 0xff0000 (silhueta humanoide vermelha): $F"
                    HOLO_HITS=$((HOLO_HITS+1))
                fi
            done
        fi
    fi

    # 3) Three.js library dentro de pasta do FF (não tem motivo legítimo)
    THREE_JS=$(find $HOLO_PATHS 2>/dev/null -maxdepth 5 -type f \
        ! -path "$SELF_PATH" ! -path '*/a4ther_audits/*' ! -name 'A4THER_UPLOAD_SITE_*' \
        \( -iname 'three.min.js' -o -iname 'three.js' -o -iname 'three.module.js' \) 2>/dev/null | head -5)
    if [ -n "$THREE_JS" ]; then
        echo "$THREE_JS" | while IFS= read -r F; do
            [ -n "$F" ] && alert "Three.js dentro de pasta do FF (dependência do Holograma): $F"
        done
        HOLO_HITS=$((HOLO_HITS+1))
    fi

    # 4) WebView cache / IndexedDB com strings de holograma
    for FFPKG in com.dts.freefireth com.dts.freefiremax; do
        for WV in "/data/data/$FFPKG/app_webview" "/data/data/$FFPKG/app_chromium" \
                  "/data/data/$FFPKG/cache/WebView"; do
            [ -d "$WV" ] || continue
            WV_HIT=$(grep -rliE --exclude="$SELF_BASE" --exclude='_scan_console.log' --exclude='A4THER_UPLOAD_SITE_*' --exclude-dir='a4ther_audits' --exclude-dir='a4ther' 'createHologram|updateHolograms|hologram-.{1,5}enemy' "$WV" 2>/dev/null | head -3)
            if [ -n "$WV_HIT" ]; then
                echo "$WV_HIT" | while IFS= read -r F; do
                    [ -n "$F" ] && alert "WebView do FF contém script Holograma: $F"
                done
                HOLO_HITS=$((HOLO_HITS+1))
            fi
        done
    done
fi
[ "$HOLO_HITS" = "0" ] && ok "Sem IOC do Holograma (hash/strings/Three.js/WebView)"

# ============================================================
#  10. FREE FIRE - SHADERS (UnityFS signature - wallhack)
# ============================================================
header "SHADERS UnityFS (wallhack)"

SHADER_HITS=0
for PKG in $FF_PKGS; do
    GAB_DIR="/sdcard/Android/data/$PKG/files/contentcache/Optional/android/gameassetbundles"
    [ -d "$GAB_DIR" ] || continue
    info "gameassetbundles: $GAB_DIR"
    # v4.4.63: INVENTÁRIO técnico (sempre exibe — info completa p/ perícia)
    _gn=$(find "$GAB_DIR" -maxdepth 3 -type f 2>/dev/null | wc -l | tr -d ' ')
    _gsh=$(find "$GAB_DIR" -maxdepth 3 -type f -name 'shader*' 2>/dev/null | wc -l | tr -d ' ')
    _gsz=$(du -sh "$GAB_DIR" 2>/dev/null | awk '{print $1}')
    info "  inventário: ${_gn:-0} arquivo(s) no bundle (${_gsh:-0} shader*) · total ${_gsz:-?}"
    _gls=$(ls -t "$GAB_DIR"/shaders* 2>/dev/null | head -1)
    if [ -n "$_gls" ]; then
        _gh=""; have sha256sum && _gh=$(sha256sum "$_gls" 2>/dev/null | awk '{print $1}')
        info "  shader recente: $(basename "$_gls") ($(du -h "$_gls" 2>/dev/null | awk '{print $1}'))${_gh:+ · sha256 ${_gh}}"
    fi
    if have find; then
        # listar arquivos shader* / asset
        SH_FILES=$(find "$GAB_DIR" 2>/dev/null -maxdepth 3 -type f 2>/dev/null | head -n 40)
        [ -n "$SH_FILES" ] && echo "$SH_FILES" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            SIG=$(head -c 7 "$F" 2>/dev/null)
            BN=$(basename "$F")
            case "$BN" in
                shader*|*.shader|*.bundle)
                    if [ "$SIG" != "UnityFS" ]; then
                        alert "Shader signature INVÁLIDA (esperado UnityFS): $F (sig: $(printf '%s' "$SIG" | od -An -c 2>/dev/null | head -c 50))"
                    else
                        ok "  $BN: UnityFS OK"
                    fi ;;
                *)
                    if [ "$SIG" != "UnityFS" ]; then
                        warn "Asset bundle sem UnityFS: $F"
                    fi ;;
            esac
        done
        # DG7 SS: tamanho do shader esperado é 1-3MB; fora disso = suspeito
        LATEST_SHADER=$(ls -t "$GAB_DIR"/shaders* 2>/dev/null | head -1)
        if [ -n "$LATEST_SHADER" ]; then
            SH_SIZE_MB=$(du -m "$LATEST_SHADER" 2>/dev/null | awk '{print $1}')
            if [ -n "$SH_SIZE_MB" ]; then
                if [ "$SH_SIZE_MB" -lt 1 ] || [ "$SH_SIZE_MB" -gt 3 ] 2>/dev/null; then
                    alert "Shader com tamanho SUSPEITO (${SH_SIZE_MB}MB, esperado 1-3MB): $LATEST_SHADER"
                else
                    ok "Shader size sanity: ${SH_SIZE_MB}MB (1-3MB esperado) ✓"
                fi
            fi

            # === OlhosDoCapeta2: shader perm + UID + nano forensics ===
            # Permissão esperada: 660 (rw-rw----). Qualquer outra = manipulação
            SH_PERM=$(stat -c '%a' "$LATEST_SHADER" 2>/dev/null)
            if [ -n "$SH_PERM" ]; then
                case "$SH_PERM" in
                    660|0660) ok "Shader perm: 660 ✓" ;;
                    *) alert "Shader perm ANORMAL: $SH_PERM (esperado 660) — modificado manualmente" ;;
                esac
            fi
            # UID 2000 = shell/adb (transferido via ADB push)
            SH_UID=$(stat -c '%u' "$LATEST_SHADER" 2>/dev/null)
            if [ "$SH_UID" = "2000" ]; then
                alert "Shader UID=2000 (shell/ADB) — transferido via ADB push, não criado in-game"
            fi
            # v4.4.32: Modify != Change só conta como suspeito se delta > 24h.
            # Diff de minutos/horas pode ser chmod do sistema, package update
            # tocando AOT profile, ou /sdcard remontado. Threshold antigo (60s)
            # gerava FP em quase toda execução.
            SH_MOD=$(stat -c '%Y' "$LATEST_SHADER" 2>/dev/null)
            SH_CHG=$(stat -c '%Z' "$LATEST_SHADER" 2>/dev/null)
            if [ -n "$SH_MOD" ] && [ -n "$SH_CHG" ] && [ "$SH_MOD" != "$SH_CHG" ]; then
                DIFF=$((SH_CHG - SH_MOD))
                [ "$DIFF" -lt 0 ] && DIFF=$((-DIFF))
                if [ "$DIFF" -gt 86400 ] 2>/dev/null; then
                    alert "Shader Modify != Change (delta ${DIFF}s, >24h) — alteração manual"
                elif [ "$DIFF" -gt 60 ] 2>/dev/null; then
                    info "Shader Modify != Change (delta ${DIFF}s, <24h) — provavelmente chmod do sistema"
                fi
            fi
            # v4.4.32: Nanos zerados só viram alerta se o FS suporta nanos.
            # Em vfat/sdcardfs (várias ROMs antigas mantêm /sdcard em FAT mode),
            # 000000000 é o ESPERADO — gerava ALERTA crítico injusto.
            if fs_has_nanos "$LATEST_SHADER"; then
                SH_ANANO=$(stat "$LATEST_SHADER" 2>/dev/null | grep 'Access:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)
                case "$SH_ANANO" in
                    000000000) alert "Shader nanos ZERADOS em FS com suporte a nanos — bypass de timestamp" ;;
                esac
                # v4.4.102: heurística `999` removida — FP puro (nanos legítimo é aleatório;
                # timestomp real ZERA os nanos, já coberto acima). Não tem base forense.
            else
                info "Shader em FS sem nanos (vfat/sdcardfs) — checks de nanossegundo skipados"
            fi
            # Múltiplos shaders detectados (legítimo cria UM por sessão; vários = limpou só algum)
            SH_COUNT=$(ls "$GAB_DIR"/shaders* 2>/dev/null | wc -l)
            if [ -n "$SH_COUNT" ] && [ "$SH_COUNT" -gt 1 ] 2>/dev/null; then
                warn "Múltiplos shaders detectados ($SH_COUNT) — esperado 1 por sessão"
            fi
        fi
    fi
done
# GFX tools
for PKG in com.gfxtool.fps com.gfx.tool com.flixgrade.bgmigfx com.gfxtool.pro \
           com.fast.flixfps com.gfx.optimizer com.shadermod.ff com.tool.gfx.pro; do
    pkg_installed "$PKG" && { warn "GFX tool: $PKG"; SHADER_HITS=$((SHADER_HITS+1)); }
done
[ "$SHADER_HITS" = "0" ] && ok "Shaders sem indícios"

# ============================================================
#  11. FREE FIRE - REPLAYS (MReplays + análise temporal)
# ============================================================
header "REPLAYS (MReplays + análise temporal)"

REPLAY_HITS=0
for PKG in $FF_PKGS; do
    RDIR="/sdcard/Android/data/$PKG/files/MReplays"
    [ -d "$RDIR" ] || continue
    info "MReplays: $RDIR"
    # v4.4.63: INVENTÁRIO técnico dos replays (sempre exibe — info completa)
    _rb=$(find "$RDIR" -maxdepth 2 -type f -name '*.bin' 2>/dev/null | wc -l | tr -d ' ')
    _rj=$(find "$RDIR" -maxdepth 2 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
    _rsz=$(du -sh "$RDIR" 2>/dev/null | awk '{print $1}')
    info "  inventário: ${_rb:-0} .bin · ${_rj:-0} .json · total ${_rsz:-?}"
    _rlb=$(ls -t "$RDIR"/*.bin 2>/dev/null | head -1)
    if [ -n "$_rlb" ]; then
        _rh=""; have sha256sum && _rh=$(sha256sum "$_rlb" 2>/dev/null | awk '{print $1}')
        info "  replay recente (.bin): $(basename "$_rlb") ($(du -h "$_rlb" 2>/dev/null | awk '{print $1}'))${_rh:+ · sha256 ${_rh}}"
    fi
    _rlj=$(ls -t "$RDIR"/*.json 2>/dev/null | head -1)
    if [ -n "$_rlj" ]; then
        _jh=""; have sha256sum && _jh=$(sha256sum "$_rlj" 2>/dev/null | awk '{print $1}')
        info "  metadata (.json): $(basename "$_rlj") ($(du -h "$_rlj" 2>/dev/null | awk '{print $1}'))${_jh:+ · sha256 ${_jh}}"
    fi
    if have find; then
        BINS=$(find "$RDIR" 2>/dev/null -maxdepth 2 -type f -name '*.bin' 2>/dev/null)
        if [ -n "$BINS" ]; then
            # v4.4.75: DEDUP/RESUMO — antes saía 1 linha (info + warn) POR arquivo .bin
            # (flood de dezenas no cache de replays). Agora percorre tudo emitindo um TAG
            # por anomalia e imprime só CONTAGENS agregadas. (O while roda em subshell, então
            # agregamos via grep -c na saída de tags, não com variáveis de loop.)
            _RFIND=$(echo "$BINS" | while IFS= read -r B; do
                [ -z "$B" ] && continue
                ACC=$(stat -c '%X' "$B" 2>/dev/null); MOD=$(stat -c '%Y' "$B" 2>/dev/null)
                CHG=$(stat -c '%Z' "$B" 2>/dev/null); MTHUMAN=$(stat -c '%y' "$B" 2>/dev/null)
                # Access > Modify > 7d = touch -d antigo (assistir replay atualiza atime: normal só se <7d)
                if [ -n "$ACC" ] && [ -n "$MOD" ] && [ "$ACC" -gt "$MOD" ] 2>/dev/null; then
                    [ "$((ACC - MOD))" -gt 604800 ] 2>/dev/null && echo "ACCGTMOD"
                fi
                # v4.4.88: equality Access=Modify=Change REMOVIDA — era FALSO
                # POSITIVO da sincronização nativa da engine do jogo nos .bin de
                # replay (disparava "touch bypass" em todo replay legítimo).
                # Touch bypass REAL agora = (a) flag de imutabilidade (chattr +i)
                # ou (b) timestamp explicitamente anômalo (ano < 1981 ou > 2030).
                lsattr "$B" 2>/dev/null | grep -qi -- '-i-' && echo "IMMUTABLE"
                # NOTA: SEM `case` aqui — estamos DENTRO do $() do _RFIND, e o ")"
                # do padrão de case quebra o parser do bash<4 (mesma armadilha do
                # comentário v4.4.79 acima). Usa só `[ ] 2>/dev/null` (POSIX puro).
                if [ -n "$MOD" ]; then
                    if [ "$MOD" -lt 347155200 ] 2>/dev/null || [ "$MOD" -gt 1893456000 ] 2>/dev/null; then
                        echo "TSANOMALY"
                    fi
                fi
                # v4.4.79 (fix portab.): era `case` inline DENTRO do $() do _RFIND —
                # o ")" do padrão quebra o parser do bash<4. Troca por expansão de
                # parâmetro (POSIX puro, idêntico): detecta ".000000000" em qualquer lugar.
                if fs_has_nanos "$B" && [ "$MTHUMAN" != "${MTHUMAN%%.000000000*}" ]; then echo "NANOZERO"; fi
                JSON="${B%.bin}.json"
                if [ -f "$JSON" ]; then
                    JMOD=$(stat -c '%Y' "$JSON" 2>/dev/null)
                    [ -n "$JMOD" ] && [ -n "$MOD" ] && [ "$JMOD" -lt "$MOD" ] 2>/dev/null && echo "JSONBEFORE"
                fi
            done)
            _C_IMM=$(printf '%s\n'   "$_RFIND" | grep -c '^IMMUTABLE$'   2>/dev/null)
            _C_TS=$(printf '%s\n'    "$_RFIND" | grep -c '^TSANOMALY$'   2>/dev/null)
            _C_ACC=$(printf '%s\n'   "$_RFIND" | grep -c '^ACCGTMOD$'    2>/dev/null)
            _C_NANO=$(printf '%s\n'  "$_RFIND" | grep -c '^NANOZERO$'    2>/dev/null)
            _C_JSON=$(printf '%s\n'  "$_RFIND" | grep -c '^JSONBEFORE$'  2>/dev/null)
            [ "${_C_IMM:-0}" -gt 0 ]  2>/dev/null && { alert "  ${_C_IMM} replay(s) .bin com flag de IMUTABILIDADE (chattr +i) — touch bypass real"; REPLAY_HITS=$((REPLAY_HITS+1)); }
            [ "${_C_TS:-0}" -gt 0 ]   2>/dev/null && { alert "  ${_C_TS} replay(s) .bin com timestamp ANÔMALO (ano <1981 ou >2030) — touch bypass"; REPLAY_HITS=$((REPLAY_HITS+1)); }
            [ "${_C_ACC:-0}" -gt 0 ]   2>/dev/null && { warn "  ${_C_ACC} arquivo(s) de replay com Access > Modify >7d (possível touch -d antigo)"; REPLAY_HITS=$((REPLAY_HITS+1)); }
            [ "${_C_NANO:-0}" -gt 0 ]  2>/dev/null && { alert "  ${_C_NANO} arquivo(s) de replay com nanossegundos zerados em mtime (touch)"; REPLAY_HITS=$((REPLAY_HITS+1)); }
            [ "${_C_JSON:-0}" -gt 0 ]  2>/dev/null && { alert "  ${_C_JSON} replay(s) com JSON modificado ANTES do BIN (anomalia)"; REPLAY_HITS=$((REPLAY_HITS+1)); }
        fi
        # arquivos não-.bin/.json na pasta de replay
        ODD=$(find "$RDIR" -type f ! -name '*.bin' ! -name '*.json' 2>/dev/null)
        [ -n "$ODD" ] && echo "$ODD" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Arquivo estranho em MReplays: $L"
        done
        # folder timestamps vs file timestamps
        FOLDER_MOD=$(stat -c '%Y' "$RDIR" 2>/dev/null)
        LAST_FILE_MOD=$(find "$RDIR" -maxdepth 1 -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -n 1 | cut -d. -f1)
        if [ -n "$FOLDER_MOD" ] && [ -n "$LAST_FILE_MOD" ] && [ "$FOLDER_MOD" -gt "$LAST_FILE_MOD" ] 2>/dev/null; then
            warn "  Folder Modify > último file Modify (replay deletado?)"
        fi
        # === DG7 SS finding: group ownership check ===
        # Replays criados in-game = grupo do app FF
        # Group 1015 (sdcard_rw) ou 9997 (everybody) = arquivo veio de fora (WhatsApp/SHAREit transfer)
        ls -nl "$RDIR" 2>/dev/null | awk '
            NR>1 && $4 ~ /^(1015|9997)$/ {
                printf "EXTERN_REPLAY|%s|gid=%s|%s\n", $NF, $4, $1
            }
            NR>1 && $1 ~ /x/ && $NF ~ /\.(bin|json)$/ {
                printf "EXEC_REPLAY|%s|%s\n", $NF, $1
            }' 2>/dev/null | while IFS='|' read -r KIND FNAME GID PERMS; do
            case "$KIND" in
                EXTERN_REPLAY) alert "Replay com origem externa (group=$(echo $GID|sed 's/gid=//')): $FNAME — transferido entre devices?" ;;
                EXEC_REPLAY)   alert "Replay com permissão de EXECUÇÃO: $FNAME (perms=$GID) — arquivo alterado/injetado" ;;
            esac
        done
        # === DG7 SS: replay antes do boot — ALERTA REMOVIDO (FP real-device, v4.4.99) ===
        # "mtime do replay < btime do boot" sozinho NÃO é evidência de passador: QUALQUER replay
        # gravado antes do último reboot satisfaz isso (caso normal — o jogador só não gravou
        # replay desde que ligou o aparelho) → dava CRÍTICO falso. O sinal real de replay copiado/
        # passado é a ORIGEM EXTERNA (group 1015/9997 = EXTERN_REPLAY) e a permissão de EXECUÇÃO
        # (EXEC_REPLAY), ambas ACIMA e seguem como ALERTA. As atribuições abaixo são mantidas
        # porque LATEST_BIN/LATEST_JSON alimentam o bloco NANOSECOND FORENSICS logo adiante.
        LATEST_BIN=$(ls -t "$RDIR"/*.bin 2>/dev/null | head -1)
        LATEST_JSON=$(ls -t "$RDIR"/*.json 2>/dev/null | head -1)

        # === NANOSECOND FORENSICS ===
        # v4.4.32: TODO o bloco roda só se o fs do replay suporta nanos.
        # /sdcard em modo vfat/sdcardfs legacy NUNCA tem nanos — gerava ALERTA
        # crítico em 100% dos replays. Agora checa antes.
        if [ -n "$LATEST_BIN" ] && [ -n "$LATEST_JSON" ] && fs_has_nanos "$LATEST_BIN"; then
            ABIN=$(stat "$LATEST_BIN"  2>/dev/null | grep 'Access:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)
            MBIN=$(stat "$LATEST_BIN"  2>/dev/null | grep 'Modify:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)
            CBIN=$(stat "$LATEST_BIN"  2>/dev/null | grep 'Change:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)
            AJSON=$(stat "$LATEST_JSON" 2>/dev/null | grep 'Access:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)
            MJSON=$(stat "$LATEST_JSON" 2>/dev/null | grep 'Modify:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)
            CJSON=$(stat "$LATEST_JSON" 2>/dev/null | grep 'Change:' | tail -1 | awk '{print $3}' | cut -d'.' -f2 | cut -c1-9)

            # Nanos zerados em TODOS os campos = bypass forte (em fs com nanos).
            # Antes: qualquer um zerado disparava. Agora: tem que ser TODOS,
            # senão é só uma syscall que perdeu precisão.
            ZERO_COUNT=0
            for N in "$ABIN" "$MBIN" "$CBIN" "$AJSON" "$MJSON" "$CJSON"; do
                [ "$N" = "000000000" ] && ZERO_COUNT=$((ZERO_COUNT+1))
            done
            if [ "$ZERO_COUNT" -ge 4 ] 2>/dev/null; then
                alert "Replay nanos ZERADOS em $ZERO_COUNT/6 timestamps — bypass via touch"
            elif [ "$ZERO_COUNT" -gt 0 ] 2>/dev/null; then
                info "Replay nanos: $ZERO_COUNT/6 zerados (provável fs limitation)"
            fi
            # v4.4.102: heurística `999` removida (era FP puro contado 1×/campo = até 6× o MESMO
            # valor → inflava o veredito). Nanos legítimo é aleatório; timestomp real ZERA os nanos
            # (coberto pelo ZERO_COUNT acima). Sem base forense.
            # BIN: Modify != Change só conta se o delta de nanos é grande
            if [ -n "$MBIN" ] && [ -n "$CBIN" ] && [ "$MBIN" != "$CBIN" ]; then
                warn "Replay BIN: Modify != Change (nanos) — possível alteração"
            fi
            if [ -n "$MJSON" ] && [ -n "$CJSON" ] && [ "$MJSON" != "$CJSON" ]; then
                warn "Replay JSON: Modify != Change (nanos) — possível alteração"
            fi
            # BIN/JSON primeiro dígito divergente
            BF=$(echo "$ABIN"  | cut -c1)
            JF=$(echo "$AJSON" | cut -c1)
            if [ -n "$BF" ] && [ -n "$JF" ] && [ "$BF" != "$JF" ]; then
                warn "Replay BIN+JSON primeiro dígito divergente — gerados separadamente?"
            fi
            # Timezone consistency (offset do stat)
            TZ_BIN=$(stat "$LATEST_BIN" 2>/dev/null | grep 'Modify:' | tail -1 | sed 's/.*\([-+][0-9][0-9][0-9][0-9]\)$/\1/')
            TZ_DEV=$(date +%z 2>/dev/null)
            if [ -n "$TZ_BIN" ] && [ -n "$TZ_DEV" ] && [ "$TZ_BIN" != "$TZ_DEV" ]; then
                alert "Timezone do REPLAY ($TZ_BIN) ≠ device atual ($TZ_DEV) — replay de outro fuso (transferido?)"
            fi
        elif [ -n "$LATEST_BIN" ]; then
            info "Replay em FS sem suporte a nanos — análise temporal limitada a segundos"
        fi
    fi
done
[ "$REPLAY_HITS" = "0" ] && ok "Replays sem anomalia temporal óbvia"

# ============================================================
#  12. FREE FIRE - OBB
# ============================================================
header "OBB DO FREE FIRE"

OBB_HITS=0
for PKG in $FF_PKGS; do
    OBB_DIR="/sdcard/Android/obb/$PKG"
    [ -d "$OBB_DIR" ] || continue
    info "OBB: $OBB_DIR"
    ls -la "$OBB_DIR" 2>/dev/null | tail -n +2 | grep -v '^total' | while IFS= read -r L; do
        info "  $L"
    done
    if have find; then
        ODD=$(find "$OBB_DIR" -type f ! -name '*.obb' 2>/dev/null)
        [ -n "$ODD" ] && echo "$ODD" | while IFS= read -r L; do
            [ -n "$L" ] && alert "NÃO-OBB em OBB: $L"
        done
        SMALL=$(find "$OBB_DIR" -type f -name '*.obb' -size -1M 2>/dev/null)
        [ -n "$SMALL" ] && alert "OBB <1MB: $SMALL"
        for OBB in "$OBB_DIR"/*.obb; do
            [ -f "$OBB" ] || continue
            BN=$(basename "$OBB")
            case "$BN" in
                main.*.com.dts.freefireth.obb|patch.*.com.dts.freefireth.obb|\
                main.*.com.dts.freefiremax.obb|patch.*.com.dts.freefiremax.obb) ;;
                *) alert "OBB nome não-padrão: $OBB"; OBB_HITS=$((OBB_HITS+1)) ;;
            esac
        done
    fi
done
[ "$OBB_HITS" = "0" ] && ok "OBB sem indícios na pasta padrão"

# OBB ESCONDIDA fora da pasta padrão (vetor recém-descoberto)
# Cheats escondem em /sdcard/MIUI/sound_recorder/fm_rec/ e outras pastas
if have find; then
    HIDDEN_OBB=$(find "$SDCARD" 2>/dev/null \
        -maxdepth 6 -type f -name '*.obb' \
        ! -path '*/Android/obb/*' 2>/dev/null | head -n 30)
    if [ -n "$HIDDEN_OBB" ]; then
        echo "$HIDDEN_OBB" | while IFS= read -r O; do
            [ -z "$O" ] && continue
            SZ=$(stat -c '%s' "$O" 2>/dev/null)
            MT=$(stat -c '%y' "$O" 2>/dev/null)
            alert "OBB ESCONDIDA fora de Android/obb/: $O ($SZ b, $MT)"
        done
    fi
    # Qualquer arquivo com nome de FF fora dos paths esperados
    HIDDEN_FF=$(find /sdcard 2>/dev/null -maxdepth 6 -type f -iname '*com.dts.freefire*' \
        ! -path '*/Android/obb/*' ! -path '*/Android/data/*' ! -path '*FFScanner*' 2>/dev/null | head -n 20)
    [ -n "$HIDDEN_FF" ] && echo "$HIDDEN_FF" | while IFS= read -r F; do
        [ -n "$F" ] && alert "Arquivo FF fora dos paths esperados: $F"
    done
    # Paths conhecidos de cheat-installer (MIUI sound recorder etc.)
    for HP in /sdcard/MIUI/sound_recorder/fm_rec \
              /sdcard/MIUI/sound_recorder \
              /sdcard/Music/.cache \
              /sdcard/Movies/.cache \
              /sdcard/Pictures/.cache \
              /sdcard/Documents/.cache; do
        [ -d "$HP" ] || continue
        HIDDEN_HERE=$(find "$HP" 2>/dev/null -maxdepth 3 -type f \( -name '*.obb' -o -name '*.apk' -o -name '*.so' \) 2>/dev/null | head -n 10)
        [ -n "$HIDDEN_HERE" ] && echo "$HIDDEN_HERE" | while IFS= read -r F; do
            [ -n "$F" ] && alert "Arquivo game/cheat em pasta atípica ($HP): $F"
        done
    done
fi

# ============================================================
#  13. APKs SUSPEITOS em /sdcard
# ============================================================
header "APKs SUSPEITOS em /sdcard"

if have find; then
    APK_LIST=$(find "$SDCARD" 2>/dev/null -maxdepth 5 -type f -name '*.apk' 2>/dev/null | head -n 50)
    if [ -n "$APK_LIST" ]; then
        echo "$APK_LIST" | while IFS= read -r APK; do
            [ -z "$APK" ] && continue
            BN=$(basename "$APK")
            case "$BN" in
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*FFH4X*|*ffh4x*|*[Aa]imbot*|\
                *[Ee][Ss][Pp]*|*[Mm]enu*|*[Ii]njector*|*Frida*|*frida*|\
                *[Ww]all[Hh]ack*|*[Aa]imkill*|*VIP*FF*|*FF*VIP*|*BLOODY*|\
                *REGEDIT*|*[Hh]eadshot*|*[Bb]ypass*|*[Mm]agisk*|*KSU*|*KernelSU*|\
                *LSPatch*|*LSPosed*|*Lulubox*|*[Ll]ucky[Pp]atcher*|\
                *[Hh]olograma*|*[Hh]ologram*|*HOLO_*|*_HOLO*)
                    alert "APK suspeito: $APK" ;;
                *) info "  $APK" ;;
            esac
        done
    else
        ok "Nenhum APK em /sdcard"
    fi
fi

# MIUI/HyperOS backup com APKs
if [ -d /sdcard/MIUI/backup/AllBackup ]; then
    MIUI_BK=$(find /sdcard/MIUI/backup/AllBackup 2>/dev/null -maxdepth 3 -type f -name '*.apk' 2>/dev/null | head -n 20)
    [ -n "$MIUI_BK" ] && echo "$MIUI_BK" | while IFS= read -r L; do
        [ -n "$L" ] && warn "APK em MIUI backup: $L"
    done
fi

# === OlhosDoCapeta2: SMART CHEAT KEYWORD SCAN ===
# Procura arquivos com nomes de cheats em /sdcard inteiro (modificados em 2026)
# Lista de keywords expandida (silent_aim, neck_aim, drip, luxe, hgmods, etc.)
if have find; then
    SMART_IGNORE='Android/data|Android/obb|DCIM|Pictures|Movies|Music|WhatsApp|Telegram|\.thumbnails|FreeFire|com\.dts\.'
    # v4.4.68: assinaturas de cheat como LISTA — 1 padrão ERE por linha. O grep -E
    # trata cada linha como um -e separado (OR implícito), então não precisa da
    # regex-monstro numa linha só (estourava limite/sintaxe) e fica fácil de
    # manter/expandir. Sintaxe ERE pura: nada de (?:...) PCRE — só (...) e .?.
    # (corrige o crash 'grep: bad regex ... repetition-operator operand invalid'
    #  causado por  hologram(?:_|ff|mod|cheat)?  — o (?: não existe em ERE.)
    SMART_SIGS=$(cat <<'SIGS'
aim(bot|lock|assist)
silent.?aim
neck.?aim
no.?recoil
recoil.?off
wall.?(view|hack)
visionhack
overlayhack
injector
memoryhack
memhack
speedhack
bypass
mod.?menu
cheat.?panel
vip.?tool
ff.?tool
macro.?fire
script.?aim
passador
replay.?(tool|edit)
drip.?mod
luxe.?mod
hgmods
shizuku.?ff
mt.?manager.?ff
ffh4x
fatality
polar.?bear
teambot
op999
panelff
nova.?esp
huyjit
esp.?ff
gameguardian
gg.?script
lua.?ff
holograma
hologram(_|ff|mod|cheat)?
holo.?(ff|mod|cheat|hack|panel)
SIGS
)
    # v4.4.86: ESCOPO RESTRITO — só Download + Android/data + Android/obb, e só
    # extensões críticas (.apk/.sh/.so/.lua/.zip). Mídia/DCIM ficam de fora por
    # construção. Self-exclude do próprio scanner. Erros nativos → /dev/null.
    SMART_ROOTS="/storage/emulated/0/Download /storage/emulated/0/Android/data /storage/emulated/0/Android/obb"
    SMART_RES=$(find $SMART_ROOTS -type f \
            \( -iname '*.apk' -o -iname '*.sh' -o -iname '*.so' -o -iname '*.lua' -o -iname '*.zip' \) 2>/dev/null \
        | grep -viE '/DCIM/|a4ther|_scan_console\.log|\.(jpg|jpeg|png|mp4)$' \
        | grep -iE "$SMART_SIGS" \
        | sort -u | head -20)
    if [ -n "$SMART_RES" ]; then
        echo "$SMART_RES" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Arquivo de cheat (nome+extensão crítica): $L"
        done
    else
        ok "Smart keyword scan limpo (Download/Android-data/obb · apk/sh/so/lua/zip)"
    fi
fi

# === OlhosDoCapeta2: ATIVIDADE PÓS-PARTIDA ===
# Arquivos em MReplays/gameassetbundles modificados < 5min = mexeram após a partida
for FFPKG in com.dts.freefireth com.dts.freefiremax; do
    REPLAYS_DIR="/storage/emulated/0/Android/data/$FFPKG/files/MReplays"
    GAB_DIR_CHECK="/storage/emulated/0/Android/data/$FFPKG/files/contentcache/Optional/android/gameassetbundles"
    POS_PARTIDA=""
    [ -d "$REPLAYS_DIR" ]   && POS_PARTIDA=$(find "$REPLAYS_DIR" -type f -mmin -5 2>/dev/null | head -3)
    [ -d "$GAB_DIR_CHECK" ] && POS_PARTIDA="$POS_PARTIDA
$(find "$GAB_DIR_CHECK" -type f -mmin -5 2>/dev/null | head -3)"
    [ -n "$POS_PARTIDA" ] && echo "$POS_PARTIDA" | while IFS= read -r L; do
        [ -n "$L" ] && warn "Arquivo modificado < 5min (pós-partida): $L"
    done
done

# === OlhosDoCapeta2: HORA AUTOMÁTICA DESLIGADA ===
# Usuário desliga hora automática pra spoofar timestamp dos replays
AUTO_TIME=$(setting_get global auto_time)
AUTO_TZ=$(setting_get global auto_time_zone)
if [ "$AUTO_TIME" = "0" ]; then
    alert "Hora automática DESATIVADA (auto_time=0) — usuário pode spoofar timestamps"
fi
if [ "$AUTO_TZ" = "0" ]; then
    warn "Fuso automático DESATIVADO (auto_time_zone=0)"
fi
# Inconsistência boot vs uptime (alteração manual da hora durante a sessão)
BTIME_NOW=$(grep btime /proc/stat 2>/dev/null | awk '{print $2}')
NOW_TS=$(date +%s)
UPTIME_S=$(cut -d. -f1 /proc/uptime)
if [ -n "$BTIME_NOW" ] && [ -n "$UPTIME_S" ]; then
    EXPECTED_UP=$((NOW_TS - BTIME_NOW))
    DIFF_UP=$((EXPECTED_UP - UPTIME_S))
    [ "$DIFF_UP" -lt 0 ] && DIFF_UP=$((-DIFF_UP))
    if [ "$DIFF_UP" -gt 120 ] 2>/dev/null; then
        alert "Inconsistência tempo: uptime vs (now-boot) diferem em ${DIFF_UP}s — hora foi alterada manualmente"
    fi
fi

# ============================================================
#  14. PACOTES DE CHEAT / VIRTUALIZADORES
# ============================================================
header "PACOTES DE CHEAT / VIRTUALIZADORES"

CHEAT_PKGS="
com.proxy.free
com.holograma.ff
com.hologramff.app
com.hologram.ff
com.holograma.app
com.holo.ff
br.com.holograma.ff
com.modbibi.holograma
xyzapk.hologram
com.xyzapk.hologram
com.aurel.gg.ff
com.aurelpvp.ff
com.coc.modff
com.ffh4x.menu
com.ffh4x.mod
com.fxxxx.gg
com.fxxxx.ffmaster
com.kiwi.modff
com.zoroakiff.mod
com.ginxdroid.ginxgg
com.ginx.gg
com.xmodgames.gg
com.xmodgames.modxff
com.killuabox.mod
com.bloody.ff
com.headshot.ff
com.aimkill.ff
com.regedit.ff
com.regeditff.pro
com.modff.menu
com.skinmod.ff
com.luckyboy.modff
com.naxff.injector
com.aimhook.ff
com.menuff.x
com.ffhack.tools
com.modder.ff
com.cheatdroid.ff
com.gamehunter.ff
com.suspect.fff.gg
com.exotic.ff
com.ffx.headshot
com.dynamo.ff
com.cleomenu.ff
com.darksoul.ff
com.ankit.injector
com.tehnoinfra.injector
com.proff.injector
com.coc.king.cheat
com.spyhuman.ffinject
com.modder.king.ff
com.darkmoddroid.ff
com.lulubox.gg
com.luluboxruncenter.gg
com.aurora.store
io.virtualapp
com.lbe.parallel
com.lbe.parallel.intl
com.excelliance.dualaid
com.lody.virtual
com.parallel.space
com.parallel.space.lite
com.ludashi.dualspace
com.dualspace.cloner
com.swift.dualspace
com.qihoo.magic
com.cloneapp.go
multispace.cloner.dualspace
com.applisto.appcloner
com.x8zs.sandbox
com.x8zs.platform
com.cih.game_cih
com.cih.gamecih2
com.gtarcade.cih
com.chelpus.lackypatch
com.chelpus.luckypatcher
com.dimonvideo.luckypatcher
com.forpda.lp
ru.org.amse.android.gamekiller
com.felixheller.sharedprefsedit
com.as.autoshoot.nxs
io.va.exposed
com.vmos.pro
com.oasisfeng.island
com.smarte.virtual.app
com.gbwhatsapp
com.tsng.hidemyapplist
net.dinglisch.android.taskerm
com.arlosoft.macrodroid
com.llamalab.automate
com.eternal.xdsdk.App
com.fff_ffh4xforfire.ff_modmenuhack
"

CHEAT_HITS=0
if [ -n "$ALL_PKGS" ]; then
    for PKG in $CHEAT_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && {
            alert "Cheat pkg: $PKG"; CHEAT_HITS=$((CHEAT_HITS+1));
        }
    done
    HEUR=$(echo "$ALL_PKGS" | grep -Ei 'package:.*(ffh4x|aimkill|aimbot|wallhack|esp\.ff|modmenu|gamehack|hookboy|freefire.*mod|mod.*freefire|ffmod|nyx\.ff|headshot\.ff|cheat\.ff|ff\.cheat|ff\.mod)' | sed 's/^package://')
    [ -n "$HEUR" ] && echo "$HEUR" | while IFS= read -r L; do
        [ -n "$L" ] && alert "Pkg por padrão de nome: $L"
    done
fi
[ "$CHEAT_HITS" = "0" ] && ok "Sem cheat package conhecido"

# ============================================================
#  15. MEMORY EDITORS
# ============================================================
header "MEMORY EDITORS"

MEM_PKGS="com.gameguardian com.gg.intersec gg.intersec catch_.me_.if_.you_.can_ com.cih.game_cih com.cih.gamecih2 com.glasswire.cih com.gtarcade.cih ru.org.amse.android.gamekiller com.taogame.taogame com.felixheller.sharedprefsedit com.android.helloworld com.cheatengine.android com.kuhakupixel.acethegame com.tonicboomerkewl.tonicguardian"
# Virtual sandboxes (permitem GG sem root — vetor stealth 2026)
VSPACE_PKGS="io.virtualapp com.lbe.parallel.intl com.parallel.space.lite com.excelliance.dualaid com.ludashi.dualspace com.icecold.gomultiple me.weishu.exp"
for PKG in $VSPACE_PKGS; do
    [ -n "$ALL_PKGS" ] && echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Virtual sandbox (permite GG sem root): $(pkg_show "$PKG")"; MEM_HITS=$((MEM_HITS+1)); }
done
# FFH4X family + injectors Android FF 2026
# v4.4.89: keymappers/mapeamento de tela (mantis gamepad/mouse) SAÍRAM daqui — não são
# injeção em memória nem dão vantagem balística real; foram pro §16 (warn não-crítico).
# Aqui ficam SÓ injetores/painéis reais.
FFCHEAT_PKGS="com.ffh4x com.ff.injector com.op999.injector com.teambot.injector com.tb71.injector com.ng.injector com.panelff.app com.novaesp tn.loukious.fakerunlocker"
for PKG in $FFCHEAT_PKGS; do
    [ -n "$ALL_PKGS" ] && echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Cheat injector/painel FF: $(pkg_show "$PKG")"; MEM_HITS=$((MEM_HITS+1)); }
done
MEM_HITS=0
if [ -n "$ALL_PKGS" ]; then
    for PKG in $MEM_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Mem editor: $PKG"; MEM_HITS=$((MEM_HITS+1)); }
    done
fi
for P in /sdcard/Notezilla /sdcard/Guarded.json /sdcard/.GameGuardian \
         /sdcard/GameGuardian /sdcard/.gg /sdcard/GG; do
    exists "$P" && { alert "GameGuardian artifact: $P"; MEM_HITS=$((MEM_HITS+1)); }
done
if have find; then
    GG=$(find /sdcard 2>/dev/null -maxdepth 4 -type f \( -name '*.gg' -o -name '*.vbm' -o -name '*.gg2' -o -name '*.gg3' \) 2>/dev/null | head -n 10)
    [ -n "$GG" ] && echo "$GG" | while IFS= read -r L; do
        [ -n "$L" ] && alert "Script GG: $L"
    done
fi
[ "$MEM_HITS" = "0" ] && ok "Sem editor de memória"

# ============================================================
#  16. MACROS / AUTOCLICKER + KEYMAPPERS (hardware externo)
# ============================================================
header "MACROS / KEYMAPPERS"

MACRO_PKGS="
com.tools.autoclicker
com.truedevelopersstudio.automatictap.autoclicker
com.cheatdroid.autoclicker
com.autoclicker.clicker
com.touchassistant.autotap
com.macrokeyboard.android
app.mantispro.gamepad
app.mantispro.mouse
mantis.mouse.pro.beta
com.repetitouch.repetitouch
com.repetitouch.repetitouchpro
com.macropro.touch
com.autotouch.android
bishakhghosh.macroclicker
com.byrobin.spiderboy
com.gamermob.amgmob
com.zhiliao.app.touchsimulation
com.gamesir.global
com.tincore.gsp.gpad
com.flydigi.center
com.panda.gamepad
com.mantis.gamepad
com.regula.mantisactivator
io.github.ggmouse
"

MACRO_HITS=0
if [ -n "$ALL_PKGS" ]; then
    # FP real-device: dedup — pacote que JÁ casou a lista exata (MACRO_PKGS) NÃO deve sair de
    # novo pelo heurístico (HEUR). Antes, o autoclicker conhecido saía 2× ("Macro/keymap" +
    # "Pkg padrão macro"). MACRO_SEEN registra os já-flagados; o HEUR pula esses.
    MACRO_SEEN=""
    for PKG in $MACRO_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { warn "Macro/keymap (não-crítico): $PKG"; MACRO_HITS=$((MACRO_HITS+1)); MACRO_SEEN="$MACRO_SEEN $PKG"; }
    done
    HEUR=$(echo "$ALL_PKGS" | grep -Ei 'package:.*(autoclick|autotap|macro|touchsim|repetitouch|autotouch|gamepad|keymap)' | sed 's/^package://')
    [ -n "$HEUR" ] && echo "$HEUR" | while IFS= read -r L; do
        [ -z "$L" ] && continue
        case " $MACRO_SEEN " in *" $L "*) continue ;; esac
        warn "Pkg padrão macro: $L"
    done
fi
[ "$MACRO_HITS" = "0" ] && ok "Sem macro/keymapper"

# ============================================================
#  17. FILE MANAGERS perigosos (usados pra esconder mods)
# ============================================================
header "FILE MANAGERS perigosos"

FM_HITS=0
for PKG in bin.mt.plus bin.mt.signature.killer ru.zdevs.zarchiver \
           com.alphainventor.filemanager com.ace.ex.filemanager \
           com.rs.explorer.filemanager com.rxfileexplorer \
           com.a0soft.gphone.uninstaller; do
    pkg_installed "$PKG" && { warn "File manager: $PKG"; FM_HITS=$((FM_HITS+1)); }
done
[ "$FM_HITS" = "0" ] && ok "Sem file manager arriscado"

# ============================================================
#  17b. FILE MANAGERS - USO RECENTE (quando foram abertos)
# ============================================================
header "FILE MANAGERS - HISTÓRICO DE USO"

FM_TRACKED="
bin.mt.plus
ru.zdevs.zarchiver
ru.zdevs.zarchiverpro
com.alphainventor.filemanager
com.ace.ex.filemanager
com.rs.explorer.filemanager
com.rxfileexplorer
com.sec.android.app.myfiles
com.mi.android.globalFileexplorer
com.miui.gallery
com.android.documentsui
com.google.android.documentsui
com.google.android.apps.nbu.files
com.estrongs.android.pop
com.lonelycatgames.Xplore
com.cxinventor.file.explorer
com.amaze.filemanager
com.simplemobiletools.filemanager
com.huawei.filemanager
com.coloros.filemanager
com.realme.filemanager
com.transsion.filemanager
com.tencent.qqfilemanager
com.solidexplorer2
com.solidexplorer
com.metago.astro
"

FM_USED_HITS=0
if have dumpsys; then
    USAGEDUMP=$(dumpsys usagestats 2>/dev/null)
    for PKG in $FM_TRACKED; do
        pkg_installed "$PKG" || continue
        LAST=$(echo "$USAGEDUMP" | awk -v p="$PKG" '
            $0 ~ "package="p" " {found=1}
            found && /lastTimeUsed/ {print; found=0}
        ' | head -n 1)
        if [ -n "$LAST" ]; then
            LAST_MS=$(echo "$LAST" | grep -oE '[0-9]{12,}' | head -n 1)
            if [ -n "$LAST_MS" ]; then
                LAST_S=$((LAST_MS / 1000))
                LAST_DATE=$(date -d "@$LAST_S" 2>/dev/null || date -r "$LAST_S" 2>/dev/null)
                NOW_S=$(date +%s 2>/dev/null)
                if [ -n "$NOW_S" ]; then
                    AGE_M=$(( (NOW_S - LAST_S) / 60 ))
                    AGE_H=$(( AGE_M / 60 ))
                    if [ "$AGE_H" -lt 24 ] 2>/dev/null; then
                        alert "$PKG aberto há ${AGE_H}h ${AGE_M}min ($LAST_DATE)"
                    elif [ "$AGE_H" -lt 168 ] 2>/dev/null; then
                        warn "$PKG aberto há ${AGE_H}h ($LAST_DATE)"
                    else
                        info "$PKG aberto em $LAST_DATE"
                    fi
                    FM_USED_HITS=$((FM_USED_HITS+1))
                fi
            else
                info "$PKG instalado (último uso indeterminado)"
            fi
        else
            info "$PKG instalado (sem registro usagestats)"
        fi
    done
fi

# Eventos am_resume_activity de file managers no logcat
if have logcat; then
    RES_EVENTS=$(timeout 5 logcat -b events -d 2>/dev/null | grep -iE 'am_activity_resume|am_resume_activity' | grep -iE 'filemanager|fileexplorer|zarchiver|myfiles|documentsui|estrongs|xplore|amaze|solidexplorer|astro' | tail -n 15)
    if [ -n "$RES_EVENTS" ]; then
        info "Eventos de file manager no logcat (am_resume_activity):"
        echo "$RES_EVENTS" | while IFS= read -r L; do
            [ -n "$L" ] && info "  $(echo "$L" | head -c 180)"
        done
    fi
fi

# Cache/histórico recente de file managers
for HISTDIR in /sdcard/Android/data/com.sec.android.app.myfiles/cache \
                /sdcard/Android/data/com.mi.android.globalFileexplorer/cache \
                /sdcard/Android/data/ru.zdevs.zarchiver/cache \
                /sdcard/Android/data/com.android.documentsui/cache; do
    [ -d "$HISTDIR" ] || continue
    if have find; then
        RECENT=$(find "$HISTDIR" 2>/dev/null -maxdepth 2 -type f -mtime -7 2>/dev/null | head -n 10)
        [ -n "$RECENT" ] && {
            info "Cache recente em $HISTDIR:"
            echo "$RECENT" | while IFS= read -r L; do
                MT=$(stat -c '%y' "$L" 2>/dev/null)
                info "  $L ($MT)"
            done
        }
    fi
done

[ "$FM_USED_HITS" = "0" ] && ok "Nenhum file manager rastreado em uso recente"

# ============================================================
#  19. SPOOFERS (GPS / DeviceID / IMEI)
# ============================================================
header "SPOOFERS (GPS / DeviceID / IMEI)"

SPOOF_PKGS="
com.lexa.fakegps
com.fakegps.mock
com.incorporateapps.fakegps_route
com.metatech.deviceidfaker
com.deviceid.changer
com.xposed.imei
com.devicechanger.free
com.imei.generator
com.imeichanger.imei
com.xposed.imei.changer
"
SPOOF_HITS=0
if [ -n "$ALL_PKGS" ]; then
    for PKG in $SPOOF_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Spoofer: $PKG"; SPOOF_HITS=$((SPOOF_HITS+1)); }
    done
fi
[ "$SPOOF_HITS" = "0" ] && ok "Sem spoofer"

# ============================================================
#  20. VPNs + APPS DE BYPASS de rede
# ============================================================
header "VPNs / Bypass de rede"

VPN_PKGS="
com.nordvpn.android
com.protonvpn.android
com.expressvpn.vpn
com.surfshark.vpnclient.android
com.cloudflare.onedotonedotonedotone
com.hiddify.app
com.github.shadowsocks
com.shadowsocks.vpn
com.v2ray.ang
net.openvpn.openvpn
de.blinkt.openvpn
com.netcatch.network
"
VPN_HITS=0
if [ -n "$ALL_PKGS" ]; then
    for PKG in $VPN_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { warn "VPN app: $PKG"; VPN_HITS=$((VPN_HITS+1)); }
    done
fi
[ "$VPN_HITS" = "0" ] && ok "Sem app VPN"

# ============================================================
#  21. PROXY / SNIFFER / MITM
# ============================================================
header "PROXY / SNIFFER / MITM"

PROXY_HITS=0
if have settings; then
    # v4.4.3: usa setting_get pra filtrar "Failure calling service settings"
    HTTP_PROXY=$(setting_get global http_proxy)
    case "$HTTP_PROXY" in
        ""|":0") ok "Sem proxy global" ;;
        *) alert "Proxy global ATIVO: $HTTP_PROXY"; PROXY_HITS=$((PROXY_HITS+1)) ;;
    esac
    PROXY_HOST=$(setting_get global global_http_proxy_host)
    PROXY_PORT=$(setting_get global global_http_proxy_port)
    [ -n "$PROXY_HOST" ] && {
        alert "Proxy host: $PROXY_HOST:$PROXY_PORT"; PROXY_HITS=$((PROXY_HITS+1));
    }
fi

PROXY_PKGS="com.httpcanary.pro com.guoshi.httpcanary com.guoshi.httpcanary.premium tech.httptoolkit.android.v1 io.github.lsposed.lspatch com.minhui.networkcapture com.minhui.networkcapture.pro com.evbadroid.proxymon com.evbadroid.wicap com.adguard.android.contentblocker com.lonelycatgames.HTTPProxy com.emanuelef.remote_capture com.packetcapture.android com.reqable.android com.proxyman.proxyman"

if [ -n "$ALL_PKGS" ]; then
    for PKG in $PROXY_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Sniffer: $PKG"; PROXY_HITS=$((PROXY_HITS+1)); }
    done
fi

# v4.4.86: CAs de usuário (Mitmproxy/Burp/injeção). v4.4.93: o dir é ROOT-ONLY em
# muitos devices (HyperOS/Android 14+ → "Permission denied" pro uid 2000). Antes o
# erro caía no 2>/dev/null e o check passava como "limpo" = FALSO NEGATIVO. Agora
# distingue 3 casos: lê+lista (CA presente) / lê vazio (limpo) / SEM ACESSO (avisa
# que NÃO foi possível verificar — não finge limpo). Cert real só via root/bugreport.
CERT_DIR="/data/misc/user/0/cacerts-added"
_CERT_LS=$(ls -A "$CERT_DIR" 2>/dev/null)
if [ -n "$_CERT_LS" ]; then
    alert "[CRÍTICO] Certificado CA de Usuário detectado (Possível Mitmproxy/Injeção de Rede)."
    PROXY_HITS=$((PROXY_HITS+1))
    printf '%s\n' "$_CERT_LS" | while IFS= read -r L; do
        [ -n "$L" ] && info "  CA: $L"
    done
elif ! ls -A "$CERT_DIR" >/dev/null 2>&1; then
    # ls falhou (permission denied) → NÃO é limpo, é "não verificável" sem root.
    # v4.4.93: confirmado que nem o bugreport (dumpstate) dumpa esse store → a
    # única verificação confiável sem root é MANUAL, nas Configurações.
    warn "Store de CAs de usuário inacessível sem root ($CERT_DIR) — MITM/Mitmproxy NÃO verificável via ADB."
    warn "  CONFIRA MANUALMENTE: Ajustes → Segurança → Credenciais → 'Credenciais do usuário'. Qualquer CA tipo 'o=mitmproxy' / Charles / Burp = injeção de rede (cheat)."
fi

# v4.4.93: proxy POR-Wi-Fi. O check global acima só vê o `http_proxy` global; o
# mitm clássico é setado como proxy MANUAL na rede Wi-Fi (não cai no global).
# dumpsys mostra "Proxy settings: NONE" quando limpo; STATIC/PAC quando há proxy.
if have dumpsys; then
    WIFI_PROXY=$(dumpsys wifi 2>/dev/null | grep -iE 'Proxy settings:' | grep -ivE 'NONE|UNASSIGNED' | head -3)
    [ -n "$WIFI_PROXY" ] && { alert "Proxy por-Wi-Fi configurado: $(printf '%s' "$WIFI_PROXY" | head -1 | tr -s ' ')"; PROXY_HITS=$((PROXY_HITS+1)); }
fi

# v4.4.93: interface VPN ATIVA via /sys/class/net. O `ip link` é NEGADO pro shell
# em HyperOS (netlink "Permission denied"); /sys/class/net é leitura de arquivo,
# que o uid 2000 LÊ. Flag só tun/tap/ppp/wg + dígito (VPN real, ex. tun0) com
# operstate up/unknown; IGNORA tunl0/sit0/gre0/ccmni*/dummy*/ifb*/miw_oem*/p2p*
# (interfaces de kernel/modem padrão deste MTK/HyperOS). Pega o mitm-via-VPN ativo.
if [ -d /sys/class/net ]; then
    VPN_IF=""
    for _IF in $(ls /sys/class/net 2>/dev/null | grep -E '^(tun|tap|ppp|wg)[0-9]+$'); do
        _ST=$(cat "/sys/class/net/$_IF/operstate" 2>/dev/null)
        case "$_ST" in up|unknown) VPN_IF="$VPN_IF $_IF($_ST)" ;; esac
    done
    [ -n "$VPN_IF" ] && { alert "Interface VPN ATIVA:$VPN_IF — túnel ligado (possível rota de mitm/bypass)"; PROXY_HITS=$((PROXY_HITS+1)); }
fi

if have iptables; then
    REDIR=$(iptables -t nat -L OUTPUT -n 2>/dev/null | grep -E 'REDIRECT|DNAT')
    [ -n "$REDIR" ] && { alert "iptables REDIRECT/DNAT ativo"; PROXY_HITS=$((PROXY_HITS+1)); }
fi
[ "$PROXY_HITS" = "0" ] && ok "Sem proxy/sniffer/MITM"

# ============================================================
#  21b. DEVICE ADMINS / VPN PROFILES / WI-FI PROXY
#       (Android equivalente do iOS Configuration Profile)
# ============================================================
header "DEVICE ADMINS / VPN PROFILES / WI-FI PROXY"

DA_HITS=0

# 1) Device admins (apps com poder de admin do device)
if have dumpsys; then
    DA_INFO=$(dumpsys device_policy 2>/dev/null)
    if [ -n "$DA_INFO" ]; then
        ACTIVE=$(echo "$DA_INFO" | grep -E 'Active admin|ComponentName=|ComponentInfo\{' | head -n 15)
        if [ -n "$ACTIVE" ]; then
            echo "$ACTIVE" | while IFS= read -r L; do
                [ -z "$L" ] && continue
                # v4.4.101: era whitelist por SUBSTRING DA LINHA (`*com.android.*`) — 2 bugs: (a)
                # FORJÁVEL (rename p/ com.miui.securitycenter escapava); (b) FN REAL: um admin
                # malicioso cuja CLASSE contém com.android. (ex.: com.evil.app/com.android.Admin)
                # casava `*com.android.*` e virava `info`. Agora extrai o PACOTE do ComponentName
                # (pkg/cls) e decide por is_oem_preload (device-admin = vetor de persistência).
                # v4.4.101 (fix Fable 5): a CLASSE pode vir RELATIVA (flattenToShortString abrevia
                # p/ `pkg/.Cls` quando a classe é do próprio pacote = o DEFAULT, escolha do atacante)
                # → regex aceita classe começando com `.`. Se a linha tem `/` mas não parseou =
                # FAIL-CLOSED (warn), nunca info (o info era fail-open p/ admin malicioso).
                DA_PKG=$(echo "$L" | grep -oE '[a-zA-Z][a-zA-Z0-9_.]+/[.a-zA-Z][a-zA-Z0-9_.$]*' | head -1 | cut -d/ -f1)
                if [ -z "$DA_PKG" ]; then
                    case "$L" in
                        */*) warn "  admin device-policy não-parseável (revisar): $(echo "$L" | head -c 140)"; DA_HITS=$((DA_HITS+1)) ;;
                        *)   info "  admin: $(echo "$L" | head -c 140)" ;;   # header/linha sem componente
                    esac
                    continue
                fi
                # v4.4.101 (fix Fable 5): NÃO liberar por nome forjável. Os admins OEM genuínos
                # (Find My Device/Device Care/Security Center) são SYSTEM → caem no is_oem_preload
                # abaixo (não-forjável). Único mantido por nome = clouddpc (MDM corporativo, é o
                # único legítimo NÃO-preload) — residual estreito; ancorar por cert num follow-up.
                [ "$DA_PKG" = "com.google.android.apps.work.clouddpc" ] && { info "  admin: $DA_PKG (Android Device Policy/MDM)"; continue; }
                is_oem_preload "$DA_PKG" "" "$(pm path "$DA_PKG" 2>/dev/null | head -1 | sed 's/^package://')" \
                    && { info "  admin (sistema): $DA_PKG"; continue; }
                warn "  admin de 3rd party (device-admin — vetor de persistência de RAT/cheat): $DA_PKG"
                DA_HITS=$((DA_HITS+1))
            done
        fi
    fi

    # 2) Managed profiles (work profile, multi-user)
    USR_INFO=$(dumpsys user 2>/dev/null | grep -E 'UserInfo|isManagedProfile|MANAGED_PROFILE')
    if [ -n "$USR_INFO" ]; then
        MGD=$(echo "$USR_INFO" | grep -iE 'managed' | head -n 5)
        [ -n "$MGD" ] && {
            warn "Managed/work profile presente:"
            echo "$MGD" | while IFS= read -r L; do warn "  $(echo "$L" | head -c 140)"; done
            DA_HITS=$((DA_HITS+1))
        }
    fi
fi

# 3) VPN profiles armazenados
for VDIR in /data/misc/vpn /data/system/vpn /data/misc/keystore/user_0; do
    [ -d "$VDIR" ] || continue
    VFILES=$(ls "$VDIR" 2>/dev/null)
    [ -n "$VFILES" ] && {
        info "VPN/key storage em $VDIR:"
        echo "$VFILES" | head -n 10 | while IFS= read -r F; do
            [ -n "$F" ] && warn "  $F"
        done
        DA_HITS=$((DA_HITS+1))
    }
done

# 4) Wi-Fi configs com proxy POR REDE (proxy só ativa em uma SSID = cheat lobby)
for WIFI_CFG in /data/misc/wifi/WifiConfigStore.xml \
                /data/misc/apexdata/com.android.wifi/WifiConfigStore.xml \
                /data/misc/wifi/networkHistory.txt; do
    [ -r "$WIFI_CFG" ] || continue
    PROXY_WIFI=$(grep -iE 'ProxySettings|ProxyHost|ProxyPort|PacFileUrl|HTTPProxy' "$WIFI_CFG" 2>/dev/null | head -n 10)
    if [ -n "$PROXY_WIFI" ]; then
        alert "Wi-Fi config com PROXY (proxy por SSID):"
        echo "$PROXY_WIFI" | while IFS= read -r L; do
            [ -n "$L" ] && alert "  $(echo "$L" | head -c 160)"
        done
        DA_HITS=$((DA_HITS+1))
    fi
done

# 5) Always-on VPN (app que SEMPRE roteia)
if have settings; then
    ALWAYS_VPN=$(setting_get global always_on_vpn_app)
    [ -n "$ALWAYS_VPN" ] && {
        alert "Always-on VPN ativo: $ALWAYS_VPN"
        DA_HITS=$((DA_HITS+1))
    }
    LOCKDOWN=$(setting_get global always_on_vpn_lockdown)
    [ "$LOCKDOWN" = "1" ] && alert "Always-on VPN com LOCKDOWN (todo tráfego forçado pelo VPN)"
fi

# 6) Estado da conectividade VPN
if have dumpsys; then
    VPN_INFO=$(dumpsys connectivity 2>/dev/null | grep -iE 'VPN|tun[0-9]' | head -n 5)
    [ -n "$VPN_INFO" ] && {
        info "Conectividade VPN ativa:"
        echo "$VPN_INFO" | while IFS= read -r L; do info "  $(echo "$L" | head -c 160)"; done
    }
fi

# 7) Perfis de provisioning de MDM/Enterprise
for MDM in /data/system/profiles.xml /data/system/users/0/managed_profile.xml \
           /data/system/devicepolicies.xml /data/system/users/0/admins.xml; do
    [ -r "$MDM" ] || continue
    info "MDM profile: $MDM ($(stat -c '%s' "$MDM" 2>/dev/null) bytes)"
    HEAD=$(head -c 500 "$MDM" 2>/dev/null)
    [ -n "$HEAD" ] && info "  preview: $(echo "$HEAD" | head -c 200)"
    DA_HITS=$((DA_HITS+1))
done

[ "$DA_HITS" = "0" ] && ok "Sem device admin/VPN profile/Wi-Fi proxy suspeito"

# ============================================================
#  CONTROLE REMOTO / ESPELHAMENTO DE TELA (v4.4.94)
#  Vetor forense: cheat por PC (visão/aimbot via captura) + controle
#  remoto do device. Acesso remoto não tem uso legítimo numa partida.
# ============================================================
header "CONTROLE REMOTO / ESPELHAMENTO DE TELA"

REMOTE_HITS=0
for PKG in com.anydesk.anydeskandroid com.carriez.flutter_hbb \
           com.koushikdutta.vysor \
           com.teamviewer.quicksupport.market com.teamviewer.teamviewer.market.mobile \
           com.sand.airdroid com.sand.airmirror \
           com.apowersoft.mirror com.splashtop.remote.pad.v2; do
    echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && {
        alert "App de controle remoto/espelhamento: $(pkg_show "$PKG")"; REMOTE_HITS=$((REMOTE_HITS+1)); }
done
for ENTRY in \
    "/storage/emulated/0/anydesk|AnyDesk (controle remoto)" \
    "/storage/emulated/0/.anydesk|AnyDesk (controle remoto)" \
    "/storage/emulated/0/AnyDesk|AnyDesk (controle remoto)" \
    "/storage/emulated/0/rustdesk|RustDesk (controle remoto)" \
    "/storage/emulated/0/.rustdesk|RustDesk (controle remoto)" \
    "/storage/emulated/0/Vysor|Vysor (espelhamento/controle)" \
    "/storage/emulated/0/.vysor|Vysor (espelhamento/controle)" \
    "/data/local/tmp/scrcpy-server|scrcpy (espelhamento/controle via PC)"; do
    P=${ENTRY%%|*}; LBL=${ENTRY#*|}
    [ -e "$P" ] && { alert "Rastro de controle remoto: $P → $LBL"; REMOTE_HITS=$((REMOTE_HITS+1)); }
done
[ "$REMOTE_HITS" = "0" ] && ok "Nenhum app/rastro de controle remoto ou espelhamento"

# ============================================================
#  22. DNS
# ============================================================
header "DNS"

DNS_HITS=0
if have settings; then
    PDNS_MODE=$(setting_get global private_dns_mode)
    PDNS_HOST=$(setting_get global private_dns_specifier)
    case "$PDNS_MODE" in
        ""|"off"|"opportunistic") ok "Private DNS: ${PDNS_MODE:-off}" ;;
        "hostname")
            warn "Private DNS hostname: $PDNS_HOST"
            case "$PDNS_HOST" in
                *dns.google|*cloudflare-dns.com|*one.one.one.one|*quad9*) ;;
                *) alert "Private DNS custom: $PDNS_HOST"; DNS_HITS=$((DNS_HITS+1)) ;;
            esac ;;
    esac
fi
for D in /etc/resolv.conf /system/etc/resolv.conf; do
    [ -r "$D" ] && grep -v '^#' "$D" 2>/dev/null | grep nameserver | while IFS= read -r L; do
        [ -n "$L" ] && info "$D: $L"
    done
done
NET_DNS=$(gp net.dns1)
[ -n "$NET_DNS" ] && info "net.dns1=$NET_DNS"
[ "$DNS_HITS" = "0" ] && ok "DNS sem custom"

# ============================================================
#  23. PERMISSÕES PERIGOSAS / ESP / OVERLAY
# ============================================================
header "ESP / OVERLAY / ACCESSIBILITY"

ESP_HITS=0
if have settings; then
    ACC=$(setting_get secure enabled_accessibility_services)
    if [ -n "$ACC" ] && [ "$ACC" != "null" ]; then
        case "$ACC" in
            *esp*|*aimbot*|*menu*|*hack*|*cheat*|*ffh*|*ESP*|*Aim*|*Menu*|*Hack*|*Cheat*|*injector*|*bot*)
                alert "Accessibility suspeito: $ACC"; ESP_HITS=$((ESP_HITS+1)) ;;
            *) info "Accessibility: $ACC" ;;
        esac
    fi
fi
if have dumpsys; then
    OVL=$(dumpsys window 2>/dev/null | grep -E 'TYPE_APPLICATION_OVERLAY|mOverlayLayer' | grep -oE 'com\.[a-zA-Z0-9._]+' | sort -u | head -n 30)
    [ -n "$OVL" ] && echo "$OVL" | while IFS= read -r PP; do
        [ -z "$PP" ] && continue
        # v4.4.100: mantém os 3rd-party de overlay LEGÍTIMO explícitos (bolha/chat-head — NÃO são
        # system, então is_oem_preload não os cobriria); o resto: a whitelist de namespace OEM crua
        # era FORJÁVEL (com.miui.espdraw escapava) → troca por is_oem_preload (preload de sistema
        # real). Disfarce em namespace de fábrica cai no warn.
        case "$PP" in
            # NOMES EXATOS (nunca glob de namespace — glob é forjável, a classe que este patch cura):
            com.facebook.katana|com.facebook.orca|com.facebook.lite|com.whatsapp|com.whatsapp.w4b|\
            com.instagram.android|com.instagram.lite|com.instagram.barcelona|com.truecaller|\
            com.viber.voip|com.skype.raider) ;;
            *)
                is_oem_preload "$PP" "" "$(pm path "$PP" 2>/dev/null | head -1 | sed 's/^package://')" \
                    || warn "Overlay ativo: $PP" ;;
        esac
    done
fi
if [ -n "$ALL_PKGS" ]; then
    ESP_PKG=$(echo "$ALL_PKGS" | grep -Ei 'package:.*(\.esp$|esp\.|aim.*menu|menu.*ff|overlay.*ff|ff.*overlay|magicbullet|aimhack|skyboy|drawing.*ff|ff.*drawing)' | sed 's/^package://')
    [ -n "$ESP_PKG" ] && echo "$ESP_PKG" | while IFS= read -r L; do
        [ -n "$L" ] && alert "Pkg ESP/menu: $L"
    done
fi
if have find; then
    EF=$(find /sdcard 2>/dev/null -maxdepth 4 -type f -name '*.esp' 2>/dev/null | head -n 10)
    [ -n "$EF" ] && echo "$EF" | while IFS= read -r L; do
        [ -n "$L" ] && alert "Arquivo .esp: $L"
    done
fi
# v4.4.79 (A7): heurística COMPORTAMENTAL (independe de nome na blacklist) — app de
# terceiro com overlay (SYSTEM_ALERT_WINDOW) E serviço de acessibilidade ligado AO MESMO
# TEMPO = perfil clássico de PAINEL de cheat (desenha por cima + lê/clica a tela).
if have dumpsys && have settings; then
    _OVL_PKGS=$(dumpsys appops 2>/dev/null | grep -B100 'SYSTEM_ALERT_WINDOW: allow' \
        | grep -E '^[a-zA-Z0-9_.]+[[:space:]]*:[[:space:]]*\(uid=' | awk '{print $1}' | sort -u)
    _ACC_PKGS=$(setting_get secure enabled_accessibility_services | tr ':' '\n' | sed 's:/.*::' | grep -E '^[a-zA-Z]' | sort -u)
    if [ -n "$_OVL_PKGS" ] && [ -n "$_ACC_PKGS" ]; then
        printf '%s\n' "$_OVL_PKGS" | while IFS= read -r P; do
            [ -z "$P" ] && continue
            # v4.4.100: era whitelist de NAMESPACE cru (FORJÁVEL) — um cheat renomeado p/
            # com.miui.aimpanel casava e o `continue` matava o alerta ANTES do cross-check com
            # _ACC_PKGS (o exato erro Fable-5/sideload). Agora só preload de sistema REAL
            # (is_oem_preload) é liberado; app de fábrica-sem-lastro com overlay+accessibility
            # cai no warn de painel.
            [ "$P" = "android" ] && continue                       # framework pseudo-pkg
            is_oem_preload "$P" "" "$(pm path "$P" 2>/dev/null | head -1 | sed 's/^package://')" && continue
            printf '%s\n' "$_ACC_PKGS" | grep -qxF "$P" && \
                warn "[SUSPEITO] App com perfil de PAINEL (overlay + accessibility): $P — comportamento de cheat-panel; revisar mesmo sem nome conhecido"
        done
    fi
fi
[ "$ESP_HITS" = "0" ] && ok "Sem ESP/overlay óbvio"

# ============================================================
#  24. /data SUSPEITO
# ============================================================
header "/data SUSPEITO"

DATA_HITS=0
# v4.4.31: brevent.sh removido daqui — já é reportado na seção PRIVILEGE ESCALATION,
# duplicar gerava ruído. Os outros paths são de cheats/injectors puros.
for P in /data/local/tmp/frida-server /data/local/tmp/re.frida.server \
         /data/local/tmp/cheat /data/local/tmp/.cheats /data/local/tmp/gg \
         /data/local/tmp/.gg /data/local/tmp/script.lua /data/local/tmp/hack.so \
         /data/local/tmp/.injector /data/local/tmp/gadget.so \
         /data/local/tmp/menu.so /data/local/tmp/esp.so \
         /data/local/tmp/lib /data/local/tmp/mod; do
    exists "$P" && { alert "Cheat em /data: $P"; DATA_HITS=$((DATA_HITS+1)); }
done

TMP_LS=$(ls -la /data/local/tmp 2>/dev/null | tail -n +2 | grep -v '^total')
[ -n "$TMP_LS" ] && { info "/data/local/tmp:"; echo "$TMP_LS" | while IFS= read -r L; do info "  $L"; done; }

# DG7 SS: scan ATIVO de scripts/binários em /data/local/tmp e /sdcard/tmp
for TMPDIR in /data/local/tmp /sdcard/tmp; do
    [ -d "$TMPDIR" ] || continue
    # Arquivos suspeitos (so/sh/bin/lua)
    SUS_TMP=$(find "$TMPDIR" -type f \( -iname "*.so" -o -iname "*.sh" -o -iname "*.bin" -o -iname "*.lua" -o -iname "*.dex" \) 2>/dev/null | head -10)
    if [ -n "$SUS_TMP" ]; then
        echo "$SUS_TMP" | while IFS= read -r F; do
            [ -n "$F" ] && alert "TMP binário/script: $F"
        done
        DATA_HITS=$((DATA_HITS+1))
    fi
    # Atividade recente (< 20min) — DG7 SS heuristic
    # FP real-device: exclui os PRÓPRIOS acumuladores do scanner (.a4_crit_$$/.a4_warn_$$,
    # l.83-84) — senão o a4ther se auto-detecta como "atividade tmp recente" em todo scan.
    RECENT_TMP=$(find "$TMPDIR" -type f -mmin -20 ! -name '.a4_*' 2>/dev/null | head -5)
    if [ -n "$RECENT_TMP" ]; then
        echo "$RECENT_TMP" | while IFS= read -r F; do
            [ -n "$F" ] && alert "TMP atividade recente (<20min): $F"
        done
        DATA_HITS=$((DATA_HITS+1))
    fi
done

for PKG in $CHEAT_PKGS $MEM_PKGS; do
    [ -d "/data/data/$PKG" ] && { alert "Dir cheat em /data/data: $PKG"; DATA_HITS=$((DATA_HITS+1)); }
done

[ -d /data/tombstones ] && {
    TOMBS=$(ls -t /data/tombstones 2>/dev/null | head -n 3)
    [ -n "$TOMBS" ] && { info "Tombstones recentes:"; echo "$TOMBS" | while IFS= read -r L; do info "  /data/tombstones/$L"; done; }
}

[ -d /data/anr ] && {
    ANRS=$(ls -t /data/anr 2>/dev/null | head -n 3)
    [ -n "$ANRS" ] && info "ANRs recentes: $(echo "$ANRS" | tr '\n' ' ')"
}

[ "$DATA_HITS" = "0" ] && ok "/data sem indícios"

# ============================================================
#  25. /sdcard SUSPEITO + DEEP SCAN
# ============================================================
header "/sdcard SUSPEITO"

SD_HITS=0
for P in /sdcard/Android/data/.cheats /sdcard/cheats /sdcard/Cheats \
         /sdcard/Hacks /sdcard/.modded /sdcard/.gg-config /sdcard/GameGuardian \
         /sdcard/.GameGuardian /sdcard/.aimbot /sdcard/.wallhack \
         /sdcard/HostEditor /sdcard/.injector /sdcard/.esp /sdcard/ESP \
         /sdcard/MenuMod /sdcard/.menu /sdcard/.cheat /sdcard/CheatMenu \
         /sdcard/Mods /sdcard/.mods /sdcard/FFMod /sdcard/.ffmod \
         /sdcard/tmp; do
    exists "$P" && { alert "Existe: $P"; SD_HITS=$((SD_HITS+1)); }
done

if have find; then
    EXT=$(find /sdcard 2>/dev/null -maxdepth 5 -type f \( \
        -name '*.lua' -o -name '*.so' -o -name '*.modff' -o -name '*.ffmod' \
        -o -name '*.hack' -o -name '*.cheat' -o -name '*.menu' -o -name '*.esp' \
        -o -name '*.dex' -o -name '*.jar' -o -name '*.gg' -o -name '*.vbm' \
        -o -name '*.gg2' -o -name '*.gg3' \) 2>/dev/null | head -n 40)
    [ -n "$EXT" ] && echo "$EXT" | while IFS= read -r L; do
        [ -z "$L" ] && continue
        case "$L" in
            */WhatsApp/*|*/Telegram/*|*/Pictures/*) info "  (mídia) $L" ;;
            *) warn "Arquivo: $L" ;;
        esac
    done

    NAMED=$(find /sdcard 2>/dev/null -maxdepth 5 -type f \( \
        -iname '*cheat*' -o -iname '*hack*' -o -iname '*modmenu*' \
        -o -iname '*ffh4x*' -o -iname '*aimbot*' -o -iname '*wallhack*' \
        -o -iname '*injector*' -o -iname '*esp.menu*' -o -iname '*headshot*' \
        -o -iname '*menuffx*' -o -iname '*bypass*' -o -iname '*ffmod*' \
        -o -iname '*holograma*' -o -iname '*hologram*' -o -iname 'holo_*' -o -iname '*_holo.*' \
        \) 2>/dev/null | head -n 30)
    [ -n "$NAMED" ] && echo "$NAMED" | while IFS= read -r L; do
        [ -n "$L" ] && alert "Nome de cheat: $L"
    done
fi
[ "$SD_HITS" = "0" ] && ok "/sdcard limpo"

# ============================================================
#  25b. ARQUIVOS APAGADOS / LIXEIRA
# ============================================================
header "ARQUIVOS APAGADOS / LIXEIRA"

DEL_HITS=0

# 1) Tag .trashed-* (Android 11+ MediaStore.createDeleteRequest)
#    Quando o usuário apaga via API moderna, o arquivo vira .trashed-<timestamp>-<name>
if have find; then
    TRASHED=$(find "$SDCARD" 2>/dev/null -maxdepth 5 -name '.trashed-*' 2>/dev/null | grep -viE '/DCIM/|\.(jpg|jpeg|png|mp4|gif|webp|heic)$' | head -n 40)
    if [ -n "$TRASHED" ]; then
        info "Arquivos .trashed-* (apagados via Android 11+ MediaStore):"
        echo "$TRASHED" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            MT=$(stat -c '%y' "$F" 2>/dev/null)
            SZ=$(stat -c '%s' "$F" 2>/dev/null)
            BN=$(basename "$F")
            # extrair nome original (.trashed-<epoch>-<nome>)
            ORIG=$(echo "$BN" | sed -E 's/^\.trashed-[0-9]+-//')
            case "$ORIG" in
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*[Aa]imbot*|*[Ee][Ss][Pp]*|*[Mm]enu*|*FFH4X*|*ffh4x*|*[Ii]njector*|*[Ww]all[Hh]ack*|*[Bb]ypass*|*[Mm]agisk*|*frida*|*[Hh]olograma*|*[Hh]ologram*|*HOLO_*|*_HOLO*)
                    alert "  $F  →  '$ORIG' ($SZ b, apagado em $MT) - NOME SUSPEITO" ;;
                *) info "  $F  →  '$ORIG' ($SZ b, apagado em $MT)" ;;
            esac
        done
        DEL_HITS=$((DEL_HITS+1))
    fi
fi

# 2) Diretórios de lixeira de file managers conhecidos
TRASH_DIRS="
/sdcard/.Trash
/sdcard/Trash
/sdcard/RecycleBin
/sdcard/.RecycleBin
/sdcard/.Recycle
/sdcard/Recycle
/sdcard/MtRecycle
/sdcard/.MtRecycle
/sdcard/MT2/Recycle
/sdcard/MT2/.recycle
/sdcard/ZArchiver/.trash
/sdcard/.zarchiverTrash
/sdcard/MIUI/Gallery/cloud/.trash
/sdcard/MIUI/.trashed
/sdcard/SamsungFiles/.Trash
/sdcard/Android/data/com.sec.android.app.myfiles/.Trash
/sdcard/Android/data/com.mi.android.globalFileexplorer/.Trash
/sdcard/Android/data/com.android.documentsui/.Trash
/sdcard/Android/data/com.google.android.apps.nbu.files/files/.Trash
/sdcard/Android/data/com.android.documentsui/cache/Trash
/sdcard/Android/media/com.google.android.apps.nbu.files
/sdcard/DCIM/.thumbnails
/sdcard/.System/Recycle
"

for D in $TRASH_DIRS; do
    [ -d "$D" ] || continue
    info "Lixeira: $D"
    if have find; then
        # arquivos modificados na última semana
        TRFILES=$(find "$D" 2>/dev/null -maxdepth 4 -type f -mtime -7 2>/dev/null | head -n 30)
        [ -n "$TRFILES" ] && echo "$TRFILES" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            MT=$(stat -c '%y' "$F" 2>/dev/null)
            SZ=$(stat -c '%s' "$F" 2>/dev/null)
            BN=$(basename "$F")
            case "$BN" in
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*[Aa]imbot*|*[Ee][Ss][Pp]*|*[Mm]enu*|*FFH4X*|*ffh4x*|*[Ii]njector*|*[Ww]all[Hh]ack*|*[Bb]ypass*|*[Mm]agisk*|*frida*|*[Hh]olograma*|*[Hh]ologram*|*HOLO_*|*_HOLO*|*\.apk|*\.lua|*\.so)
                    alert "  $F ($SZ b, $MT) - SUSPEITO" ;;
                *) info "  $F ($SZ b, $MT)" ;;
            esac
        done
        DEL_HITS=$((DEL_HITS+1))
    fi
done

# 3) Logcat: eventos de delete
if have logcat; then
    # FP real-device (MIUI): 'content.*deleted' casava 'contentValues=…deleted_from_mars_auto'
    # do FASProvider — auto-gerência de apps da MIUI (MARS/FAS), benigna. Ancorado a
    # content:// + exclui FASProvider/mars (não é deleção de evidência de cheat).
    DEL_EVENTS=$(timeout 5 logcat -d 2>/dev/null | grep -iE 'deletePackage|deleteFile|MediaStore.*delete|Filesystem.*delete|content://[^ ]*delet|removed.*\.apk|file_remove' \
        | grep -viE 'FASProvider|deleted_from_mars|mars_auto' | head -n 20)
    if [ -n "$DEL_EVENTS" ]; then
        # filtrar só eventos com nome suspeito
        # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo do OTHER_REMOVED acima: substring
        # crua bate em nomes de package/lib legítimos com 'mod' embutido).
        SUSPECT_DEL=$(echo "$DEL_EVENTS" | grep -iE 'cheat|hack|modmenu|ffh4x|aimbot|esp\.|menu|injector|wallhack|magisk|frida|freefire|\.apk|\.lua|\.so|\.dex')
        if [ -n "$SUSPECT_DEL" ]; then
            alert "Eventos de delete suspeitos no logcat:"
            echo "$SUSPECT_DEL" | head -n 10 | while IFS= read -r L; do
                [ -n "$L" ] && alert "  $(echo "$L" | head -c 180)"
            done
        else
            info "Eventos de delete no logcat (gerais):"
            echo "$DEL_EVENTS" | head -n 5 | while IFS= read -r L; do
                [ -n "$L" ] && info "  $(echo "$L" | head -c 160)"
            done
        fi
    fi
fi

# 4) Arquivos recentemente removidos via Activity de notification history (algumas ROMs)
for H in /data/system/notification_history.xml \
         /data/system/recent-tasks.xml \
         /sdcard/.android/notification_log.txt; do
    [ -r "$H" ] || continue
    # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo dos sítios acima).
    FF_DEL=$(grep -iE 'freefire|cheat|hack|modmenu|aimbot|esp|frida|magisk|deleted|removed' "$H" 2>/dev/null | head -n 10)
    [ -n "$FF_DEL" ] && {
        info "Indícios em $H:"
        echo "$FF_DEL" | while IFS= read -r L; do
            info "  $(echo "$L" | head -c 180)"
        done
    }
done

# 5) Apps recentes via dumpsys activity recents (apps que estavam abertos)
# v4.4.70 (FIX falso-positivo): o parser antigo greppava o DUMP INTEIRO, então
# 'mod' batia em "RESIZE_MODE_RESIZEABLE"/"taskDescription" e cuspia propriedades
# do Window Manager como "app suspeito". Agora extrai SÓ o PACOTE das linhas
# realActivity=/baseIntent= e compara com a blacklist (tokens específicos de
# cheat — sem 'mod'/'menu' soltos que batem em palavras do SO).
if have dumpsys; then
    RECENT_PKGS=$(dumpsys activity recents 2>/dev/null \
        | grep -iE 'realActivity=|baseIntent=' \
        | grep -v 'mResizeMode' | grep -v 'taskDescription' | grep -v 'mSupportsPictureInPicture' \
        | grep -oE 'com\.[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+' \
        | sort -u)
    RECENT_TASKS=$(printf '%s\n' "$RECENT_PKGS" \
        | grep -iE 'cheat|hack|ffh4x|aimbot|injector|frida|magisk|virtualapp|lulubox|luckypatcher|brevent|gameguardian|holograma|hologram|modmenu|mod\.menu|\.mod\.|panel\.ff|h4x' \
        | head -n 10)
    if [ -n "$RECENT_TASKS" ]; then
        alert "Apps suspeitos em activity recents (abertos recentemente):"
        printf '%s\n' "$RECENT_TASKS" | while IFS= read -r L; do
            [ -n "$L" ] && alert "  $L"
        done
    fi
fi

# 6) Thumbnails órfãos (imagem apagada, thumbnail fica)
if [ -d /sdcard/DCIM/.thumbnails ] && have find; then
    ORPHAN_THUMBS=$(find /sdcard/DCIM/.thumbnails 2>/dev/null -maxdepth 2 -type f -mtime -7 2>/dev/null | wc -l 2>/dev/null)
    [ -n "$ORPHAN_THUMBS" ] && [ "$ORPHAN_THUMBS" -gt 0 ] 2>/dev/null && info "$ORPHAN_THUMBS thumbnails recentes em /sdcard/DCIM/.thumbnails (apagados podem deixar thumb órfã)"
fi

[ "$DEL_HITS" = "0" ] && ok "Sem lixeira/arquivos apagados detectados"

# ============================================================
#  26. ARQUIVOS OCULTOS / SYMLINKS
# ============================================================
header "ARQUIVOS OCULTOS / SYMLINKS"

_HIDDEN_H0=$(_hits_count)   # v4.4.98: baseline p/ linha-limpo honesta (alert em find|while)
if have find; then
    HIDDEN=$(find /sdcard 2>/dev/null -maxdepth 3 -name '.*' -type f 2>/dev/null | head -n 30)
    [ -n "$HIDDEN" ] && echo "$HIDDEN" | while IFS= read -r H; do
        [ -z "$H" ] && continue
        BN=$(basename "$H")
        case "$BN" in
            .nomedia|.thumbnails|.DS_Store|.trashed-*) ;;
            .cheat*|.hack*|.mod*|.menu*|.esp*|.aim*|.ff*|.gg*)
                alert "Oculto suspeito: $H" ;;
            *) info "  oculto: $H" ;;
        esac
    done
    SYMS=$(find /sdcard 2>/dev/null -maxdepth 4 -type l 2>/dev/null | head -n 20)
    # v4.4.31: skip symlinks padrão do AOSP (não são IOC). /sdcard→/storage/self/primary
    # é o symlink que o Android usa pra mapear o storage emulado do user atual desde
    # Android 6. Reportar isso warpa o sinal de IOCs reais.
    [ -n "$SYMS" ] && echo "$SYMS" | while IFS= read -r S; do
        [ -z "$S" ] && continue
        TARGET=$(readlink "$S" 2>/dev/null)
        case "$S→$TARGET" in
            "/sdcard→/storage/self/primary"|"/sdcard→/storage/emulated/0") continue ;;
        esac
        warn "Symlink: $S -> $TARGET"
    done
fi
[ "$(_hits_count)" = "$_HIDDEN_H0" ] && ok "Sem ocultos suspeitos"

# ============================================================
#  27. REDE (hosts / VPN / interfaces / portas)
# ============================================================
header "REDE (hosts / VPN / portas)"

for H in /system/etc/hosts /etc/hosts; do
    [ -r "$H" ] || continue
    NONSTD=$(grep -v '^[[:space:]]*#' "$H" 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | grep -vE '^127\.0\.0\.1[[:space:]]+localhost' \
        | grep -vE '^::1[[:space:]]+(ip6-)?localhost' \
        | grep -vE '^fe00::0' \
        | grep -vE '^ff[0-9a-f]{2}::' \
        | grep -vE '^255\.255\.255\.255[[:space:]]+broadcasthost' \
        | grep -vE '^10\.0\.0\.1[[:space:]]+localhost')
    if [ -n "$NONSTD" ]; then
        echo "$NONSTD" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Hosts não-padrão em $H: $L"
        done
    else
        ok "$H limpo"
    fi
done

if have ip; then
    VPN=$(ip link show tun0 2>/dev/null; ip link show ppp0 2>/dev/null)
    [ -n "$VPN" ] && warn "VPN ativa (tun0/ppp0)"
fi

# Conexões TCP ativas suspeitas (via /proc/net/tcp - sem netstat)
if [ -r /proc/net/tcp ]; then
    TCP_CONNS=$(awk '$4=="0A" {print $2}' /proc/net/tcp 2>/dev/null | head -n 30)
    LISTEN_PORTS=$(echo "$TCP_CONNS" | awk -F: '{print $2}' | sort -u)
    for HEX_PORT in $LISTEN_PORTS; do
        DEC=$(printf '%d' "0x$HEX_PORT" 2>/dev/null)
        case "$DEC" in
            27042|27043|27044|27045) alert "Porta Frida $DEC em LISTEN" ;;
            6573)  alert "Porta Shizuku 6573 em LISTEN" ;;
            5555)  alert "Porta ADB 5555 em LISTEN (ADB wireless ATIVO)" ;;
        esac
    done
fi

if have dumpsys; then
    WIFI_SSID=$(dumpsys wifi 2>/dev/null | grep -m1 'SSID:' | head -c 100)
    [ -n "$WIFI_SSID" ] && info "$WIFI_SSID"
fi

# ============================================================
#  27b. PROXY CHEATS / FF NETWORK / KNOWN CHEAT INFRA
#       (detecção de cheats remotos via proxy - vetor principal 2025/26)
# ============================================================
header "PROXY CHEATS / FF NETWORK / CHEAT INFRA"

PROXY_NET_HITS=0

# 0) v4.4.67 — VARREDURA AGRESSIVA DE REDE: interfaces virtuais, proxies locais,
#    Private DNS e módulos/apps de bypass. VPN/túnel/proxy local é o vetor nº1
#    de cheat de rede no FF (redireciona o tráfego do jogo por um MITM/painel).

# 0a) Interfaces de túnel/VPN ATIVAS (tun0/ppp0/wg0/…)
for IFACE in tun0 tun1 tun2 ppp0 ppp1 tap0 wg0 vpn0 ipsec0; do
    if ip link show "$IFACE" 2>/dev/null | grep -q 'state UP' \
       || ip addr show "$IFACE" 2>/dev/null | grep -q 'inet '; then
        alert "  INTERFACE VIRTUAL ATIVA: ${IFACE} (VPN/túnel — pode mascarar a infra do FF)"
        PROXY_NET_HITS=$((PROXY_NET_HITS+1))
    fi
done
if [ -r /proc/net/dev ]; then
    VIRT_IF=$(awk -F: 'NR>2{gsub(/ /,"",$1); if($1 ~ /^(tun|ppp|tap|wg|vpn|ipsec)[0-9]/) print $1}' /proc/net/dev 2>/dev/null | tr '\n' ' ')
    [ -n "$VIRT_IF" ] && warn "  Interfaces de túnel em /proc/net/dev: ${VIRT_IF}"
fi

# 0b) PROXY LOCAL escutando (ss/netstat): porta local em LISTEN = ponto de MITM.
_NETLISTEN=""
if have ss; then _NETLISTEN=$(ss -tln 2>/dev/null)
elif have netstat; then _NETLISTEN=$(netstat -tln 2>/dev/null); fi
if [ -n "$_NETLISTEN" ]; then
    PROXY_PORTS=$(printf '%s\n' "$_NETLISTEN" | grep -oE '127\.0\.0\.1:(1080|3128|8080|8081|8000|8888|9090|9050|6573|8118|10808|10809|7890|7891|8123|1087|8889)' | sort -u | tr '\n' ' ')
    [ -n "$PROXY_PORTS" ] && { alert "  PROXY LOCAL em LISTEN: ${PROXY_PORTS}(MITM/painel de cheat?)"; PROXY_NET_HITS=$((PROXY_NET_HITS+1)); }
fi

# 0c) Private DNS custom (DNS-over-TLS próprio pode rotear/filtrar a infra do jogo)
PDNS_MODE=$(setting_get global private_dns_mode)
PDNS_HOST=$(setting_get global private_dns_specifier)
case "$PDNS_MODE" in
    hostname|on) [ -n "$PDNS_HOST" ] && warn "  Private DNS custom ativo: ${PDNS_HOST} (revisar)" ;;
esac

# 0d) MÓDULOS root (Magisk/KSU) focados em BYPASS DE REDE
for MODROOT in /data/adb/modules /data/adb/modules_update /sbin/.magisk/modules; do
    [ -d "$MODROOT" ] || continue
    NETMODS=$(ls "$MODROOT" 2>/dev/null | grep -iE 'proxy|tunnel|clash|v2ray|xray|trojan|mitm|burp|sslunpin|dns|vpn|warp|tun2|netbypass|hostfix|ff[._-]?net|garena')
    for M in $NETMODS; do
        alert "  MÓDULO de rede (root): ${MODROOT##*/}/${M} (bypass/proxy/MITM)"
        PROXY_NET_HITS=$((PROXY_NET_HITS+1))
    done
done

# 0e) Apps de captura/proxy/VPN local instalados (interceptam o tráfego do FF)
# FP real-device: o token solto 'clash' casava 'com.supercell.clashROYALE' (jogo!). Trocado
# por variantes ancoradas do Clash-proxy (clashforandroid/clashmeta/metacubex; kr328 já cobre
# o app principal) + exclusão dos jogos Supercell 'clash*'.
if have pm; then
    NETAPPS=$(pm list packages 2>/dev/null | sed 's/^package://' \
        | grep -iE 'httpcanary|packagecapture|http\.injector|netcapture|networkcapture|mitmproxy|charles|burp|clashforandroid|clashmeta|metacubex|kr328|v2ray|napsternet|drony|postern|proxydroid|com\.evozi|sniffer|tcpdump' \
        | grep -viE 'supercell|clashroyale|clashofclans|clashmini' | head -10)
    for A in $NETAPPS; do
        alert "  APP de captura/proxy/VPN: ${A} (intercepta o tráfego do jogo)"
        PROXY_NET_HITS=$((PROXY_NET_HITS+1))
    done
fi

# 1) Conexões ATIVAS do processo Free Fire via /proc/<pid>/net/tcp
if have pidof; then
    for PKG in $FF_PKGS; do
        FF_PID=$(pidof "$PKG" 2>/dev/null | awk '{print $1}')
        [ -z "$FF_PID" ] && continue
        info "FF rodando ($PKG, PID $FF_PID)"
        # FP real-device (atribuição por INODE): /proc/<pid>/net/tcp é por-netns (=GLOBAL no
        # Android) → sem isto, TODA conexão do device (adbd:5037, serviços locais…) era
        # mis-atribuída a "FF→". Coletamos os inodes dos sockets que o FF REALMENTE possui
        # (/proc/<pid>/fd → 'socket:[inode]') e só contamos esses. Degrada honesto: fd ilegível
        # (hidepid/SELinux) → INCONCLUSIVO, nunca 'limpo'. (Se o maps do FF é legível, o fd também.)
        FF_INOS=$(ls -l /proc/$FF_PID/fd 2>/dev/null | grep -oE 'socket:\[[0-9]+\]' | grep -oE '[0-9]+' | sort -u)
        if [ -z "$FF_INOS" ]; then
            info "Conexões do FF não atribuíveis (/proc/$FF_PID/fd ilegível) — análise de socket INCONCLUSIVA, não 'limpo'"
            continue
        fi
        FF_INO_SET=" $(echo $FF_INOS) "
        for NTCP in /proc/$FF_PID/net/tcp /proc/$FF_PID/net/tcp6; do
            [ -r "$NTCP" ] || continue
            # v4.4.75: sort -u dedupa o MESMO endpoint repetido. Filtro por inode (col 10): só
            # endpoints ESTABELECIDOS ($4==01) cujo socket é REALMENTE do FF (não do netns global).
            CONNS=$(awk -v ino="$FF_INO_SET" 'NR>1 && $4=="01" && index(ino," " $10 " ") {print $3}' "$NTCP" 2>/dev/null | sort -u | head -n 30)
            [ -z "$CONNS" ] && continue
            echo "$CONNS" | while IFS= read -r RHEX; do
                [ -z "$RHEX" ] && continue
                IP_HEX="${RHEX%:*}"
                PORT_HEX="${RHEX##*:}"
                PORT=$(printf '%d' "0x$PORT_HEX" 2>/dev/null)
                # IPv4 little-endian: 0100007F = 127.0.0.1
                if [ "${#IP_HEX}" = "8" ]; then
                    B1=$(printf '%d' "0x${IP_HEX:6:2}" 2>/dev/null)
                    B2=$(printf '%d' "0x${IP_HEX:4:2}" 2>/dev/null)
                    B3=$(printf '%d' "0x${IP_HEX:2:2}" 2>/dev/null)
                    B4=$(printf '%d' "0x${IP_HEX:0:2}" 2>/dev/null)
                    IP="$B1.$B2.$B3.$B4"
                    case "$IP" in
                        127.*)
                            # Agora atribuído por inode (acima): se chega aqui é socket REAL do FF
                            # ligando em localhost = proxy/MITM/cheat-client local. adbd:5037/5555
                            # não é inode do FF → já filtrado, sem paliativo de porta.
                            alert "  FF→LOCALHOST $IP:$PORT (PROXY LOCAL = MITM ou cheat client)" ;;
                        10.*|192.168.*|172.16.*|172.17.*|172.18.*|172.19.*|172.20.*|172.21.*|172.22.*|172.23.*|172.24.*|172.25.*|172.26.*|172.27.*|172.28.*|172.29.*|172.30.*|172.31.*)
                            warn "  FF→IP privado $IP:$PORT (VPN/LAN proxy)" ;;
                        46.202.145.85)
                            alert "  FF→IP de CHEAT $IP:$PORT (Fatality Cheats!)" ;;
                        0.0.0.0|"")
                            ;;
                        *)
                            info "  FF→$IP:$PORT" ;;
                    esac
                fi
            done
        done
    done
fi

# 2) Domínios de cheat conhecidos (multi-plataforma, vivos em 2025/26)
CHEAT_DOMAINS="fatalitycheats.xyz anubisw.online api.baontq.xyz purplevioleto.com ggwhitehawk.com ggpolarbear.com ggblueshark.com version.ffmax.purplevioleto.com version.ggwhitehawk.com loginbp.ggpolarbear.com sacnetwork.ggblueshark.com sacevent.ggblueshark.com ipasign.cc ipa.aspy.dev hologram-ff.xyzapk.com xyzapk.io xyzapk.com apkphat.io apkmodjoy.com modbibi.com holograma.es.apkhihe.org apkhihe.org holograma-apk.tumblr.com red-x-panel.modcombo.com modcombo.com modfyp.com modyolo.com apktodo.io ffh4xreg.com linkjust.com derod.org"

# FF_PROXY_LOGIN_DOMAINS - domínios oficiais do FF que NÃO devem ser acessados por outros apps
FF_PROXY_LOGIN_DOMAINS="version.ffmax.purplevioleto.com version.ggwhitehawk.com loginbp.ggpolarbear.com gin.freefiremobile.com 100067.connect.garena.com 100067.msdk.garena.com client.us.freefiremobile.com client.sea.freefiremobile.com sacnetwork.ggblueshark.com sacevent.ggblueshark.com"
for D in $CHEAT_DOMAINS; do
    # /etc/hosts
    for HF in /system/etc/hosts /etc/hosts; do
        if [ -r "$HF" ]; then
            HIT=$(grep -i "$D" "$HF" 2>/dev/null)
            [ -n "$HIT" ] && { alert "Domínio cheat ($D) em $HF: $HIT"; PROXY_NET_HITS=$((PROXY_NET_HITS+1)); }
        fi
    done
    # Arquivos cache/files do FF (cheats que telefonam pra casa deixam log)
    if have grep; then
        for PKG in $FF_PKGS; do
            for FFD in "/sdcard/Android/data/$PKG/files" \
                       "/sdcard/Android/data/$PKG/cache" \
                       "/data/data/$PKG/files" \
                       "/data/data/$PKG/cache"; do
                [ -d "$FFD" ] || continue
                MATCHES=$(grep -rl --exclude="a4ther*" --exclude="_scan_console.log" "$D" "$FFD" 2>/dev/null | head -n 3)
                [ -n "$MATCHES" ] && echo "$MATCHES" | while IFS= read -r F; do
                    [ -n "$F" ] && alert "Domínio cheat ($D) referenciado em: $F"
                done
            done
        done
    fi
done

# 3) IPs de cheat conhecidos contra /proc/net/tcp ativo
CHEAT_IPS="46.202.145.85"
if [ -r /proc/net/tcp ]; then
    for IP in $CHEAT_IPS; do
        B1=$(echo "$IP" | cut -d. -f1)
        B2=$(echo "$IP" | cut -d. -f2)
        B3=$(echo "$IP" | cut -d. -f3)
        B4=$(echo "$IP" | cut -d. -f4)
        IP_HEX=$(printf '%02X%02X%02X%02X' "$B4" "$B3" "$B2" "$B1" 2>/dev/null)
        FOUND=$(awk '{print $3}' /proc/net/tcp 2>/dev/null | grep "^$IP_HEX:" | head -n 1)
        [ -n "$FOUND" ] && { alert "CONEXÃO ATIVA para IP de cheat $IP"; PROXY_NET_HITS=$((PROXY_NET_HITS+1)); }
    done
fi

# 4) TLDs suspeitos (free hosting usado por cheat panels)
TLDS_SUSP=".netlify.app .workers.dev .vercel.app .xyz .pw .top .click .icu .gq .cf .ml .ga .tk .monster .fun .rest .bar .lol"
for HF in /system/etc/hosts /etc/hosts; do
    [ -r "$HF" ] || continue
    for T in $TLDS_SUSP; do
        HIT=$(grep -v '^[[:space:]]*#' "$HF" 2>/dev/null | grep -i "$T")
        [ -n "$HIT" ] && warn "Hosts com TLD suspeito '$T': $(echo "$HIT" | head -c 100)"
    done
done

# 5) Termux git typosquat (cheat installers usam pra puxar binário falso)
for RC in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" \
          /data/data/com.termux/files/home/.bashrc \
          /data/data/com.termux/files/home/.zshrc; do
    [ -r "$RC" ] || continue
    GIT_ALIAS=$(grep -E '^\s*alias\s+git\s*=' "$RC" 2>/dev/null)
    [ -n "$GIT_ALIAS" ] && {
        alert "Alias 'git' em $RC: $GIT_ALIAS (typosquat?)"
        PROXY_NET_HITS=$((PROXY_NET_HITS+1))
    }
done
for D in "$HOME/git-safe" /data/data/com.termux/files/home/git-safe; do
    [ -d "$D" ] && { alert "Pasta git-safe presente: $D (infraestrutura de typosquat)"; PROXY_NET_HITS=$((PROXY_NET_HITS+1)); }
done

[ "$PROXY_NET_HITS" = "0" ] && ok "Sem proxy cheat / cheat infra detectada"

# ============================================================
#  28. PROCESSOS SUSPEITOS
# ============================================================
header "PROCESSOS"

_PROC_H0=$(_hits_count)   # v4.4.98: baseline p/ linha-limpo honesta (alert roda em subshell)
if have ps; then
    # v4.4.32: usa clean_procs pra remover o próprio scanner do output. Antes
    # o ps capturava a string "scarlet" do argv do script e reportava como
    # "Processo (scarlet)" — FP em 100% das execuções.
    PROCS=$(ps -A 2>/dev/null | clean_procs)
    [ -z "$PROCS" ] && PROCS=$(ps 2>/dev/null | clean_procs)
    for PAT in frida-server frida-agent gameguardian gg.intersec xposed lsposed \
               substrated cydia.substrate \
               cheatengine virtualapp parallel.space dualspace \
               luckypatcher gamekiller autoclicker.click macro.tap \
               brevent.guard shizuku.server hunter.shizuku; do
        HIT=$(echo "$PROCS" | tok_grep "$PAT" | grep -v grep)
        [ -n "$HIT" ] && echo "$HIT" | head -n 2 | while IFS= read -r L; do
            [ -n "$L" ] && alert "Processo ($PAT): $L"
        done
    done
fi
[ "$(_hits_count)" = "$_PROC_H0" ] && ok "Nenhum processo suspeito"

# ============================================================
#  29. LOGCAT (rastros nos logs)
# ============================================================
header "LOGCAT"

_LOG_H0=$(_hits_count)   # v4.4.98: baseline p/ linha-limpo honesta (alert em subshell)
if have logcat; then
    if have timeout; then
        LOG_OUT=$(timeout 5 logcat -d 2>/dev/null | tail -n 2000)
    else
        LOG_OUT=$(logcat -d -t 2000 2>/dev/null)
    fi
    if [ -z "$LOG_OUT" ]; then
        info "logcat sem permissão (READ_LOGS) - skip"
    else
        for PAT in frida-server "frida.gadget" gameguardian xposed lsposed \
                   substrate "FFH4X" "ffh4x" aimbot "mod menu" "mod.menu" \
                   "cheat" "injection" "ptrace" "virtualapp" "io.virtualapp" \
                   "esp.cheat" "wallhack" "luckypatcher" "shamiko" "brevent" \
                   "UsageStatsService: Time changed" "hcallSetClipboardTextRpc"; do
            HIT=$(echo "$LOG_OUT" | tok_grep "$PAT" | head -n 2)   # v4.4.102: ancorado (era grep -i cru → casava system_e[xposed]_libraries)
            [ -n "$HIT" ] && echo "$HIT" | while IFS= read -r L; do
                [ -n "$L" ] && alert "Logcat [$PAT]: $(echo "$L" | head -c 160)"
            done
        done
        [ "$(_hits_count)" = "$_LOG_H0" ] && ok "Logcat limpo (últimas 2000 linhas)"
    fi
else
    info "logcat não disponível"
fi

# ============================================================
#  29b. PERSISTENT LOGS (rastros que sobrevivem reboot/desconexão)
#       O usuário falou: cheats remotos deixam logs na ROM após desconectar cabo
# ============================================================
header "PERSISTENT LOGS (logs que ficam na ROM)"

PLOG_HITS=0

# /data/anr — ANR traces ficam no disco
if [ -d /data/anr ]; then
    ANRS=$(ls -t /data/anr 2>/dev/null | head -n 5)
    if [ -n "$ANRS" ]; then
        info "ANRs recentes (/data/anr):"
        echo "$ANRS" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            FULL="/data/anr/$F"
            MT=$(stat -c '%y' "$FULL" 2>/dev/null)
            info "  $FULL ($MT)"
            if [ -r "$FULL" ]; then
                # v4.4.103: ancorado (era grep -i cru → ANR de app c/ ExposedDropdownMenuBox no
                # stack casava 'xposed' dentro de "Exposed" e virava ALERTA falso).
                CHEAT_HIT=$(grep -iE '(^|[^a-zA-Z0-9_])(lib)?(freefire|frida|magisk|xposed|lsposed|cheat|injector|hack|gameguardian|libsubstrate|brevent)' "$FULL" 2>/dev/null | head -n 3)
                [ -n "$CHEAT_HIT" ] && echo "$CHEAT_HIT" | while IFS= read -r L; do
                    [ -n "$L" ] && alert "    ANR contém: $(echo "$L" | head -c 140)"
                done
            fi
        done
    fi
fi

# /data/tombstones — native crashes ficam no disco
if [ -d /data/tombstones ]; then
    TOMBS=$(ls -t /data/tombstones 2>/dev/null | head -n 5)
    if [ -n "$TOMBS" ]; then
        info "Tombstones recentes (/data/tombstones):"
        echo "$TOMBS" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            FULL="/data/tombstones/$F"
            MT=$(stat -c '%y' "$FULL" 2>/dev/null)
            info "  $FULL ($MT)"
            if [ -r "$FULL" ]; then
                # v4.4.70 (FIX falso-positivo): identifica o PROCESSO dono do tombstone.
                # Só analisa se for o JOGO auditado OU se houver assinatura CLARA de
                # injeção. ANTES greppava termos genéricos e flaggava crash de app
                # aleatório (ex: br.gov.caixa.tem / libmcrypt.so) como injeção.
                TOMB_PROC=$(grep -m1 -E '>>> .+ <<<|Cmdline:|name: ' "$FULL" 2>/dev/null | head -c 200)
                # libs de hook/injeção INEQUÍVOCAS (não inclui libil2cpp — é runtime
                # NORMAL do FF/Unity; flaggar isso reprovaria todo crash legítimo).
                INJ_RE='libfrida|frida-gadget|frida-server|gum-js|libsubstrate|substrate|libdobby|libxhook|libwhale|libsandhook|libhooker|libepic|injector\.so|libinjector'
                if printf '%s' "$TOMB_PROC" | grep -qiE 'com\.dts\.freefire(th|max)?'; then
                    # crash NO Free Fire → procura libs de injeção
                    FF_INJ=$(grep -iE "$INJ_RE" "$FULL" 2>/dev/null | head -n 3)
                    if [ -n "$FF_INJ" ]; then
                        alert "Tombstone do Free Fire com lib de INJEÇÃO:"
                        echo "$FF_INJ" | while IFS= read -r L; do
                            [ -n "$L" ] && alert "    $(echo "$L" | head -c 140)"
                        done
                    else
                        info "  Tombstone do Free Fire (crash sem assinatura de cheat)"
                    fi
                else
                    # NÃO é o jogo (ex: app de banco) → só sinaliza se tiver lib de hook
                    # conhecida; senão IGNORA (não é problema do FF).
                    OTHER_INJ=$(grep -iE "$INJ_RE" "$FULL" 2>/dev/null | head -n 2)
                    [ -n "$OTHER_INJ" ] && warn "  Tombstone de outro app com lib de hook (revisar contexto): $FULL"
                fi
            fi
        done
    fi
fi

# /data/system/dropbox - system event log persistente (Samsung/Xiaomi/etc)
if [ -d /data/system/dropbox ]; then
    DROPS=$(ls -t /data/system/dropbox 2>/dev/null | head -n 15)
    if [ -n "$DROPS" ]; then
        info "Dropbox events recentes (/data/system/dropbox):"
        echo "$DROPS" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            case "$F" in
                *freefire*|*cheat*|*hack*|*frida*|*magisk*|*inject*)
                    alert "  Dropbox suspeito: $F" ;;
                *system_app_crash*|*system_app_native_crash*|*data_app_crash*)
                    info "  $F" ;;
                *) info "  $F" ;;
            esac
        done
    fi
fi

# /data/log e variantes (Samsung/Xiaomi/MIUI persistent logs)
for LOGDIR in /data/log /sdcard/log /sdcard/MIUI/debug_log \
              /data/system/log /data/vendor/log /data/misc/log; do
    [ -d "$LOGDIR" ] || continue
    info "Log persistente: $LOGDIR"
    if have find; then
        RECENT=$(find "$LOGDIR" 2>/dev/null -maxdepth 3 -type f -mtime -7 2>/dev/null | head -n 10)
        [ -n "$RECENT" ] && echo "$RECENT" | while IFS= read -r F; do
            [ -z "$F" ] && continue
            BN=$(basename "$F")
            info "  $F"
            if [ -r "$F" ]; then
                # FP real-device: removido o token 'freefire' — o NOME do jogo aparece em logs
                # benignos (foreground/Firebase JobScheduler/batterystats) e NÃO é evidência de
                # cheat. Mantém só indicadores reais de injeção/root.
                # v4.4.103: ancorado (era grep -i cru → na MIUI/Xiaomi esse arquivo é um DUMP de
                # logcat, e 'xposed' casava dentro de 'system_exposed_libraries' do nativeloader
                # — libs de câmera ArcSoft contadas como ALERTA falso).
                HIT=$(grep -iE '(^|[^a-zA-Z0-9_])(lib)?(frida|magisk|xposed|cheat|injector|libsubstrate|frida-server|frida-gadget)' "$F" 2>/dev/null | head -n 2)
                [ -n "$HIT" ] && echo "$HIT" | while IFS= read -r L; do
                    [ -n "$L" ] && alert "    contém: $(echo "$L" | head -c 140)"
                done
            fi
        done
        PLOG_HITS=$((PLOG_HITS+1))
    fi
done

# Last kernel logs (sobrevivem reboot em algumas ROMs)
for KMSG in /proc/last_kmsg /sys/fs/pstore/console-ramoops-0 \
            /sys/fs/pstore/dmesg-ramoops-0 /sys/fs/pstore/console-ramoops; do
    [ -r "$KMSG" ] || continue
    HIT=$(grep -iE 'apatch|magisk|kernelsu|frida|susfs|ksu_init|ksu_load' "$KMSG" 2>/dev/null | head -n 5)
    [ -n "$HIT" ] && echo "$HIT" | while IFS= read -r L; do
        [ -n "$L" ] && alert "Kernel log persistente ($KMSG): $(echo "$L" | head -c 140)"
    done
done

# v4.4.33: parser FULL de bugreport — extrai TUDO que dá pra extrair.
# Antes só pegava tombstones/package/crashes (5 categorias). Agora extrai 22
# categorias: dumpsys snapshots embedded, todos os logcat buffers, procstats,
# OOM kills, accessibility services, batterystats history, dropbox, WiFi, etc.
#
# Suporta também BUGREPORT_FILE=/sdcard/Download/bugreport.zip sh a4ther.sh
# pra analisar bugreport puxado via adb por depuração WiFi (modo offline).
BR_HITS=0
BR_PATHS="/data/user_de/0/com.android.shell/files/bugreports /data/data/com.android.shell/files/bugreports /sdcard/bugreports /storage/emulated/0/bugreports /sdcard/Download /storage/emulated/0/Download"

# v4.4.7: globais preenchidos por br_parse (modo offline) e usados como
# fallback na seção 31 (HWID) quando o getprop LIVE vem vazio — que é o caso
# quando o scanner roda sobre um bugreport.zip puxado de OUTRO device.
BR_SERIAL=""; BR_BOOT_SERIAL=""; BR_MAC=""; BR_BT_MAC=""
BR_ANDROID_ID=""; BR_WIDEVINE=""; BR_FINGERPRINT=""; BR_BOOTLOADER=""
# v4.4.7: região/SIM/Play também saem do dump (usados no fallback do §31b)
BR_LOCALE=""; BR_COUNTRY=""; BR_SIM_COUNTRY=""; BR_SIM_OPERATOR=""
BR_SIM_MCC=""; BR_PLAY_COUNTRY=""

# br_prop NOME ARQUIVO — extrai o valor de uma System Property do dump do
# bugreport. O getprop dentro do bugreport tem o formato:
#     [ro.serialno]: [R5CN30XXXXX]
# Os '.' do nome são escapados (senão viram coringa de regex) e os colchetes
# do valor são removidos. Retorna string vazia se a chave não existir.
br_prop() {
    [ -r "$2" ] || return 0
    _pn=$(printf '%s' "$1" | sed 's/\./\\./g')
    grep -m1 -E "^\[$_pn\]:" "$2" 2>/dev/null \
        | sed -E 's/^\[[^]]*\]:[[:space:]]*\[(.*)\][[:space:]]*$/\1/'
}

# Helper: parseia 1 bugreport (zip ou txt) e roda TODAS as extrações
br_parse() {
    _BRFILE="$1"
    _BRBASE=$(basename "$_BRFILE")
    [ -r "$_BRFILE" ] || return 0
    _BRMT=$(stat -c '%y' "$_BRFILE" 2>/dev/null)
    info "Parsing: $_BRFILE ($_BRMT)"

    # 1) Extrai conteúdo — bugreport zip moderno tem múltiplos arquivos.
    #    Estratégia: extrai tudo num tmpdir se unzip estiver disponível.
    _BRWORK=""
    _BRMAIN=""
    case "$_BRFILE" in
        *.zip)
            if have unzip; then
                _BRWORK="${TMPDIR:-/data/local/tmp}/a4ther_br_$$"
                mkdir -p "$_BRWORK" 2>/dev/null
                unzip -q -o "$_BRFILE" -d "$_BRWORK" 2>/dev/null
                # bugreport principal: bugreport-<device>-<date>.txt
                _BRMAIN=$(find "$_BRWORK" -maxdepth 2 -name 'bugreport-*.txt' 2>/dev/null | head -1)
                [ -z "$_BRMAIN" ] && _BRMAIN=$(find "$_BRWORK" -maxdepth 2 -name '*.txt' 2>/dev/null | head -1)
            fi
            ;;
        *.txt|*.log)
            _BRMAIN="$_BRFILE"
            ;;
    esac
    [ -z "$_BRMAIN" ] || [ ! -r "$_BRMAIN" ] && {
        warn "  Não consegui extrair conteúdo (unzip ausente?)"
        [ -n "$_BRWORK" ] && rm -rf "$_BRWORK" 2>/dev/null
        return 0
    }
    _BRSIZE=$(stat -c '%s' "$_BRMAIN" 2>/dev/null)
    info "  Conteúdo principal: $_BRMAIN ($_BRSIZE bytes)"

    # ── 0. HWID / IDENTIFICADORES DO DEVICE (v4.4.7) ────────────────
    # ESTE era o passo que faltava: o bugreport carrega o dump COMPLETO do
    # getprop ([ro.serialno]: [VALOR]) + android_id/MAC/Widevine nas seções
    # do dumpsys. Sem extrair aqui, a seção 31 (HWID) — que só lia getprop
    # LIVE — vinha 100% vazia em modo offline (Serial: ?). Preenche os
    # globais BR_* que a seção 31 usa como fallback.
    _GP_SERIAL=$(br_prop ro.serialno "$_BRMAIN")
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(br_prop ro.boot.serialno "$_BRMAIN")
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(br_prop ro.vendor.boot.serialno "$_BRMAIN")
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(br_prop ril.serialnumber "$_BRMAIN")    # Samsung/RIL
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(br_prop ro.serialno.fact "$_BRMAIN")    # Samsung fact
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(br_prop ro.boot.em.serial "$_BRMAIN")   # MediaTek
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(br_prop ril.serial "$_BRMAIN")          # OPPO/realme
    # Fallback OEM 1: linha "Serial number:" (header de alguns dumpstate Samsung)
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(grep -m1 -iE '^Serial( number)?:' "$_BRMAIN" 2>/dev/null | sed -E 's/.*:[[:space:]]*//')
    # Fallback OEM 2: kernel cmdline androidboot.serialno= (sempre presente no bugreport)
    [ -z "$_GP_SERIAL" ] && _GP_SERIAL=$(grep -m1 -oE 'androidboot\.serialno=[^ ]+' "$_BRMAIN" 2>/dev/null | cut -d= -f2)
    [ -z "$BR_SERIAL" ] && [ -n "$_GP_SERIAL" ] && BR_SERIAL="$_GP_SERIAL"

    _GP_BOOTSER=$(br_prop ro.boot.serialno "$_BRMAIN")
    [ -z "$BR_BOOT_SERIAL" ] && [ -n "$_GP_BOOTSER" ] && BR_BOOT_SERIAL="$_GP_BOOTSER"

    _GP_FP=$(br_prop ro.build.fingerprint "$_BRMAIN")
    [ -z "$_GP_FP" ] && _GP_FP=$(grep -m1 -E 'Build fingerprint:' "$_BRMAIN" 2>/dev/null | sed -E "s/.*'([^']*)'.*/\1/")
    [ -z "$BR_FINGERPRINT" ] && [ -n "$_GP_FP" ] && BR_FINGERPRINT="$_GP_FP"

    _GP_BL=$(br_prop ro.bootloader "$_BRMAIN")
    [ -z "$BR_BOOTLOADER" ] && [ -n "$_GP_BL" ] && BR_BOOTLOADER="$_GP_BL"

    _GP_BTMAC=$(br_prop ro.boot.btmacaddr "$_BRMAIN")
    [ -z "$_GP_BTMAC" ] && _GP_BTMAC=$(br_prop persist.service.bdroid.bdaddr "$_BRMAIN")
    [ -z "$BR_BT_MAC" ] && [ -n "$_GP_BTMAC" ] && BR_BT_MAC="$_GP_BTMAC"

    # android_id: no dumpsys settings aparece como  android_id=<16 hex>
    _GP_AID=$(grep -m1 -oE 'android_id[=:][[:space:]]*[0-9a-f]{16}' "$_BRMAIN" 2>/dev/null | grep -oE '[0-9a-f]{16}' | head -1)
    [ -z "$BR_ANDROID_ID" ] && [ -n "$_GP_AID" ] && BR_ANDROID_ID="$_GP_AID"

    # Widevine deviceUniqueId/PluginUniqueId no dumpsys media.drm embutido
    _GP_WV=$(grep -m1 -iE 'deviceUniqueId|PluginUniqueId' "$_BRMAIN" 2>/dev/null | grep -oE '[0-9A-Fa-f-]{16,}' | head -1)
    [ -z "$BR_WIDEVINE" ] && [ -n "$_GP_WV" ] && BR_WIDEVINE="$_GP_WV"

    # MAC wlan0 (ignora 02:.. que é o randomizado por privacidade quando possível)
    _GP_MAC=$(grep -m1 -iE 'wlan0.*HWaddr|Wi-?Fi.*MAC|factory.*MAC' "$_BRMAIN" 2>/dev/null | grep -oiE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    [ -z "$_GP_MAC" ] && _GP_MAC=$(br_prop ro.boot.wifi.macaddr "$_BRMAIN")
    [ -z "$_GP_MAC" ] && _GP_MAC=$(br_prop persist.sys.wifi.mac "$_BRMAIN")
    [ -z "$BR_MAC" ] && [ -n "$_GP_MAC" ] && BR_MAC="$_GP_MAC"

    # Região / SIM / Play Store (usados no fallback do §31b em modo offline)
    _GP_LOC=$(br_prop ro.product.locale "$_BRMAIN")
    [ -z "$_GP_LOC" ] && _GP_LOC=$(br_prop persist.sys.locale "$_BRMAIN")
    [ -z "$BR_LOCALE" ] && [ -n "$_GP_LOC" ] && BR_LOCALE="$_GP_LOC"

    _GP_CTRY=$(br_prop persist.sys.country "$_BRMAIN")
    [ -z "$_GP_CTRY" ] && _GP_CTRY=$(br_prop ro.csc.countryiso_code "$_BRMAIN")
    [ -z "$_GP_CTRY" ] && _GP_CTRY=$(br_prop ro.product.locale.region "$_BRMAIN")
    [ -z "$BR_COUNTRY" ] && [ -n "$_GP_CTRY" ] && BR_COUNTRY="$_GP_CTRY"

    _GP_SIMC=$(br_prop gsm.sim.operator.iso-country "$_BRMAIN")
    [ -z "$_GP_SIMC" ] && _GP_SIMC=$(br_prop gsm.operator.iso-country "$_BRMAIN")
    [ -z "$BR_SIM_COUNTRY" ] && [ -n "$_GP_SIMC" ] && BR_SIM_COUNTRY=$(printf '%s' "$_GP_SIMC" | tr '[:lower:]' '[:upper:]')
    _GP_SIMOP=$(br_prop gsm.sim.operator.alpha "$_BRMAIN")
    [ -z "$BR_SIM_OPERATOR" ] && [ -n "$_GP_SIMOP" ] && BR_SIM_OPERATOR="$_GP_SIMOP"
    _GP_SIMN=$(br_prop gsm.sim.operator.numeric "$_BRMAIN")
    [ -z "$BR_SIM_MCC" ] && [ -n "$_GP_SIMN" ] && BR_SIM_MCC=$(printf '%s' "$_GP_SIMN" | cut -c1-3)

    _GP_PLAY=$(br_prop ro.com.google.gmsversion "$_BRMAIN" | sed -nE 's/.*_([A-Z]{2}).*/\1/p')
    [ -z "$BR_PLAY_COUNTRY" ] && [ -n "$_GP_PLAY" ] && BR_PLAY_COUNTRY="$_GP_PLAY"

    if [ -n "$BR_SERIAL$BR_ANDROID_ID$BR_WIDEVINE$BR_MAC" ]; then
        info "  HWID do bugreport → serial=${BR_SERIAL:-?} android_id=${BR_ANDROID_ID:-?} widevine=${BR_WIDEVINE:-?} mac=${BR_MAC:-?}"
    else
        warn "  Nenhum identificador (serial/android_id/widevine/MAC) achado no bugreport."
        warn "  ↳ Gere o bugreport como FULL (não 'interactive/mini'):"
        warn "    adb bugreport <arq>.zip   OU   Developer options → Take bug report → Full"
    fi

    # ── 1. Build/version info ─────────────────────────────────────────
    _BUILD=$(grep -m1 -E '^Build: |Build fingerprint:' "$_BRMAIN" 2>/dev/null | head -c 200)
    [ -n "$_BUILD" ] && info "  $_BUILD"
    _UPTIME=$(grep -m1 -E '^Uptime:' "$_BRMAIN" 2>/dev/null | head -c 200)
    [ -n "$_UPTIME" ] && info "  $_UPTIME"
    _BOOT=$(grep -m1 -E '^Bootloader:|^Boot info:' "$_BRMAIN" 2>/dev/null | head -c 200)
    [ -n "$_BOOT" ] && info "  $_BOOT"

    # ── 2. SELinux mode ──────────────────────────────────────────────
    _SE=$(grep -m1 -E 'getenforce|SELinux:.*(Enforcing|Permissive|Disabled)' "$_BRMAIN" 2>/dev/null | head -c 100)
    case "$_SE" in
        *Permissive*) alert "  SELinux=Permissive no bugreport ($_SE)" ;;
        *Disabled*)   alert "  SELinux=Disabled no bugreport ($_SE)" ;;
        *) [ -n "$_SE" ] && info "  $_SE" ;;
    esac

    # ── 3. Tombstones + native libs cheat ─────────────────────────────
    _TS=$(grep -iE 'libfrida|libsubstrate|libxhook|libgum|libdobby|libsandhook|libwhale|libsubstitute|libepic|libellekit|libhooker|frida-server|frida-gadget|FridaGadget|MobileSubstrate' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_TS" ]; then
        alert "  Libs cheat no bugreport:"
        echo "$_TS" | while IFS= read -r L; do
            [ -n "$L" ] && alert "    $(echo "$L" | head -c 160)"
        done
        BR_HITS=$((BR_HITS+1))
    fi

    # ── 4. Crashes (FATAL EXCEPTION + signal) por app ─────────────────
    _CRASH=$(grep -iE 'FATAL EXCEPTION.*(freefire|com\.dts\.|camera|gallery|photos|miui\.gallery)|signal [0-9]+.*com\.dts\.freefire' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_CRASH" ]; then
        alert "  Crashes (FF/Câmera/Galeria) no bugreport:"
        echo "$_CRASH" | while IFS= read -r L; do
            [ -n "$L" ] && alert "    $(echo "$L" | head -c 180)"
        done
        BR_HITS=$((BR_HITS+1))
    fi

    # ── 5. ANRs (Application Not Responding) ──────────────────────────
    _ANR=$(grep -iE 'ANR in |Reason: .*hang|Subject: Executing service' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_ANR" ]; then
        info "  ANRs no bugreport:"
        echo "$_ANR" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 180)"
            case "$L" in
                *freefire*|*dts\.freefire*) alert "    ANR de FREE FIRE: $(echo "$L" | head -c 140)" ;;
            esac
        done
    fi

    # ── 6. LMK / OOM kills ───────────────────────────────────────────
    _LMK=$(grep -iE 'lowmemorykiller|LMK.*killed|Out of memory:.*Kill|killing.*adj|to-be-killed adj' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_LMK" ]; then
        _LMK_FF=$(echo "$_LMK" | grep -iE 'freefire|com\.dts\.freefire' | head -3)
        if [ -n "$_LMK_FF" ]; then
            alert "  Free Fire foi killed por LMK/OOM:"
            echo "$_LMK_FF" | while IFS= read -r L; do
                [ -n "$L" ] && alert "    $(echo "$L" | head -c 160)"
            done
            BR_HITS=$((BR_HITS+1))
        else
            _LMK_COUNT=$(echo "$_LMK" | wc -l)
            info "  LMK/OOM kills: $_LMK_COUNT eventos (sem FF)"
        fi
    fi

    # ── 7. Package events (install/uninstall/replace) ────────────────
    _PKG=$(grep -iE 'PackageManager:.*(installPackage|uninstallPackage|replaced|deleted)|am_(install|uninstall)|pkg_(install|uninstall)|installer_uid' "$_BRMAIN" 2>/dev/null | head -15)
    if [ -n "$_PKG" ]; then
        # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo dos sítios acima — bugreport tem
        # nomes de package/lib legítimos com 'mod' embutido, ex: com.motorola.mod*).
        _PKG_SUS=$(echo "$_PKG" | grep -iE 'freefire|cheat|hack|modmenu|aimbot|esp|frida|magisk|brevent|shizuku|gameguardian|virtualapp|parallel|lulubox|luckypatcher|mantispro|fakerunlocker|holograma|hologram')
        if [ -n "$_PKG_SUS" ]; then
            alert "  Eventos de pkg suspeitos no bugreport:"
            echo "$_PKG_SUS" | while IFS= read -r L; do
                [ -n "$L" ] && alert "    $(echo "$L" | head -c 180)"
            done
            BR_HITS=$((BR_HITS+1))
        fi
        info "  Total de eventos pkg: $(echo "$_PKG" | wc -l)"
    fi

    # ── 8. installerPackageName por app ──────────────────────────────
    _INST=$(grep -iE 'installerPackageName=|initiatingPackageName=' "$_BRMAIN" 2>/dev/null | grep -iE 'freefire|dts\.freefire' | head -5)
    if [ -n "$_INST" ]; then
        info "  Installer do FF no bugreport:"
        echo "$_INST" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 200)"
            case "$L" in
                *com.android.vending*|*com.google.market*) ;;
                *) alert "    Origem NÃO Play Store: $(echo "$L" | head -c 160)" ;;
            esac
        done
    fi

    # ── 9. Frida ports + abstract sockets ────────────────────────────
    _FRIDA_NET=$(grep -iE '@(frida|gum-js|linjector)|:27042|:27043|:27044|:27045|frida-server.*LISTEN' "$_BRMAIN" 2>/dev/null | head -5)
    if [ -n "$_FRIDA_NET" ]; then
        alert "  Frida network signature no bugreport:"
        echo "$_FRIDA_NET" | while IFS= read -r L; do
            [ -n "$L" ] && alert "    $(echo "$L" | head -c 160)"
        done
        BR_HITS=$((BR_HITS+1))
    fi

    # ── 10. Accessibility services suspeitos ─────────────────────────
    _ACC=$(grep -iE 'enabled_accessibility_services.*[a-z]' "$_BRMAIN" 2>/dev/null | head -3)
    if [ -n "$_ACC" ]; then
        info "  Accessibility services:"
        echo "$_ACC" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 180)"
            case "$L" in
                *esp*|*aimbot*|*menu*|*hack*|*cheat*|*ffh*|*macro*|*injector*)
                    alert "    Accessibility SUSPEITO: $(echo "$L" | head -c 160)" ;;
            esac
        done
    fi

    # ── 11. Overlays ativos (TYPE_APPLICATION_OVERLAY) ───────────────
    _OVL=$(grep -iE 'TYPE_APPLICATION_OVERLAY|TYPE_PHONE|SYSTEM_ALERT_WINDOW: allow' "$_BRMAIN" 2>/dev/null | head -20)
    if [ -n "$_OVL" ]; then
        # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo dos sítios acima).
        _OVL_SUS=$(echo "$_OVL" | grep -iE 'panel|injector|ffh4x|modmenu|cheat|esp|gameguardian|teambot|vipkill|fatality|aimbot')
        if [ -n "$_OVL_SUS" ]; then
            alert "  Overlays suspeitos no bugreport:"
            echo "$_OVL_SUS" | head -5 | while IFS= read -r L; do
                [ -n "$L" ] && alert "    $(echo "$L" | head -c 180)"
            done
            BR_HITS=$((BR_HITS+1))
        fi
    fi

    # ── 12. Processos suspeitos no ps snapshot ───────────────────────
    _PS=$(grep -iE '^\s*(u0_a[0-9]+|root|shell|system).*\b(frida|cheatengine|gameguardian|substrate|brevent|shizuku|virtualapp|parallel|lulubox)\b' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_PS" ]; then
        alert "  Processos suspeitos no ps do bugreport:"
        echo "$_PS" | while IFS= read -r L; do
            [ -n "$L" ] && alert "    $(echo "$L" | head -c 180)"
        done
        BR_HITS=$((BR_HITS+1))
    fi

    # ── 13. Procstats — apps com runtime suspeito ────────────────────
    _PROCSTATS=$(grep -iE '\* (com\.dts\.freefire|com\.topjohnwu\.magisk|.*frida.*|.*cheat.*|.*brevent.*|.*shizuku.*).*:.*%.*hour' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_PROCSTATS" ]; then
        info "  Procstats (runtime):"
        echo "$_PROCSTATS" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 200)"
        done
    fi

    # ── 14. Wake locks suspeitos (cheats que mantêm device acordado) ─
    _WAKE=$(grep -iE 'WakeLock.*com\.(dts\.freefire|.*cheat.*|.*injector.*|.*hack.*)' "$_BRMAIN" 2>/dev/null | head -5)
    if [ -n "$_WAKE" ]; then
        warn "  WakeLocks de apps suspeitos:"
        echo "$_WAKE" | while IFS= read -r L; do
            [ -n "$L" ] && warn "    $(echo "$L" | head -c 180)"
        done
    fi

    # ── 15. Boot completed + reboot history ──────────────────────────
    _BOOT_HIST=$(grep -iE 'boot_complete|sys_boot_completed|BOOT_COMPLETED|Shutdown reason|sys.shutdown' "$_BRMAIN" 2>/dev/null | head -5)
    if [ -n "$_BOOT_HIST" ]; then
        info "  Boot history:"
        echo "$_BOOT_HIST" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 180)"
        done
    fi

    # ── 16. ADB connections (wireless debug usado) ───────────────────
    _ADB=$(grep -iE 'adb_(enabled|wifi)|persist\.adb\.tcp\.port|adb_keys|adbd: connected' "$_BRMAIN" 2>/dev/null | head -5)
    if [ -n "$_ADB" ]; then
        warn "  ADB activity:"
        echo "$_ADB" | while IFS= read -r L; do
            [ -n "$L" ] && warn "    $(echo "$L" | head -c 180)"
        done
    fi

    # ── 17. Mock location / Developer settings ─────────────────────
    _DEV=$(grep -iE 'mock_location|allow_mock_location|development_settings_enabled|stay_on_while_plugged_in' "$_BRMAIN" 2>/dev/null | head -3)
    if [ -n "$_DEV" ]; then
        warn "  Developer settings:"
        echo "$_DEV" | while IFS= read -r L; do
            [ -n "$L" ] && warn "    $(echo "$L" | head -c 160)"
        done
    fi

    # ── 18. Private DNS / Proxy ─────────────────────────────────────
    _NET=$(grep -iE 'private_dns_mode|private_dns_specifier|global_http_proxy_host|http_proxy=' "$_BRMAIN" 2>/dev/null | head -5)
    if [ -n "$_NET" ]; then
        info "  Network config:"
        echo "$_NET" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 180)"
            case "$L" in
                *http_proxy=h*|*global_http_proxy_host=h*)
                    alert "    Proxy ATIVO no bugreport: $(echo "$L" | head -c 160)" ;;
            esac
        done
    fi

    # ── 19. Dropbox events list ─────────────────────────────────────
    _DROP=$(grep -iE 'DropBox.*entry|dropbox.*crash|system_app_(crash|anr)|data_app_crash' "$_BRMAIN" 2>/dev/null | head -15)
    if [ -n "$_DROP" ]; then
        # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo dos sítios acima).
        _DROP_SUS=$(echo "$_DROP" | grep -iE 'freefire|cheat|hack|modmenu|injector|frida')
        if [ -n "$_DROP_SUS" ]; then
            alert "  Dropbox events suspeitos:"
            echo "$_DROP_SUS" | head -5 | while IFS= read -r L; do
                [ -n "$L" ] && alert "    $(echo "$L" | head -c 180)"
            done
            BR_HITS=$((BR_HITS+1))
        fi
    fi

    # ── 20. WiFi history (SSIDs conectados) ──────────────────────────
    _WIFI=$(grep -iE 'SSID:|configured_network|saved_network|last_connected_ssid' "$_BRMAIN" 2>/dev/null | head -10)
    if [ -n "$_WIFI" ]; then
        info "  WiFi history (primeiras 10):"
        echo "$_WIFI" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 180)"
        done
    fi

    # ── 21. App firstInstallTime + lastUpdateTime de FF ─────────────
    _FF_TIME=$(grep -A5 -E 'Package \[com\.dts\.freefire(th|max)\]' "$_BRMAIN" 2>/dev/null | grep -iE 'firstInstallTime|lastUpdateTime|installerPackageName' | head -10)
    if [ -n "$_FF_TIME" ]; then
        info "  Free Fire install timeline:"
        echo "$_FF_TIME" | while IFS= read -r L; do
            [ -n "$L" ] && info "    $(echo "$L" | head -c 200)"
        done
    fi

    # ── 22. Batterystats — uninstalls registrados ───────────────────
    _BSTATS_UNI=$(grep -oE 'pkgunin=[0-9]+:"[^"]+"' "$_BRMAIN" 2>/dev/null | sort -u | head -20)
    if [ -n "$_BSTATS_UNI" ]; then
        # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo dos sítios acima).
        _BSTATS_SUS=$(echo "$_BSTATS_UNI" | grep -iE 'freefire|cheat|hack|modmenu|aimbot|injector|frida|magisk|brevent|shizuku|gameguardian|virtualapp|lulubox|luckypatcher')
        if [ -n "$_BSTATS_SUS" ]; then
            alert "  Uninstalls suspeitos (batterystats):"
            echo "$_BSTATS_SUS" | while IFS= read -r L; do
                [ -n "$L" ] && alert "    $L"
            done
            BR_HITS=$((BR_HITS+1))
        fi
    fi

    # Limpa o tmpdir
    [ -n "$_BRWORK" ] && rm -rf "$_BRWORK" 2>/dev/null
}

# Modo offline: BUGREPORT_FILE=/path/to/bugreport.zip sh a4ther.sh
if [ -n "$BUGREPORT_FILE" ] && [ -r "$BUGREPORT_FILE" ]; then
    info "Modo offline: analisando $BUGREPORT_FILE"
    br_parse "$BUGREPORT_FILE"
fi

# Modo normal: vasculha paths conhecidos de bugreport
BR_FOUND=0
for BR in $BR_PATHS; do
    [ -d "$BR" ] || continue
    COUNT=$(ls "$BR" 2>/dev/null | grep -E '\.(zip|txt|log)$' | wc -l)
    [ "$COUNT" = "0" ] && continue
    BR_FOUND=1
    info "Bugreports em $BR: $COUNT arquivo(s)"
    for BRF in $(ls -t "$BR" 2>/dev/null | grep -E 'bugreport.*\.(zip|txt)$' | head -3); do
        br_parse "$BR/$BRF"
    done
done

if [ "$BR_FOUND" = "0" ] && [ -z "$BUGREPORT_FILE" ]; then
    info "Nenhum bugreport encontrado nos paths conhecidos."
    info "Pra gerar um bugreport completo (ver instruções no final do scan):"
    info "  Settings → System → Developer options → Take bug report (Full)"
    info "  OU via depuração WiFi (instruções pós-scan)"
fi

[ "$PLOG_HITS" = "0" ] && ok "Logs persistentes sem rastros de cheat"

# ============================================================
#  29c. CRASHES POR APP (v4.4.32)
#  Crashes do FF, app de Câmera e Galeria. Cheats que tocam memória crashem
#  o jogo; cheats de foto crashem a câmera/galeria. Filtra tombstones/ANRs/
#  dropbox por bundle dessas categorias.
# ============================================================
header "CRASHES POR APP (Free Fire + Câmera + Galeria)"

CRASH_HITS=0

# Apps de interesse por categoria
FF_BUNDLES_LOCAL="com.dts.freefireth com.dts.freefiremax"
CAM_BUNDLES="com.android.camera com.android.camera2 com.miui.camera com.sec.android.app.camera com.huawei.camera com.oppo.camera com.coloros.camera com.realme.camera org.codeaurora.snapcam"
GAL_BUNDLES="com.miui.gallery com.sec.android.gallery3d com.google.android.apps.photos com.android.gallery3d com.coloros.gallery3d com.huawei.gallery com.android.documentsui"

for CATEGORY in "FF:$FF_BUNDLES_LOCAL" "CAMERA:$CAM_BUNDLES" "GALERIA:$GAL_BUNDLES"; do
    CAT_NAME="${CATEGORY%%:*}"
    CAT_PKGS="${CATEGORY#*:}"
    for PKG in $CAT_PKGS; do
        # 1) Dropbox crashes (persistentes)
        if [ -d /data/system/dropbox ]; then
            DROP_HITS=$(grep -l "$PKG" /data/system/dropbox/*crash* /data/system/dropbox/*anr* 2>/dev/null | head -3)
            [ -n "$DROP_HITS" ] && echo "$DROP_HITS" | while IFS= read -r DF; do
                [ -z "$DF" ] && continue
                DMT=$(stat -c '%y' "$DF" 2>/dev/null)
                alert "[$CAT_NAME] Crash de $PKG: $DF ($DMT)"
            done
            [ -n "$DROP_HITS" ] && CRASH_HITS=$((CRASH_HITS+1))
        fi
        # 2) ANRs com o PKG mencionado
        if [ -d /data/anr ]; then
            for ANR in $(ls -t /data/anr 2>/dev/null | head -10); do
                [ -r "/data/anr/$ANR" ] || continue
                if grep -lq "$PKG" "/data/anr/$ANR" 2>/dev/null; then
                    AMT=$(stat -c '%y' "/data/anr/$ANR" 2>/dev/null)
                    warn "[$CAT_NAME] ANR de $PKG: /data/anr/$ANR ($AMT)"
                fi
            done
        fi
        # 3) Logcat crash buffer
        if have logcat; then
            LC_HIT=$(timeout 5 logcat -d -b crash 2>/dev/null | grep -iE "FATAL.*$PKG|tombstone.*$PKG" | head -3)
            if [ -n "$LC_HIT" ]; then
                echo "$LC_HIT" | while IFS= read -r L; do
                    [ -n "$L" ] && alert "[$CAT_NAME] logcat crash de $PKG: $(echo "$L" | head -c 150)"
                done
                CRASH_HITS=$((CRASH_HITS+1))
            fi
        fi
    done
done

# Tombstones recentes que mencionem libs cheat (qualquer app)
if [ -d /data/tombstones ]; then
    for TS in $(ls -t /data/tombstones 2>/dev/null | head -10); do
        [ -r "/data/tombstones/$TS" ] || continue
        SUS=$(grep -iE 'libfrida|libsubstrate|libxhook|libgum|libdobby|libsandhook|libwhale' "/data/tombstones/$TS" 2>/dev/null | head -2)
        if [ -n "$SUS" ]; then
            TMT=$(stat -c '%y' "/data/tombstones/$TS" 2>/dev/null)
            alert "Tombstone com lib de cheat: /data/tombstones/$TS ($TMT)"
            echo "$SUS" | while IFS= read -r L; do
                [ -n "$L" ] && alert "  $(echo "$L" | head -c 140)"
            done
            CRASH_HITS=$((CRASH_HITS+1))
        fi
    done
fi

if [ "$CRASH_HITS" = "0" ]; then
    ok "Sem crashes recentes de FF/câmera/galeria com libs cheat"
    info "Pra análise mais profunda (sem root no Termux): depuração WiFi + adb bugreport"
    info "  1) Settings → Developer → Wireless debugging → Pair device"
    info "  2) No PC: adb pair <ip:port> + código; adb connect <ip:port>"
    info "  3) adb bugreport bugreport.zip → analisar offline"
fi

# ============================================================
#  30. SYSTEM TAMPERING
# ============================================================
header "SYSTEM TAMPERING"

SYS_HITS=0
if [ -d /system/etc/init.d ]; then
    INIT_FILES=$(ls /system/etc/init.d 2>/dev/null | head -n 10)
    [ -n "$INIT_FILES" ] && echo "$INIT_FILES" | while IFS= read -r F; do
        [ -n "$F" ] && warn "Script init.d: /system/etc/init.d/$F"
    done
fi

for SYSBIN in /system/bin/.ext /system/xbin/su /system/xbin/busybox /system/bin/busybox \
              /system/xbin/daemonsu /system/bin/.has_su; do
    exists "$SYSBIN" && { warn "Binário extra: $SYSBIN"; SYS_HITS=$((SYS_HITS+1)); }
done

exists /system/recovery-from-boot.p && info "/system/recovery-from-boot.p presente"
for RECOVERY in TWRP OrangeFox PBRP; do
    exists "/sdcard/$RECOVERY" && warn "Recovery custom: /sdcard/$RECOVERY"
done

if mount 2>/dev/null | grep -E ' /system ' | grep -q ' rw,'; then
    alert "/system montado RW (tampering ativo)"
    SYS_HITS=$((SYS_HITS+1))
fi

[ "$SYS_HITS" = "0" ] && ok "/system sem tampering visível"

# ============================================================
#  31. HWID (SHA-256 + MD5)
#  v4.4.3: Android 10+ bloqueia ro.serialno, MAC e android_id pra apps não-
#  privilegiados (Termux). Cada campo agora tem 4-7 fallbacks de fontes
#  diferentes (getprop vendor-specific, /proc/cmdline, /sys, ip link, etc).
# ============================================================
header "HWID"

# ─── SERIAL ─── v4.4.67: prioriza o serial REAL do hardware; o ro.boot.serialno
# (= "Boot serial") vai por ÚLTIMO. Antes ele era a 2ª fonte e, no Android 10+
# (onde ro.serialno volta vazio p/ UID não-privilegiado), o "Serial" acabava
# ESPELHANDO o "Boot serial". Agora rastreia a FONTE (SERIAL_SRC), valida o
# candidato e só cai no boot serial se nenhuma fonte real responder. O
# `service call iphonesubinfo` (uid 2000/shell) destrava o IMEI/serial real.
SERIAL=""; SERIAL_SRC=""
# parser do `service call` (parcel UTF-16 → ascii): conteúdo entre aspas de cada
# linha (1 caractere real + \0, que o dump mostra como '.'), sem os '.'/espaços.
_svc() { awk -F"'" 'NF>1{printf "%s",$2}' 2>/dev/null | tr -d '. '; }
# _ser <fonte> <valor>: aceita o 1º candidato VÁLIDO (>=6 alfanum, sem erro/0).
_ser() {
    [ -n "$SERIAL" ] && return 0
    case "$2" in ""|*Failure*|*Exception*|*error*|null|unknown|0|00000000|0x0) return 0 ;; esac
    printf '%s' "$2" | grep -qE '^[A-Za-z0-9_.:-]{6,}$' || return 0
    SERIAL="$2"; SERIAL_SRC="$1"
}
_ser ro.serialno              "$(gp ro.serialno)"
[ -z "$SERIAL" ] && have service && _ser iphonesubinfo "$(service call iphonesubinfo 1 2>/dev/null | _svc)"
_ser ro.vendor.boot.serialno  "$(gp ro.vendor.boot.serialno)"
_ser ril.serialnumber         "$(gp ril.serialnumber)"
_ser ro.serialno.fact         "$(gp ro.serialno.fact)"
_ser ro.boot.em.serial        "$(gp ro.boot.em.serial)"
_ser ril.serial               "$(gp ril.serial)"
_ser ril.product_code         "$(gp ril.product_code)"
# SoC serial (/sys) — identificador real, raramente bloqueado pelo privacy lock
_ser soc0                     "$(cat /sys/devices/soc0/serial_number 2>/dev/null)"
_ser soc0-sys                 "$(cat /sys/devices/system/soc/soc0/serial_number 2>/dev/null)"
_ser platform-soc0            "$(cat /sys/devices/platform/soc/soc0/serial_number 2>/dev/null)"
_ser mt_efuse                 "$(cat /proc/mt_efuse 2>/dev/null | grep -oE '[A-F0-9]{16,}' | head -1)"
_ser android_usb              "$(cat /sys/class/android_usb/android0/iSerial 2>/dev/null)"
_ser sys-serial               "$(find /sys/devices -maxdepth 4 -name 'serial_number' 2>/dev/null | head -1 | xargs cat 2>/dev/null | head -c 64)"
_ser proc-serial              "$(cat /proc/serial_number 2>/dev/null | head -c 64)"
_ser ro.ril.miui.imei0        "$(gp ro.ril.miui.imei0)"
_ser ro.boot.cpuid            "$(gp ro.boot.cpuid)"
_ser persist.radio.serialno   "$(gp persist.radio.serialno)"
# ÚLTIMO recurso — é o próprio "Boot serial" (espelha quando nada acima respondeu)
_ser ro.boot.serialno         "$(gp ro.boot.serialno)"
_ser cmdline                  "$(cat /proc/cmdline 2>/dev/null | grep -oE 'androidboot\.serialno=[^ ]+' | cut -d= -f2 | head -1)"

# ─── BOOT SERIAL ─── 4 fontes
BOOT_SERIAL=$(gp ro.boot.serialno)
[ -z "$BOOT_SERIAL" ] && BOOT_SERIAL=$(cat /proc/cmdline 2>/dev/null | grep -oE 'androidboot\.serialno=[^ ]+' | cut -d= -f2 | head -1)
[ -z "$BOOT_SERIAL" ] && BOOT_SERIAL=$(gp ro.bootloader)
[ -z "$BOOT_SERIAL" ] && BOOT_SERIAL=$(gp ro.boot.bootloader)

# ─── MAC wlan0 ─── 6 fontes (a maioria falha em Android 10+ por privacy)
MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null)
[ -z "$MAC" ] && MAC=$(ip link show wlan0 2>/dev/null | awk '/link\/ether/ {print $2}' | head -1)
[ -z "$MAC" ] && MAC=$(ip addr show wlan0 2>/dev/null | awk '/link\/ether/ {print $2}' | head -1)
[ -z "$MAC" ] && MAC=$(ifconfig wlan0 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
# Algumas ROMs guardam o MAC original em getprop
[ -z "$MAC" ] && MAC=$(gp persist.sys.wifi.mac)
[ -z "$MAC" ] && MAC=$(gp ro.boot.wifi.macaddr)
[ -z "$MAC" ] && MAC=$(gp wifi.interface.macaddr)
# Fallback final: outras interfaces (eth0, ap0)
[ -z "$MAC" ] && MAC=$(cat /sys/class/net/eth0/address 2>/dev/null)

# ─── ANDROID ID ─── 3 fontes
# v4.4.7: android_id canônico = 16 dígitos hex (64-bit). Valida cada fonte de
# QUERY pra não aceitar lixo (banner de shell, msg de erro de OEM, ou um binário
# errado resolvido por `have cmd`) como se fosse o ID.
is_android_id() { printf '%s' "$1" | grep -qE '^[0-9a-fA-F]{16}$'; }
ANDROID_ID=""
ANDROID_ID=$(setting_get secure android_id)
is_android_id "$ANDROID_ID" || ANDROID_ID=""
# v4.4.59: métodos alternativos que furam o bloqueio do MIUI/HyperOS no Termux.
# No Redmi/HyperOS o comando `settings` falha pra apps não-privilegiados, mas o
# `content query` (provider direto) e o `cmd settings` muitas vezes funcionam.
if [ -z "$ANDROID_ID" ] && have content; then
    ANDROID_ID=$(content query --uri content://settings/secure --where "name=\'android_id\'" 2>/dev/null \
        | grep -oE 'value=[A-Za-z0-9]+' | head -1 | cut -d= -f2)
    is_android_id "$ANDROID_ID" || ANDROID_ID=""
fi
if [ -z "$ANDROID_ID" ] && have cmd; then
    _AID=$(cmd settings get secure android_id 2>/dev/null)
    is_android_id "$_AID" && ANDROID_ID="$_AID"
fi
# settings via service call (raro, mas funciona em alguns)
if [ -z "$ANDROID_ID" ] && have service; then
    ANDROID_ID=$(content query --uri content://settings/secure/android_id 2>/dev/null | grep -oE '[a-f0-9]{16}' | head -1)
fi
[ -z "$ANDROID_ID" ] && ANDROID_ID=$(gp ro.serialno)  # fallback comum em alguns devices
[ -z "$ANDROID_ID" ] && ANDROID_ID=$(cat /data/system/users/0/settings_secure.xml 2>/dev/null | grep -oE 'android_id" value="[^"]*' | cut -d'"' -f3)

# ─── BLUETOOTH MAC ─── (v4.4.3: novo, raramente bloqueado pelo privacy sandbox)
BT_MAC=$(gp persist.service.bdroid.bdaddr)
[ -z "$BT_MAC" ] && BT_MAC=$(gp ro.boot.btmacaddr)
[ -z "$BT_MAC" ] && BT_MAC=$(cat /sys/class/bluetooth/hci0/address 2>/dev/null)

# ─── Build fingerprint sempre disponível (uniquíssimo no install) ───
FINGERPRINT=$(gp ro.build.fingerprint)
PRODUCT_MODEL=$(gp ro.product.model)
PRODUCT_BRAND=$(gp ro.product.brand)

# ─── v4.4.32: identificadores que sobrevivem ao privacy lock do Android 10+ ───
# WIDEVINE_ID — DRM L1/L3 ID, único POR DEVICE, sempre legível por qualquer app
# (incluindo Termux) via dumpsys. Estável após factory reset (L1 não muda).
WIDEVINE_ID=""
if have dumpsys; then
    WIDEVINE_ID=$(dumpsys media.drm 2>/dev/null | grep -m1 -oE 'PluginUniqueId.*[0-9A-Fa-f-]{20,}' | grep -oE '[0-9A-Fa-f-]{20,}')
    [ -z "$WIDEVINE_ID" ] && \
        WIDEVINE_ID=$(dumpsys drm 2>/dev/null | grep -m1 -oE 'deviceUniqueId.*[0-9A-Fa-f]{16,}' | grep -oE '[0-9A-Fa-f]{16,}' | head -1)
fi
# BOOT_ID — UUID do kernel gerado em cada boot. Não é único por device, mas
# permite correlacionar logs/sessões. Sempre disponível.
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
# GSF_ID — Google Services Framework ID (precisa root pra ler, mas tenta)
GSF_ID=$(sqlite3 /data/data/com.google.android.gsf/databases/gservices.db \
    "select value from main where name='android_id'" 2>/dev/null)
# Bootloader version (parte do device fingerprint)
BOOTLOADER=$(gp ro.bootloader)
[ -z "$BOOTLOADER" ] && BOOTLOADER=$(gp ro.boot.bootloader)
# Build description (mais único que fingerprint em alguns devices)
BUILD_DESC=$(gp ro.build.description)

# v4.4.7: FALLBACK BUGREPORT — em modo offline (BUGREPORT_FILE=) o getprop/sys
# LIVE vem vazio (o script não roda no device-alvo). Preenche cada campo ainda
# vazio com o valor extraído do bugreport (br_parse → BR_*). O valor LIVE sempre
# tem prioridade; o do bugreport só entra no buraco.
[ -z "$SERIAL" ]      && [ -n "$BR_SERIAL" ]      && SERIAL="$BR_SERIAL"
[ -z "$BOOT_SERIAL" ] && [ -n "$BR_BOOT_SERIAL" ] && BOOT_SERIAL="$BR_BOOT_SERIAL"
[ -z "$MAC" ]         && [ -n "$BR_MAC" ]         && MAC="$BR_MAC"
[ -z "$BT_MAC" ]      && [ -n "$BR_BT_MAC" ]      && BT_MAC="$BR_BT_MAC"
[ -z "$ANDROID_ID" ]  && [ -n "$BR_ANDROID_ID" ]  && ANDROID_ID="$BR_ANDROID_ID"
[ -z "$WIDEVINE_ID" ] && [ -n "$BR_WIDEVINE" ]    && WIDEVINE_ID="$BR_WIDEVINE"
[ -z "$FINGERPRINT" ] && [ -n "$BR_FINGERPRINT" ] && FINGERPRINT="$BR_FINGERPRINT"
[ -z "$BOOTLOADER" ]  && [ -n "$BR_BOOTLOADER" ]  && BOOTLOADER="$BR_BOOTLOADER"
[ -n "$BR_SERIAL$BR_ANDROID_ID$BR_WIDEVINE" ] && \
    info "Serial/HWID preenchidos do BUGREPORT (modo offline)"

# HWID composto — usa TODOS os campos disponíveis (não vazios).
# Widevine + Boot ID + Fingerprint são os pillars quando serial/MAC estão bloqueados.
RAW="${SERIAL}|${BOOT_SERIAL}|${MAC}|${BT_MAC}|${ANDROID_ID}|${WIDEVINE_ID}|${FINGERPRINT}|${PRODUCT_BRAND}|${PRODUCT_MODEL}|${BOOTLOADER}"
HWID_ALT_RAW="${ANDROID_ID}:${SERIAL}:${BOOT_SERIAL}:${WIDEVINE_ID}"

HASH=""
HASH_HWID_ALT=""
if have sha256sum; then
    HASH=$(printf '%s' "$RAW" | sha256sum 2>/dev/null | awk '{print $1}')
fi
if have md5sum; then
    HASH_HWID_ALT=$(printf '%s' "$HWID_ALT_RAW" | md5sum 2>/dev/null | awk '{print $1}')
elif have md5; then
    HASH_HWID_ALT=$(printf '%s' "$HWID_ALT_RAW" | md5 -q 2>/dev/null)
fi

if [ -n "$SERIAL" ] && [ -n "$BOOT_SERIAL" ] && [ "$SERIAL" = "$BOOT_SERIAL" ]; then
    info "Serial:        ${SERIAL}  (= Boot serial; fonte: ${SERIAL_SRC:-boot})"
else
    info "Serial:        ${SERIAL:-?}${SERIAL_SRC:+  (fonte: ${SERIAL_SRC})}"
fi
info "Boot serial:   ${BOOT_SERIAL:-?}"
info "MAC wlan0:     ${MAC:-?}"
info "Bluetooth MAC: ${BT_MAC:-?}"
info "Android ID:    ${ANDROID_ID:-?}"
info "Widevine ID:   ${WIDEVINE_ID:-?}"
info "Boot ID:       ${BOOT_ID:-?}"
[ -n "$GSF_ID" ]     && info "GSF ID:        $GSF_ID"
[ -n "$BOOTLOADER" ] && info "Bootloader:    $BOOTLOADER"
info "Brand/Model:   ${PRODUCT_BRAND:-?} / ${PRODUCT_MODEL:-?}"
info "Fingerprint:   ${FINGERPRINT:-?}"
info "HWID SHA-256:  ${HASH:-(indisponível)}"
info "HWID MD5:      ${HASH_HWID_ALT:-(indisponível)}"

# v4.4.32: diagnóstico granular — quais fontes vieram e quais bloquearam
# v4.4.57: aponta o CULPADO (Termux) e a SOLUÇÃO (adb shell) inline
if [ -z "$SERIAL" ] && [ -z "$MAC" ] && [ -z "$ANDROID_ID" ] && [ -z "$WIDEVINE_ID" ]; then
    warn "Todas fontes de HWID vazias — HWID fica baseado só em fingerprint/model (NÃO único)."
    if [ "$_IS_TERMUX" = "1" ] || { [ "$_IS_ROOT" = "0" ] && [ "$_IS_SHELL" = "0" ]; }; then
        warn "  ↳ CAUSA: scanner rodando no TERMUX (UID $_CUR_UID, sem privilégio)."
        warn "  ↳ SOLUÇÃO: rode VIA adb shell pra destravar serial + Widevine ID:"
        warn "       ${CW}adb shell sh /sdcard/Download/a4ther.sh${CN}"
        warn "  ↳ Parear a depuração SOZINHO não resolve — tem que RODAR pelo adb."
    fi
elif [ -z "$SERIAL" ] && [ -z "$MAC" ] && [ -z "$ANDROID_ID" ]; then
    info "Serial/MAC/AndroidID bloqueados (app sem permissão), mas Widevine ID/Boot ID/Fingerprint OK — HWID composto é único."
    [ "$_IS_TERMUX" = "1" ] && \
        info "  ↳ Pra também pegar o serial real: rode via ${CW}adb shell sh ...a4ther.sh${CN}"
fi

# ============================================================
#  31b. PLAY STORE / REGIÃO (v4.4.32)
#  Cheaters em FF usam conta de outra região pra pegar item antes ou usar
#  cheats regionais. Compara COUNTRY/LOCALE/SIM/PlayStore — se algum diverge,
#  flag pra revisão. Esperado pra BR: locale pt-BR + SIM 724/BR + Play BR.
# ============================================================
header "PLAY STORE / REGIÃO"

REGION_HITS=0
EXPECTED_COUNTRY="${EXPECTED_COUNTRY:-BR}"

# Re-coleta (variáveis podem ter sumido depois de várias seções)
LOCALE_NOW=$(gp ro.product.locale)
[ -z "$LOCALE_NOW" ] && LOCALE_NOW=$(gp persist.sys.locale)
COUNTRY_NOW=$(gp persist.sys.country)
[ -z "$COUNTRY_NOW" ] && COUNTRY_NOW=$(gp ro.csc.countryiso_code)
[ -z "$COUNTRY_NOW" ] && COUNTRY_NOW=$(gp ro.product.locale.region)
[ -z "$COUNTRY_NOW" ] && [ -n "$LOCALE_NOW" ] && COUNTRY_NOW=$(echo "$LOCALE_NOW" | sed -nE 's/.*[-_]([A-Z]{2}).*/\1/p')

SIM_COUNTRY=$(gp gsm.sim.operator.iso-country | tr '[:lower:]' '[:upper:]')
[ -z "$SIM_COUNTRY" ] && SIM_COUNTRY=$(gp gsm.operator.iso-country | tr '[:lower:]' '[:upper:]')
SIM_OPERATOR=$(gp gsm.sim.operator.alpha)
SIM_MCC=$(gp gsm.sim.operator.numeric | head -c 3)

# Play Store: prioriza shared_prefs (precisa root). Fallback: gmsversion regex.
PLAY_COUNTRY_NOW=""
for VPATH in /data/data/com.android.vending/shared_prefs/finsky.xml \
             /data/data/com.android.vending/shared_prefs/finsky-user-prefs.xml; do
    [ -r "$VPATH" ] && {
        PLAY_COUNTRY_NOW=$(grep -oE 'BillingCountry[^>]*>[A-Z]{2}<' "$VPATH" 2>/dev/null | grep -oE '>[A-Z]{2}<' | tr -d '><')
        [ -z "$PLAY_COUNTRY_NOW" ] && \
            PLAY_COUNTRY_NOW=$(grep -oE '"[A-Z]{2}"' "$VPATH" 2>/dev/null | head -1 | tr -d '"')
        [ -n "$PLAY_COUNTRY_NOW" ] && break
    }
done
[ -z "$PLAY_COUNTRY_NOW" ] && PLAY_COUNTRY_NOW=$(gp ro.com.google.gmsversion 2>/dev/null | sed -nE 's/.*_([A-Z]{2}).*/\1/p')

# v4.4.7: fallback bugreport (modo offline) — live vem vazio fora do device-alvo
[ -z "$LOCALE_NOW" ]       && [ -n "$BR_LOCALE" ]       && LOCALE_NOW="$BR_LOCALE"
[ -z "$COUNTRY_NOW" ]      && [ -n "$BR_COUNTRY" ]      && COUNTRY_NOW="$BR_COUNTRY"
[ -z "$SIM_COUNTRY" ]      && [ -n "$BR_SIM_COUNTRY" ]  && SIM_COUNTRY="$BR_SIM_COUNTRY"
[ -z "$SIM_OPERATOR" ]     && [ -n "$BR_SIM_OPERATOR" ] && SIM_OPERATOR="$BR_SIM_OPERATOR"
[ -z "$SIM_MCC" ]          && [ -n "$BR_SIM_MCC" ]      && SIM_MCC="$BR_SIM_MCC"
[ -z "$PLAY_COUNTRY_NOW" ] && [ -n "$BR_PLAY_COUNTRY" ] && PLAY_COUNTRY_NOW="$BR_PLAY_COUNTRY"

info "Locale device:    ${LOCALE_NOW:-?}"
info "Country device:   ${COUNTRY_NOW:-?}"
info "SIM country:      ${SIM_COUNTRY:-?} (operadora: ${SIM_OPERATOR:-?}, MCC: ${SIM_MCC:-?})"
info "Play Store:       ${PLAY_COUNTRY_NOW:-?}"
info "Expected:         $EXPECTED_COUNTRY (override via EXPECTED_COUNTRY=XX)"

# Divergências
if [ -n "$COUNTRY_NOW" ] && [ "$COUNTRY_NOW" != "$EXPECTED_COUNTRY" ]; then
    warn "Country device ($COUNTRY_NOW) ≠ esperado ($EXPECTED_COUNTRY)"
    REGION_HITS=$((REGION_HITS+1))
fi
if [ -n "$SIM_COUNTRY" ] && [ "$SIM_COUNTRY" != "$EXPECTED_COUNTRY" ]; then
    warn "SIM country ($SIM_COUNTRY) ≠ esperado ($EXPECTED_COUNTRY) — chip de outro país"
    REGION_HITS=$((REGION_HITS+1))
fi
if [ -n "$PLAY_COUNTRY_NOW" ] && [ "$PLAY_COUNTRY_NOW" != "$EXPECTED_COUNTRY" ]; then
    alert "Play Store country ($PLAY_COUNTRY_NOW) ≠ esperado ($EXPECTED_COUNTRY) — conta Play de outro país"
    REGION_HITS=$((REGION_HITS+1))
fi
# SIM vs Play divergem = cheater usando proxy/VPN+conta de outra região
if [ -n "$SIM_COUNTRY" ] && [ -n "$PLAY_COUNTRY_NOW" ] && [ "$SIM_COUNTRY" != "$PLAY_COUNTRY_NOW" ]; then
    alert "SIM ($SIM_COUNTRY) ≠ Play Store ($PLAY_COUNTRY_NOW) — combinação típica de cheater regional"
    REGION_HITS=$((REGION_HITS+1))
fi
[ "$REGION_HITS" = "0" ] && ok "Locale/SIM/Play Store consistentes com $EXPECTED_COUNTRY"

fi  # ===== fim do bloco ANDROID =====

# ============================================================
#  ====== BLOCO iOS (jailbreak + tweaks + Frida + Free Fire) ==========
# ============================================================
if [ "$PLATFORM" = "ios" ]; then

# ============================================================
#  iOS-1. INFO DO SISTEMA
# ============================================================
header "iOS - INFO DO SISTEMA"

IOS_VERSION=""
IOS_MODEL=""
IOS_BUILD=""
if [ -r /System/Library/CoreServices/SystemVersion.plist ]; then
    IOS_VERSION=$(grep -A1 '<key>ProductVersion</key>' /System/Library/CoreServices/SystemVersion.plist 2>/dev/null | grep -oE '<string>[^<]+' | head -n1 | sed 's/<string>//')
    IOS_BUILD=$(grep -A1 '<key>ProductBuildVersion</key>' /System/Library/CoreServices/SystemVersion.plist 2>/dev/null | grep -oE '<string>[^<]+' | head -n1 | sed 's/<string>//')
fi
if have sw_vers; then
    [ -z "$IOS_VERSION" ] && IOS_VERSION=$(sw_vers -productVersion 2>/dev/null)
    [ -z "$IOS_BUILD" ]   && IOS_BUILD=$(sw_vers -buildVersion 2>/dev/null)
fi
IOS_MODEL=$(uname -m 2>/dev/null)

info "iOS version:  ${IOS_VERSION:-?}"
info "Build:        ${IOS_BUILD:-?}"
info "Machine:      ${IOS_MODEL:-?}"
info "Kernel:       $(uname -r 2>/dev/null)"

# Já estar conseguindo rodar bash via SSH = device jailbroken
# v4.4.32: gate em IS_REAL_IOS pra não disparar em macOS com FORCE_PLATFORM=ios.
if [ "$IS_REAL_IOS" = "1" ]; then
    warn "Você está rodando bash em iOS - device JÁ está jailbroken (SSH habilitado)"
else
    info "Modo iOS forçado em macOS (FORCE_PLATFORM=ios) — checks limitados"
fi

# ============================================================
#  iOS-1b. REGIÃO / APP STORE COUNTRY (v4.4.32)
#  Cheaters usam Apple ID de outra região pra puxar IPA sem assinatura, comprar
#  cheats ou pegar release antecipado. Lê AppleLocale + StorefrontIdentifier.
# ============================================================
header "iOS - REGIÃO / APP STORE COUNTRY"

REGION_IOS_HITS=0
EXPECTED_COUNTRY_IOS="${EXPECTED_COUNTRY:-BR}"

APPLE_LOCALE=""
APPLE_COUNTRY=""
STOREFRONT_ID=""
STOREFRONT_COUNTRY=""

# 1) AppleLocale + AppleCountry de .GlobalPreferences.plist
for GP in /var/mobile/Library/Preferences/.GlobalPreferences.plist \
          /private/var/mobile/Library/Preferences/.GlobalPreferences.plist \
          "$HOME/Library/Preferences/.GlobalPreferences.plist"; do
    [ -r "$GP" ] || continue
    if have plutil; then
        APPLE_LOCALE=$(plutil -p "$GP" 2>/dev/null | grep -m1 'AppleLocale' | sed -E 's/.*=> "([^"]+)".*/\1/')
        APPLE_COUNTRY=$(plutil -p "$GP" 2>/dev/null | grep -m1 'AppleCountry' | sed -E 's/.*=> "([^"]+)".*/\1/')
    fi
    if [ -z "$APPLE_LOCALE" ] && have defaults; then
        APPLE_LOCALE=$(defaults read NSGlobalDomain AppleLocale 2>/dev/null)
        APPLE_COUNTRY=$(defaults read NSGlobalDomain AppleICUForce24HourTime 2>/dev/null; defaults read NSGlobalDomain AppleCountry 2>/dev/null)
    fi
    [ -n "$APPLE_LOCALE" ] && break
done

# 2) Storefront ID — código numérico da App Store (143441=US, 143503=BR, 143465=KR, etc.)
for SS in /var/mobile/Library/Preferences/com.apple.storeservices.plist \
          /private/var/mobile/Library/Preferences/com.apple.storeservices.plist \
          /var/mobile/Library/Preferences/com.apple.itunesstored.plist \
          "$HOME/Library/Preferences/com.apple.storeservices.plist"; do
    [ -r "$SS" ] || continue
    if have plutil; then
        STOREFRONT_ID=$(plutil -p "$SS" 2>/dev/null | grep -m1 -iE 'storefront|frontid' | grep -oE '[0-9]{6,}' | head -1)
    fi
    [ -z "$STOREFRONT_ID" ] && have strings && \
        STOREFRONT_ID=$(strings "$SS" 2>/dev/null | grep -m1 -E '^[0-9]{6}-[0-9]+,[0-9]+' | cut -d- -f1)
    [ -n "$STOREFRONT_ID" ] && break
done

# Mapa de storefront ID → ISO country (subset mais comum)
case "$STOREFRONT_ID" in
    143441) STOREFRONT_COUNTRY="US" ;;
    143503) STOREFRONT_COUNTRY="BR" ;;
    143442) STOREFRONT_COUNTRY="FR" ;;
    143443) STOREFRONT_COUNTRY="DE" ;;
    143444) STOREFRONT_COUNTRY="GB" ;;
    143445) STOREFRONT_COUNTRY="AT" ;;
    143446) STOREFRONT_COUNTRY="BE" ;;
    143447) STOREFRONT_COUNTRY="FI" ;;
    143452) STOREFRONT_COUNTRY="JP" ;;
    143460) STOREFRONT_COUNTRY="AU" ;;
    143462) STOREFRONT_COUNTRY="CA" ;;
    143465) STOREFRONT_COUNTRY="KR" ;;
    143467) STOREFRONT_COUNTRY="IN" ;;
    143470) STOREFRONT_COUNTRY="MX" ;;
    143476) STOREFRONT_COUNTRY="RU" ;;
    143480) STOREFRONT_COUNTRY="TR" ;;
    143489) STOREFRONT_COUNTRY="ID" ;;
    143505) STOREFRONT_COUNTRY="AR" ;;
    143508) STOREFRONT_COUNTRY="CO" ;;
    143464) STOREFRONT_COUNTRY="HK" ;;
    143470) STOREFRONT_COUNTRY="MY" ;;
    143474) STOREFRONT_COUNTRY="PH" ;;
    143479) STOREFRONT_COUNTRY="TH" ;;
    143481) STOREFRONT_COUNTRY="VN" ;;
    143542) STOREFRONT_COUNTRY="EG" ;;
    "") STOREFRONT_COUNTRY="" ;;
    *) STOREFRONT_COUNTRY="?($STOREFRONT_ID)" ;;
esac

# 3) ICU locale via defaults (timezone também ajuda)
SYS_LOCALE=""
if have defaults; then
    SYS_LOCALE=$(defaults read -g AppleLocale 2>/dev/null)
fi
TIMEZONE=$(systemsetup -gettimezone 2>/dev/null | sed 's/Time Zone: //')
[ -z "$TIMEZONE" ] && TIMEZONE=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
[ -z "$TIMEZONE" ] && have date && TIMEZONE=$(date +%Z 2>/dev/null)

info "AppleLocale:     ${APPLE_LOCALE:-?}"
info "AppleCountry:    ${APPLE_COUNTRY:-?}"
info "Storefront ID:   ${STOREFRONT_ID:-?}  →  country: ${STOREFRONT_COUNTRY:-?}"
info "System locale:   ${SYS_LOCALE:-?}"
info "Timezone:        ${TIMEZONE:-?}"
info "Expected:        $EXPECTED_COUNTRY_IOS"

if [ -n "$APPLE_COUNTRY" ] && [ "$APPLE_COUNTRY" != "$EXPECTED_COUNTRY_IOS" ]; then
    warn "AppleCountry ($APPLE_COUNTRY) ≠ esperado ($EXPECTED_COUNTRY_IOS)"
    REGION_IOS_HITS=$((REGION_IOS_HITS+1))
fi
if [ -n "$STOREFRONT_COUNTRY" ] && [ "$STOREFRONT_COUNTRY" != "$EXPECTED_COUNTRY_IOS" ]; then
    case "$STOREFRONT_COUNTRY" in
        \?*) warn "Storefront ID desconhecido: $STOREFRONT_ID — country não mapeado" ;;
        *)
            alert "App Store country ($STOREFRONT_COUNTRY) ≠ esperado ($EXPECTED_COUNTRY_IOS) — Apple ID de outra região"
            REGION_IOS_HITS=$((REGION_IOS_HITS+1)) ;;
    esac
fi
if [ -n "$APPLE_COUNTRY" ] && [ -n "$STOREFRONT_COUNTRY" ] \
   && [ "$APPLE_COUNTRY" != "$STOREFRONT_COUNTRY" ] && [ "${STOREFRONT_COUNTRY:0:1}" != "?" ]; then
    alert "AppleCountry ($APPLE_COUNTRY) ≠ Storefront ($STOREFRONT_COUNTRY) — device em região X, Apple ID em região Y"
    REGION_IOS_HITS=$((REGION_IOS_HITS+1))
fi
[ "$REGION_IOS_HITS" = "0" ] && ok "Locale + Apple ID + Storefront consistentes com $EXPECTED_COUNTRY_IOS"

# ============================================================
#  iOS-2. JAILBREAK (Cydia / Sileo / Zebra / rootless)
# ============================================================
header "iOS - JAILBREAK"

JB_HITS=0

# Apps de package manager (jailbreak clássico = rootful)
for P in /Applications/Cydia.app /Applications/Sileo.app /Applications/Zebra.app \
         /Applications/Installer.app /Applications/Saily.app /Applications/Aemulo.app \
         /Applications/blackra1n.app /Applications/MxTube.app /Applications/RockApp.app \
         /Applications/SBSettings.app /Applications/WinterBoard.app \
         /Applications/IntelliScreen.app /Applications/FakeCarrier.app \
         /Applications/snoop-itConfig.app; do
    exists "$P" && { alert "Jailbreak app: $P"; JB_HITS=$((JB_HITS+1)); }
done

# TrollStore (sideload sem jailbreak via bug Apple)
for P in /Applications/TrollStore.app /Applications/TrollHelper.app \
         /Applications/TrollNonce.app /Applications/TrollInstaller.app; do
    exists "$P" && { alert "TrollStore (sideload sem assinatura): $P"; JB_HITS=$((JB_HITS+1)); }
done

# Rootless jailbreak (palera1n / Dopamine / Bootstrap) - guarda em /var/jb
for P in /var/jb /private/var/jb /var/binpack /jb \
         /.bootstrapped_palera1n /.installed_unc0ver /.installed_dopamine \
         /var/checkra1n.dmg /var/mobile/Library/Dopamine; do
    exists "$P" && { alert "Rootless JB artifact: $P"; JB_HITS=$((JB_HITS+1)); }
done

# Paths clássicos de jailbreak (rootful) — separados em 2 grupos:
#  HARD: paths que SÓ existem em iOS jailbroken
#  SOFT: paths que TAMBÉM existem em macOS comum (skip se IS_REAL_IOS=0)
for P in /private/var/lib/cydia /private/var/cache/apt \
         /private/var/lib/apt /etc/apt \
         /usr/libexec/cydia/firmware.sh \
         /private/var/tmp/cydia.log \
         /var/lib/apt /var/lib/cydia /var/cache/apt \
         /private/etc/apt /Library/MobileSubstrate \
         /usr/share/jailbreak /private/var/stash; do
    exists "$P" && { alert "JB path: $P"; JB_HITS=$((JB_HITS+1)); }
done

# v4.4.32: paths que existem em macOS comum (ssh/sshd/sftp-server vêm com
# Remote Login). Só conta como JB se a gente confirmou device iOS real.
if [ "$IS_REAL_IOS" = "1" ]; then
    for P in /usr/sbin/sshd /usr/libexec/sftp-server /usr/bin/ssh; do
        exists "$P" && { alert "JB path (iOS real): $P"; JB_HITS=$((JB_HITS+1)); }
    done
else
    info "(skip ssh/sshd path checks — não confirmado como device iOS real)"
fi

# Pacotes APT que indicam jailbreak ativo
if have dpkg; then
    DPKG_LIST=$(dpkg -l 2>/dev/null | awk '/^ii/ {print $2}')
    if [ -n "$DPKG_LIST" ]; then
        info "Pacotes APT instalados: $(echo "$DPKG_LIST" | wc -l) total"
        # nomes notoriamente associados a jailbreak/cheat
        for SUSP in mobilesubstrate substrate frida-server preferenceloader \
                    libhooker ellekit dopamine taurine unc0ver palera1n \
                    rootless-launchd choicy crane filza-list filza signing \
                    flex-3 hook libsubstitute cycript ssh openssh sslkillswitch \
                    ssl-killswitch trollstore appsync flex protect-my-privacy; do
            HIT=$(echo "$DPKG_LIST" | grep -i "$SUSP")
            [ -n "$HIT" ] && { alert "Pacote APT suspeito: $HIT"; JB_HITS=$((JB_HITS+1)); }
        done
    fi
fi

[ "$JB_HITS" = "0" ] && ok "Sem indício de jailbreak"

# ============================================================
#  iOS-2b. CONFIGURATION PROFILES (.mobileconfig)
#          Proxy cheats iOS instalam aqui (Settings → VPN & Device Management)
# ============================================================
header "iOS - CONFIGURATION PROFILES (proxy cheats)"

CFG_HITS=0

# Diretórios oficiais de profiles
PROFILE_DIRS="
/private/var/mobile/Library/ConfigurationProfiles
/var/MobileDevice/ProvisioningProfiles
/var/installd/Library/MobileDevice/ProvisioningProfiles
/Library/Managed Preferences
/var/preferences/SystemConfiguration
"

for PDIR in $PROFILE_DIRS; do
    [ -d "$PDIR" ] || continue
    info "Profile dir: $PDIR"
    FILES=$(ls "$PDIR" 2>/dev/null)
    [ -z "$FILES" ] && continue
    echo "$FILES" | while IFS= read -r F; do
        [ -z "$F" ] && continue
        FULL="$PDIR/$F"
        info "  $F"
        # 1) Procurar payloads críticos no conteúdo do plist
        if [ -r "$FULL" ]; then
            # Plist binário ou XML - usar strings/plutil
            CONTENT=""
            if have plutil; then
                CONTENT=$(plutil -p "$FULL" 2>/dev/null)
            fi
            [ -z "$CONTENT" ] && have strings && CONTENT=$(strings "$FULL" 2>/dev/null)
            if [ -n "$CONTENT" ]; then
                # PayloadType crítico: VPN / proxy / CA root / web filter
                PT_VPN=$(echo "$CONTENT" | grep -iE 'com\.apple\.vpn\.managed|com\.apple\.vpn\.managed\.applayer' | head -n 1)
                PT_PROXY=$(echo "$CONTENT" | grep -iE 'com\.apple\.proxy\.http\.global|HTTPProxy|HTTPSProxy|ProxyServer|ProxyAutoConfigURLString' | head -n 1)
                PT_CA=$(echo "$CONTENT" | grep -iE 'com\.apple\.security\.root|com\.apple\.security\.pkcs1|com\.apple\.security\.pkcs12|com\.apple\.security\.scep' | head -n 1)
                PT_WCF=$(echo "$CONTENT" | grep -iE 'com\.apple\.webcontent-filter' | head -n 1)
                PT_DNS=$(echo "$CONTENT" | grep -iE 'com\.apple\.dnsSettings\.managed|com\.apple\.dnsProxy\.managed|com\.apple\.relay\.managed' | head -n 1)
                PT_MDM=$(echo "$CONTENT" | grep -iE 'com\.apple\.mdm' | head -n 1)
                # SystemProfile Restrictions (Screen Time / applicationaccess / passwordpolicy)
                PT_RESTR=$(echo "$CONTENT" | grep -iE 'com\.apple\.applicationaccess|com\.apple\.applicationaccess\.new|com\.apple\.screentimepolicy|com\.apple\.passwordpolicy|com\.apple\.systempolicy\.kernel-extension-policy|com\.apple\.systempolicy\.system-extension-policy' | head -n 1)
                PT_AIRPLAY=$(echo "$CONTENT" | grep -iE 'com\.apple\.airplay\.security' | head -n 1)
                PT_WIFI=$(echo "$CONTENT" | grep -iE 'com\.apple\.wifi\.managed' | head -n 1)
                PT_CERT_PKCS=$(echo "$CONTENT" | grep -iE 'com\.apple\.security\.pkcs' | head -n 1)
                PT_ACTIVATION=$(echo "$CONTENT" | grep -iE 'com\.apple\.iTunesStoreAccount|com\.apple\.activation' | head -n 1)

                [ -n "$PT_VPN" ]      && { alert "  Profile com VPN payload: $FULL"; CFG_HITS=$((CFG_HITS+1)); }
                [ -n "$PT_PROXY" ]    && { alert "  Profile com PROXY/HTTPProxy payload: $FULL"; CFG_HITS=$((CFG_HITS+1)); }
                [ -n "$PT_CA" ]       && { alert "  Profile com CA root (MITM-capable): $FULL"; CFG_HITS=$((CFG_HITS+1)); }
                [ -n "$PT_WCF" ]      && { alert "  Profile com WebContentFilter (proxy): $FULL"; CFG_HITS=$((CFG_HITS+1)); }
                [ -n "$PT_DNS" ]      && { alert "  Profile com DNS/Relay custom: $FULL"; CFG_HITS=$((CFG_HITS+1)); }
                [ -n "$PT_MDM" ]      && { warn  "  Profile com MDM (controle remoto): $FULL"; }

                # v4.4.52: detect específico de famílias de cheat DNS conhecidas via
                # PayloadIdentifier (não só PayloadType genérico). Atribui NOME do cheat.
                KHOIN_HIT=$(echo "$CONTENT" | grep -iE 'khoindvn|khoind\.app|com\.khoindvn\.apple-dns' | head -n 1)
                if [ -n "$KHOIN_HIT" ]; then
                    alert "  Profile KHOINDVN (DNS proxy FF iOS) em $FULL"
                    alert "    └─ Identifier: $(echo "$KHOIN_HIT" | head -c 200)"
                    CFG_HITS=$((CFG_HITS+1))
                fi
                # Pattern <vendor>.apple-dns.<UUID> — vetor genérico de DNS sequester
                APPLE_DNS_PROFILE=$(echo "$CONTENT" | grep -iE '[a-z0-9_-]+\.apple-dns\.[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -n 1)
                if [ -n "$APPLE_DNS_PROFILE" ] && [ -z "$KHOIN_HIT" ]; then
                    alert "  Profile com identifier '<vendor>.apple-dns.<UUID>' (DNS sequester) em $FULL"
                    alert "    └─ $(echo "$APPLE_DNS_PROFILE" | head -c 200)"
                    CFG_HITS=$((CFG_HITS+1))
                fi
                # Hashes específicos do threat intel da print (4-char prefixes)
                for HASH_PREFIX in "0af71eab" "60a5560f" "90eb5f87" "bd32d3a8"; do
                    if echo "$CONTENT" | grep -qiE "$HASH_PREFIX[a-f0-9]{56}"; then
                        alert "  Profile com hash conhecido de THREAT INTEL ($HASH_PREFIX...): $FULL"
                        CFG_HITS=$((CFG_HITS+1))
                        break
                    fi
                done
                [ -n "$PT_RESTR" ]    && { alert "  Profile com RESTRICTIONS (applicationaccess/ScreenTime): $FULL"; CFG_HITS=$((CFG_HITS+1)); }
                [ -n "$PT_AIRPLAY" ]  && { warn  "  Profile com AirPlay policy: $FULL"; }
                [ -n "$PT_WIFI" ]     && { warn  "  Profile com Wi-Fi managed: $FULL"; }
                [ -n "$PT_CERT_PKCS" ] && [ -z "$PT_CA" ] && { warn  "  Profile com PKCS cert payload: $FULL"; }
                [ -n "$PT_ACTIVATION" ] && { warn  "  Profile com iTunes/Activation: $FULL"; }

                # Strings de cheat services no payload (TeamName/Organization)
                CHEAT_ORG=$(echo "$CONTENT" | grep -iE 'esign|feather|ksign|gbox|scarlet|trollstore|sideload|cheat|hack|aimbot|wallhack' | head -n 3)
                if [ -n "$CHEAT_ORG" ]; then
                    echo "$CHEAT_ORG" | while IFS= read -r L; do
                        [ -n "$L" ] && alert "  Profile contém string de cheat/sideload: $(echo "$L" | head -c 120)"
                    done
                    CFG_HITS=$((CFG_HITS+1))
                fi

                # Metadata útil
                META=$(echo "$CONTENT" | grep -iE 'PayloadDisplayName|PayloadIdentifier|PayloadOrganization|HostName|ProxyServer' | head -n 5)
                [ -n "$META" ] && echo "$META" | while IFS= read -r L; do
                    [ -n "$L" ] && info "    $(echo "$L" | head -c 140)"
                done
            fi
        fi
    done
done

# Profile truth (manifest mestre das profiles instaladas)
for PT in /private/var/mobile/Library/ConfigurationProfiles/ProfileTruth.plist \
          /private/var/mobile/Library/ConfigurationProfiles/PayloadManifest.plist; do
    [ -r "$PT" ] || continue
    info "Manifest: $PT"
    if have plutil; then
        plutil -p "$PT" 2>/dev/null | head -n 40 | while IFS= read -r L; do
            [ -n "$L" ] && info "  $(echo "$L" | head -c 160)"
        done
    fi
done

[ "$CFG_HITS" = "0" ] && ok "Sem profile com VPN/proxy/CA suspeito"

# ============================================================
#  iOS-3. SUBSTRATE / TWEAK FRAMEWORKS
# ============================================================
header "iOS - SUBSTRATE / TWEAKS"

TWK_HITS=0
for P in /Library/MobileSubstrate/MobileSubstrate.dylib \
         /Library/MobileSubstrate/DynamicLibraries \
         /usr/lib/libsubstrate.dylib /usr/lib/substitute-loader.dylib \
         /usr/lib/libsubstitute.dylib /usr/lib/libhooker.dylib \
         /usr/lib/libellekit.dylib /var/jb/usr/lib/libellekit.dylib \
         /Library/Frameworks/CydiaSubstrate.framework; do
    exists "$P" && { alert "Tweak framework: $P"; TWK_HITS=$((TWK_HITS+1)); }
done

# Tweaks instalados (.dylib em DynamicLibraries)
for TWKDIR in /Library/MobileSubstrate/DynamicLibraries \
              /var/jb/Library/MobileSubstrate/DynamicLibraries \
              /var/jb/usr/lib/TweakInject; do
    if [ -d "$TWKDIR" ]; then
        info "Tweaks em $TWKDIR:"
        ls "$TWKDIR" 2>/dev/null | grep -iE '\.(dylib|plist)$' | while IFS= read -r T; do
            [ -z "$T" ] && continue
            case "$T" in
                *cheat*|*hack*|*mod*|*aim*|*esp*|*wallhack*|*ff*|*freefire*|*macro*|*helper*|*menu*)
                    alert "Tweak suspeito: $TWKDIR/$T" ;;
                *) warn "Tweak: $TWKDIR/$T" ;;
            esac
        done
        TWK_HITS=$((TWK_HITS+1))
    fi
done

# Cycript (injector iOS clássico)
for P in /usr/bin/cycript /var/jb/usr/bin/cycript /usr/lib/libcycript.dylib; do
    exists "$P" && { alert "Cycript: $P"; TWK_HITS=$((TWK_HITS+1)); }
done

[ "$TWK_HITS" = "0" ] && ok "Sem tweak framework"

# ============================================================
#  iOS-3b. SUBSTRATE TWEAK FILTERS (quais tweaks miram o FREE FIRE)
# ============================================================
header "iOS - TWEAK FILTERS (que miram Free Fire)"

FILTER_HITS=0
# Tweaks .dylib têm .plist companion com Filter.Bundles array
# Se algum .plist filtra com.dts.freefireth ou similar → tweak alvo ao FF!
for TWKDIR in /Library/MobileSubstrate/DynamicLibraries \
              /var/jb/Library/MobileSubstrate/DynamicLibraries \
              /var/jb/usr/lib/TweakInject; do
    [ -d "$TWKDIR" ] || continue
    PLISTS=$(ls "$TWKDIR" 2>/dev/null | grep '\.plist$')
    [ -z "$PLISTS" ] && continue
    echo "$PLISTS" | while IFS= read -r PL; do
        [ -z "$PL" ] && continue
        FULL="$TWKDIR/$PL"
        # ler conteúdo (plist binário ou XML)
        CONTENT=""
        if have plutil; then
            CONTENT=$(plutil -p "$FULL" 2>/dev/null)
        fi
        [ -z "$CONTENT" ] && have strings && CONTENT=$(strings "$FULL" 2>/dev/null)
        [ -z "$CONTENT" ] && continue
        # Mira FF?
        FF_TARGET=$(echo "$CONTENT" | grep -iE 'com\.dts\.freefire|com\.garena\.freefire|com\.garena\.global\.freefire|com\.garena\.global\.ffmax')
        if [ -n "$FF_TARGET" ]; then
            DYLIB="${FULL%.plist}.dylib"
            alert "TWEAK MIRA FREE FIRE: $FULL"
            [ -f "$DYLIB" ] && alert "  → dylib: $DYLIB"
            FILTER_HITS=$((FILTER_HITS+1))
        fi
        # Também flag se .plist menciona qualquer string suspeita
        # v4.4.103: 'mod' cru → 'modmenu' (mesmo motivo dos sítios acima).
        SUSP=$(echo "$CONTENT" | grep -iE 'cheat|hack|aimbot|wallhack|esp|menu.*ff|ff.*menu|injection|modmenu')
        [ -n "$SUSP" ] && warn "  Tweak $PL com strings suspeitas (cheat/hack/etc)"
    done
done
[ "$FILTER_HITS" = "0" ] && ok "Nenhum tweak iOS mirando Free Fire"

# ============================================================
#  iOS-3c. LAUNCHD SERVICES (daemons/agents persistentes)
# ============================================================
header "iOS - LAUNCHD SERVICES"

LD_HITS=0
for LDDIR in /Library/LaunchDaemons /Library/LaunchAgents \
             /var/jb/Library/LaunchDaemons /var/jb/Library/LaunchAgents \
             /System/Library/LaunchDaemons; do
    [ -d "$LDDIR" ] || continue
    info "LaunchDir: $LDDIR"
    FILES=$(ls "$LDDIR" 2>/dev/null | grep '\.plist$' | head -n 50)
    [ -z "$FILES" ] && continue
    echo "$FILES" | while IFS= read -r F; do
        [ -z "$F" ] && continue
        # Filtra Apple/sistema legítimos
        case "$F" in
            com.apple.*) ;;
            *cheat*|*hack*|*mod*|*aim*|*esp*|*ff.*|*freefire*|*frida*|*injector*|*menu*)
                alert "Launch suspeito: $LDDIR/$F" ;;
            org.lsposed.*|org.coolstar.*|com.opa334.*|com.saurik.*|com.tigisoftware.*)
                warn "Launch JB/tweak: $LDDIR/$F" ;;
            *)
                # Check content for FF references
                if [ -r "$LDDIR/$F" ]; then
                    FF_REF=$(strings "$LDDIR/$F" 2>/dev/null | grep -iE 'freefire|dts\.freefire|cheat|hack' | head -n 1)
                    if [ -n "$FF_REF" ]; then
                        alert "Launch $F referencia FF/cheat: $(echo "$FF_REF" | head -c 100)"
                    else
                        info "  $F"
                    fi
                fi ;;
        esac
    done
    LD_HITS=$((LD_HITS+1))
done

# launchctl list (serviços ativos no momento)
if have launchctl; then
    # v4.4.103: 'mod' cru → 'modmenu' (labels de serviço podem ter 'mod' como substring
    # legítima, ex: com.apple.*.modeswitch; mesmo motivo dos sítios acima).
    ACTIVE=$(launchctl list 2>/dev/null | head -n 80 | grep -iE 'cheat|hack|modmenu|aim|esp|freefire|frida|injector|substrate' | head -n 15)
    if [ -n "$ACTIVE" ]; then
        echo "$ACTIVE" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Service ativo (launchctl): $(echo "$L" | head -c 160)"
        done
    fi
fi

[ "$LD_HITS" = "0" ] && ok "Sem launchd services suspeitos"

# ============================================================
#  iOS-4. FRIDA / LLDB / DEBUGGERS
# ============================================================
header "iOS - FRIDA / DEBUGGERS"

FIOS_HITS=0
# v4.4.32: removido /System/Library/PrivateFrameworks/DebugSymbols.framework — é
# framework PADRÃO do iOS/macOS pra symbolication de crashes, gerava FP em 100%
# dos devices. Frida real nunca instala em /System/Library/PrivateFrameworks.
for P in /usr/sbin/frida-server /var/jb/usr/sbin/frida-server \
         /var/jb/usr/bin/frida /usr/bin/frida \
         /usr/lib/frida /var/jb/usr/lib/frida \
         /var/jb/usr/sbin/frida-server-* \
         /var/mobile/frida-server /var/root/frida-server \
         /Library/Frameworks/FridaGadget.framework \
         /usr/lib/FridaGadget.dylib /var/jb/usr/lib/FridaGadget.dylib; do
    exists "$P" && { alert "Frida iOS: $P"; FIOS_HITS=$((FIOS_HITS+1)); }
done

# Frida processo
if have ps; then
    FRIDA_PROC=$(ps -A 2>/dev/null | grep -i frida | grep -v grep)
    [ -n "$FRIDA_PROC" ] && echo "$FRIDA_PROC" | head -n 3 | while IFS= read -r L; do
        [ -n "$L" ] && alert "Processo Frida: $L"
    done
fi

# Porta 27042 (Frida default)
if have netstat; then
    FP=$(netstat -an 2>/dev/null | grep -E ':27042|:27043')
    [ -n "$FP" ] && alert "Porta Frida em LISTEN: $FP"
fi

# LLDB / debugserver
# v4.4.32: /usr/bin/lldb vem com Xcode em macOS. Só conta como suspeito em iOS
# real (Xcode-paired debugger persistente, indicador de análise dinâmica).
for P in /Developer/usr/bin/debugserver /var/jb/usr/bin/debugserver \
         /var/jb/usr/bin/lldb; do
    exists "$P" && { warn "Debugger: $P"; FIOS_HITS=$((FIOS_HITS+1)); }
done
if [ "$IS_REAL_IOS" = "1" ]; then
    exists /usr/bin/lldb && { warn "Debugger (iOS real): /usr/bin/lldb"; FIOS_HITS=$((FIOS_HITS+1)); }
fi

[ "$FIOS_HITS" = "0" ] && ok "Sem Frida/debugger iOS"

# ============================================================
#  iOS-5. SIDELOAD / IPA NÃO-ASSINADAS (AltStore, Scarlet, etc.)
# ============================================================
header "iOS - SIDELOAD / IPA MODIFICADAS"

SL_HITS=0
for P in /Applications/AltStore.app /Applications/Scarlet.app \
         /Applications/Esign.app /Applications/AppCake.app \
         /Applications/iGameGod.app /Applications/iGameCheat.app \
         /Applications/ReProvision.app /Applications/Sideloadly.app \
         /Applications/Provenance.app /Applications/Asahi.app \
         /Applications/IPA-Library.app; do
    exists "$P" && { alert "Sideloader: $P"; SL_HITS=$((SL_HITS+1)); }
done

# iGameGod / GameGem (mem editors iOS)
for P in /Applications/iGameGod.app /Applications/GameGem.app \
         /Applications/iGameCheat.app /Applications/GamePlayer.app; do
    exists "$P" && { alert "Mem editor iOS: $P"; SL_HITS=$((SL_HITS+1)); }
done

# Listar apps em /var/containers/Bundle/Application (apps user)
if [ -d /var/containers/Bundle/Application ]; then
    APP_DIRS=$(find /var/containers/Bundle/Application -maxdepth 2 -name '*.app' -type d 2>/dev/null | head -n 50)
    if [ -n "$APP_DIRS" ]; then
        info "Apps em /var/containers/Bundle/Application: $(echo "$APP_DIRS" | wc -l)"
        echo "$APP_DIRS" | while IFS= read -r APD; do
            [ -z "$APD" ] && continue
            BN=$(basename "$APD" .app)
            case "$BN" in
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*FF*MOD*|*FFH4X*|*[Aa]imbot*|*[Hh]olograma*|*[Hh]ologram*|\
                *[Ee][Ss][Pp]*|*[Mm]enu*|*[Ii]njector*|*FreeFire*VIP*|\
                *FF*VIP*|*BLOODY*)
                    alert "App suspeito: $APD" ;;
            esac
        done
    fi
fi

[ "$SL_HITS" = "0" ] && ok "Sem sideloader/IPA suspeita visível"

# ============================================================
#  iOS-6. FREE FIRE iOS - INSTALAÇÃO + BUNDLE
# ============================================================
header "iOS - FREE FIRE INSTALAÇÃO"

FF_IOS_FOUND=0
for BID in $FF_IOS_BUNDLES; do
    # Procurar pelo bundle ID em todos os apps
    if [ -d /var/containers/Bundle/Application ]; then
        MATCH=$(find /var/containers/Bundle/Application -maxdepth 4 -name 'Info.plist' 2>/dev/null \
            | xargs grep -lE "<string>$BID</string>" 2>/dev/null | head -n 1)
        if [ -n "$MATCH" ]; then
            FF_IOS_FOUND=1
            APP_DIR=$(dirname "$MATCH")
            info "Bundle encontrado: $BID"
            info "  Path: $APP_DIR"
            # extrair info do plist
            if have plutil; then
                APP_VER=$(plutil -p "$MATCH" 2>/dev/null | grep -E 'CFBundleShortVersionString' | head -c 100)
                [ -n "$APP_VER" ] && info "  $APP_VER"
            fi
            # checar se app é assinado pela App Store
            EMBED_PROV="$APP_DIR/embedded.mobileprovision"
            if [ -f "$EMBED_PROV" ]; then
                if strings "$EMBED_PROV" 2>/dev/null | grep -qE 'AppleAppStoreUpdateConfiguration|ProductionIOS'; then
                    ok "  Assinatura: App Store (OFICIAL)"
                else
                    alert "  Assinatura NAO-AppStore (sideload/modded)"
                fi
            else
                alert "  embedded.mobileprovision AUSENTE (TrollStore/sideload sem assinatura)"
            fi

            # FAIRPLAY DRM — apps legítimos da App Store têm encriptação FairPlay
            # Mods/sideloads PERDEM o FairPlay segment do executável
            BINARY=$(plutil -p "$MATCH" 2>/dev/null | grep -m1 'CFBundleExecutable' | sed -E 's/.*=> "([^"]+)".*/\1/')
            [ -z "$BINARY" ] && BINARY=$(basename "$APP_DIR" .app)
            EXEC_PATH="$APP_DIR/$BINARY"
            if [ -f "$EXEC_PATH" ]; then
                if have otool; then
                    FAIRPLAY=$(otool -l "$EXEC_PATH" 2>/dev/null | grep -E 'LC_ENCRYPTION_INFO|cryptid' | head -n 2)
                    CRYPTID=$(echo "$FAIRPLAY" | grep -m1 cryptid | awk '{print $2}')
                    case "$CRYPTID" in
                        1) ok "  FairPlay DRM: ATIVO (cryptid=1, app oficial criptografada)" ;;
                        0) alert "  FairPlay DRM: REMOVIDO (cryptid=0, decriptado/modded)" ;;
                        "") warn "  FairPlay: indeterminado (sem otool ou binário stripped)" ;;
                    esac
                elif have strings; then
                    # fallback: procurar marker FairPlay no binário
                    HAS_FP=$(strings "$EXEC_PATH" 2>/dev/null | grep -c 'FairPlay')
                    [ "$HAS_FP" -gt 0 ] 2>/dev/null && info "  FairPlay strings presentes ($HAS_FP)" || warn "  Sem strings FairPlay (possível decrypt)"
                fi
            fi

            # _CodeSignature dir deve existir
            if [ -d "$APP_DIR/_CodeSignature" ]; then
                ok "  _CodeSignature/: presente"
            else
                alert "  _CodeSignature/ AUSENTE - app não assinado"
            fi

            # PlugIns/AppExtensions suspeitas (mods às vezes adicionam extension)
            if [ -d "$APP_DIR/PlugIns" ]; then
                PLUGINS=$(ls "$APP_DIR/PlugIns" 2>/dev/null)
                [ -n "$PLUGINS" ] && echo "$PLUGINS" | while IFS= read -r P; do
                    [ -n "$P" ] && warn "  PlugIn em FF.app: $P (verificar)"
                done
            fi
        fi
    fi
done

# Caça mais ampla: qualquer Info.plist com bundle ID contendo "freefire" mesmo se NÃO está na lista FF_IOS_BUNDLES
if [ -d /var/containers/Bundle/Application ]; then
    SUSP_FF=$(find /var/containers/Bundle/Application -maxdepth 4 -name 'Info.plist' 2>/dev/null \
        | xargs grep -lE 'freefire|ffmod|ffh4x|aimkill\.ff|esp\.ff' 2>/dev/null | head -n 10)
    if [ -n "$SUSP_FF" ]; then
        echo "$SUSP_FF" | while IFS= read -r M; do
            [ -z "$M" ] && continue
            BID=$(grep -A1 'CFBundleIdentifier' "$M" 2>/dev/null | tail -n1 | sed -E 's/.*<string>([^<]+)<.*/\1/')
            case "$BID" in
                com.dts.freefireth|com.dts.freefiremax|com.garena.freefire.br|com.garena.freefire.kr|com.garena.global.freefire|com.garena.global.ffmax) ;;
                *) alert "Bundle FF SUSPEITO (não-oficial): $BID (em $M)" ;;
            esac
        done
    fi
fi

[ "$FF_IOS_FOUND" = "0" ] && warn "Free Fire iOS não encontrado"

# ============================================================
#  iOS-6b. CHEAT BUNDLES iOS CONHECIDOS
# ============================================================
header "iOS - CHEAT BUNDLES CONHECIDOS"

CHEAT_BUNDLES_IOS="
com.khoindvn
com.khoindvn.apple-dns
com.khoindvn.dns
com.khoindvn.vpn
com.khoindvn.proxy
com.khoind.app
com.34306.espff
com.dts.freefireth.externalesp
com.quyhoang.fxy
com.phuc.aimlock
com.checkboxcus.hhn
com.hhnios.pubgvngatena
com.dts.freefirethack
com.dts.freefireth2
com.nextor.app
com.touchingapp.potatso
com.touchingapp.potatsolite
com.monite.proxyff
com.nssurge.inc.surge-ios
com.luo.quantumultx
group.com.luo.quantumult
com.shadowrocket.Shadowrocket
com.liguangming.Shadowrocket
com.github.shadowsocks
com.netease.trojan
com.hiddify.app
com.karing.app
com.metacubex.ClashX
com.ssrss.Ssrss
com.adguard.ios.AdguardPro
com.privateinternetaccess.ios
com.anonymousiphone.detoxme
com.futureland.vpnmaster
com.cloudflare.1dot1dot1dot1
com.Nord.VPN
com.expressvpn.ExpressVPN
com.protonvpn.ios
com.surfshark.vpnclient.ios
com.windscribe.vpn
com.celeritasdesign.GoodVPN
com.getlantern.lantern
com.psiphon3.PsiphonForIOS
com.v2box.ios
com.streisand.Streisand
com.limeVPN.LimeVPN
com.openVPN.OpenVPN-Connect
io.nextdns.NextDNS
com.opa334.TrollStore
com.opa334.TrollStoreHelper
com.opa334.trolldecrypt
com.opa334.trollfools
com.opa334.dopamine
xyz.palera1n.palera1n
com.electrateam.unc0ver
com.tihmstar.checkra1n
org.taurine.jailbreak
org.coolstar.odyssey
org.coolstar.sileo
xyz.willy.Zebra
com.cydia.Cydia
com.rileytestut.AltStore
com.altstore.altstoreclassic
com.sideloadly.sideloadly
com.apple.dt.Xcode
com.apple.Preferences.Developer
com.apple.developer
com.apple.TestFlight
developer.apple.wwdc-Release
com.limneos.adprivacy
com.jjcm.nomoread
com.esign.ios
com.esign.esign
app.esign.esign
com.esignapp.esign
io.esign.esign
kh.crysalis.feather
xn.crysalis.feather
com.crysalis.feather
io.feather.feather
app.feather.feather
com.ksign.app
io.ksign.ksign
app.ksign.ksign
com.ksign.ksign
pkr.appwhitelist.ksign
com.gbox.gbox
com.gboxapp.gbox
io.gbox.gbox
app.gbox.io
com.itools.gbox
com.usescarlet.scarlet
com.scarletapp.scarlet
com.scarletios.scarlet
com.appdb.appdb
com.tutuapp.tutuapp
com.appcake.appcake
com.appvalley.appvalley
com.buildstore.buildstore
com.ignition.ignition
com.signtools.signtools
io.itrustteam.itrust
io.appdb.appdb
com.iosgods.iosgods
com.gbox.pubg
live.cclerc.geranium
com.tigisoftware.Filza
com.tigisoftware.FilzaFree
com.ifunbox.ifunbox
app.ish.iSH
com.septudio.SSHClientLite
com.shpion.cleaner
"

CB_HITS=0
if [ -d /var/containers/Bundle/Application ]; then
    INSTALLED_BIDS=$(find /var/containers/Bundle/Application -maxdepth 4 -name 'Info.plist' 2>/dev/null \
        | xargs grep -hA1 'CFBundleIdentifier' 2>/dev/null \
        | grep -oE '<string>[^<]+</string>' | sed -E 's|</?string>||g' \
        | grep -E '^[a-z]+\.' | sort -u)
    for BID in $CHEAT_BUNDLES_IOS; do
        if echo "$INSTALLED_BIDS" | grep -q "^${BID}$"; then
            alert "Cheat bundle iOS: $BID"
            CB_HITS=$((CB_HITS+1))
        fi
    done
fi
[ "$CB_HITS" = "0" ] && ok "Sem cheat bundle iOS conhecido"

# ============================================================
#  iOS-6c. PROVISIONING PROFILES / CERTIFICATES
#         Cert sideloaders (Esign/Feather/Ksign/Gbox/Scarlet) deixam pegada
#         em /var/MobileDevice/ProvisioningProfiles/ + cada .app tem o seu
# ============================================================
header "iOS - PROVISIONING PROFILES / CERTIFICATES"

PROV_HITS=0

# 1) Diretórios de provisioning profiles (global - todos perfis instalados)
PROV_DIRS="
/var/MobileDevice/ProvisioningProfiles
/private/var/MobileDevice/ProvisioningProfiles
/var/installd/Library/MobileDevice/ProvisioningProfiles
/var/jb/var/MobileDevice/ProvisioningProfiles
"

for PD in $PROV_DIRS; do
    [ -d "$PD" ] || continue
    PROVS=$(ls "$PD" 2>/dev/null | grep '\.mobileprovision$')
    [ -z "$PROVS" ] && continue
    info "Profiles em $PD: $(echo "$PROVS" | wc -l)"
    echo "$PROVS" | while IFS= read -r PF; do
        [ -z "$PF" ] && continue
        FULL="$PD/$PF"
        # mobileprovision é CMS-encoded; usar 'security cms' ou strings
        CONTENT=""
        if have security; then
            CONTENT=$(security cms -D -i "$FULL" 2>/dev/null)
        fi
        [ -z "$CONTENT" ] && have strings && CONTENT=$(strings "$FULL" 2>/dev/null)
        [ -z "$CONTENT" ] && continue
        # Team Name e Team ID
        TEAM_NAME=$(echo "$CONTENT" | grep -A1 -i 'TeamName' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
        TEAM_ID=$(echo "$CONTENT" | grep -A1 -i 'TeamIdentifier' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
        APP_ID=$(echo "$CONTENT" | grep -A1 -i 'application-identifier' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
        # ProvisionsAllDevices (true = enterprise cert)
        ENTERPRISE=$(echo "$CONTENT" | grep -i 'ProvisionsAllDevices' | head -n 1)
        # IsXcodeManaged
        XCODE=$(echo "$CONTENT" | grep -i 'IsXcodeManaged' | head -n 1)

        info "  $PF"
        [ -n "$TEAM_NAME" ] && info "    Team: $TEAM_NAME ($TEAM_ID)"
        [ -n "$APP_ID" ]    && info "    App: $APP_ID"
        [ -n "$ENTERPRISE" ] && warn "    ENTERPRISE certificate (ProvisionsAllDevices)"

        # Team ID conhecidos legítimos
        case "$TEAM_ID" in
            "H99WFFB59J") ok "    Team Garena (oficial Free Fire)" ;;
            "")           warn "    Team ID ausente" ;;
            *)
                # Procurar team names suspeitos
                case "$(echo "$TEAM_NAME" | tr '[:upper:]' '[:lower:]')" in
                    *esign*|*feather*|*ksign*|*gbox*|*scarlet*|*sideload*|*trollstore*|*altstore*|*signtools*|*ignition*|*appcake*|*appdb*|*tutuapp*|*panda*|*iosgods*)
                        alert "    Cert de SIDELOAD SERVICE detectado: $TEAM_NAME" ;;
                esac ;;
        esac
        # Strings cheat no payload
        CHEAT_STR=$(echo "$CONTENT" | grep -iE 'cheat|hack|aimbot|wallhack|ffh4x|mod\.menu|injector|cracked' | head -n 1)
        [ -n "$CHEAT_STR" ] && alert "    Profile contém string suspeita: $(echo "$CHEAT_STR" | head -c 100)"
    done
    PROV_HITS=$((PROV_HITS+1))
done

# 2) Cada .app instalada tem seu próprio embedded.mobileprovision — listar e checar Team ID
if [ -d /var/containers/Bundle/Application ]; then
    EMBED=$(find /var/containers/Bundle/Application -maxdepth 4 -name 'embedded.mobileprovision' 2>/dev/null | head -n 40)
    if [ -n "$EMBED" ]; then
        info "Embedded provisioning profiles (por app instalado):"
        echo "$EMBED" | while IFS= read -r EP; do
            [ -z "$EP" ] && continue
            APP_DIR=$(dirname "$EP")
            APP_NAME=$(basename "$APP_DIR" .app)
            CONTENT=""
            if have security; then
                CONTENT=$(security cms -D -i "$EP" 2>/dev/null)
            fi
            [ -z "$CONTENT" ] && have strings && CONTENT=$(strings "$EP" 2>/dev/null)
            TEAM_NAME=$(echo "$CONTENT" | grep -A1 -i 'TeamName' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
            TEAM_ID=$(echo "$CONTENT" | grep -A1 -i 'TeamIdentifier' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
            case "$TEAM_ID" in
                "H99WFFB59J") info "  $APP_NAME: $TEAM_NAME ($TEAM_ID) [Garena]" ;;
                "")           warn "  $APP_NAME: Team ID ausente (TrollStore/sem assinatura)" ;;
                *)
                    # Filtrar grandes legítimos (Google, Microsoft, etc.)
                    case "$(echo "$TEAM_NAME" | tr '[:upper:]' '[:lower:]')" in
                        *apple*|*google*|*microsoft*|*meta*|*facebook*|*samsung*|\
                        *spotify*|*adobe*|*amazon*|*netflix*|*disney*|*twitter*|\
                        *whatsapp*|*tencent*|*supercell*|*riot*|*epic*|*activision*)
                            info "  $APP_NAME: $TEAM_NAME ($TEAM_ID)" ;;
                        *esign*|*feather*|*ksign*|*gbox*|*scarlet*|*sideload*|*trollstore*|*altstore*|*signtools*|*ignition*|*appcake*|*appdb*|*tutuapp*|*panda*|*iosgods*)
                            alert "  $APP_NAME: cert de SIDELOAD = $TEAM_NAME ($TEAM_ID)" ;;
                        *)
                            warn "  $APP_NAME: cert 3rd-party = $TEAM_NAME ($TEAM_ID)" ;;
                    esac ;;
            esac
        done
        PROV_HITS=$((PROV_HITS+1))
    fi
fi

# 3) Free Fire especificamente: pegar Team ID dele e comparar com Garena oficial
if [ -d /var/containers/Bundle/Application ]; then
    FF_BIDS_LIST=" com.dts.freefireth com.dts.freefiremax com.garena.global.freefire com.garena.global.ffmax com.garena.freefire.br com.garena.freefire.kr "
    EMBEDS=$(find /var/containers/Bundle/Application -maxdepth 4 -name 'embedded.mobileprovision' 2>/dev/null)
    for EP in $EMBEDS; do
        [ -f "$EP" ] || continue
        APP_DIR=$(dirname "$EP")
        INFO="$APP_DIR/Info.plist"
        [ -f "$INFO" ] || continue
        BID=$(grep -A1 'CFBundleIdentifier' "$INFO" 2>/dev/null | tail -n1 | sed -E 's/.*<string>([^<]+)<.*/\1/')
        # checar se BID é Free Fire oficial
        IS_FF=0
        case "$FF_BIDS_LIST" in
            *" $BID "*) IS_FF=1 ;;
        esac
        [ "$IS_FF" = "0" ] && continue
        info "Free Fire ($BID) cert:"
        CONTENT=""
        if have security; then
            CONTENT=$(security cms -D -i "$EP" 2>/dev/null)
        fi
        [ -z "$CONTENT" ] && have strings && CONTENT=$(strings "$EP" 2>/dev/null)
        TEAM_NAME=$(echo "$CONTENT" | grep -A1 -i 'TeamName' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
        TEAM_ID=$(echo "$CONTENT" | grep -A1 -i 'TeamIdentifier' | grep -oE '<string>[^<]+</string>' | head -n1 | sed 's|</?string>||g')
        info "  Team: $TEAM_NAME ($TEAM_ID)"
        if [ "$TEAM_ID" = "H99WFFB59J" ]; then
            ok "  Free Fire assinado por GARENA OFICIAL"
        else
            alert "  Free Fire assinado por OUTRO team ($TEAM_NAME) - sideload/re-sign confirmado"
            PROV_HITS=$((PROV_HITS+1))
        fi
    done
fi

[ "$PROV_HITS" = "0" ] && ok "Sem provisioning profile suspeito"

# ============================================================
#  iOS-7. PROCESSOS SUSPEITOS
# ============================================================
header "iOS - PROCESSOS"

if have ps; then
    # v4.4.32: clean_procs + patterns mais específicos. Antes o `grep -i hack`
    # pegava qualquer linha do argv do scanner que tivesse "hack" como string.
    PROCS=$(ps -A 2>/dev/null | clean_procs)
    for PAT in frida-server frida-agent substrated cycript debugserver \
               igamegod gamegem trollstored scarletd \
               cheatengine ffcheat ffmod aimbot.daemon; do
        HIT=$(echo "$PROCS" | tok_grep "$PAT" | grep -v grep)
        [ -n "$HIT" ] && echo "$HIT" | head -n 2 | while IFS= read -r L; do
            [ -n "$L" ] && alert "Processo ($PAT): $L"
        done
    done
fi

# ============================================================
#  iOS-8. HWID (UDID-like)
# ============================================================
header "iOS - HWID"

UDID=""
SERIAL=""
if have ioreg; then
    UDID=$(ioreg -d2 -c IOPlatformExpertDevice 2>/dev/null | grep -i 'IOPlatformUUID' | awk -F'"' '{print $4}')
    SERIAL=$(ioreg -d2 -c IOPlatformExpertDevice 2>/dev/null | grep -i 'IOPlatformSerialNumber' | awk -F'"' '{print $4}')
fi

RAW="${UDID}|${SERIAL}|${IOS_MODEL}|${IOS_VERSION}"
HASH=""
if have sha256sum; then
    HASH=$(printf '%s' "$RAW" | sha256sum 2>/dev/null | awk '{print $1}')
elif have shasum; then
    HASH=$(printf '%s' "$RAW" | shasum -a 256 2>/dev/null | awk '{print $1}')
fi

info "UDID:    ${UDID:-?}"
info "Serial:  ${SERIAL:-?}"
info "HWID:    ${HASH:-(indisponível)}"

# ============================================================
#  iOS-9. CRASHES (Free Fire + Câmera + Fotos)  v4.4.32
#  ~/Library/Logs/CrashReporter/ + DiagnosticReports/ — analisar tombstone-like
#  reports do iOS. Crash do FF com lib não-oficial = cheat instável.
# ============================================================
header "iOS - CRASHES (Free Fire + Câmera + Fotos)"

_IOS_CRASH_H0=$(_hits_count)   # v4.4.98: baseline p/ linha-limpo honesta (tudo em subshell)
FF_IOS_BUNDLES_LOCAL="$FF_IOS_BUNDLES"
CAM_IOS_BUNDLES="com.apple.camera com.apple.CameraKit"
GAL_IOS_BUNDLES="com.apple.mobileslideshow com.apple.Photos"

CRASH_DIRS="
/var/mobile/Library/Logs/CrashReporter
/var/mobile/Library/Logs/CrashReporter/MobileDevice
/private/var/mobile/Library/Logs/CrashReporter
/private/var/mobile/Library/Logs/CrashReporter/MobileDevice
/Library/Logs/CrashReporter
/var/mobile/Library/Logs/DiagnosticReports
/private/var/mobile/Library/Logs/DiagnosticReports
"

for CDIR in $CRASH_DIRS; do
    [ -d "$CDIR" ] || continue
    info "Crash dir: $CDIR"
    # Lista até 30 mais recentes (.ips ou .crash ou .panic)
    RECENT=$(ls -t "$CDIR" 2>/dev/null | head -30)
    [ -z "$RECENT" ] && continue
    echo "$RECENT" | while IFS= read -r F; do
        [ -z "$F" ] && continue
        FULL="$CDIR/$F"
        # FF crashes
        for BID in $FF_IOS_BUNDLES_LOCAL; do
            case "$F" in
                *${BID}*|*FreeFire*|*Garena*)
                    FMT=$(stat -c '%y' "$FULL" 2>/dev/null || stat -f '%Sm' "$FULL" 2>/dev/null)
                    alert "[FF] Crash: $FULL ($FMT)"
                    # extrai bug class + termination + libs envolvidas
                    if [ -r "$FULL" ]; then
                        BUG=$(grep -m1 -iE 'Bug ?Type|Exception Type|Termination' "$FULL" 2>/dev/null | head -c 200)
                        [ -n "$BUG" ] && info "    $BUG"
                        LIBS=$(grep -iE 'libsubstrate|libsubstitute|libellekit|libhooker|libfrida|FridaGadget|MobileSubstrate' "$FULL" 2>/dev/null | head -3)
                        [ -n "$LIBS" ] && echo "$LIBS" | while IFS= read -r L; do
                            [ -n "$L" ] && alert "    lib cheat: $(echo "$L" | head -c 140)"
                        done
                    fi
                    ;;
            esac
        done
        # Câmera
        for BID in $CAM_IOS_BUNDLES; do
            case "$F" in
                *${BID}*|*Camera*|*camera*)
                    FMT=$(stat -c '%y' "$FULL" 2>/dev/null || stat -f '%Sm' "$FULL" 2>/dev/null)
                    warn "[CAMERA] Crash: $FULL ($FMT)"
                    ;;
            esac
        done
        # Fotos
        for BID in $GAL_IOS_BUNDLES; do
            case "$F" in
                *${BID}*|*MobileSlideShow*|*Photos*)
                    FMT=$(stat -c '%y' "$FULL" 2>/dev/null || stat -f '%Sm' "$FULL" 2>/dev/null)
                    warn "[FOTOS] Crash: $FULL ($FMT)"
                    ;;
            esac
        done
        # Panics do kernel (sinaliza tweak ruim ou kext custom)
        case "$F" in
            *panic*|*kernel*)
                FMT=$(stat -c '%y' "$FULL" 2>/dev/null || stat -f '%Sm' "$FULL" 2>/dev/null)
                alert "Kernel panic: $FULL ($FMT) — possível tweak instável"
                ;;
        esac
    done
done

if [ "$(_hits_count)" = "$_IOS_CRASH_H0" ]; then
    ok "Sem crashes de FF/Câmera/Fotos encontrados nos paths analisáveis"
    info "Pra extrair logs sem JB use bugreport sysdiagnose:"
    info "  iPhone: pressionar Vol+ Vol- Side ~1s. Diagnóstico vai pra Privacidade → Analytics"
    info "  Coletar via Mac com Apple Configurator 2 ou: idevicesyslog (via USB)"
fi

fi  # ===== fim do bloco iOS =====

# ============================================================
#  RESUMO
# ============================================================
header "RESUMO"
# v4.4.88: contagem REAL a partir dos acumuladores (os contadores ALERTS/WARNINGS
# são incrementados dentro de subshells `... | while` e por isso subnotificam).
_NA=$(grep -c . "$A4_CRIT_FILE" 2>/dev/null); case "$_NA" in ''|*[!0-9]*) _NA=0 ;; esac
_NW=$(grep -c . "$A4_WARN_FILE" 2>/dev/null); case "$_NW" in ''|*[!0-9]*) _NW=0 ;; esac
[ "$_NA" -gt "$ALERTS" ]   2>/dev/null && ALERTS=$_NA
[ "$_NW" -gt "$WARNINGS" ] 2>/dev/null && WARNINGS=$_NW

show ""
show "    ${CR}●${CN}  Alertas: ${CW}${CR}${ALERTS}${CN}"
show "    ${CY}●${CN}  Avisos:  ${CW}${CY}${WARNINGS}${CN}"
show "    ${CG}●${CN}  OKs:     ${CW}${CG}${CLEAN}${CN}"
show ""

# v4.4.88: PAINEL FINAL — lista críticos/suspeitos na TELA, UMA vez (screen-only:
# em modo verboso/ADB fica suprimido pra não duplicar nem poluir o arquivo de
# upload — lá o wrapper renderiza o painel dele).
if [ "$ALERTS" -gt 0 ]; then
    screen "  ${CR}${CW}CRÍTICOS (${ALERTS}):${CN}"
    while IFS= read -r _l; do [ -n "$_l" ] && screen "    ${CR}✗${CN} $_l"; done < "$A4_CRIT_FILE"
    screen ""
fi
if [ "$WARNINGS" -gt 0 ]; then
    screen "  ${CY}${CW}SUSPEITOS (${WARNINGS}):${CN}"
    while IFS= read -r _l; do [ -n "$_l" ] && screen "    ${CY}•${CN} $_l"; done < "$A4_WARN_FILE"
    screen ""
fi

if [ "$ALERTS" -gt 0 ]; then
    show ""
    show "${CR}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    show ""
    show "${CR}${CW}         ✗   S U S P E I T O   ▪   ${ALERTS} alertas${CN}"
    show ""
    show "${CR}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    RC=2
elif [ "$WARNINGS" -gt 0 ]; then
    show ""
    show "${CY}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    show ""
    show "${CY}${CW}         ⚠   R E V I S A R   ▪   ${WARNINGS} avisos${CN}"
    show ""
    show "${CY}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    RC=1
else
    show ""
    show "${CG}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    show ""
    show "${CG}${CW}         ✓   L I M P O   ▪   device aprovado${CN}"
    show ""
    show "${CG}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    RC=0
fi
show ""
show "  ${CC}›${CN} Relatório salvo em: ${CW}$REPORT${CN}"
show ""

# ============================================================
#  COLETA DE DUMP COMPLETO (estilo KellerDump — 62+ arquivos raw)
#  Gera tar.gz com TODOS os logs/dumpsys/settings pra reanálise
# ============================================================
if [ "$REPORT" != "/dev/null" ]; then
    REPORT_DIR=$(dirname "$REPORT")
    DUMP_DIR="$REPORT_DIR/a4ther_dump_${TS}"
    DUMP_TAR="$REPORT_DIR/a4ther_dump_${TS}.tar.gz"

    if mkdir -p "$DUMP_DIR" 2>/dev/null; then
        show "${CC}›${CN} Coletando dump completo (logs+dumpsys+settings)…"

        # ─ Device info + sistema ─
        cat > "$DUMP_DIR/device_info.txt" <<EOF
versao_android:$(getprop ro.build.version.release 2>/dev/null)
sdk:$(getprop ro.build.version.sdk 2>/dev/null)
modelo:$(getprop ro.product.model 2>/dev/null)
fabricante:$(getprop ro.product.brand 2>/dev/null)
device:$(getprop ro.product.device 2>/dev/null)
serial:$(getprop ro.serialno 2>/dev/null || getprop ro.boot.serialno 2>/dev/null)
hwid:$(settings get secure android_id 2>/dev/null)
fingerprint:$(getprop ro.build.fingerprint 2>/dev/null)
build_date:$(getprop ro.build.date 2>/dev/null)
hardware:$(getprop ro.hardware 2>/dev/null)
cpu_abi:$(getprop ro.product.cpu.abi 2>/dev/null)
cpu_abilist:$(getprop ro.product.cpu.abilist 2>/dev/null)
EOF
        # Integridade props (root/bootloader detection)
        cat > "$DUMP_DIR/integridade_props.txt" <<EOF
fingerprint:$(getprop ro.build.fingerprint 2>/dev/null)
tags:$(getprop ro.build.tags 2>/dev/null)
debuggable:$(getprop ro.debuggable 2>/dev/null)
secure:$(getprop ro.secure 2>/dev/null)
verifiedbootstate:$(getprop ro.boot.verifiedbootstate 2>/dev/null)
veritymode:$(getprop ro.boot.veritymode 2>/dev/null)
flash_locked:$(getprop ro.boot.flash.locked 2>/dev/null)
warranty_bit:$(getprop ro.boot.warranty_bit 2>/dev/null)
vbmeta_device_state:$(getprop ro.boot.vbmeta.device_state 2>/dev/null)
avb_version:$(getprop ro.boot.avb_version 2>/dev/null)
service_adb_root:$(getprop service.adb.root 2>/dev/null)
bootmode:$(getprop ro.bootmode 2>/dev/null)
cpu_abi:$(getprop ro.product.cpu.abi 2>/dev/null)
cpu_abilist:$(getprop ro.product.cpu.abilist 2>/dev/null)
hardware:$(getprop ro.hardware 2>/dev/null)
EOF
        # Properties completas
        getprop > "$DUMP_DIR/propriedades.txt" 2>/dev/null

        # ─ /proc snapshots ─
        cat /proc/cpuinfo  > "$DUMP_DIR/cpuinfo.txt"  2>/dev/null
        cat /proc/meminfo  > "$DUMP_DIR/meminfo.txt"  2>/dev/null
        cat /proc/mounts   > "$DUMP_DIR/mounts.txt"   2>/dev/null
        cat /proc/loadavg  > "$DUMP_DIR/loadavg.txt"  2>/dev/null
        cat /proc/version  > "$DUMP_DIR/kernel.txt"   2>/dev/null
        uptime             > "$DUMP_DIR/uptime.txt"   2>/dev/null
        date               > "$DUMP_DIR/data_hora.txt" 2>/dev/null
        df -h              > "$DUMP_DIR/disco.txt"    2>/dev/null
        free -h 2>/dev/null > "$DUMP_DIR/memoria.txt"
        top -n 1 -b 2>/dev/null > "$DUMP_DIR/top.txt"
        ps -A              > "$DUMP_DIR/processos.txt" 2>/dev/null

        # ─ SELinux ─
        getenforce > "$DUMP_DIR/selinux.txt" 2>/dev/null
        ls -lZ /system/bin/su 2>/dev/null > "$DUMP_DIR/selinux_root.txt"

        # ─ Network (proxy/dns/route) ─
        ip addr               > "$DUMP_DIR/ip.txt"           2>/dev/null
        ip route              > "$DUMP_DIR/route.txt"        2>/dev/null
        netstat -an 2>/dev/null > "$DUMP_DIR/netstat.txt"
        cat /proc/net/tcp     >  "$DUMP_DIR/netstat.txt"     2>/dev/null
        cat /proc/net/tcp6    >> "$DUMP_DIR/netstat.txt"     2>/dev/null
        cat > "$DUMP_DIR/http_proxy.txt" <<EOF
global.http_proxy:$(settings get global http_proxy 2>/dev/null)
global.global_http_proxy_host:$(settings get global global_http_proxy_host 2>/dev/null)
global.global_http_proxy_port:$(settings get global global_http_proxy_port 2>/dev/null)
global.global_http_proxy_pac_url:$(settings get global global_http_proxy_pac_url 2>/dev/null)
global.private_dns_mode:$(settings get global private_dns_mode 2>/dev/null)
global.private_dns_specifier:$(settings get global private_dns_specifier 2>/dev/null)
EOF

        # ─ Settings (3 namespaces) ─
        settings list global > "$DUMP_DIR/settings_global.txt" 2>/dev/null
        settings list secure > "$DUMP_DIR/settings_secure.txt" 2>/dev/null
        settings list system > "$DUMP_DIR/settings_system.txt" 2>/dev/null

        # ─ Accessibility (overlay/macro) ─
        settings get secure enabled_accessibility_services > "$DUMP_DIR/enabled_accessibility_services.txt" 2>/dev/null
        settings get secure accessibility_enabled > "$DUMP_DIR/accessibility_enabled.txt" 2>/dev/null

        # ─ Kernel ring buffer (dmesg) ─
        dmesg 2>/dev/null > "$DUMP_DIR/dmesg.txt"

        # ─ Packages ─
        pm list packages -f 2>/dev/null > "$DUMP_DIR/pacotes_com_caminho.txt"
        pm list packages    2>/dev/null > "$DUMP_DIR/pacotes.txt"

        # ─ Logcat (4 buffers + crash) ─
        logcat -d -b main   -t 10000 2>/dev/null > "$DUMP_DIR/logcat_main.txt"
        logcat -d -b system -t 10000 2>/dev/null > "$DUMP_DIR/logcat_system.txt"
        logcat -d -b events -t 5000  2>/dev/null > "$DUMP_DIR/logcat_events.txt"
        logcat -d -b radio  -t 5000  2>/dev/null > "$DUMP_DIR/logcat_radio.txt"
        logcat -d -b crash           2>/dev/null > "$DUMP_DIR/logcat_crash.txt"
        logcat -d -v threadtime -t 5000 2>/dev/null > "$DUMP_DIR/logcat_all_threadtime_tail.txt"

        # ─ Dumpsys (18 serviços + FF específico) ─
        for SVC in activity alarm appops audio battery batterystats connectivity \
                   cpuinfo diskstats display input jobscheduler location meminfo \
                   netstats notification package power procstats usb wifi window; do
            dumpsys "$SVC" 2>/dev/null > "$DUMP_DIR/dumpsys_${SVC}.txt"
        done
        # FF específico
        dumpsys package com.dts.freefireth 2>/dev/null > "$DUMP_DIR/dumpsys_package_freefireth.txt"
        dumpsys package com.dts.freefiremax 2>/dev/null > "$DUMP_DIR/dumpsys_package_freefiremax.txt"

        # ─ Overlays (ESP detection dedicado) ─
        dumpsys window windows 2>/dev/null | grep -E 'Window #|mOwnerUid|mPackage|TYPE_(APPLICATION_OVERLAY|PHONE|SYSTEM_ALERT)' > "$DUMP_DIR/overlays_dumpsys.txt"
        dumpsys appops 2>/dev/null | grep -B5 'SYSTEM_ALERT_WINDOW: allow' > "$DUMP_DIR/overlays_cmd.txt"

        # ─ Usage stats (sequence apps abertos) ─
        dumpsys usagestats 2>/dev/null | head -2000 > "$DUMP_DIR/usagestats_tail.txt"

        # ─ Resumo ─
        cat > "$DUMP_DIR/resumo.txt" <<EOF
=== A4THER DUMP RESUMO ===
Coletado em: $(date)
Dispositivo: $(getprop ro.product.brand) $(getprop ro.product.model)
Android: $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk))
Kernel: $(uname -a 2>/dev/null)
SELinux: $(getenforce 2>/dev/null)
Uptime:  $(uptime 2>/dev/null)
Veredito do scan: ${RC} (0=LIMPO 1=REVISAR 2=W.O)
Alertas: ${ALERTS} · Avisos: ${WARNINGS}
EOF

        # Inclui o próprio relatório TXT no dump (forensics: análise + raw juntos)
        cp "$REPORT" "$DUMP_DIR/a4ther_relatorio.txt" 2>/dev/null

        # ─ Pack em tar.gz ─
        cd "$REPORT_DIR" 2>/dev/null && \
            tar -czf "$DUMP_TAR" "$(basename "$DUMP_DIR")" 2>/dev/null && \
            rm -rf "$DUMP_DIR" 2>/dev/null
        if [ -f "$DUMP_TAR" ]; then
            DUMP_SIZE=$(du -h "$DUMP_TAR" 2>/dev/null | awk '{print $1}')
            DUMP_COUNT=$(tar -tzf "$DUMP_TAR" 2>/dev/null | wc -l)
            show "  ${CG}›${CN} Dump completo: ${CW}$DUMP_TAR${CN} (${DUMP_SIZE}, $DUMP_COUNT arquivos)"
            show "  ${CC}›${CN} Pra enviar pro analista:"
            show "      ${CW}cp \"$DUMP_TAR\" /sdcard/Download/${CN}"
            show "      depois abra Files no Android → /sdcard/Download/ → compartilhar"
        else
            show "  ${CY}›${CN} Dump tar.gz falhou (sem espaço/permissão?), pasta: $DUMP_DIR"
        fi
    fi
fi

# ============================================================
#  v4.4.86: análise profunda movida pro verificador web (BugReport nativo).
#  Instruções verbosas de pareamento WiFi/bugreport REMOVIDAS — usuário já em ADB.
# ============================================================
if [ "$PLATFORM" = "android" ]; then
    emit ""
    emit "[INFO] Para análise profunda de sistema e rede, gere um BugReport nativo no Android e envie o .zip para o verificador web."
fi

# ─── v4.4.2: FINAL — onde achar o .txt + auto-copy pra Downloads ─────────────
# Mostra o caminho com tamanho real do .txt, e tenta copiar pro /sdcard/Download/
# (gerenciador de arquivos do Android) pra o user não precisar abrir o Termux.
show ""
if [ "$REPORT" != "/dev/null" ] && [ -f "$REPORT" ]; then
    REPORT_SIZE=$(du -h "$REPORT" 2>/dev/null | awk '{print $1}')
    REPORT_LINES=$(wc -l < "$REPORT" 2>/dev/null | tr -d ' ')
    show "${CB}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    show "${CG}  ✓ Relatório salvo (perícia profunda):${CN}"
    show "    ${CW}$REPORT${CN}"
    show "    ${CC}(${REPORT_SIZE:-?}, ${REPORT_LINES:-?} linhas)${CN}"

    # Tenta copiar pra Downloads (acessível pelo gerenciador de arquivos)
    COPIED=""
    for DL in /sdcard/Download /storage/emulated/0/Download; do
        if [ -d "$DL" ] && [ -w "$DL" ]; then
            if cp "$REPORT" "$DL/a4ther_scan_${TS}.txt" 2>/dev/null; then
                COPIED="$DL/a4ther_scan_${TS}.txt"
                break
            fi
        fi
    done
    if [ -n "$COPIED" ]; then
        show ""
        show "${CG}  ✓ Cópia em Downloads (gerenciador de arquivos):${CN}"
        show "    ${CW}$COPIED${CN}"
        show "    ${CC}Abra o app Arquivos → Downloads → a4ther_scan_${TS}.txt${CN}"
    else
        show ""
        show "${CY}  !${CN} Não consegui copiar pra Downloads. Pra mandar pro analista:"
        show "    ${CW}cp \"$REPORT\" /sdcard/Download/${CN}"
        show "    (se falhar: ${CW}termux-setup-storage${CN} antes)"
    fi
    show "${CB}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
else
    show "${CR}  ✗ Relatório NÃO foi gerado (REPORT=$REPORT).${CN}"
    show "${CY}  ›${CN} Provável causa: sem permissão de armazenamento no Termux."
    show "${CY}  ›${CN} Solução: ${CW}termux-setup-storage${CN} + rodar de novo."
fi

show ""
exit "$RC"
