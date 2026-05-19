#!/system/bin/sh
# ============================================================
#  A4ther Systems v3.4.0 | LS Aluguel
#  Anti-Cheat Scanner para Free Fire (Android + iOS auto-detect).
#  Verifica:
#   - Plataforma (Android via Termux ou iOS via SSH em device jailbroken)
#   - Free Fire / Free Fire Max instalados via Play Store / App Store oficial
#   - Cheats: root/jailbreak, frida, mods, tweaks, etc.
#
#  Síntese de detecções de:
#   - KellerSS-Android (binário Go)            [kellerzz/KellerSS-Android]
#   - CardozoSS / OlhosDoCapeta (binário Go)   [CardozoServer/OlhosDoCapeta-Android]
#   - TiziXit-AntiCheat (bash 2364 linhas)     [Streakxit/TiziXit-AntiCheat]
#   - thxrlk00/Scanner KellerSS.php (PHP 2198) [thxrlk00/Scanner]
#   - thzzSS/scanner-brevent (thz.sh)          [thzzSS/scanner-brevent]
#   - ZackSS (bash)                            [zacksevenSS/ZackSS]
#   + 12 forks/variantes analisados
#
#  Uso no Termux:
#     pkg install -y curl
#     curl -L -o FFScanner.sh <URL_RAW>
#     chmod +x FFScanner.sh && sh FFScanner.sh
# ============================================================

VERSION="3.8.0"

# ---------- Cores (NÃO usar R G Y B C W N como vars de loop!) ----------
if [ -t 1 ]; then
    CR=$(printf '\033[1;31m'); CG=$(printf '\033[1;32m'); CY=$(printf '\033[1;33m')
    CB=$(printf '\033[1;34m'); CC=$(printf '\033[1;36m'); CW=$(printf '\033[1m')
    CN=$(printf '\033[0m')
else
    CR=''; CG=''; CY=''; CB=''; CC=''; CW=''; CN=''
fi

# ---------- Relatório ----------
TS=$(date '+%Y%m%d_%H%M%S' 2>/dev/null)
[ -z "$TS" ] && TS="scan"
REPORT=""
for D in "$HOME" /sdcard /storage/emulated/0 /data/local/tmp /tmp .; do
    [ -d "$D" ] && [ -w "$D" ] || continue
    if mkdir -p "$D/FFScanner_reports" 2>/dev/null; then
        REPORT="$D/FFScanner_reports/scan_${TS}.txt"
        : > "$REPORT" 2>/dev/null && break
        REPORT=""
    fi
done
[ -z "$REPORT" ] && REPORT="/dev/null"

ALERTS=0
WARNINGS=0
CLEAN=0

strip_color() { sed -E 's/\x1B\[[0-9;]*[mK]//g' 2>/dev/null; }
emit() {
    printf '%s\n' "$*"
    if [ "$REPORT" != "/dev/null" ]; then
        printf '%s\n' "$*" | strip_color >> "$REPORT" 2>/dev/null
    fi
}
alert()  { emit "  ${CR}●  ALERTA  ${CN}$*"; ALERTS=$((ALERTS+1));     }
warn()   { emit "  ${CY}●  AVISO   ${CN}$*"; WARNINGS=$((WARNINGS+1)); }
ok()     { emit "  ${CG}●  OK      ${CN}$*"; CLEAN=$((CLEAN+1));       }
info()   { emit "  ${CC}○  info    ${CN}$*"; }
header() {
    emit ""
    emit "${CB}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    emit "${CW}${CB} ◆  $*${CN}"
    emit "${CB}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
}

# ---------- Helpers ----------
have()   { command -v "$1" >/dev/null 2>&1; }
gp()     { getprop "$1" 2>/dev/null; }
exists() { [ -e "$1" ]; }
pkg_installed() {
    have pm && pm path "$1" 2>/dev/null | grep -q '^package:'
}

# ---------- Banner ----------
emit ""
emit "${CW}${CC}    ╭──────────────────────────────────────────────────────╮${CN}"
emit "${CW}${CC}    │                                                      │${CN}"
emit "${CW}${CC}    │    █████╗ ██╗  ██╗████████╗██╗  ██╗███████╗██████╗   │${CN}"
emit "${CW}${CC}    │   ██╔══██╗██║  ██║╚══██╔══╝██║  ██║██╔════╝██╔══██╗  │${CN}"
emit "${CW}${CC}    │   ███████║███████║   ██║   ███████║█████╗  ██████╔╝  │${CN}"
emit "${CW}${CC}    │   ██╔══██║╚════██║   ██║   ██╔══██║██╔══╝  ██╔══██╗  │${CN}"
emit "${CW}${CC}    │   ██║  ██║     ██║   ██║   ██║  ██║███████╗██║  ██║  │${CN}"
emit "${CW}${CC}    │   ╚═╝  ╚═╝     ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  │${CN}"
emit "${CW}${CC}    │                                                      │${CN}"
emit "${CW}${CC}    │${CN}      ${CW}S Y S T E M S${CN}  ${CY}▪${CN}  ${CW}v${VERSION}${CN}  ${CY}▪${CN}  ${CW}LS Aluguel${CN}         ${CW}${CC}│${CN}"
emit "${CW}${CC}    │${CN}      ${CC}Free Fire Anti-Cheat Scanner${CN}                    ${CW}${CC}│${CN}"
emit "${CW}${CC}    │                                                      │${CN}"
emit "${CW}${CC}    ╰──────────────────────────────────────────────────────╯${CN}"
emit ""
emit "  ${CC}›${CN} Relatório: $REPORT"
emit ""

