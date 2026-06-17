#!/bin/sh
# decrypt.sh — recover an AES-enveloped, packed A4ther script, then RUN it.
# Usage: FF_PASSPHRASE=... sh decrypt.sh a4ther.sh.enc [args...]
set -eu
[ $# -ge 1 ] || { echo "usage: FF_PASSPHRASE=... sh decrypt.sh <file.enc> [args]" >&2; exit 1; }
[ -n "${FF_PASSPHRASE:-}" ] || { echo "FF_PASSPHRASE not set" >&2; exit 1; }
ENC="$1"; shift
TMP=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.a4dec_$$")
trap 'rm -f "$TMP" 2>/dev/null' EXIT INT TERM
openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
  -in "$ENC" -out "$TMP" -pass pass:"$FF_PASSPHRASE"
chmod 0700 "$TMP" 2>/dev/null || true
sh "$TMP" "$@"
