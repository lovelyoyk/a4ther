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
  sed -n '/^_oem_sig_of() {/,/^}/p'    "$ENGINE"
  sed -n '/^_oem_sig_build() {/,/^}/p' "$ENGINE"
  sed -n '/^oem_cert_ok() {/,/^}/p'    "$ENGINE"
  sed -n '/^pkg_label() {/,/^}/p'      "$ENGINE"
  sed -n '/^pkg_show() /p'             "$ENGINE"
  sed -n '/^tok_grep() /p'             "$ENGINE"
  sed -n '/^_sl_classify() {/,/^}/p'   "$ENGINE"
} > "$TMP/fns.sh"
. "$TMP/fns.sh"

# self-guard: se uma função foi renomeada/reformatada, a extração falha — pare LOUD.
for _fn in is_oem_ns is_oem_store is_oem_preload _oem_sig_of _oem_sig_build oem_cert_ok pkg_label pkg_show tok_grep _sl_classify; do
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
ck "com.android.samsung.* é OEM (gap fechado)" 0 "$(rc is_oem_ns com.android.samsung.utilityagent)"
ck "com.android.chrome (AOSP) NÃO é OEM"       1 "$(rc is_oem_ns com.android.chrome)"

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
decide_oem(){ is_oem_ns "$1" || { echo NOT_OEM_NS; return; }; is_oem_store "$2" && return; is_oem_preload "$1" "$2" "$3" && return; oem_cert_ok "$1" && return; echo D; }
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

echo "# _oem_sig_of / oem_cert_ok — cert-pinning por âncora do device (v4.4.105)"
# _oem_sig_of: pega o 1º signatures:[hex], ignora o obj-hash e o past signatures:[]
DUMPSYS_OUT="    signatures=PackageSignatures{b776f8b version:2, signatures:[b378e95c], past signatures:[]}"
ck "_oem_sig_of: 1o grupo, ignora obj-hash e past"  "b378e95c" "$(_oem_sig_of com.sec.x)"
DUMPSYS_OUT="    signatures=PackageSignatures{x version:3, signatures:[aa11bb22], past signatures:[ccdd3344]}"
ck "_oem_sig_of: past populado, ainda pega o atual" "aa11bb22" "$(_oem_sig_of com.sec.x)"
DUMPSYS_OUT="    signatures=PackageSignatures{c version:4, signatures:[], past signatures:[bbbb2222]}"
ck "_oem_sig_of: corrente vazio + past populado => vazio (fail-closed, NIT-1)" "" "$(_oem_sig_of com.sec.x)"
DUMPSYS_OUT="pkgFlags=[ HAS_CODE ]"
ck "_oem_sig_of: sem linha signatures => vazio"     "" "$(_oem_sig_of com.sec.x)"
# oem_cert_ok: libera se signer ∈ âncora; fail-CLOSED sem âncora / signer ilegível
_OEM_SIG_SET="b378e95c"; _OEM_SIG_SET_DONE=1
DUMPSYS_OUT="    signatures=PackageSignatures{b776f8b version:2, signatures:[b378e95c], past signatures:[]}"
ck "oem_cert_ok: signer NA âncora => libera (0)"    0 "$(rc oem_cert_ok com.sec.android.app.kidshome)"
DUMPSYS_OUT="    signatures=PackageSignatures{aa version:2, signatures:[deadbeef], past signatures:[]}"
ck "oem_cert_ok: signer FORA da âncora => flagra (1)" 1 "$(rc oem_cert_ok com.sec.evil)"
_OEM_SIG_SET=""; _OEM_SIG_SET_DONE=1
ck "oem_cert_ok: sem âncora => fail-CLOSED (1)"     1 "$(rc oem_cert_ok com.sec.foo)"
_OEM_SIG_SET="b378e95c"; DUMPSYS_OUT="Unable to find package: com.sec.foo"
ck "oem_cert_ok: signer ilegível => fail-CLOSED (1)" 1 "$(rc oem_cert_ok com.sec.foo)"
# decide_oem (com o gate oem_cert_ok) no ramo de disfarce
_OEM_SIG_SET="b378e95c"; _OEM_SIG_SET_DONE=1; _SYS_PKGS=""
DUMPSYS_OUT="    signatures=PackageSignatures{b776f8b version:2, signatures:[b378e95c], past signatures:[]}"
ck "FP FIX: kidshome baixado (installer null) mas Samsung-assinado => limpo" "" "$(decide_oem com.sec.android.app.kidshome null /data/app/x/base.apk)"
DUMPSYS_OUT="    signatures=PackageSignatures{aa version:2, signatures:[deadbeef], past signatures:[]}"
ck "DISFARCE: com.sec.evil assinado por chave estranha => D" "D" "$(decide_oem com.sec.evil null /data/app/x/base.apk)"
_OEM_SIG_SET=""; _OEM_SIG_SET_DONE=""; DUMPSYS_OUT="pkgFlags=[ HAS_CODE ]"; _SYS_PKGS=""
sck "gate oem_cert_ok no ramo disfarce" 'oem_cert_ok "$APP" && continue'

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