# Pre-cache: lista de pacotes (usado por várias seções)
ALL_PKGS=""
have pm && ALL_PKGS=$(pm list packages 2>/dev/null)

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
            elif [ -d /System/Library/CoreServices ] && [ -d /Users ]; then
                PLATFORM="macos"
            else
                PLATFORM="darwin"
            fi
            ;;
        *)
            PLATFORM="unknown"
            ;;
    esac
}
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
    AT=$(settings get global auto_time 2>/dev/null)
    ATZ=$(settings get global auto_time_zone 2>/dev/null)
    [ "$AT" = "0" ]  && alert "auto_time DESLIGADO (manipulação de data/hora)" || [ -n "$AT" ] && ok "auto_time=$AT"
    [ "$ATZ" = "0" ] && warn "auto_time_zone DESLIGADO" || [ -n "$ATZ" ] && ok "auto_time_zone=$ATZ"
    [ "$(settings get global adb_enabled 2>/dev/null)" = "1" ] && warn "ADB habilitado"
    [ "$(settings get global development_settings_enabled 2>/dev/null)" = "1" ] && warn "Opções de dev habilitadas"
    [ "$(settings get global install_non_market_apps 2>/dev/null)" = "1" ] && warn "Fontes desconhecidas habilitadas"
    [ "$(settings get secure mock_location 2>/dev/null)" = "1" ] && alert "Mock location HABILITADO"
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

# force_normal_boot (recovery bypass)
case "$(gp ro.boot.force_normal_boot)" in
    1) warn "ro.boot.force_normal_boot=1" ;;
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

# Módulos no /sys/module
if [ -d /sys/module ]; then
    SUS_MODS=$(ls /sys/module 2>/dev/null | grep -iE 'frida|inject|hide|ksu|apatch|magisk|susfs' | head -n 5)
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

# Paths su (todas variantes vistas em KellerSS/CardozoSS/TiziXit)
for P in /system/bin/su /system/xbin/su /sbin/su /system/sbin/su \
         /vendor/bin/su /su/bin/su /system/sd/xbin/su /data/magisk \
         /system/app/Superuser.apk /system/etc/init.d/99SuperSUDaemon \
         /cache/su /dev/su /system/usr/we-need-root \
         /system/xbin/daemonsu /system/xbin/busybox /system/bin/busybox \
         /system/bin/.ext /system/etc/.has_su_daemon /system/bin/.has_su; do
    exists "$P" && { alert "Caminho su/root: $P"; ROOT_HITS=$((ROOT_HITS+1)); }
done

# Nomes de binário "su" disfarçado (CardozoSS caça estes)
for SU_VAR in su64 su32 su-back __su off.su Bksu susu su.sh supersu; do
    for D in /system/bin /system/xbin /sbin /vendor/bin /data/adb /data/local/tmp; do
        if exists "$D/$SU_VAR"; then
            alert "su disfarçado: $D/$SU_VAR"
            ROOT_HITS=$((ROOT_HITS+1))
        fi
    done
done

# Pacotes de root manager
for PKG in com.topjohnwu.magisk io.github.vvb2060.magisk io.github.huskydg.magisk \
           com.kingroot.kinguser com.kingo.root eu.chainfire.supersu \
           com.koushikdutta.superuser com.noshufou.android.su com.thirdparty.superuser \
           com.zachspong.temprootremovejb me.weishu.kernelsu com.rifsxd.ksunext \
           me.bmax.apatch com.dergoogler.mmrl \
           com.formyhm.hideroot com.devadvance.rootcloak com.devadvance.rootcloakplus \
           com.amphoras.hidemyroot com.amphoras.hidemyrootadfree com.yellowes.su \
           ru.fond3.installer stericson.busybox \
           com.zhiqupk.root.global org.checkroot.checkroot \
           com.googleplay.ndkvs; do
    pkg_installed "$PKG" && { alert "App de root: $PKG"; ROOT_HITS=$((ROOT_HITS+1)); }
done

