#!/data/data/com.termux/files/usr/bin/env bash
# ============================================================
#  a4ther — Auditoria de integridade Free Fire via ADB Wi-Fi
#  A4ther Systems · Coletor ativo (ADB Wi-Fi) · v4.4.68
#
#  Assistente passo a passo para auditoria CONSENTIDA de um
#  dispositivo Android (o dono precisa habilitar a Depuração
#  sem fio e autorizar a conexão). UM comando faz TUDO:
#    1) Conexão ADB Wi-Fi (pareamento opcional + connect)
#    2) Seleção do alvo (Free Fire normal / max)
#    3) Verificação CRÍTICA de origem (installerPackageName)
#    4) Scan COMPLETO device + FF VIA adb shell (uid 2000 → destrava
#       serial/HWID/dumpsys). Os RESULTADOS (críticos/suspeitos) são
#       exibidos DIRETO na tela do Termux + um RESUMO consolidado.
#  No FINAL: pergunta se deseja SALVAR o dump completo da análise
#  (relatório .txt + artefatos sensíveis + manifesto SHA-256). Se não,
#  nada é salvo no Termux — a análise fica só na tela (independente).
#
#  Instalação como comando `a4ther`:
#    cp a4ther-adb.sh $PREFIX/bin/a4ther && chmod +x $PREFIX/bin/a4ther
#    (depois é só digitar:  a4ther)
# ============================================================
set -uo pipefail

# ---------- Cores ----------
if [ -t 1 ]; then
  RED=$'\033[1;31m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'
  CYN=$'\033[1;36m'; BLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
else
  RED=''; GRN=''; YLW=''; CYN=''; BLD=''; DIM=''; NC=''
fi

hr()    { printf '%s\n' "${DIM}────────────────────────────────────────────────────────${NC}"; }
info()  { printf '%s\n' "${CYN}ℹ  $*${NC}"; }
ok()    { printf '%s\n' "${GRN}✓  $*${NC}"; }
warn()  { printf '%s\n' "${YLW}⚠  $*${NC}"; }
err()   { printf '%s\n' "${RED}✗  $*${NC}"; }
ask()   { local p="$1" __v; printf '%s' "${BLD}❯ ${p}${NC} " >&2; read -r __v; printf '%s' "$__v"; }
pause() { printf '%s' "${DIM}— Pressione ENTER para continuar —${NC}"; read -r _; }

# Downloader ROBUSTO: wget primeiro (não usa libngtcp2/QUIC, então funciona
# mesmo com o openssl velho do Termux), curl como fallback. Evita o erro
# "cannot locate symbol SSL_set_quic_tls_transport_params" do curl 8.20.
_dl() {  # _dl <url> <arquivo_saida>
  if command -v wget >/dev/null 2>&1 && wget -q -O "$2" "$1" 2>/dev/null; then return 0; fi
  if command -v curl >/dev/null 2>&1 && curl -fsSL -o "$2" "$1" 2>/dev/null; then return 0; fi
  return 1
}

# ALERTA CRÍTICO VISUAL (vermelho, em bloco)
critical() {
  printf '\n%s\n' "${RED}${BLD}╔══════════════════════════════════════════════════════╗${NC}"
  printf '%s\n'   "${RED}${BLD}║                ⛔  ALERTA CRÍTICO  ⛔                 ║${NC}"
  printf '%s\n'   "${RED}${BLD}╚══════════════════════════════════════════════════════╝${NC}"
  while [ "$#" -gt 0 ]; do printf '%s\n' "${RED}  $1${NC}"; shift; done
  printf '\n'
}

banner() {
  clear 2>/dev/null || true
  printf '%s\n' "${CYN}${BLD}"
  cat <<'EOF'
    ___    __ __  __  __
   / _ |  / // / / /_/ /  ___ ____
  / __ | / // /_/ __/ _ \/ -_) __/
 /_/ |_|/_//_/(_)__/_//_/\__/_/    AUDIT · ADB Wi-Fi
EOF
  printf '%s\n' "${NC}${DIM}  Auditoria de integridade · Free Fire · v4.4.68${NC}"
  hr
}

