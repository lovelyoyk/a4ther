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
  sed -n '/^is_oem_preload() {/,/^}/p' "$ENGINE"
  sed -n '/^pkg_label() {/,/^}/p'      "$ENGINE"
  sed -n '/^pkg_show() /p'             "$ENGINE"
  sed -n '/^_sl_classify() {/,/^}/p'   "$ENGINE"
} > "$TMP/fns.sh"
. "$TMP/fns.sh"

# self-guard: se uma função foi renomeada/reformatada, a extração falha — pare LOUD.
for _fn in is_oem_ns is_oem_preload pkg_label pkg_show _sl_classify; do
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

echo
if [ "$fail" = 0 ]; then
  printf 'HARNESS OK — %d asserções verdes.\n' "$pass"; exit 0
else
  printf 'HARNESS FALHOU — %d verdes, %d VERMELHAS.\n' "$pass" "$fail"; exit 1
fi
