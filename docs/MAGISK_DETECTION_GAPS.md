# Estudo `apkunpacker/MagiskDetection` → lacunas e oportunidades para o `a4ther.sh`

> **Status:** documento de **referência/planejamento** (não é mudança de engine).
> **Data:** 2026-06-23 · **Engine analisado:** `a4ther.sh` v4.4.95
> **Fonte estudada:** <https://github.com/apkunpacker/MagiskDetection> + repos open-source referenciados.
> **Nada aqui foi aplicado ao `a4ther.sh`.** Os snippets são **propostas** — exigem `sh -n`,
> teste em device e re-geração do `.enc` antes de qualquer merge (ver §8). Mudança no engine
> passa por branch + PR com revisão (regra do projeto).

---

## 1. O que o repositório é (e o que dele tem valor de fonte)

`apkunpacker/MagiskDetection` **não é uma biblioteca de código** — é uma **coletânea de POCs**
(29 APKs compilados: Momo, Ruru, Holmes, Hunter, Native-Root-Detector da reveny, RootBeer,
MinotaurPoc/NativeTest, OprekDetector, SafeCheck, DetectZ, DirtySepolicy, etc.) + um `README.md`
que **cataloga as técnicas** de cada um. O valor de *fonte* veio de:

| Fonte | Natureza | Uso neste estudo |
|---|---|---|
| **`Duck-Detector-Refactoring`** | Fonte C++/ASM completa (14 módulos) — incluída em zip no repo | **Achado principal**: cobre todas as categorias dos outros, em código legível |
| `apkunpacker/DetectZygisk` | Fonte C++ | Detecção de forks Zygisk via ptrace (ReZygisk/ZygiskNext/NeoZygisk) |
| `JingMatrix/Demo` | Fonte C++ | Anomalias de `/proc/<pid>/maps` (injeção em memória) |
| `LSPosed/DirtySepolicy` | Fonte Java | Detecção via existência de domínios SELinux (robusta contra hiding) |
| `vvb2060/MagiskDetector` | Fonte C | Magic-mount diffing por `dev` de `/data` × `maps`; MagiskHide via TracerPid |
| `scottyab/rootbeer`, `Ruru` | Fonte | Baselines clássicos + triangulação de existência de arquivo |
| `reveny/Native-Root-Detector` | `.so` fechado (só UI) | Mapa de prioridades (release notes): magic-mount, injection, Shamiko, key attestation |

Os repos clonados ficam em `_research-magiskdetection/` (irmão do repo, **fora** do git do scanner).

---

## 2. A lente que define a portabilidade

O `a4ther.sh` observa **de fora**, como **uid 2000** (grupo `readproc`), sem root (salvo fallback
`have su`). Isso muda tudo:

- **`readproc` dá** `/proc/$FF_PID/{maps,smaps,status,task,fd,mountinfo,mounts,cmdline,attr/current}`
  do Free Fire — **mas NÃO `/proc/$FF_PID/mem`** (isso exige `ptrace`/mesmo-uid/root).
- **Porta direto**: file/path, prop (`getprop`), mount (`mountinfo`/`mounts`), SELinux (`getenforce`,
  `attr/current`), package (`pm`), `cmdline`, `kallsyms`.