# ---------- Config ----------
TS="$(date +%Y%m%d_%H%M%S)"
# v4.4.67: salva no armazenamento INTERNO compartilhado (/storage/emulated/0),
# visível no gerenciador de arquivos do celular — não mais no $HOME do Termux
# (que só é acessível dentro do Termux). Pede permissão de storage se faltar.
_pick_outroot() {
  local D
  for D in /storage/emulated/0 /sdcard "${HOME}/storage/shared"; do
    [ -d "$D" ] && [ -w "$D" ] && { printf '%s' "$D/a4ther_audits"; return 0; }
  done
  if command -v termux-setup-storage >/dev/null 2>&1; then
    warn "Preciso de permissão de armazenamento pra salvar o relatório onde você consegue abrir."
    info "Vou abrir o pedido de permissão — ACEITE na janela do Android…"
    termux-setup-storage 2>/dev/null; sleep 2
    for D in "${HOME}/storage/shared" /storage/emulated/0 /sdcard; do
      [ -d "$D" ] && [ -w "$D" ] && { printf '%s' "$D/a4ther_audits"; return 0; }
    done
  fi
  warn "Sem acesso ao armazenamento interno — salvando dentro do Termux (${HOME}/a4ther_audits)."
  printf '%s' "${HOME}/a4ther_audits"
}
OUT_ROOT="$(_pick_outroot)"
ADB_TARGET=""        # ip:porta do connect
PKG=""               # pacote escolhido
PKG_LABEL=""
AUDIT_DIR=""         # pasta de saída desta auditoria (definida no step_scan)
REMOTE_A4=""         # caminho do a4ther.sh no device
REMOTE_RPT=""        # caminho do scan_*.txt NO DEVICE (puxado só se o user salvar)
LOG_FILE=""          # log da saída do scan (resumo é montado daqui)
SCAN_TXT=""          # .txt oficial — preenchido só quando o user OPTA por salvar
A4_URL="https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh"

# ---------- 0. Dependências ----------
ensure_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    warn "O 'adb' não está instalado (pacote android-tools)."
    local a; a="$(ask 'Instalar agora com pkg? [s/N]')"
    case "$a" in
      s|S) pkg install -y android-tools || { err "Falha ao instalar android-tools."; exit 1; } ;;
      *)   err "adb é obrigatório. Saindo."; exit 1 ;;
    esac
  fi
  adb start-server >/dev/null 2>&1 || true
}

# ---------- Inputs validados (UX passo-a-passo do pareamento Wi-Fi) ----------
# Cada dado é pedido SEPARADAMENTE, repete até vir válido e explica EXATAMENTE o
# que faltou. O valor sai em REPLY_FIELD (não usa $(...) pra não capturar o
# prompt junto com o valor). O usuário só preenche um campo simples por vez.

# 1) Endereço IP — só números e pontos, 4 octetos de 0 a 255
read_ip() {  # $1 = texto do prompt
  local v prompt="$1"
  while :; do
    printf '%s' "${BLD}❯ ${prompt}${NC} "; read -r v
    v=$(printf '%s' "$v" | tr -d '[:space:]')
    if [ -z "$v" ]; then warn "Campo vazio. Digite o Endereço IP (ex: 192.168.0.10)."; continue; fi
    case "$v" in
      *[!0-9.]*) warn "O IP tem só NÚMEROS e PONTOS — você digitou outro caractere. Tente de novo (ex: 192.168.0.10)."; continue ;;
    esac
    if ( IFS=.; set -- $v; [ "$#" -eq 4 ] || exit 1; for o in "$@"; do { [ -n "$o" ] && [ "$o" -le 255 ] 2>/dev/null; } || exit 1; done; exit 0 ); then
      REPLY_FIELD="$v"; return 0
    fi
    warn "Formato de IP inválido. São 4 números de 0 a 255 separados por ponto (ex: 192.168.0.10)."
  done
}