WHICH_SU=$(command -v su 2>/dev/null)
[ -n "$WHICH_SU" ] && [ "$WHICH_SU" != "/usr/bin/su" ] && {
    alert "Binário 'su' no PATH: $WHICH_SU"; ROOT_HITS=$((ROOT_HITS+1));
}

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
                *shamiko*|*hide*|*denylist*|*frida*|*inject*|*lsposed*|*riru*|*zygisk*|*ssl*|*pinning*|*magiskhide*|*safetynet*|*tricky*|*pif*|*susfs*)
                    emit "${CR}[ALERTA]${CN}  Módulo suspeito: $M" ;;
                *) emit "${CY}[AVISO]${CN}   Módulo: $M" ;;
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
    FPROC=$(ps -A 2>/dev/null | grep -iE 'frida|gadget' | grep -v grep)
    [ -z "$FPROC" ] && FPROC=$(ps 2>/dev/null | grep -iE 'frida|gadget' | grep -v grep)
    [ -n "$FPROC" ] && echo "$FPROC" | head -n 3 | while IFS= read -r L; do
        [ -n "$L" ] && emit "${CR}[ALERTA]${CN}  Processo Frida: $L"
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
#  6. ESCALAÇÃO DE PRIVILÉGIO sem-root (Shizuku / Brevent / Hunter)
# ============================================================
header "PRIVILEGE ESCALATION (Shizuku / Brevent / Hunter)"

PRIV_HITS=0
# Brevent - congela processos (bypass de detecção do FF)
for PKG in com.oasisfeng.brevent me.piebridge.brevent; do
    pkg_installed "$PKG" && { alert "Brevent (freeze process): $PKG"; PRIV_HITS=$((PRIV_HITS+1)); }
done
exists /data/local/tmp/brevent.sh && { alert "Brevent script: /data/local/tmp/brevent.sh"; PRIV_HITS=$((PRIV_HITS+1)); }
exists /data/data/com.oasisfeng.brevent && { alert "Brevent data dir presente"; PRIV_HITS=$((PRIV_HITS+1)); }
exists /data/data/me.piebridge.brevent && { alert "Brevent (piebridge) data dir"; PRIV_HITS=$((PRIV_HITS+1)); }

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
        # tamanho APK
        if [ -f "$APK_PATH" ]; then
            APK_SZ=$(stat -c '%s' "$APK_PATH" 2>/dev/null)
            [ -n "$APK_SZ" ] && info "  tamanho APK: $APK_SZ bytes"
            # APK do Free Fire normalmente > 700MB
            if [ -n "$APK_SZ" ] && [ "$APK_SZ" -lt 500000000 ] 2>/dev/null; then
                warn "  APK menor que 500MB - pode ser mod"
            fi
        fi
    fi
done
[ "$FF_FOUND" = "0" ] && warn "Free Fire NÃO encontrado"

# ============================================================
#  8b. FREE FIRE - HISTÓRICO DE INSTALAÇÃO / DESINSTALAÇÃO
# ============================================================
header "FREE FIRE - HISTÓRICO INSTALL/UNINSTALL (últimos 7 dias)"

# 1) Pacotes desinstalados conforme batterystats (TiziXit pattern)
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
        OTHER_REMOVED=$(echo "$UNINSTALLED" | grep -iE 'cheat|hack|mod|aimbot|esp|ffh4x|menu|injector|frida|magisk|brevent|shizuku|gameguardian|virtualapp|parallel|lulubox|luckypatcher')
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
    PKG_EVENTS=$(logcat -b events -d 2>/dev/null | grep -iE 'pkg_install|pkg_uninstall|package_added|package_removed|installer' | head -n 30)
    if [ -n "$PKG_EVENTS" ]; then
        # filtrar FF e cheats
        FF_LOGEV=$(echo "$PKG_EVENTS" | grep -iE 'freefire|dts\.freefire|garena|cheat|hack|mod|aimbot|esp|frida|magisk')
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

FFDATA_HITS=0
for PKG in $FF_PKGS; do
    PREFS="/data/data/$PKG/shared_prefs"
    CACHE="/data/data/$PKG/cache"
    FILES="/data/data/$PKG/files"
    if [ -d "$PREFS" ]; then
        ls "$PREFS" 2>/dev/null | while IFS= read -r F; do
            [ -z "$F" ] && continue
            case "$F" in
                *cheat*|*mod*|*hack*|*menu*|*esp*|*aim*)
                    emit "${CR}[ALERTA]${CN}  prefs suspeito: $PREFS/$F" ;;
                *) info "  $PREFS/$F" ;;
            esac
        done
    fi
    if [ -d "$FILES" ] && have find; then
        ODD=$(find "$FILES" 2>/dev/null -maxdepth 3 -type f \( \
            -name '.modded' -o -name '*.modff' -o -name 'cheat.cfg' \
            -o -name 'aim.cfg' -o -name 'esp.cfg' -o -name 'mod.cfg' \
            -o -name 'menu.cfg' -o -name '*.lua' -o -name '*.hack' \) 2>/dev/null)
        [ -n "$ODD" ] && echo "$ODD" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Mod file em files/: $L"
        done
    fi
    if [ -d "$CACHE" ] && have find; then
        ODDC=$(find "$CACHE" 2>/dev/null -maxdepth 2 -type f \( -name '*.so' -o -name '*.dex' -o -name '*.jar' \) 2>/dev/null | head -n 10)
        [ -n "$ODDC" ] && echo "$ODDC" | while IFS= read -r L; do
            [ -n "$L" ] && alert "Lib/dex em cache do FF: $L"
        done
    fi