# v4.4.105: set de tokens de accessibility (sítio ao vivo l.~3472 + bugreport offline l.~4494) —
# era `case *bot*|*menu*|*hack*|…` substring CRU (FP: TalkBack/robot, menu legítimo; evasão
# trivial). Agora ancorado via tok_grep. TOKS reproduz o set exato usado nos dois sítios (sem
# 'macro', que só existe no sítio de bugreport — testado à parte). Nota v4.4.105/S2: token é
# 'ffh' (NÃO 'ffh4x') — 'ffh4x' estreitava o '*ffh*' antigo e perdia ffhack/ffhax (FN real).
TOKS='esp|aimbot|aimlock|aimkill|wallhack|modmenu|killaura|ffh|magicbullet|gameguardian|cheat|hack|injector'
echo "# accessibility (v4.4.105) — tok_grep mata *bot*/*menu*/*hack* crus sem perder o idioma de cheat"
ck "MATCH: com.aimbot.ff => M"                    M "$(tg 'com.aimbot.ff' "$TOKS")"
ck "MATCH: com.x.ffh4x => M"                       M "$(tg 'com.x.ffh4x' "$TOKS")"
ck "MATCH: com.ffhack.vip (ffh não-ancora-fim) => M" M "$(tg 'com.ffhack.vip' "$TOKS")"
ck "MATCH: com.evil.modmenu => M"                  M "$(tg 'com.evil.modmenu' "$TOKS")"
ck "MATCH: com.x.wallhack => M"                     M "$(tg 'com.x.wallhack' "$TOKS")"
ck "MATCH: com.x.killaura => M"                     M "$(tg 'com.x.killaura' "$TOKS")"
ck "MATCH: libaimbot.so (lib<tok>) => M"            M "$(tg 'libaimbot.so' "$TOKS")"
ck "FP MORTO: TalkBack (marvin) × *bot* => N"        N "$(tg 'com.google.android.marvin.talkback' "$TOKS")"
ck "FP MORTO: com.x.robot × *bot* => N"              N "$(tg 'com.x.robot' "$TOKS")"
ck "FP MORTO: com.x.offhand (ffh no meio) => N"      N "$(tg 'com.x.offhand' "$TOKS")"
ck "FP MORTO: menudrawer × *menu* => N"              N "$(tg 'com.company.menudrawer' "$TOKS")"
ck "FP MORTO: lifehack (hack colado) × *hack* => N"  N "$(tg 'com.lifehack.app' "$TOKS")"
ck "FP MORTO: honeyboard (Samsung) => N"             N "$(tg 'com.samsung.android.honeyboard' "$TOKS")"

echo "# encoding — hex da porta Frida (%04X); prova o M1 (27042≠0xA992, é 0x69A2)"
ck "27042 = 0x69a2" "69a2" "$(printf '%x' 27042)"

echo "# asserção ESTRUTURAL — paridade Frida tcp6 (strings ÚNICAS do bloco novo) + hex CORRETO"
sck "bloco tcp6 novo presente (alert único)"      'Porta Frida em LISTEN (via /proc/net/tcp6)'
sck "hex CORRETO da porta Frida no engine"        ':69A[2345]$'
# anti-asserção: o hex ERRADO (:A99[2345]=43410-43413, range efêmero) NÃO pode reaparecer como
# CÓDIGO — era o M1 crítico. Pina o regex-de-grep completo (`:A99[2345]$'` com fecha-âncora +
# aspa) que só existe em código; o comentário v4.4.105 do engine cita ':A99[2345]' entre aspas
# simples (sem o `$'`) pra documentar o "era X", então NÃO colide. Padrão do gate abaixo.
if grep -qF ":A99[2345]\$'" "$ENGINE"; then
  fail=$((fail+1)); printf '  FAIL (estrutural): %s\n        hex ERRADO da porta Frida (regex :A99[2345]$) reapareceu como codigo no engine\n' "hex :A99[2345] eliminado"
else
  pass=$((pass+1))
fi
# nota: busca o glob-cru como CÓDIGO ativo (`case "$ACC/L" in *esp*|...`), não como texto —
# o comentário v4.4.105 acima cita o padrão antigo entre crases pra documentar o "era X"
# (convenção já usada em v4.4.100/v4.4.103), o que faria um grep -qF genérico se auto-detectar.
if grep -qE '(ACC|L)" in$' "$ENGINE" && grep -A1 -E '(ACC|L)" in$' "$ENGINE" | grep -qF '*esp*|*aimbot*|*menu*|*hack*'; then
  fail=$((fail+1)); printf '  FAIL (estrutural): %s\n        substring-cru de accessibility AINDA presente como CODIGO no engine\n' "case *esp*|*aimbot*|*menu*|*hack* removido"