# 2/4) Porta — SÓ números. $2 = nome amigável ("de pareamento" / "de conexão")
read_port() {  # $1 = prompt · $2 = nome
  local v prompt="$1" nome="$2"
  while :; do
    printf '%s' "${BLD}❯ ${prompt}${NC} "; read -r v
    v=$(printf '%s' "$v" | tr -d '[:space:]')
    if [ -z "$v" ]; then warn "Campo vazio. Digite a PORTA ${nome} (só os números)."; continue; fi
    case "$v" in
      *[!0-9]*) warn "Você digitou letras ou símbolos num campo de NÚMEROS. Tente novamente a Porta ${nome} — só os números, sem o IP e sem os dois-pontos."; continue ;;
    esac
    REPLY_FIELD="$v"; return 0
  done
}

# 3) Código de pareamento — EXATAMENTE 6 dígitos
read_code() {  # $1 = prompt
  local v prompt="$1"
  while :; do
    printf '%s' "${BLD}❯ ${prompt}${NC} "; read -r v
    v=$(printf '%s' "$v" | tr -d '[:space:]')
    case "$v" in
      *[!0-9]*) warn "O código tem só NÚMEROS. Tente de novo o Código de Pareamento de 6 dígitos."; continue ;;
    esac
    if [ "${#v}" -ne 6 ]; then warn "O código precisa ter EXATAMENTE 6 dígitos — você digitou ${#v}. Tente de novo."; continue; fi
    REPLY_FIELD="$v"; return 0
  done
}

# ---------- 1. Conexão ADB Wi-Fi (passo a passo) ----------
step_connect() {
  hr; info "ETAPA 1/4 — Conexão ADB via Wi-Fi (passo a passo)"
  printf '%s\n' "${DIM}  No CELULAR que vai ser escaneado, abra:
    Configurações → Opções do Desenvolvedor → Depuração sem fio
    → toque em 'Parear dispositivo com código de pareamento'

  Vai abrir uma janela com  IP : PORTA  e um  CÓDIGO  de 6 dígitos.
  Deixe essa janela ABERTA e preencha abaixo — um dado por vez.${NC}"

  local ip ppair pcode pconn
  read_ip   "1. Digite apenas o Endereço IP (ex: 192.168.0.10):";                                          ip="$REPLY_FIELD"
  read_port "2. Digite os 5 números da PORTA (os números depois dos ':' na janela de pareamento):" "de pareamento"; ppair="$REPLY_FIELD"
  read_code "3. Digite o Código de Pareamento de 6 dígitos:";                                              pcode="$REPLY_FIELD"

  # Junta IP:Porta em segundo plano — o usuário não precisa saber a sintaxe
  info "Pareando ${ip}:${ppair} …"
  if printf '%s\n' "$pcode" | adb pair "${ip}:${ppair}" 2>&1 | grep -qi 'Successfully paired'; then
    ok "Pareado com sucesso!"
  else
    warn "Pareamento não confirmado. Confira IP/Porta/Código e se a janela de pareamento ainda está aberta. Vou tentar conectar mesmo assim…"
  fi

  # No Android 11+ a porta de CONEXÃO é DIFERENTE da de pareamento. Tenta achar
  # automaticamente via mDNS; se não der, pede ao usuário com instrução clara.
  info "Procurando a porta de conexão do aparelho…"
  pconn=$(adb mdns services 2>/dev/null | grep -i '_adb-tls-connect' | grep -oE "${ip}:[0-9]+" | head -1 | cut -d: -f2)
  if [ -n "$pconn" ]; then
    ok "Porta de conexão encontrada automaticamente: ${pconn}"
  else
    printf '%s\n' "${DIM}  Quase lá! Agora FECHE a janela de pareamento e fique na tela
  'Depuração sem fio'. No alto dela aparece outro  IP : PORTA
  — essa porta de CONEXÃO é diferente da de pareamento.${NC}"
    read_port "4. Digite os números da PORTA de conexão (a da tela 'Depuração sem fio'):" "de conexão"; pconn="$REPLY_FIELD"
  fi

  # Connect com retry
  local tries=0 max=3
  while [ "$tries" -lt "$max" ]; do
    tries=$((tries+1))
    ADB_TARGET="${ip}:${pconn}"
    info "Conectando em ${ADB_TARGET} … (tentativa ${tries}/${max})"
    adb connect "$ADB_TARGET" >/dev/null 2>&1
    sleep 1
    if [ "$(adb -s "$ADB_TARGET" get-state 2>/dev/null)" = "device" ]; then
      ok "Conectado e autorizado: ${ADB_TARGET}"
      adb -s "$ADB_TARGET" shell getprop ro.product.model 2>/dev/null \
        | tr -d '\r' | sed 's/^/   Modelo: /' || true
      return 0
    fi
    err "Não foi possível conectar/autorizar ${ADB_TARGET}. (tentativa ${tries}/${max})"
    adb disconnect "$ADB_TARGET" >/dev/null 2>&1 || true
    if [ "$tries" -lt "$max" ]; then
      read_port "Confira a PORTA de conexão na tela 'Depuração sem fio' e digite de novo:" "de conexão"; pconn="$REPLY_FIELD"
    fi
  done
  err "Conexão falhou após ${max} tentativas. Confirme que o Termux e o celular estão no MESMO Wi-Fi e refaça o pareamento."
  exit 1
}