done
[ "$FFDATA_HITS" = "0" ] && ok "Dados internos FF sem indícios"

# ============================================================
#  10. FREE FIRE - SHADERS (UnityFS signature - wallhack)
# ============================================================
header "SHADERS UnityFS (wallhack)"

SHADER_HITS=0
for PKG in $FF_PKGS; do
    GAB_DIR="/sdcard/Android/data/$PKG/files/contentcache/Optional/android/gameassetbundles"
    [ -d "$GAB_DIR" ] || continue
    info "gameassetbundles: $GAB_DIR"
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
    if have find; then
        BINS=$(find "$RDIR" 2>/dev/null -maxdepth 2 -type f -name '*.bin' 2>/dev/null)
        [ -n "$BINS" ] && echo "$BINS" | while IFS= read -r B; do
            [ -z "$B" ] && continue
            SZ=$(stat -c '%s' "$B" 2>/dev/null)
            ACC=$(stat -c '%X' "$B" 2>/dev/null)
            MOD=$(stat -c '%Y' "$B" 2>/dev/null)
            CHG=$(stat -c '%Z' "$B" 2>/dev/null)
            MTHUMAN=$(stat -c '%y' "$B" 2>/dev/null)
            info "  $B ($SZ b, mod=$MTHUMAN)"
            # 1) Access > Modify (acessou depois de modificar - bypass)
            if [ -n "$ACC" ] && [ -n "$MOD" ] && [ "$ACC" -gt "$MOD" ] 2>/dev/null; then
                alert "  Access > Modify: replay modificado/touched (bypass)"
            fi
            # 2) Modify == Change (Change deveria ser >= Modify; igual = stripado)
            if [ -n "$MOD" ] && [ -n "$CHG" ] && [ "$MOD" -eq "$CHG" ] 2>/dev/null && [ "$ACC" -eq "$MOD" ] 2>/dev/null; then
                warn "  Access=Modify=Change (timestamps idênticos = touch bypass)"
            fi
            # 3) Nanossegundos zerados (bypass via touch -d sem ns)
            case "$MTHUMAN" in
                *\.000000000*) alert "  Nanossegundos zerados em mtime ($MTHUMAN)" ;;
            esac
            # 4) JSON companion vs BIN
            JSON="${B%.bin}.json"
            if [ -f "$JSON" ]; then
                JMOD=$(stat -c '%Y' "$JSON" 2>/dev/null)
                if [ -n "$JMOD" ] && [ -n "$MOD" ] && [ "$JMOD" -lt "$MOD" ] 2>/dev/null; then
                    alert "  JSON ($JSON) modificado ANTES do BIN (anomalia)"
                fi
            fi
        done
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
    HIDDEN_OBB=$(find /sdcard /storage/emulated/0 2>/dev/null \
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
    APK_LIST=$(find /sdcard /storage/emulated/0 2>/dev/null -maxdepth 5 -type f -name '*.apk' 2>/dev/null | head -n 50)
    if [ -n "$APK_LIST" ]; then
        echo "$APK_LIST" | while IFS= read -r APK; do
            [ -z "$APK" ] && continue
            BN=$(basename "$APK")
            case "$BN" in
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*FFH4X*|*ffh4x*|*[Aa]imbot*|\
                *[Ee][Ss][Pp]*|*[Mm]enu*|*[Ii]njector*|*Frida*|*frida*|\
                *[Ww]all[Hh]ack*|*[Aa]imkill*|*VIP*FF*|*FF*VIP*|*BLOODY*|\
                *REGEDIT*|*[Hh]eadshot*|*[Bb]ypass*|*[Mm]agisk*|*KSU*|*KernelSU*|\
                *LSPatch*|*LSPosed*|*Lulubox*|*[Ll]ucky[Pp]atcher*)
                    emit "${CR}[ALERTA]${CN}  APK suspeito: $APK" ;;
                *) info "  $APK" ;;
            esac
        done
    else
        ok "Nenhum APK em /sdcard"
    fi
fi

# MIUI/HyperOS backup com APKs (TiziXit caça aqui)
if [ -d /sdcard/MIUI/backup/AllBackup ]; then
    MIUI_BK=$(find /sdcard/MIUI/backup/AllBackup 2>/dev/null -maxdepth 3 -type f -name '*.apk' 2>/dev/null | head -n 20)
    [ -n "$MIUI_BK" ] && echo "$MIUI_BK" | while IFS= read -r L; do
        [ -n "$L" ] && warn "APK em MIUI backup: $L"
    done
fi

