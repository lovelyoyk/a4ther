# RELEASING — como editar e subir o engine (deploy seguro)

> Guia pro time (sócio) editar o `a4ther.sh`, re-criptografar/ofuscar e subir o deploy
> **sem quebrar a assinatura nem a integridade**. Atualizado em 2026-07-01.

## ⛔ Regra 0 — sempre `git pull` antes de trabalhar
Antes de tocar em qualquer arquivo: `git pull`. E `git pull` de novo antes do `push`.
Nunca `--force`. Nunca commit/push direto no `main` (ver "Deploy" abaixo).

## O que é protegido e por quê
- **`a4ther.sh`** (engine, ~5800 linhas) — **plaintext, versionado**. O APK baixa ele pela
  raw URL (`raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther.sh`) e roda no device.
- **`a4ther.sh.sig`** — assinatura **Ed25519** (64 B) do `a4ther.sh`. O APK **verifica** antes
  de executar (fail-closed). Sem `.sig` válido = scan não roda.
- **`a4ther.sh.enc` / `a4ther-adb.sh.enc`** — versões **cifradas** (AES-256-CBC) pro fluxo
  PROTEGIDO do site. Re-gerar SEMPRE que o `.sh` mudar.
- **`dist/` + `a4ther-scanner-*.zip`** — bundle do **site** (JS ofuscado + HTML minificado +
  guard). **Gitignored** — NÃO commita.

A `.sig`, o `.enc` e o bundle dependem dos **bytes EXATOS** do `a4ther.sh`. Mudou 1 byte? refaz todos.

## 🔑 Pré-requisitos (segredos — nunca no repo)
1. **`.env.local`** com `FF_PASSPHRASE=...` (passphrase de produção do `.enc`). Já gitignored.
2. **Chave de assinatura Ed25519** (`engine-signing-ed25519.pem`). Você recebe do **custodiante da chave**
   **cifrada** (`engine-key.enc`) + a senha por canal separado:
   ```sh
   openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in engine-key.enc -out engine-signing-ed25519.pem
   chmod 600 engine-signing-ed25519.pem
   # confere o fingerprint (tem que bater):
   openssl pkey -in engine-signing-ed25519.pem -pubout -outform DER | openssl dgst -sha256
   # esperado: c291129b4d445aca968ecbfdc8d11accd0cc4a47f7cd016f11fed30ad3b7a5fe
   ```
   Guarda fora do repo, `chmod 600`, **nunca commita**.

## 📋 Passo a passo (editar → assinar → subir)

### 1. (opcional) Recuperar o `.sh` a partir do `.enc`
Normalmente o `a4ther.sh` em claro já está no repo. Só se precisar:
```sh
( set -a; . ./.env.local; set +a; sh decrypt.sh a4ther.sh.enc > a4ther.sh )
```

### 2. Editar o `a4ther.sh`
Faça a mudança (fix do KSU etc.). Comentários/logs em **pt-BR**.

### 3. Validar (obrigatório)
```sh
sh -n a4ther.sh                     # sintaxe OK
tr -cd '\r' < a4ther.sh | wc -c     # tem que dar 0 (LF puro)
```

### 4. Re-criptografar o `.enc` da raiz + provar round-trip
```sh
( set -a; . ./.env.local; set +a; \
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
    -in a4ther.sh -out a4ther.sh.enc -pass pass:"$FF_PASSPHRASE" )
( set -a; . ./.env.local; set +a; sh decrypt.sh a4ther.sh.enc | cmp - a4ther.sh && echo "round-trip OK" )
# idem pra a4ther-adb.sh.enc se mexer no a4ther-adb.sh
```

### 5. Re-assinar (Ed25519 `.sig`) — use o `sign.sh` (re-sign em 1 comando)

> O `main` já tem o **guard anti-`.sig`-stale** (commit `168313c`): `hooks/pre-commit` e o CI
> `verify-engine-sig.yml` são **verify-only** (bloqueiam `.sig` desalinhado, mas **NÃO** auto-assinam),
> e `keys/engine-pub.pem` é a pública versionada. O caminho normal é rodar `A4_ENGINE_KEY=<sua chave> ./sign.sh`
> (assina + já verifica). **A chave privada vive só na máquina do custodiante** — assine lá, nunca numa máquina de dev genérica.
> O passo manual via `openssl` abaixo é fallback:
```sh
openssl pkeyutl -sign -inkey engine-signing-ed25519.pem -rawin -in a4ther.sh -out a4ther.sh.sig
wc -c a4ther.sh.sig    # = 64
# provar:
printf '302a300506032b6570032100' > /tmp/spki.hex
echo -n "ZrryyeYlQdRlX5j/ESRgKncHTKiiMsFzbTvUlkp+mGw=" | base64 -d | xxd -p | tr -d '\n' >> /tmp/spki.hex
xxd -r -p /tmp/spki.hex > /tmp/pub.der
openssl pkey -pubin -inform DER -in /tmp/pub.der -out /tmp/pub.pem
openssl pkeyutl -verify -pubin -inkey /tmp/pub.pem -rawin -in a4ther.sh -sigfile a4ther.sh.sig
# tem que imprimir: Signature Verified Successfully
```

### 6. Build completo (ofuscação + protegido) → `dist/` + zip
```sh
( set -a; . ./.env.local; set +a; sh build.sh )
```

### 7. Commit + push (branch + PR — NUNCA direto no `main`)
```sh
git add a4ther.sh a4ther.sh.sig a4ther.sh.enc a4ther-adb.sh.enc .gitattributes
# (+ index.html se bumpou a versão)
git commit -m "engine: <descricao> + re-encrypt + reassinatura Ed25519"
git push origin <sua-branch>
gh pr create     # merge no main = deploy
```

## 🚀 Deploy — SEMPRE via branch + PR
O GitHub Pages publica do `main` na hora (`main` = site AO VIVO). **Nunca** commitar/pushar
direto no `main`. Branch → PR → revisa → merge. O **merge no `main` É o deploy**.

## ⚠️ Regras de ouro
- **NÃO commita** `dist/`, `*.zip`, `*.zip.sha256`, `dist-extreme/`, `.env.local`,
  `engine-signing-ed25519.pem`, `engine-key.enc`.
- `.enc` e `.sig` são dos **bytes EXATOS** do `a4ther.sh` — mudou? refaz 4, 5 e 6.
- `.gitattributes` garante `eol=lf` no `a4ther.sh` e `binary` no `.sig` — sem isso, um
  checkout Windows muda os bytes e a assinatura quebra.
- Se desconfiar de vazamento da chave privada → **rotaciona** (o custodiante gera par novo, troca a
  pubkey no APK, reassina).

## Versão
Fonte da verdade = `const VERSION` no `index.html` (o `build.sh` lê dali). Hoje o
`a4ther.sh` no `main` está **4.4.98** (com feature marcada `# v4.4.99`) — mantenha o `VERSION`/banner e os literais de versão do ecossistema **alinhados** a cada bump.