# ---------- Guarda: Depuração Wi-Fi (ADB) é OBRIGATÓRIA ----------
# Aborta se NÃO há device conectado+autorizado. Chamada antes de TODA etapa de
# análise — não tem como o scanner rodar sem o critério da conexão satisfeito
# (cobre também queda de conexão no meio do fluxo).
require_connected() {
  local st; st="$(adb -s "$ADB_TARGET" get-state 2>/dev/null | tr -d '\r')"
  if [ -z "$ADB_TARGET" ] || [ "$st" != "device" ]; then
    hr
    err "CONEXÃO ADB Wi-Fi AUSENTE — a Depuração sem fio é OBRIGATÓRIA."
    err "O scanner NÃO roda sem device conectado+autorizado. Refaça a ETAPA 1."
    [ -n "$ADB_TARGET" ] && adb disconnect "$ADB_TARGET" >/dev/null 2>&1
    exit 1
  fi
}

# ---------- 2. Seleção de alvo ----------
step_target() {
  require_connected
  hr; info "ETAPA 2/4 — Selecione o jogo a auditar"
  printf '%s\n' "   ${BLD}1)${NC} Free Fire ${DIM}(com.dts.freefireth)${NC}"
  printf '%s\n' "   ${BLD}2)${NC} Free Fire MAX ${DIM}(com.dts.freefiremax)${NC}"
  while :; do
    # Lê DIRETO (sem $(...)): com $(ask) o prompt + códigos de cor ANSI eram
    # capturados JUNTO com o valor e o case NUNCA batia — era a causa do
    # "Opção inválida" mesmo digitando "1".
    local raw c
    printf '%s' "${BLD}❯ Digite 1 ou 2:${NC} "; read -r raw
    # Sanitiza: minúsculas + remove ')' e '.' de menu/pacote + trim + colapsa
    # espaços. Assim "1)", "01", "Free Fire", "com.dts.freefireth", "FF MAX" etc
    # caem todos numa forma canônica.
    c=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ').' \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g')
    case "$c" in
      1|01|ff|freefire|"free fire"|freefireth|comdtsfreefireth)
        PKG="com.dts.freefireth";  PKG_LABEL="Free Fire";     break ;;
      2|02|ffmax|"ff max"|freefiremax|"freefire max"|"free fire max"|comdtsfreefiremax)
        PKG="com.dts.freefiremax"; PKG_LABEL="Free Fire MAX"; break ;;
      "") warn "Você não digitou nada. Digite 1 (Free Fire) ou 2 (Free Fire MAX)." ;;
      *)  err "Jogo não reconhecido. Por favor, digite apenas o número 1 ou 2." ;;
    esac
  done
  ok "Jogo selecionado: ${PKG_LABEL} (${PKG}). Avançando para a ETAPA 3…"
  # Confirma que o pacote existe no device
  if ! adb -s "$ADB_TARGET" shell pm path "$PKG" 2>/dev/null | tr -d '\r' | grep -q '^package:'; then
    err "O pacote ${PKG} NÃO está instalado neste dispositivo."
    exit 1
  fi
  ok "Alvo: ${PKG_LABEL} (${PKG})"
}