# ============================================================
#  14. PACOTES DE CHEAT / VIRTUALIZADORES
# ============================================================
header "PACOTES DE CHEAT / VIRTUALIZADORES"

CHEAT_PKGS="
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

MEM_PKGS="com.gameguardian com.gg.intersec gg.intersec catch_.me_.if_.you_.can_ com.cih.game_cih com.cih.gamecih2 com.glasswire.cih com.gtarcade.cih ru.org.amse.android.gamekiller com.taogame.taogame com.felixheller.sharedprefsedit com.android.helloworld com.cheatengine.android"
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
    for PKG in $MACRO_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Macro/keymap: $PKG"; MACRO_HITS=$((MACRO_HITS+1)); }
    done
    HEUR=$(echo "$ALL_PKGS" | grep -Ei 'package:.*(autoclick|autotap|macro|touchsim|repetitouch|autotouch|gamepad|keymap)' | sed 's/^package://')
    [ -n "$HEUR" ] && echo "$HEUR" | while IFS= read -r L; do
        [ -n "$L" ] && warn "Pkg padrão macro: $L"
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
    RES_EVENTS=$(logcat -b events -d 2>/dev/null | grep -iE 'am_activity_resume|am_resume_activity' | grep -iE 'filemanager|fileexplorer|zarchiver|myfiles|documentsui|estrongs|xplore|amaze|solidexplorer|astro' | tail -n 15)
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
    HTTP_PROXY=$(settings get global http_proxy 2>/dev/null)
    case "$HTTP_PROXY" in
        ""|"null"|":0") ok "Sem proxy global" ;;
        *) alert "Proxy global ATIVO: $HTTP_PROXY"; PROXY_HITS=$((PROXY_HITS+1)) ;;
    esac
    PROXY_HOST=$(settings get global global_http_proxy_host 2>/dev/null)
    PROXY_PORT=$(settings get global global_http_proxy_port 2>/dev/null)
    [ -n "$PROXY_HOST" ] && [ "$PROXY_HOST" != "null" ] && {
        alert "Proxy host: $PROXY_HOST:$PROXY_PORT"; PROXY_HITS=$((PROXY_HITS+1));
    }
fi

PROXY_PKGS="com.httpcanary.pro com.guoshi.httpcanary com.guoshi.httpcanary.premium tech.httptoolkit.android.v1 io.github.lsposed.lspatch com.minhui.networkcapture com.minhui.networkcapture.pro com.evbadroid.proxymon com.evbadroid.wicap com.adguard.android.contentblocker com.lonelycatgames.HTTPProxy com.emanuelef.remote_capture com.packetcapture.android com.reqable.android com.proxyman.proxyman"

if [ -n "$ALL_PKGS" ]; then
    for PKG in $PROXY_PKGS; do
        echo "$ALL_PKGS" | grep -q "^package:${PKG}$" && { alert "Sniffer: $PKG"; PROXY_HITS=$((PROXY_HITS+1)); }
    done
fi

USER_CA="/data/misc/user/0/cacerts-added"
if [ -d "$USER_CA" ]; then
    CAS=$(ls "$USER_CA" 2>/dev/null)
    [ -n "$CAS" ] && echo "$CAS" | while IFS= read -r L; do
        [ -n "$L" ] && alert "CA do usuário: $L (permite MITM)"
    done
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
        ACTIVE=$(echo "$DA_INFO" | grep -E 'Active admin|ComponentName=' | head -n 15)
        if [ -n "$ACTIVE" ]; then
            echo "$ACTIVE" | while IFS= read -r L; do
                [ -z "$L" ] && continue
                # filtrar admins legítimos (Google/Android/Samsung Find My Mobile etc.)
                case "$L" in
                    *com.google.android.apps.work*|*com.google.android.gms*|\
                    *com.samsung.android.lool*|*com.samsung.android.knox*|\
                    *com.android.*|*com.miui.securitycenter*)
                        info "  admin: $(echo "$L" | head -c 140)" ;;
                    *)
                        warn "  admin de 3rd party: $(echo "$L" | head -c 140)"
                        DA_HITS=$((DA_HITS+1)) ;;
                esac
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
    ALWAYS_VPN=$(settings get global always_on_vpn_app 2>/dev/null)
    [ -n "$ALWAYS_VPN" ] && [ "$ALWAYS_VPN" != "null" ] && {
        alert "Always-on VPN ativo: $ALWAYS_VPN"
        DA_HITS=$((DA_HITS+1))
    }
    LOCKDOWN=$(settings get global always_on_vpn_lockdown 2>/dev/null)
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
#  22. DNS
# ============================================================
header "DNS"

