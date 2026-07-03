#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Harness de regressão do engine a4ther.sh  (roda em sh E dash; CI: engine-tests.yml)
#
# COMO FUNCIONA: extrai as FUNÇÕES PURAS de detecção do a4ther.sh (as que decidem
# benigno×malicioso) e roda-as com MOCKS determinísticos do ambiente Android
# (have/dumpsys/pm), afirmando o resultado. Assim, um FALSO-POSITIVO (ou falso-
# negativo) numa dessas funções vira uma FALHA de CI — a rede que faltava: todo FP
# histórico do engine só apareceu EM PRODUÇÃO, no device, DEPOIS do dano.
#
# RODAR:      sh tests/run.sh        (ou: dash tests/run.sh)
# ESTENDER:   achou um FP? adicione um `ck` que reproduz a entrada benigna →
#             resultado esperado; a regressão fica barrada pra sempre. Ver tests/README.md.
# ─────────────────────────────────────────────────────────────────────────────
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
ENGINE="${A4_ENGINE:-$HERE/../a4ther.sh}"
[ -r "$ENGINE" ] || { echo "ERRO: engine não encontrado em $ENGINE"; exit 2; }
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT INT TERM

# ── extrai as funções puras (assinatura em coluna 0; corpo indentado; fecha em ^}) ──
{
  sed -n '/^is_oem_ns() {/,/^}/p'      "$ENGINE"
  sed -n '/^is_oem_store() {/,/^}/p'   "$ENGINE"
  sed -n '/^is_oem_preload() {/,/^}/p' "$ENGINE"
  sed -n '/^pkg_label() {/,/^}/p'      "$ENGINE"
  sed -n '/^pkg_show() /p'             "$ENGINE"
  sed -n '/^tok_grep() /p'             "$ENGINE"
  sed -n '/^_sl_classify() {/,/^}/p'   "$ENGINE"
} > "$TMP/fns.sh"
. "$TMP/fns.sh"

# self-guard: se uma função foi renomeada/reformatada, a extração falha — pare LOUD.
for _fn in is_oem_ns is_oem_store is_oem_preload pkg_label pkg_show tok_grep _sl_classify; do
  command -v "$_fn" >/dev/null 2>&1 || { echo "ERRO: função '$_fn' não foi extraída (renomeada/reformatada no engine?)"; exit 2; }
done

# ── mocks do ambiente Android (o engine chama estes; aqui são determinísticos) ──
HAVE_DUMPSYS=1; DUMPSYS_OUT="pkgFlags=[ HAS_CODE ]"
have(){ case "$1" in dumpsys) [ "$HAVE_DUMPSYS" = 1 ];; aapt|aapt2) return 1;; *) return 0;; esac; }
dumpsys(){ printf '%s\n' "$DUMPSYS_OUT"; }
pm(){ return 0; }
_SYS_PKGS=""