# ---------- 3. Verificação crítica de origem (Play Store) ----------
step_origin() {
  require_connected
  hr; info "ETAPA 3/4 — Verificação de origem (installerPackageName)"
  local dump installer
  dump="$(adb -s "$ADB_TARGET" shell dumpsys package "$PKG" 2>/dev/null | tr -d '\r')"
  installer="$(printf '%s\n' "$dump" \
    | grep -m1 -i 'installerPackageName=' \
    | sed -E 's/.*installerPackageName=([^[:space:]]+).*/\1/')"
  [ "$installer" = "null" ] && installer=""

  printf '%s\n' "   Instalador detectado: ${BLD}${installer:-<vazio>}${NC}"

  if [ "$installer" = "com.android.vending" ]; then
    ok "ORIGEM VALIDADA — instalado pela Google Play Store."
    return 0
  fi

  # Qualquer outra origem → ALERTA CRÍTICO + pausa
  local origem
  case "$installer" in
    "")                         origem="VAZIO (sideload / adb install / instalador removeu rastro)" ;;
    com.android.packageinstaller|com.google.android.packageinstaller)
                                origem="Instalador de Pacotes do sistema (APK manual / sideload)" ;;
    com.android.chrome|*chrome*) origem="Navegador Chrome (APK baixado da web)" ;;
    *)                          origem="Fonte externa não-oficial: ${installer}" ;;
  esac
  critical \
    "App: ${PKG_LABEL} (${PKG})" \
    "Origem: ${origem}" \
    "" \
    "O ${PKG_LABEL} NÃO veio da Play Store." \
    "Forte indício de APK MODIFICADO / clonado / repackaged." \
    "Operação PAUSADA para avaliação manual do auditor."
  warn "Recomendação: NÃO confie nos arquivos sem inspeção. Veredito provável: W.O / REVISAR."
  local cont; cont="$(ask 'Continuar mesmo assim e coletar artefatos para perícia? [s/N]')"
  case "$cont" in
    s|S) warn "Prosseguindo em MODO PERÍCIA (origem suspeita registrada)." ;;
    *)   err "Auditoria interrompida pelo auditor."; exit 2 ;;
  esac
}