DNS_HITS=0
if have settings; then
    PDNS_MODE=$(settings get global private_dns_mode 2>/dev/null)
    PDNS_HOST=$(settings get global private_dns_specifier 2>/dev/null)
    case "$PDNS_MODE" in
        ""|"null"|"off"|"opportunistic") ok "Private DNS: $PDNS_MODE" ;;
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
    ACC=$(settings get secure enabled_accessibility_services 2>/dev/null)
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
        case "$PP" in
            com.android.*|com.google.*|com.facebook.katana|com.whatsapp|\
            com.instagram.*|com.miui.*|com.samsung.*|com.huawei.*|\
            com.oppo.*|com.oneplus.*|com.coloros.*|com.realme.*|com.xiaomi.*) ;;
            *) warn "Overlay ativo: $PP" ;;
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
[ "$ESP_HITS" = "0" ] && ok "Sem ESP/overlay óbvio"

# ============================================================
#  24. /data SUSPEITO
# ============================================================
header "/data SUSPEITO"

DATA_HITS=0
for P in /data/local/tmp/frida-server /data/local/tmp/re.frida.server \
         /data/local/tmp/cheat /data/local/tmp/.cheats /data/local/tmp/gg \
         /data/local/tmp/.gg /data/local/tmp/script.lua /data/local/tmp/hack.so \
         /data/local/tmp/.injector /data/local/tmp/gadget.so \
         /data/local/tmp/menu.so /data/local/tmp/esp.so \
         /data/local/tmp/lib /data/local/tmp/mod \
         /data/local/tmp/brevent.sh /data/local/tmp/.brevent; do
    exists "$P" && { alert "Cheat em /data: $P"; DATA_HITS=$((DATA_HITS+1)); }
done

TMP_LS=$(ls -la /data/local/tmp 2>/dev/null | tail -n +2 | grep -v '^total')
[ -n "$TMP_LS" ] && { info "/data/local/tmp:"; echo "$TMP_LS" | while IFS= read -r L; do info "  $L"; done; }

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
    TRASHED=$(find /sdcard /storage/emulated/0 2>/dev/null -maxdepth 5 -name '.trashed-*' 2>/dev/null | head -n 40)
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
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*[Aa]imbot*|*[Ee][Ss][Pp]*|*[Mm]enu*|*FFH4X*|*ffh4x*|*[Ii]njector*|*[Ww]all[Hh]ack*|*[Bb]ypass*|*[Mm]agisk*|*frida*)
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
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*[Aa]imbot*|*[Ee][Ss][Pp]*|*[Mm]enu*|*FFH4X*|*ffh4x*|*[Ii]njector*|*[Ww]all[Hh]ack*|*[Bb]ypass*|*[Mm]agisk*|*frida*|*\.apk|*\.lua|*\.so)
                    alert "  $F ($SZ b, $MT) - SUSPEITO" ;;
                *) info "  $F ($SZ b, $MT)" ;;
            esac
        done
        DEL_HITS=$((DEL_HITS+1))
    fi
done

# 3) Logcat: eventos de delete
if have logcat; then
    DEL_EVENTS=$(logcat -d 2>/dev/null | grep -iE 'deletePackage|deleteFile|MediaStore.*delete|Filesystem.*delete|content.*deleted|removed.*\.apk|file_remove' | head -n 20)
    if [ -n "$DEL_EVENTS" ]; then
        # filtrar só eventos com nome suspeito
        SUSPECT_DEL=$(echo "$DEL_EVENTS" | grep -iE 'cheat|hack|mod|ffh4x|aimbot|esp\.|menu|injector|wallhack|magisk|frida|freefire|\.apk|\.lua|\.so|\.dex')
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
    FF_DEL=$(grep -iE 'freefire|cheat|hack|mod|aimbot|esp|frida|magisk|deleted|removed' "$H" 2>/dev/null | head -n 10)
    [ -n "$FF_DEL" ] && {
        info "Indícios em $H:"
        echo "$FF_DEL" | while IFS= read -r L; do
            info "  $(echo "$L" | head -c 180)"
        done
    }
done

# 5) Activity de delete via dumpsys activity recents (apps que estavam abertos)
if have dumpsys; then
    RECENT_TASKS=$(dumpsys activity recents 2>/dev/null | grep -iE 'cheat|hack|mod|ffh4x|aimbot|menu|injector|frida|magisk|virtualapp|lulubox|luckypatcher|brevent' | head -n 20)
    if [ -n "$RECENT_TASKS" ]; then
        alert "Apps suspeitos em activity recents (foram abertos recentemente):"
        echo "$RECENT_TASKS" | head -n 10 | while IFS= read -r L; do
            [ -n "$L" ] && alert "  $(echo "$L" | head -c 180)"
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

HIDDEN_HITS=0
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
    [ -n "$SYMS" ] && echo "$SYMS" | while IFS= read -r S; do
        [ -n "$S" ] && warn "Symlink: $S -> $(readlink "$S" 2>/dev/null)"
    done
fi
[ "$HIDDEN_HITS" = "0" ] && ok "Sem ocultos suspeitos"

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