pass=0; fail=0
ck(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL: %s\n        esperado=[%s]  obtido=[%s]\n' "$1" "$2" "$3"; fi; }
rc(){ "$@" >/dev/null 2>&1; echo $?; }   # captura o exit-code (0/1) de uma função
sck(){ if grep -qF "$2" "$ENGINE"; then pass=$((pass+1)); else fail=$((fail+1)); printf '  FAIL (estrutural): %s\n        gate ausente do engine: [%s]\n' "$1" "$2"; fi; }

echo "# is_oem_ns — namespace de vendor OEM (detecta disfarce; NUNCA libera sozinho)"
ck "samsung é OEM"        0 "$(rc is_oem_ns com.samsung.foo)"
ck "miui é OEM"           0 "$(rc is_oem_ns com.miui.home)"
ck "motorola é OEM"       0 "$(rc is_oem_ns com.motorola.ctx)"
ck "Free Fire NÃO é OEM"  1 "$(rc is_oem_ns com.dts.freefireth)"
ck "app random NÃO é OEM" 1 "$(rc is_oem_ns com.acme.app)"

echo "# is_oem_preload — libera SÓ por sinal NÃO-FORJÁVEL (partição / pkgFlags SYSTEM / pm -s)"
DUMPSYS_OUT="pkgFlags=[ SYSTEM HAS_CODE ]"; _SYS_PKGS=""
ck "pkgFlags SYSTEM => preload"          0 "$(rc is_oem_preload com.x null /data/app/x/base.apk)"
HAVE_DUMPSYS=0; DUMPSYS_OUT=""
ck "partição /product => preload"        0 "$(rc is_oem_preload com.miui.calc null /product/app/c.apk)"
HAVE_DUMPSYS=1; DUMPSYS_OUT="pkgFlags=[ HAS_CODE ]"; _SYS_PKGS="package:com.miui.weather2"
ck "em 'pm list packages -s' => preload" 0 "$(rc is_oem_preload com.miui.weather2 com.android.chrome /data/app/x.apk)"
ck "spoof com.samsung.evil via chrome"   1 "$(_SYS_PKGS='package:com.miui.home'; rc is_oem_preload com.samsung.evil com.android.chrome /data/app/x.apk)"
ck "spoof com.samsung.evil via adb-null" 1 "$(_SYS_PKGS='package:com.miui.home'; rc is_oem_preload com.samsung.evil null /data/app/x.apk)"
ck "grep -qxF: prefixo NÃO casa -s"      1 "$(_SYS_PKGS='package:com.samsung.android.app.tips'; rc is_oem_preload com.samsung.android.app.tip null /data/app/x.apk)"
ck "cheat ffh4x via packageinstaller"    1 "$(rc is_oem_preload com.ffh4x com.google.android.packageinstaller /data/app/x.apk)"
DUMPSYS_OUT="pkgFlags=[ HAS_CODE ]"; _SYS_PKGS=""

echo "# is_oem_store — loja/updater OEM de 1a parte (origem legitima; corrige o FP Samsung)"
ck "Galaxy Store => loja"           0 "$(rc is_oem_store com.sec.android.app.samsungapps)"
ck "Samsung Update Center => loja"  0 "$(rc is_oem_store com.samsung.android.app.updatecenter)"
ck "Xiaomi GetApps => loja"         0 "$(rc is_oem_store com.xiaomi.mipicks)"
ck "chrome NAO e loja"              1 "$(rc is_oem_store com.android.chrome)"
ck "packageinstaller NAO e loja"    1 "$(rc is_oem_store com.google.android.packageinstaller)"
ck "installer inventado NAO e loja" 1 "$(rc is_oem_store com.fake.store)"
ck "Phoenix BROWSER NAO e loja (M1)" 1 "$(rc is_oem_store com.transsion.phoenix)"
ck "Palm Store (Transsion) => loja"  0 "$(rc is_oem_store com.transsnet.store)"

echo "# decisao de DISFARCE do loop SIDELOAD (app de namespace OEM)"
decide_oem(){ is_oem_ns "$1" || { echo NOT_OEM_NS; return; }; is_oem_store "$2" && return; is_oem_preload "$1" "$2" "$3" && return; echo D; }
HAVE_DUMPSYS=1; DUMPSYS_OUT="pkgFlags=[ HAS_CODE ]"; _SYS_PKGS=""
ck "FP FIX Samsung: arzone via Galaxy Store => limpo"        "" "$(decide_oem com.samsung.android.arzone com.sec.android.app.samsungapps /data/app/x/base.apk)"
ck "FP FIX Samsung: clock via Update Center => limpo"        "" "$(decide_oem com.sec.android.app.clockpackage com.samsung.android.app.updatecenter /data/app/x/base.apk)"
ck "DISFARCE: samsung.evil via chrome => D"                  "D" "$(decide_oem com.samsung.evil com.android.chrome /data/app/x/base.apk)"
ck "DISFARCE: samsung.evil via installer inventado => D"     "D" "$(decide_oem com.samsung.evil com.fake.store /data/app/x/base.apk)"
ck "residual doc: samsung.evil via -i Galaxy Store => limpo" "" "$(decide_oem com.samsung.evil com.sec.android.app.samsungapps /data/app/x/base.apk)"
_SYS_PKGS="package:com.miui.weather2"
ck "OEM real em -s via chrome => limpo (is_oem_preload)"     "" "$(decide_oem com.miui.weather2 com.android.chrome /data/app/x/base.apk)"
_SYS_PKGS=""

echo "# asserção ESTRUTURAL — decide_oem testa a LÓGICA; estas provam que o GATE segue no engine (pega remoção/reorder)"
sck "gate is_oem_store no loop SIDELOAD (branch disfarce)" 'is_oem_store "$INST" && continue'
sck "is_oem_store no topo de _sl_classify"                 'is_oem_store "$2" && return'

echo "# pkg_label / pkg_show — nome do app no relatório (dispensa lib checker)"
ck "label Free Fire"     "Free Fire"                        "$(pkg_label com.dts.freefireth)"
ck "label Free Fire MAX" "Free Fire MAX"                    "$(pkg_label com.dts.freefiremax)"
ck "label AnyDesk"       "AnyDesk — controle remoto"        "$(pkg_label com.anydesk.anydeskandroid)"
ck "label ff.injector"   "FF Injector — painel de cheat FF" "$(pkg_label com.ff.injector)"
ck "label injector genérico => vazio"  ""                   "$(pkg_label com.acme.injector)"
ck "label desconhecido => vazio"       ""                   "$(pkg_label com.random.unknown)"
ck "show conhecido"      "com.dts.freefireth (Free Fire)"   "$(pkg_show com.dts.freefireth)"
ck "show desconhecido => só o pacote"  "com.random.unknown" "$(pkg_show com.random.unknown)"

echo "# _sl_classify — origem do app (loja oficial => vazio; sideload conhecido => candidato)"
ck "Play Store => vazio"           "" "$(_sl_classify com.foo com.android.vending)"
ck "Xiaomi GetApps => vazio"       "" "$(_sl_classify com.foo com.xiaomi.mipicks)"
ck "Samsung Store => vazio"        "" "$(_sl_classify com.foo com.sec.android.app.samsungapps)"
ck "chrome => candidato"           "com.foo|com.android.chrome" "$(_sl_classify com.foo com.android.chrome)"
ck "packageinstaller => candidato" "com.foo|com.google.android.packageinstaller" "$(_sl_classify com.foo com.google.android.packageinstaller)"
ck "null => candidato"             "com.foo|null" "$(_sl_classify com.foo null)"
ck "installer desconhecido => vazio (design v4.4.88)" "" "$(_sl_classify com.foo com.weird.store)"

echo "# tok_grep — âncora que mata FP-por-substring SEM perder lib<token> nem variantes"
tg(){ if printf '%s\n' "$1" | tok_grep "$2" >/dev/null 2>&1; then echo M; else echo N; fi; }
ck "FP MORTO: system_exposed_libraries × xposed => N" N "$(tg 'nativeloader: Extending system_exposed_libraries: libhumantracking.arcsoft.so' xposed)"
ck "FP MORTO: journal_checksum × ksu => N"            N "$(tg 'ext4 journal_checksum enabled' ksu)"
ck "libxposed (lib<tok>) × xposed => M"               M "$(tg '/system/lib64/libxposed_art.so' xposed)"
ck "libsubstrate (lib<tok>) × substrate => M"         M "$(tg 'loaded libsubstrate.so' substrate)"
ck "de.robv...xposed.installer × xposed => M"         M "$(tg 'de.robv.android.xposed.installer' xposed)"
ck "LSPosed: (início de palavra) × lsposed => M"      M "$(tg '01-02 03:04 D LSPosed: module carregado' lsposed)"
ck "variante xposedmod × xposed => M"                 M "$(tg 'daemon xposedmod started' xposed)"
ck "ksud (início de palavra) × ksu => M"              M "$(tg 'starting ksud service' ksu)"

# v4.4.103: FPs de LOG EM DISCO (ANR/bugreport/logcat dump/módulos kernel) — a mesma
# classe do FP-por-substring acima, encontrada em grep -iE cru dos scanners que lêem
# arquivo/dump em vez de rodar tok_grep diretamente. Aqui reproduzimos os tokens/termos
# curados (via tok_grep, que aplica a MESMA âncora usada inline nesses sítios).
ck "FP MORTO: ExposedDropdownMenuBox (ANR Compose) × xposed => N" N "$(tg 'FATAL EXCEPTION: main ... at androidx.compose.material.ExposedDropdownMenuBox' xposed)"
ck "FP MORTO: xt_CHECKSUM (módulo netfilter real) × ksu => N"     N "$(tg 'xt_CHECKSUM' ksu)"
ck "FP MORTO: com.motorola.modservice × modmenu => N"             N "$(tg 'package:com.motorola.modservice' modmenu)"
ck "positivo: daemon modmenu ativo × modmenu => M"                M "$(tg 'daemon modmenu ativo' modmenu)"

echo
if [ "$fail" = 0 ]; then
  printf 'HARNESS OK — %d asserções verdes.\n' "$pass"; exit 0
else
  printf 'HARNESS FALHOU — %d verdes, %d VERMELHAS.\n' "$pass" "$fail"; exit 1
fi