else
  pass=$((pass+1))
fi

echo "# asserção ESTRUTURAL — #A1 integridade .text libil2cpp (smaps Private_Dirty>0 no r-xp)"
sck "gate #A1 (.text sujo da libil2cpp) presente no engine" 'com .text SUJO em RAM'
sck "#A1 lê Private_Dirty do smaps do FF"                    'Private_Dirty:'

echo "# #A1b — exec anônima ensanduichada no VMA de uma .so (evasão munmap+MAP_ANON do #A1)"
# ax() = réplica EXATA do awk inline do engine; retorna M se flagra, N se não.
ax(){ printf '%s\n' "$1" | awk '
    {
        perms=$2; path=$6
        if (perms ~ /^---/) next
        if (cand) {
            if (path==candlib) { print candlib; cand=0 }
            else if (perms ~ /x/ && path=="") { }
            else { cand=0 }
        }
        if (!cand && perms ~ /x/ && path=="" && prevso) { cand=1; candlib=prevpath }
        if (path != "") { prevpath=path; prevso=(path ~ /\.so$/) }
    }' | grep -q . && echo M || echo N; }
MAPS_HOOK='7b40000000-7b40010000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40010000-7b40020000 r-xp 00000000 00:00 0
7b40020000-7b40030000 r--p 00020000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so'
MAPS_CLEAN='7b40000000-7b40010000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40010000-7b40020000 r-xp 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40020000-7b40030000 rw-p 00020000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so'
MAPS_JIT='7b40000000-7b40010000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40010000-7b40020000 r-xp 00000000 00:00 0 [anon:dalvik-jit-code-cache]
7b40020000-7b40030000 r--p 00020000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so'
MAPS_XLIB='7b40000000-7b40010000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libA.so
7b40010000-7b40020000 r-xp 00000000 00:00 0
7b40020000-7b40030000 r--p 00020000 fe:09 222 /data/app/x/lib/arm64/libB.so'
MAPS_BSS='7b40000000-7b40010000 rw-p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40010000-7b40020000 rw-p 00000000 00:00 0'
# 16KB/linker: guarda ---p entre r--p e o code-seg (o layout REAL de device 16KB — sem
# transparência do ---p, o hook ingênuo escaparia; regressão apontada pela review Fable).
MAPS_HOOK16K='7b40000000-7b40004000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40004000-7b40010000 ---p 00000000 00:00 0
7b40010000-7b40020000 r-xp 00000000 00:00 0
7b40020000-7b40024000 ---p 00000000 00:00 0
7b40024000-7b40030000 r--p 00024000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so'
# hole exec fatiado em 2 VMAs anônimas (evasão barata: a run tem que ser colapsada).
MAPS_2VMA='7b40000000-7b40010000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so
7b40010000-7b40018000 r-xp 00000000 00:00 0
7b40018000-7b40020000 r-xp 00000000 00:00 0
7b40020000-7b40030000 r--p 00020000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so'
# lib remapeada com backing deletado dos dois lados (o $6 ignora o sufixo "(deleted)").
MAPS_DEL='7b40000000-7b40010000 r--p 00000000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so (deleted)
7b40010000-7b40020000 r-xp 00000000 00:00 0
7b40020000-7b40030000 r--p 00020000 fe:09 111 /data/app/x/lib/arm64/libil2cpp.so (deleted)'
ck "#A1b FLAG: anon r-x ensanduichada em libil2cpp"   M "$(ax "$MAPS_HOOK")"
ck "#A1b FLAG: hook 16KB (guardas ---p transparentes)" M "$(ax "$MAPS_HOOK16K")"
ck "#A1b FLAG: hole exec em 2 VMAs anônimas"          M "$(ax "$MAPS_2VMA")"
ck "#A1b FLAG: sanduíche em .so (deleted)"            M "$(ax "$MAPS_DEL")"
ck "#A1b N: lib normal toda file-backed"              N "$(ax "$MAPS_CLEAN")"
ck "#A1b N: JIT [anon:dalvik-jit-code-cache] nomeada" N "$(ax "$MAPS_JIT")"
ck "#A1b N: anon exec entre libs DIFERENTES"          N "$(ax "$MAPS_XLIB")"
ck "#A1b N: anon rw- (.bss), nao exec"                N "$(ax "$MAPS_BSS")"
sck "gate #A1b (exec anônima no VMA de lib) no engine" 'Página EXEC anônima dentro do VMA'
sck "#A1b usa adjacência de .so no maps (prevso)"      'prevso'

echo
if [ "$fail" = 0 ]; then
  printf 'HARNESS OK — %d asserções verdes.\n' "$pass"; exit 0
else
  printf 'HARNESS FALHOU — %d verdes, %d VERMELHAS.\n' "$pass" "$fail"; exit 1
fi