# 1) Conexões ATIVAS do processo Free Fire via /proc/<pid>/net/tcp
if have pidof; then
    for PKG in $FF_PKGS; do
        FF_PID=$(pidof "$PKG" 2>/dev/null | awk '{print $1}')
        [ -z "$FF_PID" ] && continue
        info "FF rodando ($PKG, PID $FF_PID)"
        for NTCP in /proc/$FF_PID/net/tcp /proc/$FF_PID/net/tcp6; do
            [ -r "$NTCP" ] || continue
            CONNS=$(awk 'NR>1 && $4=="01" {print $3}' "$NTCP" 2>/dev/null | head -n 30)
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
CHEAT_DOMAINS="fatalitycheats.xyz anubisw.online api.baontq.xyz purplevioleto.com ggwhitehawk.com ggpolarbear.com ggblueshark.com version.ffmax.purplevioleto.com version.ggwhitehawk.com loginbp.ggpolarbear.com sacnetwork.ggblueshark.com sacevent.ggblueshark.com ipasign.cc ipa.aspy.dev"

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
                MATCHES=$(grep -rl "$D" "$FFD" 2>/dev/null | head -n 3)
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

PROC_HITS=0
if have ps; then
    PROCS=$(ps -A 2>/dev/null)
    [ -z "$PROCS" ] && PROCS=$(ps 2>/dev/null)
    for PAT in frida gameguardian gg.intersec xposed lsposed substrate cydia \
               injector cheatengine virtualapp parallel.space dualspace \
               luckypatcher cih gamekiller autoclicker macro brevent shizuku; do
        HIT=$(echo "$PROCS" | grep -i "$PAT" | grep -v grep)
        [ -n "$HIT" ] && echo "$HIT" | head -n 2 | while IFS= read -r L; do
            [ -n "$L" ] && alert "Processo ($PAT): $L"
        done
    done
fi
[ "$PROC_HITS" = "0" ] && ok "Nenhum processo suspeito"

# ============================================================
#  29. LOGCAT (rastros nos logs)
# ============================================================
header "LOGCAT"

LOG_HITS=0
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
            HIT=$(echo "$LOG_OUT" | grep -i "$PAT" | head -n 2)
            [ -n "$HIT" ] && echo "$HIT" | while IFS= read -r L; do
                [ -n "$L" ] && alert "Logcat [$PAT]: $(echo "$L" | head -c 160)"
            done
        done
        [ "$LOG_HITS" = "0" ] && ok "Logcat limpo (últimas 2000 linhas)"
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
                CHEAT_HIT=$(grep -iE 'freefire|frida|magisk|xposed|lsposed|cheat|injector|hack|gameguardian|libsubstrate|brevent' "$FULL" 2>/dev/null | head -n 3)
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
                CHEAT_HIT=$(grep -iE 'freefire|frida|magisk|xposed|cheat|injector|hack|libsubstrate|substitute|libhooker' "$FULL" 2>/dev/null | head -n 3)
                [ -n "$CHEAT_HIT" ] && echo "$CHEAT_HIT" | while IFS= read -r L; do
                    [ -n "$L" ] && alert "    Tombstone contém: $(echo "$L" | head -c 140)"
                done
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
                HIT=$(grep -iE 'freefire|frida|magisk|xposed|cheat|injector|libsubstrate|frida-server|frida-gadget' "$F" 2>/dev/null | head -n 2)
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

# Bugreports / dumps persistentes
for BR in /data/user_de/0/com.android.shell/files/bugreports \
          /data/data/com.android.shell/files/bugreports \
          /sdcard/bugreports; do
    [ -d "$BR" ] || continue
    COUNT=$(ls "$BR" 2>/dev/null | wc -l)
    [ "$COUNT" -gt 0 ] 2>/dev/null && warn "$COUNT bug reports em $BR (rastros forenses)"
done

[ "$PLOG_HITS" = "0" ] && ok "Logs persistentes sem rastros de cheat"

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
#  31. HWID (SHA-256 + MD5 TiziXit-compat)
# ============================================================
header "HWID"

SERIAL=$(gp ro.serialno)
[ -z "$SERIAL" ] && SERIAL=$(gp ro.boot.serialno)
BOOT_SERIAL=$(gp ro.boot.serialno)
MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null)
ANDROID_ID=""
have settings && ANDROID_ID=$(settings get secure android_id 2>/dev/null)

RAW="${SERIAL}|${MAC}|${ANDROID_ID}|$(gp ro.product.model)"
TIZIXIT_RAW="${ANDROID_ID}:${SERIAL}:${BOOT_SERIAL}"

HASH=""
HASH_TIZIXIT=""
if have sha256sum; then
    HASH=$(printf '%s' "$RAW" | sha256sum 2>/dev/null | awk '{print $1}')
fi
if have md5sum; then
    HASH_TIZIXIT=$(printf '%s' "$TIZIXIT_RAW" | md5sum 2>/dev/null | awk '{print $1}')
elif have md5; then
    HASH_TIZIXIT=$(printf '%s' "$TIZIXIT_RAW" | md5 -q 2>/dev/null)
fi

