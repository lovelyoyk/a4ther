#!/bin/sh
# sign.sh — re-assina a a4ther.sh DELIBERADAMENTE (ato HUMANO).
# A chave PRIVADA nao fica em disco aqui: o caminho preferido decripta em memoria.
set -e
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT"

# Forneca a chave privada Ed25519 decriptada. Em ordem de preferencia de SEGURANCA:
#   1) A4_DECRYPT aponta pro seu decrypt.sh, que IMPRIME a PEM no stdout (pede a senha):
#        A4_DECRYPT=./decrypt.sh ./sign.sh         <- decripta em RAM, nada em disco
#   2) A4_ENGINE_KEY aponta pra um arquivo PEM ja decriptado (menos seguro):
#        A4_ENGINE_KEY=~/.a4ther/engine-signing-ed25519.pem ./sign.sh
if [ -n "$A4_DECRYPT" ] && [ -x "$A4_DECRYPT" ]; then
  openssl pkeyutl -sign -rawin -inkey <("$A4_DECRYPT") -in a4ther.sh -out a4ther.sh.sig
elif [ -r "${A4_ENGINE_KEY:-$HOME/.a4ther/engine-signing-ed25519.pem}" ]; then
  openssl pkeyutl -sign -rawin -inkey "${A4_ENGINE_KEY:-$HOME/.a4ther/engine-signing-ed25519.pem}" \
    -in a4ther.sh -out a4ther.sh.sig
else
  echo "sign.sh: nao achei a chave."
  echo "  use:  A4_DECRYPT=./decrypt.sh ./sign.sh   (decripta em RAM, recomendado)"
  echo "  ou:   A4_ENGINE_KEY=<arquivo.pem> ./sign.sh"
  exit 1
fi

# confere que o lacre bate (chave PUBLICA)
openssl pkeyutl -verify -pubin -inkey keys/engine-pub.pem -rawin -in a4ther.sh -sigfile a4ther.sh.sig
echo "OK — a4ther.sh.sig re-assinado e verificado."
echo "Agora:  git add a4ther.sh a4ther.sh.sig && git commit"