# ---------- 4. Scan COMPLETO device + FF + RESUMO na tela ----------
# Roda o a4ther.sh como uid 2000 (shell): destrava serial/HWID/dumpsys +
# análise completa do FF. A saída aparece AO VIVO na tela; depois montamos
# um RESUMO de CRÍTICOS/SUSPEITOS. NADA é puxado aqui — o save é opcional.
step_scan() {
  require_connected
  hr; info "ETAPA 4/4 — Scan completo do device + Free Fire (via adb shell)"
  AUDIT_DIR="${OUT_ROOT}/${TS}_${PKG##*.}"
  mkdir -p "$AUDIT_DIR"
  LOG_FILE="${AUDIT_DIR}/_scan_console.log"

  # 1) Garante o a4ther.sh localmente (no Termux)
  local a4="${HOME}/a4ther.sh"
  if [ ! -s "$a4" ]; then
    info "Baixando o scanner principal (a4ther.sh)…"
    if ! _dl "$A4_URL" "$a4"; then
      err "Falha ao baixar o a4ther.sh ($A4_URL). Pulando scan completo."
      return 1
    fi
  fi
  ok "Scanner principal pronto ($(wc -c < "$a4" 2>/dev/null || echo '?') bytes)."

  # 2) Envia pro dispositivo (push funciona p/ loopback e remoto)
  info "Enviando o scanner pro dispositivo…"
  if adb -s "$ADB_TARGET" push "$a4" /sdcard/Download/a4ther.sh >/dev/null 2>&1; then
    REMOTE_A4="/sdcard/Download/a4ther.sh"
  elif adb -s "$ADB_TARGET" push "$a4" /data/local/tmp/a4ther.sh >/dev/null 2>&1; then
    REMOTE_A4="/data/local/tmp/a4ther.sh"
  else
    err "adb push falhou (Scoped Storage/OEM). Não foi possível enviar o scanner."
    return 1
  fi
  ok "Enviado: ${REMOTE_A4}"

  # 3) Roda VIA adb shell (uid 2000 → acesso elevado). Sem -t = não-interativo,
  #    o a4ther.sh detecta e pula as pausas. SKIP_WIFI_PROMPT por segurança.
  info "Rodando o scan com acesso elevado (adb shell, uid 2000)…"
  info "Leva de 1 a 3 minutos — não feche o Termux. (resultados aparecem abaixo)"
  hr
  adb -s "$ADB_TARGET" shell "SKIP_WIFI_PROMPT=1 sh ${REMOTE_A4}" 2>&1 \
    | tee "$LOG_FILE"
  hr

  # 4) Só LOCALIZA o .txt no device (NÃO puxa — fica pro save opcional)
  REMOTE_RPT="$(adb -s "$ADB_TARGET" shell "ls -t /sdcard/a4ther/a4ther_reports/scan_*.txt 2>/dev/null | head -n1" | tr -d '\r')"
  [ -z "$REMOTE_RPT" ] && REMOTE_RPT="$(adb -s "$ADB_TARGET" shell "ls -t /sdcard/Download/scan_*.txt 2>/dev/null | head -n1" | tr -d '\r')"

  # 5) RESUMO consolidado de críticos/suspeitos NA TELA
  show_resumo "$LOG_FILE"
}