info "Serial:        ${SERIAL:-?}"
info "Boot serial:   ${BOOT_SERIAL:-?}"
info "MAC wlan0:     ${MAC:-?}"
info "Android ID:    ${ANDROID_ID:-?}"
info "HWID SHA-256:  ${HASH:-(indisponível)}"
info "HWID MD5 (TX): ${HASH_TIZIXIT:-(indisponível)}"

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
warn "Você está rodando bash em iOS - device JÁ está jailbroken (SSH habilitado)"

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

# Paths clássicos de jailbreak (rootful)
for P in /private/var/lib/cydia /private/var/cache/apt \
         /private/var/lib/apt /etc/apt \
         /usr/libexec/cydia/firmware.sh /usr/sbin/sshd \
         /usr/libexec/sftp-server /private/var/tmp/cydia.log \
         /var/lib/apt /var/lib/cydia /var/cache/apt \
         /usr/bin/ssh /private/etc/apt /Library/MobileSubstrate \
         /usr/share/jailbreak /private/var/stash; do
    exists "$P" && { alert "JB path: $P"; JB_HITS=$((JB_HITS+1)); }
done

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
        ls "$TWKDIR" 2>/dev/null | grep -i '\.dylib$\|\.plist$' | while IFS= read -r T; do
            [ -z "$T" ] && continue
            case "$T" in
                *cheat*|*hack*|*mod*|*aim*|*esp*|*wallhack*|*ff*|*freefire*|*macro*|*helper*|*menu*)
                    emit "${CR}[ALERTA]${CN}  Tweak suspeito: $TWKDIR/$T" ;;
                *) emit "${CY}[AVISO]${CN}   Tweak: $TWKDIR/$T" ;;
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
        SUSP=$(echo "$CONTENT" | grep -iE 'cheat|hack|aimbot|wallhack|esp|menu.*ff|ff.*menu|injection|mod')
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
    ACTIVE=$(launchctl list 2>/dev/null | head -n 80 | grep -iE 'cheat|hack|mod|aim|esp|freefire|frida|injector|substrate' | head -n 15)
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
for P in /usr/sbin/frida-server /var/jb/usr/sbin/frida-server \
         /var/jb/usr/bin/frida /usr/bin/frida \
         /usr/lib/frida /var/jb/usr/lib/frida \
         /System/Library/PrivateFrameworks/DebugSymbols.framework; do
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
for P in /Developer/usr/bin/debugserver /var/jb/usr/bin/debugserver \
         /var/jb/usr/bin/lldb /usr/bin/lldb; do
    exists "$P" && { warn "Debugger: $P"; FIOS_HITS=$((FIOS_HITS+1)); }
done

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
                *[Hh]ack*|*[Mm]od*|*[Cc]heat*|*FF*MOD*|*FFH4X*|*[Aa]imbot*|\
                *[Ee][Ss][Pp]*|*[Mm]enu*|*[Ii]njector*|*FreeFire*VIP*|\
                *FF*VIP*|*BLOODY*)
                    emit "${CR}[ALERTA]${CN}  App suspeito: $APD" ;;
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
                if strings "$EMBED_PROV" 2>/dev/null | grep -q 'AppleAppStoreUpdateConfiguration\|ProductionIOS'; then
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
    PROCS=$(ps -A 2>/dev/null)
    for PAT in frida sshd substrated cycript lldb gdb debugserver \
               igamegod gamegem trollstore altstore scarlet \
               cheat hack injector; do
        HIT=$(echo "$PROCS" | grep -i "$PAT" | grep -v grep)
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

fi  # ===== fim do bloco iOS =====

# ============================================================
#  RESUMO
# ============================================================
header "RESUMO"
emit ""
emit "    ${CR}●${CN}  Alertas: ${CW}${CR}${ALERTS}${CN}"
emit "    ${CY}●${CN}  Avisos:  ${CW}${CY}${WARNINGS}${CN}"
emit "    ${CG}●${CN}  OKs:     ${CW}${CG}${CLEAN}${CN}"
emit ""
if [ "$ALERTS" -gt 0 ]; then
    emit ""
    emit "${CR}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    emit ""
    emit "${CR}${CW}         ✗   S U S P E I T O   ▪   ${ALERTS} alertas${CN}"
    emit ""
    emit "${CR}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    RC=2
elif [ "$WARNINGS" -gt 0 ]; then
    emit ""
    emit "${CY}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    emit ""
    emit "${CY}${CW}         ⚠   R E V I S A R   ▪   ${WARNINGS} avisos${CN}"
    emit ""
    emit "${CY}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    RC=1
else
    emit ""
    emit "${CG}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    emit ""
    emit "${CG}${CW}         ✓   L I M P O   ▪   device aprovado${CN}"
    emit ""
    emit "${CG}${CW}    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CN}"
    RC=0
fi
emit ""
emit "  ${CC}›${CN} Relatório salvo em: ${CW}$REPORT${CN}"
emit ""
exit "$RC"