- **Porta adaptado**: ideias in-process que viram leitura **do `/proc` do FF** (ex.: "detecção de
  injeção em memória" → varrer `/proc/$FF_PID/maps`).
- **NÃO porta** (vira recomendação de helper nativo no APK): leitura de **bytes** de memória/heap,
  prólogos de função (inline/GOT hook), `prctl`/`ioctl`/`reboot` com magic, KeyStore/TEE, ASM/timing.

> **Ângulo de ouro:** a ocultação (denylist/Shamiko) age **por-processo** — esconde montagens só no
> mount namespace do FF. Como o scanner roda em **outro** processo e lê o `/proc` do FF, ele enxerga
> exatamente o que a denylist não cobre. As técnicas estruturais (mount-id gap, `dev` de `/data`,
> contexto SELinux, `native.bridge`) são as de **menor FP** porque dependem de relação, não de string.

---

## 3. Cobertura atual do `a4ther.sh` (para deixar o delta claro)

Forte e **não deve ser refeito**:

- **KernelSU/APatch** — multi-vetor (path + prop + kallsyms + dmesg + uname + módulos + pacotes).
- **Mount magic-mount** — global (`MNT_SIG` em `/proc/mounts` **e** `/proc/self/mountinfo`) **e
  diff de namespace do FF** (`/proc/$FF_PID/mountinfo` × visão global — [a4ther.sh:1054](../a4ther.sh)).
- **Frida** — FS + rede (portas 27042-45) + socket abstrato + `maps` + threads + crashes.
- **`/proc/$FF_PID/*`** — TracerPid ([a4ther.sh:1019](../a4ther.sh)), maps injetados
  ([a4ther.sh:1129](../a4ther.sh)), task/comm, net/tcp, cmdline.
- **~80 pacotes** suspeitos; **suSFS**, hide/Shamiko por path/módulo; **TrickyStore keybox** por path.

Lacunas confirmadas **direto na fonte** (não no relato de agente):

| Lacuna | Evidência no `a4ther.sh` |
|---|---|
| **Emulador/virtualização — ZERO** | `native.bridge`/`qemu`/`goldfish`/`ranchu`/`qemu_pipe`/`houdini` = 0 matches |
| **Zygisk/Riru injetado no FF escapa** | regex de [a4ther.sh:1129](../a4ther.sh) não tem `zygisk`/`libriru`/`.magisk`/`memfd:frida` |
| **dm-verity nunca vira veredito** | `ro.boot.veritymode` só dumpado no payload ([a4ther.sh:5666](../a4ther.sh)) |
| **Contexto SELinux do FF/PIDs não checado** | `attr/current` = 0 matches (só `getenforce` global) |
| **Socket do magiskd** | `/proc/net/unix` só grepado p/ `@frida` ([a4ther.sh:1150](../a4ther.sh)) |
| **Spoof de prop (resetprop)** | sem cross-check `getprop` × `/proc/cmdline` |

---

## 4. TIER 1 — alto valor, portável, baixo-FP, barato

> Convenção dos snippets: helpers `alert`/`warn`/`ok`/`info`/`header`, `gp` (=`getprop`),
> `exists`, `pkg_installed`; tallies por módulo (`KERNEL_HITS`/`DFIR_HITS`/…); guarda de `$FF_PID`
> + degradação honesta (`warn` inconclusivo, **nunca** `ok` falso). POSIX `sh`, comentários pt-BR.

### 4.1 — Detecção de emulador / virtualização  *(módulo novo)*
**O que pega:** cheat em emulador (endêmico no FF) + BlueStacks/LDPlayer/Genymotion (tradução de ISA).
**Fonte:** Duck `virtualization/snapshot_builder.cpp:134-411`. **FP:** baixo (estrutural).
**Onde:** novo bloco `EMU_HITS` perto do bloco de bootloader/kernel (~l.473).

```sh
# ── Emulador / Virtualização (v4.4.95) ───────────────────────────────────────
# native.bridge≠0 num "device físico" é flagrante; cheat em emulador é endêmico no FF.
header "Emulador / Virtualização"
EMU_HITS=0
[ "$(gp ro.kernel.qemu)" = "1" ] && { alert "ro.kernel.qemu=1 (ambiente QEMU)"; EMU_HITS=$((EMU_HITS+1)); }
NB=$(gp ro.dalvik.vm.native.bridge)
case "$NB" in
  ""|0) : ;;
  *) alert "native.bridge ATIVO ($NB) — tradução ARM↔x86 (BlueStacks/LDPlayer/Genymotion)"; EMU_HITS=$((EMU_HITS+1)) ;;
esac
for K in ro.hardware ro.boot.hardware ro.product.board ro.board.platform; do
  V=$(gp "$K"); case "$V" in *goldfish*|*ranchu*) alert "$K=$V (emulador goldfish/ranchu)"; EMU_HITS=$((EMU_HITS+1)) ;; esac
done
for P in /dev/qemu_pipe /dev/qemu_trace /dev/goldfish_pipe /dev/socket/qemud; do
  exists "$P" && { alert "Device-node de emulador: $P"; EMU_HITS=$((EMU_HITS+1)); }
done
# Libs de tradução de ISA dentro do FF (libhoudini = Intel x86→ARM)
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/maps" ]; then
  TR=$(grep -iE 'libhoudini|libnb\.so|libndk_translation' "/proc/$FF_PID/maps" 2>/dev/null | awk '{print $6}' | sort -u)
  [ -n "$TR" ] && { alert "Lib de tradução ISA no FF (emulador): $(echo $TR)"; EMU_HITS=$((EMU_HITS+1)); }
fi
[ "$EMU_HITS" = 0 ] && ok "Sem indícios de emulador/virtualização"
```

### 4.2 — Tokens de Zygisk/Riru/memfd no `maps` do FF  *(extensão de 1 linha)*
**O que pega:** Zygisk/Riru injetado **no processo do jogo** — hoje escapa.
**Fonte:** Duck `mount/detector_core.cpp:586`, `zygisk/vmap_probe.cpp:18`, vvb2060.
**Onde:** [a4ther.sh:1129](../a4ther.sh). **FP:** baixo (já é só o maps do FF).

```sh
# ANTES (l.1129): '(frida|gadget|substrate|libdobby|libxhook|libgum|libwhale|libsandhook|
#                   libepic|libDexposed|libsubstitute|libellekit|libhooker|cydia|tweak)'
# ADICIONAR ao alternation: |zygisk|libriru|libriru_|/\.magisk/|/sbin/\.magisk
#   (mantém o awk '{print $6}' — são todos match de pathname)

# E, logo após (v4.4.95): .so executável DELETADO + memfd suspeito (col. de perms = $2)
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/maps" ]; then
  DELEXEC=$(awk '$2 ~ /x/ && /\.so \(deleted\)/ {print $6}' "/proc/$FF_PID/maps" 2>/dev/null | sort -u | head -5)
  [ -n "$DELEXEC" ] && { alert "Lib executável DELETADA no FF (injeção residente): $(echo $DELEXEC)"; DFIR_HITS=$((DFIR_HITS+1)); }
  MEMFD=$(awk '$2 ~ /x/ && tolower($0) ~ /memfd:.*(frida|magisk|zygisk|riru)|\/dev\/zero/ {print $6}' "/proc/$FF_PID/maps" 2>/dev/null | sort -u | head -5)
  [ -n "$MEMFD" ] && { alert "Memória executável anônima suspeita no FF: $(echo $MEMFD)"; DFIR_HITS=$((DFIR_HITS+1)); }
fi
```

### 4.3 — Contexto SELinux do FF  *(net-new)*
**O que pega:** FF rodando em domínio `su`/`magisk`/`permissive` — flagrante.
**Fonte:** Duck `su/native_bridge.cpp:153`, `self_process_ioc_probe.cpp:33`. **FP:** baixo.
**Onde:** bloco `DFIR_HITS` (junto das leituras de `/proc/$FF_PID/*`, ~l.1019).

```sh
# Contexto SELinux do FF — esperado u:r:untrusted_app*; su/magisk/permissive = crítico (v4.4.95)
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/attr/current" ]; then
  FFCTX=$(tr -d '\0' < "/proc/$FF_PID/attr/current" 2>/dev/null)
  case "$FFCTX" in
    u:r:untrusted_app*|"") : ;;
    *:su:*|*permissive*|*magisk*|*kernelsu*|*adbroot*) alert "FF em contexto SELinux de ROOT: $FFCTX"; DFIR_HITS=$((DFIR_HITS+1)) ;;
    *) warn "FF em contexto SELinux inesperado: $FFCTX (revisar — pode ser app isolado legítimo)"; DFIR_HITS=$((DFIR_HITS+1)) ;;
  esac
fi
```

### 4.4 — dm-verity como veredito + cmdline  *(net-new; hoje só dumpado)*
**O que pega:** dm-verity desligado (pré-condição de patch de partição).
**Fonte:** Duck `kernelcheck/native_bridge.cpp:32`. **FP:** baixo.
**Onde:** bloco de bootloader (`KERNEL_HITS`, ~l.475-499).

```sh
# dm-verity (v4.4.95) — hoje ro.boot.veritymode só vai no payload (l.5666), nunca vira alerta
case "$(gp ro.boot.veritymode)" in
  enforcing|"") : ;;
  *) alert "dm-verity NÃO enforcing (veritymode=$(gp ro.boot.veritymode))"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac
CMDLINE=$(cat /proc/cmdline 2>/dev/null)
case "$CMDLINE" in
  *androidboot.enable_dm_verity=0*) alert "cmdline: enable_dm_verity=0"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
esac
case "$CMDLINE" in *' init=/sbin'*|*magisk*|*' ksu'*|*apatch*) warn "cmdline contém marcador de root/init custom"; KERNEL_HITS=$((KERNEL_HITS+1)) ;; esac
```

### 4.5 — Cross-check prop × cmdline (anti-resetprop)  *(net-new)*
**O que pega:** spoof de `ro.boot.*` via resetprop (a prop diverge do cmdline real do boot).
**Fonte:** Duck `systemproperties/native_bridge.cpp:65`. **FP:** baixo (divergência objetiva).
**Onde:** bloco de bootloader (`KERNEL_HITS`).

```sh
# Spoof de verifiedbootstate: prop resolvida ≠ cmdline real do kernel (v4.4.95)
PROP_VBS=$(gp ro.boot.verifiedbootstate)
CMD_VBS=$(printf '%s' "${CMDLINE:-$(cat /proc/cmdline 2>/dev/null)}" | grep -o 'androidboot\.verifiedbootstate=[^ ]*' | cut -d= -f2)
if [ -n "$PROP_VBS" ] && [ -n "$CMD_VBS" ] && [ "$PROP_VBS" != "$CMD_VBS" ]; then
  alert "verifiedbootstate DIVERGENTE: prop=$PROP_VBS × cmdline=$CMD_VBS (resetprop/spoof)"; KERNEL_HITS=$((KERNEL_HITS+1))
fi
```

### 4.6 — Mount-forense estrutural (complementa o diff atual)  *(net-new)*
**O que pega:** bind-mount granular em system + overlay/tmpfs sobre system (systemless patch).
**Fonte:** Duck `mount/detector_core.cpp:784,999`. **FP:** baixo (relação estrutural).
**Onde:** módulo de mount (junto do diff de namespace do FF).

```sh
# Bind-mount em system no namespace do FF (4ª col. do mountinfo = root != "/") (v4.4.95)
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/mountinfo" ]; then
  BINDSYS=$(awk '$5 ~ /^\/(system|vendor|product|system_ext|odm)(\/|$)/ && $4 != "/" {print $5" (root="$4")"}' \
            "/proc/$FF_PID/mountinfo" 2>/dev/null | head -5)
  [ -n "$BINDSYS" ] && { alert "Bind-mount em system no FF (magic-mount granular): $BINDSYS"; DFIR_HITS=$((DFIR_HITS+1)); }
fi
# Tipo de filesystem das partições system (visão global) — overlay/tmpfs = patch systemless
for MP in /system /vendor /product; do
  case "$(stat -f -c %T "$MP" 2>/dev/null)" in
    overlayfs|overlay) alert "$MP é overlayfs (systemless patch)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
    tmpfs)             alert "$MP é tmpfs (anômalo — hide-mount)"; KERNEL_HITS=$((KERNEL_HITS+1)) ;;
  esac
done
```

> **Avançado (mesmo módulo):** *mount-id gap* — gap na 1ª coluna do `mountinfo` logo após
> `/apex/com.android.art` ou antes de `/data_mirror` indica mounts **desmontados** para esconder
> (pega hiding já "limpo"). Forte, mas exige anti-FP cuidadoso (Duck usa `missingCount>=3` +
> checagem de fronteira). Implementar com calibração, não no primeiro corte.

### 4.7 — Props de root-manager (variantes) + PlayIntegrityFix  *(parte net-new)*
**O que pega:** KSU/APatch por prop de versão; **PIF** = indicador forte de root+hiding ativo.
**Fonte:** Duck `nativeroot/property_probe.cpp:19`, `playintegrityfix/…Catalog.kt:15`. **FP:** baixo.
**Onde:** bloco kernel/prop. **Nota:** `ro.kernel.ksu` **já** existe em [a4ther.sh:585](../a4ther.sh) — **não duplicar**; abaixo só o que falta.

```sh
# Variantes de prop de root-manager ainda não cobertas (ro.kernel.ksu já está na l.585) (v4.4.95)
for K in ro.ksu.version ro.kernel.apatch ro.apatch.version ro.kernel.kpatch; do
  V=$(gp "$K"); [ -n "$V" ] && { alert "Prop de root-manager: $K=$V"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done
# PlayIntegrityFix — quase onipresente em device de FF com root oculto
for K in persist.sys.spoof.gms persist.sys.pihooks.disable.gms persist.sys.pihooks_BRAND \
         persist.sys.pihooks_MODEL persist.sys.pixelprops.gms persist.sys.pixelprops.pi; do
  V=$(gp "$K"); [ -n "$V" ] && { warn "PlayIntegrityFix prop: $K=$V (bypass de atestação ativo)"; PIF_HITS=$((PIF_HITS+1)); }
done
```

---

## 5. TIER 2 — bom valor, mais trabalho ou condicional

### 5.1 — fd do FF apontando para `.so (deleted)` / paths de root
**Fonte:** Duck `zygisk/fd_probe.cpp:10`. **Onde:** `DFIR_HITS`.
```sh
if [ -n "$FF_PID" ] && [ -d "/proc/$FF_PID/fd" ]; then
  FDHIT=$(ls -l "/proc/$FF_PID/fd/" 2>/dev/null | grep -iE '\.so \(deleted\)|/data/adb|zygisk|magisk|riru' | grep -v '/cache/' | head -5)
  [ -n "$FDHIT" ] && { alert "fd do FF p/ módulo deletado/root (persistência de injeção)"; DFIR_HITS=$((DFIR_HITS+1)); }
fi
```

### 5.2 — `smaps` do FF: patch in-memory de libs de system
**Fonte:** Duck `zygisk/smaps_probe.cpp:8`. **Sketch — validar o awk em device:**
```sh
# Regiões exec de /system|/vendor|/apex com Private_Dirty+Shared_Dirty >= 8 KiB = código patchado
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/smaps" ]; then
  DIRTY=$(awk '
    /^[0-9a-f]+-[0-9a-f]+ ..x. / { e=($0 ~ /\/(system|vendor|apex)/); pd=0; sd=0; rng=$1 }
    /^Private_Dirty:/ { pd=$2 }
    /^Shared_Dirty:/  { if (e && (pd+$2)>=8) print rng" ("pd"+"$2" KiB)" }
  ' "/proc/$FF_PID/smaps" 2>/dev/null | head -3)
  [ -n "$DIRTY" ] && { alert "Código de system PATCHADO em memória no FF: $DIRTY"; DFIR_HITS=$((DFIR_HITS+1)); }
fi
```

### 5.3 — ctime de `ns/mnt` no passado (FutileHide) — pega hiding já "limpo"
**Fonte:** Duck `preload/early_detector.cpp:277`.
```sh
# Se o mount-namespace do FF foi modificado ANTES do processo iniciar, o ctime denuncia
if [ -n "$FF_PID" ] && [ -e "/proc/$FF_PID/ns/mnt" ]; then
  NSCT=$(stat -c %Z "/proc/$FF_PID/ns/mnt" 2>/dev/null)         # ctime do namespace
  STARTJ=$(awk '{print $22}' "/proc/$FF_PID/stat" 2>/dev/null)  # starttime em jiffies (campo 22)
  # comparar NSCT (epoch) com o boot-epoch + STARTJ/HZ; anomalia se ns/mnt for muito anterior ao start.
  # Requer HZ (getconf CLK_TCK) + /proc/uptime; cálculo a calibrar — marcar warn, não alert.
  info "FutileHide check: ns/mnt ctime=$NSCT vs start(jiffies)=$STARTJ (calibrar comparação)"
fi
```

### 5.4 — DirtySepolicy (existência de domínio SELinux)  ⚠️ **precisa teste de campo**
**O que pega:** Magisk/KSU/APatch mesmo com arquivos escondidos **e** Enforcing — a regra de
sepolicy injetada é consultável. **Robusta contra file-hiding.**
**Fonte:** `LSPosed/DirtySepolicy` `AppZygote.java:33`.
**⚠️ Incerteza:** o probe original roda em `app_zygote` (contexto privilegiado). Sob uid 2000
(`u:r:shell:s0`) **não está confirmado** que `/sys/fs/selinux/context` ou `/proc/self/attr/current`
sejam graváveis para o teste `EINVAL`×`EPERM`. **Fazer um teste dedicado num device com Magisk/KSU
antes de confiar nos códigos de retorno.**
```sh
# PROVA DE CONCEITO — validar empiricamente em device rootado antes de usar como veredito
ctx_exists() {  # 0 = domínio existe; 1 = não existe; 2 = inconclusivo (sem acesso)
  printf '%s' "$1" > /sys/fs/selinux/context 2>/dev/null && return 0
  case $? in 1) return 1 ;; *) return 2 ;; esac
}
for CTX in u:r:magisk:s0 u:object_r:magisk_file:s0 u:r:ksu:s0 u:object_r:ksu_file:s0 u:r:adbroot:s0; do
  ctx_exists "$CTX" && { alert "Domínio SELinux de root presente (dirtysepolicy): $CTX"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done
```

### 5.5 — Socket abstrato do magiskd  ⚠️ rendimento menor
**Fonte:** Agent B. Estender [a4ther.sh:1150](../a4ther.sh) com `@magisk`. **Ressalva:** Magisk
moderno **randomiza** o nome do socket → baixo rendimento; incluir como sinal fraco, não headline.

### 5.6 — Triangulação de existência de arquivo (Ruru)
**O que pega:** root-cloak que intercepta **um** método de acesso. **Divergência** entre
`[ -e ]` × `ls` × `stat` num artefato = hiding ativo (sinal mais forte que mera ausência).
**Fonte:** Ruru `file_detection.cpp:25`. Refina os checks de path existentes (não é módulo novo).

---

## 6. NÃO-PORTÁVEIS — empurrar para um helper nativo no APK

O APK (`ssonato/a4ther-scanner-apk`) já dirige o `a4ther.sh` como uid 2000 via ADB. Ele poderia
embarcar um **helper ELF mínimo** (push via ADB, exec, parse da saída) para cobrir o que o shell
não alcança. Em ordem de impacto:

| Técnica | Por que não-portável | Valor | Fonte |
|---|---|---|---|
| **KSU `prctl(0xDEADBEEF,2)` / supercall `reboot`+`ioctl`** | syscalls cruas com magic | **Maior gap** — detecção direta de KSU, independente de file-hiding | Duck `prctl_probe.cpp`, `ksu_supercall_probe.cpp` |
| **SUSFS via `setresuid`→SIGKILL** | `setresuid` não é builtin de `sh` | Alto (SUSFS é o hide mais usado) | Duck `susfs_probe.cpp` · *parcial via `setpriv` se existir* |
| **resetprop forensics** (serial low-24, holes no trie) | `getprop` não expõe serial nem a estrutura | Alto (spoof de prop invisível) | Duck `readonly_serial_probe.cpp`, `prop_area_probe.cpp` |
| **Inline/GOT hook + heap scan** | precisa ler **bytes** de `/proc/$FF_PID/mem` (ptrace/root) | Alto (Frida/hook) | Duck `function_hook_detector.cpp`, `lsposed/heap_probe.cpp` |
| **ptrace `GETEVENTMSG`** (forks Zygisk) | precisa `PTRACE_ATTACH`/`GETEVENTMSG` | Alto (ReZygisk/ZygiskNext/NeoZygisk) | `apkunpacker/DetectZygisk` |
| **TEE attestation / keybox / Play Integrity** | KeyStore JNI + parse DER/X.509 | Baixo p/ FF (não é o anti-cheat do FF) → **lado backend** | Duck `tee/*` |

> Onde houver gap, o contrato manda emitir `warn`/`info` ("inconclusivo: exige binário nativo/root"),
> **nunca** um `ok` falso.

---

## 7. Guard-rails de falso-positivo (alinhado à classe de FP conhecida do projeto)

- **Menor FP** (priorizar): emulador (§4.1), tokens-no-maps-do-FF (§4.2), contexto SELinux (§4.3),
  mount estrutural (§4.6), prop×cmdline (§4.5) — todos dependem de **relação estrutural**.
- **Token solto exige âncora**: `magisk`/`ksu`/`gadget`/`overlay` só contam com âncora (`/data/adb/`,
  basename exato, perms `x`, `dev` de `/data`, contexto SELinux exato) — exatamente a classe de FP
  que vocês já vêm calibrando (ver memórias do projeto sobre FP por substring e o caso `gadget`/HAL USB MTK).
- **Replicar a heurística "≥2 confirmações"** do `path_probe` do Duck para checks de path
  (`test -e` + `ls` do pai casando o basename) reduz FP de hiding/cloak.
- **Degradação honesta**: todo `read` sob uid 2000 pode dar EACCES → `warn` inconclusivo, nunca `ok`.

---

## 8. Checklist de implementação (quando for codar)

1. Branch `fix/...` (nunca commit direto no `main` — merge no `main` = deploy ao vivo).
2. Escolher o `*_HITS` do módulo onde a detecção mora (novos: `EMU_HITS`; reuso: `KERNEL_HITS`/`DFIR_HITS`/`PIF_HITS`).
3. Usar **só** os helpers (`alert`/`warn`/`ok`/`info`) — o ecossistema só conta `●  ALERTA`/`●  AVISO`.
4. `$FF_PID` vazio/ilegível → `warn` inconclusivo (nunca `ok`).
5. Marcar features novas com `# v4.4.95:` (não bumpar os `# v4.4.xx:` históricos).
6. Verificações: `sh -n a4ther.sh` sem erro; line endings **LF**; UTF-8 preservado; tmpdir `/data/local/tmp`.
7. **Re-gerar `a4ther.sh.enc`** e provar round-trip (decifrar | `cmp` byte-idêntico).
8. Manter os **5 literais de versão** do `a4ther-adb.sh` em dia se a UI/relatório mudar.
9. PR para o `main`; revisão do diff antes do merge.

---

## 9. Referências

- Repo estudado: <https://github.com/apkunpacker/MagiskDetection> (README cataloga as técnicas por POC).
- Fontes primárias clonadas (fora do git do scanner, em `_research-magiskdetection/_ext/`):
  `Duck-Detector-Refactoring`, `DetectZygisk`, `JingMatrix/Demo`, `LSPosed/DirtySepolicy`,
  `vvb2060/MagiskDetector`, `scottyab/rootbeer`, `Ruru`, `reveny/Android-Native-Root-Detector`.
- Catálogo técnico completo do Duck-Detector (14 módulos, mecanismo + arquivo:linha + portabilidade):
  `_research-magiskdetection/_duck-catalog.md`.

---
---

# PARTE II — Apps adicionais (APK fechados, decompilados)

> **Por que esta parte existe:** a Parte I se apoiou nos detectores com **fonte aberta**. Os
> demais POCs do repo (`GarudaDefender/CrackME`, `Hunter`, `NativeTest/MinotaurPoc`, `Oprek`,
> `SafeCheck`, `Detect-Magisk/darvin`, `APTest/hiapatch`) são **APK fechado** — eu os havia
> caracterizado pelo README, não pelo código. Aqui eles foram **decompilados** (jadx) e tiveram
> as **libs nativas extraídas** (`strings`), para confirmar a técnica real.

## 10. Método e rendimento da decompilação

`jadx` (Java 25) sobre 7 APKs + `strings` filtrado nas libs `arm64-v8a` (em `_decompiled/_strings/`):

| App | Java | Strings da lib | Observação |
|---|---|---|---|
| **Hunter** `com.zhenxi.hunter` | 6437 .java (ofusc.) | **`libhunter.so` = 347 linhas** | Mina de ouro — JNI nomeado revela técnicas |
| **OprekDetector** | 2728 .java | `libxchecker.so` = 24 | Legível; cena indonésia |
| **SafeCheck** | 965 .java | 20+7 | Pouco delta (usa xhook Qiyi) |
| **Detect-Magisk/darvin** | 706 .java | 18 | `isolatedProcess` mount-check |
| **APTest/hiapatch** | 1160 .java | — | Confirma `kpatch` do APatch |
| **GarudaDefender** (RASP) | 3449 .java (186 erros) | `libkikypspro.so` 30MB → **22 linhas** | **String-encryption** — README é o catálogo |
| **MinotaurPoc** (nullptr.icu) | **1 .java** | `libnullptr.so` → **1 linha** | **Puro-nativo + encriptado** |

**Conclusão honesta:** GarudaDefender e MinotaurPoc são ofuscados/encriptados (jadx falha de
propósito — o próprio README do GarudaDefender exibe "JADX failed"). Para esses, o catálogo de
técnicas é o README (Parte II §13) + as categorias abaixo. Hunter/Oprek/darvin/APTest renderam
mecanismos concretos.

## 11. CORREÇÃO — o que esses apps fazem que o a4ther JÁ cobre (não duplicar)

Verificado direto no `a4ther.sh` (os agentes superestimaram alguns "gaps"):

| Técnica do POC | Situação real no a4ther | Linha |
|---|---|---|
| TracerPid do FF (GameGuardian/ptrace) | **JÁ COBRE** | [a4ther.sh:1025](../a4ther.sh) |
| Accessibility (`enabled_accessibility_services`) | **JÁ COBRE** (seção ESP/OVERLAY + perfil de painel) | [a4ther.sh:3018](../a4ther.sh), [3061](../a4ther.sh) |
| Virtual-space — `find` do FF em data-path de clone + ~30 pacotes | **JÁ COBRE** (seção CLONE) | [a4ther.sh:1558](../a4ther.sh)-1584, 2477-2537 |
| GameGuardian por pacote | **JÁ COBRE** (parcial) | [a4ther.sh:1661](../a4ther.sh), 3301 |
| `libil2cpp` em maps | **EXCLUÍDO de propósito** (é runtime) | [a4ther.sh:3674](../a4ther.sh) |
| RWX>5 em maps do FF | **JÁ COBRE** | [a4ther.sh:1136](../a4ther.sh) |

→ As recomendações abaixo são **só o delta verificado** (cobertura zero), ou **enriquecimento**
de listas existentes.

## 12. TIER A — net-new verificado, portável, baixo-FP

### 12.1 — Integridade do runtime Unity (libil2cpp) — **específico do FF, seguro**
**O que pega:** tamper do runtime Unity (GG dumpa/substitui `libil2cpp.so`). **Net-new e NÃO
conflita** com a exclusão da l.3674 — lá se evita flagrar a *presença*; aqui flagra **ausência /
duplicata / path anômalo**. **Fonte:** GarudaDefender "Game Engine Protection"; Il2CppDumper-FF.
**Onde:** bloco `DFIR_HITS` (maps do FF).
```sh
# Integridade Unity do FF (v4.4.95) — NÃO flagra presença (l.3674); flagra tamper estrutural
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/maps" ]; then
  IL2=$(awk '/libil2cpp\.so$/{print $6}' "/proc/$FF_PID/maps" 2>/dev/null | sort -u)
  if [ -z "$IL2" ]; then
    warn "FF sem libil2cpp.so mapeada (runtime Unity adulterado? ou ainda carregando) — INCONCLUSIVO"
  else
    echo "$IL2" | grep -vqE '/data/app/.*com\.dts\.freefire' && { alert "libil2cpp.so de path ANÔMALO: $(echo $IL2)"; DFIR_HITS=$((DFIR_HITS+1)); }
    [ "$(echo "$IL2" | grep -c .)" -gt 1 ] && { alert "Múltiplas libil2cpp.so (lib substituída): $(echo $IL2)"; DFIR_HITS=$((DFIR_HITS+1)); }
  fi
fi
```

### 12.2 — Free Fire rodando DENTRO de virtual-space (ótica do processo) — **FP quase-zero**
**O que pega:** o vetor stealth nº1 de 2026 — FF num container (VMOS/X8/VPhoneGaGa) **sem root**.
**Net-new:** a seção CLONE (l.1579) faz `find` em **disco**; isto lê a **ótica do FF**
(`mountinfo`/`maps` do processo). **Fonte:** VirtualApp `com.lody.virtual` (`libva++.so`).
**Onde:** bloco `DFIR_HITS`.
```sh
# Virtual-space pela ótica do PROCESSO FF (complementa o find em disco da l.1579) (v4.4.95)
if [ -n "$FF_PID" ]; then
  FF_DATA=$(grep -oE '/data/(data|user/[0-9]+)/[a-z0-9._]+' "/proc/$FF_PID/mountinfo" 2>/dev/null | sort -u)
  echo "$FF_DATA" | grep -qE 'virtualapp|lody\.virtual|/virtual/|vphonegaga|lbe\.parallel|dualspace|x8zs|vmos|gspace' \
    && { alert "Free Fire DENTRO de virtual-space (data-path host: $(echo $FF_DATA | head -c 100))"; DFIR_HITS=$((DFIR_HITS+1)); }
  grep -qiE 'libva\+\+\.so|libNimsWrap|libhookzz|/virtual/data/' "/proc/$FF_PID/maps" 2>/dev/null \
    && { alert "Lib de virtual-space mapeada no FF (va++/NimsWrap/hookzz)"; DFIR_HITS=$((DFIR_HITS+1)); }
fi
```

### 12.3 — AVC denials de domínio root no kernel log
**O que pega:** transição de domínio de processo root deixa rastro de auditoria (difícil de limpar).
**Net-new:** o a4ther usa `dmesg` (l.715) mas **não** filtra o canal `avc: denied`. **Fonte:**
Hunter `NativeEngine.checkRootFromAVCLog`. **Onde:** `KERNEL_HITS`.
```sh
# AVC denied de domínios de root no kernel log (v4.4.95)
AVC=$(dmesg 2>/dev/null | grep -iE 'avc: *denied' | grep -iE 'magisk|kernelsu|ksu|supolicy|u:r:su|u:r:magisk' | head -3)
[ -n "$AVC" ] && { alert "AVC denied de domínio root no kernel log (root ativo)"; KERNEL_HITS=$((KERNEL_HITS+1)); }
```

### 12.4 — APatch: binário `kpatch` + `su_path` configurável
**O que pega:** APatch (`/data/adb/ap` já coberto, mas **`kpatch` e `su_path` não** — 0 hits).
O `su_path` guarda **onde o su foi escondido** (derrota o esconde-su por renomeação). **Fonte:**
APTest/hiapatch + strings `libhunter.so`. **Onde:** `KERNEL_HITS`.
```sh
# APatch kpatch + su_path (v4.4.95)
for P in /data/adb/kpatch /data/adb/ap/kpatch /data/adb/ap/bin/kpatch; do
  exists "$P" && { alert "APatch kpatch: $P"; KERNEL_HITS=$((KERNEL_HITS+1)); }
done
if [ -r /data/adb/ap/su_path ]; then
  SUP=$(cat /data/adb/ap/su_path 2>/dev/null)
  [ -n "$SUP" ] && { alert "APatch su_path → su escondido em: $SUP"; exists "$SUP" && alert "  → confirmado: $SUP"; KERNEL_HITS=$((KERNEL_HITS+1)); }
fi
```

## 13. TIER B — net-new ou enriquecimento (mais trabalho ou condicional)

### 13.1 — Heurística de região executável anônima/auto-oculta no maps do FF
**Insight invertido:** a lib `libhunter_maps_hide.so` **apaga o próprio nome** de `/proc/self/maps`
(via `prctl(PR_SET_VMA_ANON_NAME)`); um cheat sofisticado faz igual. O a4ther casa libs **por nome**
(l.1129) → libs sem nome escapam. **Net-new:** contar regiões executáveis **anônimas**.
```sh
# Região exec sem path (lib auto-oculta) no FF (v4.4.95) — complementa o regex de nome da l.1129
if [ -n "$FF_PID" ] && [ -r "/proc/$FF_PID/maps" ]; then
  ANONX=$(awk '$2 ~ /x/ && (NF<6 || $6=="" || $6 ~ /^\[anon/) {c++} END{print c+0}' "/proc/$FF_PID/maps" 2>/dev/null)
  [ "${ANONX:-0}" -gt 3 ] 2>/dev/null && { warn "FF tem $ANONX regiões exec ANÔNIMAS (lib sem nome / auto-oculta)"; DFIR_HITS=$((DFIR_HITS+1)); }
fi
```
> Calibrar o limiar (`>3`) em device limpo — JIT/ART gera algumas regiões anon legítimas.

### 13.2 — Stackplz / eBPF tracer (uprobe/kprobe/bpf)
**Net-new:** instrumentação além do Frida. **Ressalva:** `/sys/kernel/(debug/)tracing` e
`/sys/fs/bpf` geralmente exigem root → sob uid 2000 dá `Permission denied` → **`info`/`warn`
inconclusivo, nunca `ok`**. **Fonte:** GarudaDefender "Anti Instrumentation"; stackplz.
```sh
for f in /sys/kernel/debug/tracing/uprobe_events /sys/kernel/tracing/uprobe_events; do
  [ -s "$f" ] && { warn "uprobe ATIVO ($f não-vazio) — tracer eBPF/stackplz"; break; }
done
pidof stackplz >/dev/null 2>&1 && { alert "stackplz em execução"; }
```

### 13.3 — Enriquecer listas existentes (paths/pacotes)
**Paths de su net-new** (0 hits — adicionar ao loop de su):
```
/sbin/nvsu   /sbin/.mianju   /system/bin/.hid/su   /data/local/xin/su   /system/xbin/mu_bak
```
**APatch/Magisk state net-new:**
```
/data/adb/kpatch  /data/adb/ap/su_path  /data/adb/.boot_count  /data/adb/magisk_simple
/cache/.disable_magisk  /system/etc/init/magisk.rc  /data/adb/riru/bin/rirud  /data/adb/edxp/misc_path
```
**Pacotes net-new** (checar via `pm list packages`; classificar conforme FP):
- **Virtual-space** (`warn` — dual-account é uso legítimo): `com.vphonegaga.titan`, `cn.v8box.app`,
  `com.pspace.vandroid`, `com.gspace.android`, `net.typeblog.shelter`, `com.vmos.glb`, `io.twoyi`,
  `com.clone.android.dual.space`.
- **Automação por Accessibility** (alto valor — aimbot/macro): `org.autojs.autojs`,
  `org.autojs.autojs6`, `org.autojs.autoxjs.v6`, `com.x0.strai.frep`, `com.cygery.repetitouch.free`,
  `com.cygery.repetitouch.pro`.
- **Root-cloak** (indicam INTENÇÃO de esconder): `com.devadvance.rootcloak(plus)`,
  `com.amphoras.hidemyroot(adfree)`, `com.formyhm.hideroot(Premium)`, `com.saurik.substrate`.
- **Superuser variantes:** `com.noshufou.android.su(.elite)`, `com.yellowes.su`, `com.thirdparty.superuser`.

### 13.4 — Calibração de FP: limiar ≥2 em substring de mount (Oprek `mo3322b`)
O Oprek só dispara Magisk quando há **>1** path-hit em `/proc/<pid>/mounts` (1 hit = ruído).
**Alinhado à dor de FP do projeto** (ver `scanner-substring-fp-class` / `scanner-fp-realdevice-mediatek`):
onde hoje 1 substring vira `alert`, considerar exigir ≥2 hits distintos. É **calibração**, não detecção nova.

### 13.5 — Magisk abstract UDS (corrobora Parte I §5.5)
O Oprek tem `checkForMagiskUDS()` (socket de controle do magiskd em `/proc/net/unix`), confirmando
a §5.5. **Mesma ressalva:** Magisk randomiza o nome → rendimento baixo; sinal fraco.

## 14. Recomendações ARQUITETURAIS ao APK (não cabem no `.sh`)

O `ssonato/a4ther-scanner-apk` poderia cobrir o que o shell não alcança:

- **`isolatedProcess` mount-check** (Detect-Magisk/darvin + Hunter `isRunISOProcess`): um Service
  `android:isolatedProcess="true"` recebe uid 99000+ e um namespace que o **DenyList/MagiskHide
  frequentemente NÃO cobre** → o magic-mount fica visível. **Bypass robusto do hide**, mas exige
  um app — pertence ao APK, não ao `a4ther.sh`.
- **Helper ELF nativo** para: KSU `prctl(0xDEADBEEF)` / supercall (Parte I §6), **checksum de ELF**
  das libs do FF (Hunter `checkLibCheckSum` — pega inline/GOT hook), **HW breakpoints**
  (`PTRACE_GETREGSET`), **ptrace twin** (ocupar o slot de tracer).

## 15. Referências da Parte II

- Decompilados (jadx): `_research-magiskdetection/_decompiled/<app>/sources/**`.
- Strings das libs: `_research-magiskdetection/_decompiled/_strings/*.txt` (rica: `Hunter_v636.libhunter.so.txt`).
- Fontes primárias clonadas a mais: `_ext/GarudaDefender` (só APK + README — RASP fechado),
  `_ext/VirtualApp` (`com.lody.virtual` → `libva++.so`).
- Ferramenta: `_research-magiskdetection/_tools/jadx` (jadx 1.5.1).

## 16. ZygiskDetector-1.7 (zip protegido — senha `infected`)

O repo tinha um arquivo **AES-zip** `ZygiskDetector-1.7_password - infected.zip` (senha `infected`,
do README) que eu havia pulado. Extraído com 7-Zip → `ZygiskDetector-1.7.apk`. Análise:

- **Pacote** `wu.Zygisk.Detector` v1.7 — lib chinesa **"wuying" (无影)**.
- **0 libs nativas** — detecção **pura Java/Kotlin** via `Runtime.exec()` (comando **shell**) +
  traversal recursivo de diretório (`com.wuying.CommandExecutor` + `FileUtil`, no `assets/util.dex`).
- **Ofuscação StringFog** (XOR+Base64): `plaintext = XOR(Base64decode(cifra), chave)` — esquema
  decodificado (`com/github/megatronking/stringfog/xor/StringFogImpl`), **mas** os literais cifrados
  e as chaves estão nos call-sites de `wu.Zygisk.Detector`, que **resistem ao jadx** (falha mesmo
  com `--show-bad-code`; pacote sai vazio). Extração exata dos comandos exige **baksmali** (smali não
  "falha" como o decompilador) ou **Ghidra**.
- **Conclusão (honesta):** como é detector shell-based de Zygisk, suas técnicas são quase certamente
  um **subconjunto** do que já está catalogado — Parte I **§4.2** (tokens `zygisk|libriru|.magisk`
  no scan de `/proc/$FF_PID/maps`), módulo `zygisk` do Duck, e o ptrace-event-leak do DetectZygisk.
  Não há `.so` próprio com técnica nova. Decodificar os comandos exatos é possível mas de **baixo
  retorno marginal** (esforço de RE smali para confirmar o já documentado).
- Artefatos: `_research-magiskdetection/_zygiskdetector/` (APK + `util.dex`),
  `_decompiled/ZygiskDetector17{,_full,_utildex}/`.

## 17. MinotaurPoc / `libnullptr.so` via Ghidra (nullptr.icu nativetest)

A pedido, importei a lib nativa fechada do MinotaurPoc no **Ghidra (MCP)** — o `strings` tinha dado
só 1 linha (100% cifrada). Resultado da análise (AARCH64, 311 funções):

- **`ANativeActivity_onCreate`** como entrypoint → é um **NativeActivity** (detecção 100% nativa,
  sem ponte JNI — por isso o jadx achou só 1 `.java`). Decompilou limpo.
- **OLLVM (Obfuscator-LLVM)**: exports `.datadiv_decode<número>` = stubs que **decifram as
  strings/dados em runtime** no load. Por isso `strings`/busca estática acham 0 paths de detecção.
- **Fingerprint de técnica pela tabela de imports (não-ofuscável):** `__system_property_get`
  (props), `access`/`stat`/`fopen`/`__open_2` (checagem de arquivo de root), `fopen`+`getline`+
  `sscanf` (**parsing de `/proc/self/maps`/`mountinfo`**), **`dl_iterate_phdr`** (enumeração de
  módulos carregados = detecção de **Zygisk/injeção**, comparando solist × maps). **Sem** `ptrace`,
  socket, `prctl`.
- **Conclusão:** todas essas técnicas **já estão no catálogo** — file/prop checks (Parte I §4.7,
  §9), `/proc/maps`/`mountinfo` parsing (§4.2, §4.6), e o `dl_iterate_phdr`/solist é o módulo
  `zygisk` do Duck (NÃO-PORTÁVEL in-process; análogo shell = ler `/proc/$FF_PID/maps`, §4.2).
  **O Ghidra confirmou (não só presumiu) que o MinotaurPoc não adiciona técnica portável nova.**
- Extrair os paths/props exatos exigiria **emular cada `.datadiv_decode*`** (OLLVM) — possível via
  `emulate_function`, mas alto esforço pra confirmar needles padrão (`/data/adb/magisk`,
  `/proc/self/maps`, `ro.build.tags`). Não compensa.
- **Para uma técnica REALMENTE nova**, o alvo Ghidra com melhor potencial é o **GarudaDefender
  `libkikypspro.so` (30 MB, RASP comercial)** — mas é o mais pesado e igualmente OLLVM.
- Artefatos: `.so` em `_research-magiskdetection/_ghidra/libnullptr.so` (projeto Ghidra
  `/a4ther-research`).

## 18. GarudaDefender / `libkikypspro.so` via Ghidra (RASP comercial, 30 MB)

A pedido, importei a engine RASP do GarudaDefender no Ghidra. É 30 MB + OLLVM (strings cifradas:
só `/proc/self/maps` e `/dev/*random` sobraram em claro). Mas a **tabela de imports (não-ofuscável)**
revela toda a superfície — e ela é MUITO mais rica que a do MinotaurPoc, batendo com o README:

| Categoria (README) | Imports que comprovam | Portável p/ shell a4ther? |
|---|---|---|
| Anti-hook (Frida/PLT/inline) | `dl_iterate_phdr`, `dlopen`/`dlsym`/`dlerror`, `/proc/self/maps`, `mprotect` | in-process → análogo = `/proc/$FF_PID/maps` (§4.2, já coberto) |
| Anti-debug | **`syscall`** (raw — bypassa hook de libc; ptrace via syscall), `fork`+`waitpid` (ptrace-twin), `signal`/`sigaction`/`raise`, timing (`clock_gettime`/`getrusage`) | NÃO-PORTÁVEL (in-process); shell já tem TracerPid (l.1025) |
| Emulador | **`glGetString`** (GL renderer = SwiftShader/emu), `uname`, `getauxval`, `__system_property_get` | GL = in-process/NÃO-PORTÁVEL; props portam (§4.1) |
| Rede (remote-control + HTTP-capture + VPN) | `socket`/`connect`/`getaddrinfo`/`if_nametoindex`/`setsockopt` | a4ther já tem VPN/PROXY (`VPN_HITS`/`PROXY_HITS`) — coberto |
| Integridade (assinatura/checksum) | `crc32`, `deflate`/`inflate` (zlib) | APK-side (verificar assinatura do FF via `pm`) |
| Anti-hiding | **`realpath`** (resolve symlink/bind-mount → path real) | **[PORTÁVEL — nugget novo]** ver abaixo |
| Memory protection | `mlock`/`munlock` (trava segredos decifrados na RAM) | auto-defesa, N/A |

**Único nugget acionável novo:** `realpath`/`readlink -f` p/ **anti-hiding** — resolver o caminho
REAL de um artefato de root antes de checar derrota symlink/bind-mount que aponta o path pra um
lugar benigno. Aplicável aos checks de path do a4ther (ex.: `RP=$(readlink -f "$P" 2>/dev/null);
[ "$RP" != "$P" ] && ...`). Baixo custo, complementa a triangulação da Parte II §5.6.

> ### Veredito consolidado do Ghidra (MinotaurPoc + GarudaDefender)
> Os dois `.so` fechados/ofuscados confirmaram a superfície de detecção via import table, **sem
> revelar técnica PORTÁVEL nova** além do `realpath` anti-hiding. Os mecanismos nativos (GL-renderer
> p/ emulador, `syscall`-raw anti-hook, ptrace-twin anti-debug, checksum de ELF) são **in-process →
> não-portáveis** ao shell (já listados no apêndice da Parte I §6). As **categorias** anti-cheat
> novas (virtual-space, GameGuardian, Unity/il2cpp, auto-clicker) já tinham sido capturadas do README
> na Parte II §12-13 — os strings exatos (listas de pacote/needle) estão cifrados por OLLVM e exigiriam
> emular cada decoder, com retorno marginal. **Conclusão: o estudo (Parte I + II) já cobre a superfície
> acionável; a RE nativa serviu para CONFIRMAR isso, não para expandir.**
- Artefato: `_research-magiskdetection/_ghidra/libkikypspro.so` (projeto Ghidra `/a4ther-research`).

## 19. Balanço final dos APKs do repo (cobertura)

Para registro de completude — toda **engine distinta** foi checada (fonte / decompilação / Ghidra):

- **Source-analisadas (Parte I):** Duck-Detector, DetectZygisk, JingMatrix/Demo, DirtySepolicy,
  vvb2060/MagiskDetector, RootBeer, Ruru.
- **Decompiladas (Parte II):** Hunter v6.36, Oprek, SafeCheck, Detect-Magisk/darvin, APTest,
  MinotaurPoc, ZygiskDetector-1.7 (§16).
- **Ghidra (imports/nativo):** MinotaurPoc `libnullptr.so` (§17), GarudaDefender `libkikypspro.so`
  (§18), **Disclosure `libdisclosure.so`**, **Holmes `libholmes.so`**.
- **Disclosure** (não estava no README): file/prop/proc + `dl_iterate_phdr` + **`ptrace`+`getppid`**
  (= ptrace-getppid do DetectZygisk, §6) + `popen`/`system` (shell) + `mincore`/`prctl`. Superfície
  já catalogada; nada portável novo.
- **Holmes** (53 MB): file/dir/proc + **`grantpt`/`ptsname`** (devpts-PTY = Duck §5f) + `popen` +
  network + `fsetxattr`. Idem.
- **Duplicatas/versões antigas (não reabertas — mesma engine):** CrackME v1.5/2.0/2.8 (=GarudaDefender),
  Hunter 3.0/4.4.1/6.0.3, Native-root-detector 6.5.7/6.8.1, DuckDetector 1.2/1.3/1.4.2,
  **NativeTest-v30 e NativeTest(TNG_Bank) = `libnullptr.so`** (=MinotaurPoc, §17).
- **reveny Native-root-detector** (`.so` fechado): via release-notes (§6 da pesquisa) — não há fonte.

**Conclusão:** a superfície de detecção do repo está saturada. Disclosure/Holmes confirmaram (via
imports) que rodam **shell commands** sobre `/proc`/`getprop`/file — exatamente o vantage do a4ther —
sem técnica portável nova. Nenhuma engine ficou sem fingerprint.