# ---------- RESUMO na tela: extrai ALERTA/AVISO do log do a4ther.sh ----------
# O a4ther.sh marca "●  ALERTA" (crítico) e "●  AVISO" (suspeito). Aqui a gente
# tira os códigos de cor, pega só essas linhas e re-imprime um bloco enxuto —
# os RESULTADOS críticos/suspeitos direto na tela, independente do .txt.
show_resumo() {
  local log="$1"
  local ESC; ESC="$(printf '\033')"
  if [ ! -s "$log" ]; then warn "Sem log do scan — não dá pra montar o resumo."; return; fi

  local plain alerts warns nA nW
  plain="$(sed "s/${ESC}\[[0-9;]*m//g" "$log" 2>/dev/null)"
  alerts="$(printf '%s\n' "$plain" | grep -E '●[[:space:]]+ALERTA' | sed -E 's/.*ALERTA[[:space:]]+//' | sed 's/[[:space:]]*$//')"
  warns="$( printf '%s\n' "$plain" | grep -E '●[[:space:]]+AVISO'  | sed -E 's/.*AVISO[[:space:]]+//'  | sed 's/[[:space:]]*$//')"
  nA="$(printf '%s\n' "$alerts" | grep -c . 2>/dev/null || echo 0)"
  nW="$(printf '%s\n' "$warns"  | grep -c . 2>/dev/null || echo 0)"

  printf '\n%s\n' "${CYN}${BLD}╔══════════════════════════════════════════════════════╗${NC}"
  printf '%s\n'   "${CYN}${BLD}║        RESUMO DA ANÁLISE  ·  CRÍTICOS / SUSPEITOS     ║${NC}"
  printf '%s\n'   "${CYN}${BLD}╚══════════════════════════════════════════════════════╝${NC}"

  if [ "${nA:-0}" -gt 0 ]; then
    printf '\n%s\n' "${RED}${BLD}  ⛔ CRÍTICOS (${nA})${NC}"
    printf '%s\n' "$alerts" | while IFS= read -r l; do [ -n "$l" ] && printf '   %s\n' "${RED}✗  ${l}${NC}"; done
  fi
  if [ "${nW:-0}" -gt 0 ]; then
    printf '\n%s\n' "${YLW}${BLD}  ⚠ SUSPEITOS (${nW})${NC}"
    printf '%s\n' "$warns" | while IFS= read -r l; do [ -n "$l" ] && printf '   %s\n' "${YLW}•  ${l}${NC}"; done
  fi

  printf '\n'
  if [ "${nA:-0}" -gt 0 ]; then
    printf '%s\n' "${RED}${BLD}  ►  VEREDITO: ${nA} crítico(s) → SUSPEITO DE CHEAT (W.O).${NC}"
  elif [ "${nW:-0}" -gt 0 ]; then
    printf '%s\n' "${YLW}${BLD}  ►  VEREDITO: 0 crítico · ${nW} suspeito(s) → REVISAR.${NC}"
  else
    printf '%s\n' "${GRN}${BLD}  ►  VEREDITO: nenhum alerta/aviso → LIMPO.${NC}"
  fi
  hr
}

# ---------- Coleta dos artefatos (SÓ roda quando o user OPTA por salvar) ----------
pull_artifacts() {
  local base="/sdcard/Android/data/${PKG}/files"
  local out="$AUDIT_DIR"
  info "Coletando artefatos sensíveis de ${base}…"
  if ! adb -s "$ADB_TARGET" shell "[ -d '$base' ] && echo OK" 2>/dev/null | tr -d '\r' | grep -q OK; then
    warn "Diretório ${base} inacessível (Scoped Storage/OEM ou precisa de root). Tentando assim mesmo."
  fi
  local list="${out}/_filelist.txt"
  adb -s "$ADB_TARGET" shell \
    "find '$base' -type f \( -iname '*.bin' -o -iname '*.json' -o -ipath '*mreplay*' -o -ipath '*shader*' \) 2>/dev/null" \
    | tr -d '\r' > "$list"
  local total; total="$(grep -c . "$list" 2>/dev/null || echo 0)"
  if [ "$total" -eq 0 ]; then
    warn "Nenhum artefato encontrado (acesso bloqueado, jogo nunca aberto, ou caminho diferente)."
  else
    info "${total} arquivo(s) candidato(s). Puxando…"
    local pulled=0 failed=0 remote rel localdir
    while IFS= read -r remote; do
      [ -z "$remote" ] && continue
      rel="${remote#/sdcard/}"; localdir="${out}/$(dirname "$rel")"; mkdir -p "$localdir"
      if adb -s "$ADB_TARGET" pull "$remote" "$localdir/" >/dev/null 2>&1; then
        pulled=$((pulled+1)); printf '%s\r' "${DIM}   ✓ ${pulled}/${total}${NC}"
      else
        failed=$((failed+1)); warn "falhou: $rel"
      fi
    done < "$list"
    printf '\n'; ok "Artefatos: ${pulled} extraídos · ${failed} falha(s)"
  fi

  info "Gerando manifesto SHA-256…"
  ( cd "$out" && find . -type f ! -name '_*' -print0 2>/dev/null \
      | xargs -0 sha256sum 2>/dev/null | sort ) > "${out}/_integrity_sha256.txt"
  local hashed; hashed="$(grep -c . "${out}/_integrity_sha256.txt" 2>/dev/null || echo 0)"
  {
    echo "A4ther Audit · v4.4.68"
    echo "data         : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "alvo         : ${PKG_LABEL} (${PKG})"
    echo "device       : ${ADB_TARGET}"
    echo "modelo       : $(adb -s "$ADB_TARGET" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    echo "fingerprint  : $(adb -s "$ADB_TARGET" shell getprop ro.build.fingerprint 2>/dev/null | tr -d '\r')"
    echo "relatorio    : ${SCAN_TXT:-<não salvo>}"
    echo "artefatos    : ${total:-0} candidatos / ${hashed} com hash"
  } > "${out}/_audit_meta.txt"
}

# ---------- Opção final: SALVAR o dump completo? ----------
save_dump() {
  hr
  local d; d="$(ask 'Deseja SALVAR o dump completo da análise (relatório .txt + artefatos + SHA-256)? [s/N]')"
  case "$d" in
    s|S) : ;;
    *)
      # salvaguarda: só apaga se o caminho for MESMO a pasta de audits desta run
      case "$AUDIT_DIR" in */a4ther_audits/*|*/a4ther/audits/*) [ -n "$AUDIT_DIR" ] && rm -rf "$AUDIT_DIR" 2>/dev/null ;; esac
      # limpa o rastro NO DEVICE também: o .txt que o a4ther.sh gerou + cópia em
      # Downloads + o script enviado. Assim "não salvar" = nada fica em lugar nenhum.
      if [ -n "$REMOTE_RPT" ]; then
        adb -s "$ADB_TARGET" shell "rm -f '$REMOTE_RPT' '/sdcard/Download/$(basename "$REMOTE_RPT")'" >/dev/null 2>&1
      fi
      [ -n "$REMOTE_A4" ] && adb -s "$ADB_TARGET" shell "rm -f '$REMOTE_A4'" >/dev/null 2>&1
      ok "Dump descartado — análise só na tela; limpei o .txt e o script do device."
      info "Pra refazer e salvar, é só rodar o a4ther de novo."
      return 0 ;;
  esac

  info "Salvando o dump completo em ${AUDIT_DIR}…"
  # 1) puxa o relatório .txt do device
  if [ -n "$REMOTE_RPT" ]; then
    if adb -s "$ADB_TARGET" pull "$REMOTE_RPT" "${AUDIT_DIR}/" >/dev/null 2>&1; then
      SCAN_TXT="${AUDIT_DIR}/$(basename "$REMOTE_RPT")"
      ok "Relatório salvo: $(basename "$SCAN_TXT")"
    else
      warn "Relatório está em ${REMOTE_RPT} no device, mas o pull falhou — pegue manualmente."
    fi
  else
    warn "Não encontrei o scan_*.txt no device (veja ${LOG_FILE})."
  fi
  # 2) artefatos + manifesto + meta
  pull_artifacts

  hr
  ok "Dump salvo em:"
  printf '   %s\n' "${BLD}${AUDIT_DIR}${NC}"
  [ -n "$SCAN_TXT" ] && \
  printf '   %s\n' "${GRN}• $(basename "$SCAN_TXT")   ← RELATÓRIO p/ enviar ao A4ther${NC}"
  printf '   %s\n' "${DIM}• _scan_console.log     (saída completa do scan)${NC}"
  printf '   %s\n' "${DIM}• _filelist.txt         (lista de artefatos)${NC}"
  printf '   %s\n' "${DIM}• _integrity_sha256.txt (hashes p/ comparação)${NC}"
  printf '   %s\n' "${DIM}• _audit_meta.txt       (contexto do device)${NC}"
  [ -n "$SCAN_TXT" ] && info "ENVIE o ${BLD}$(basename "$SCAN_TXT")${NC}${CYN} ao A4ther (site, modo 'Android · scan TXT')."
}

# ---------- main ----------
main() {
  banner
  warn "Use APENAS em dispositivo próprio ou com consentimento explícito do dono."
  ensure_adb
  step_connect
  step_target
  step_origin
  step_scan
  save_dump
  hr; ok "Concluído."
  local d; d="$(ask 'Desconectar o adb agora? [s/N]')"
  case "$d" in s|S) adb disconnect "$ADB_TARGET" >/dev/null 2>&1 && ok "Desconectado." ;; esac
}

main "$@"
