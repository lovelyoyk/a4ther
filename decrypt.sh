#!/bin/sh
# decrypt.sh — recover an encrypted A4ther script.
# Usage: FF_PASSPHRASE=... sh decrypt.sh a4ther.sh.enc > a4ther.sh
set -eu
[ $# -ge 1 ] || { echo "usage: FF_PASSPHRASE=... sh decrypt.sh <file.enc>" >&2; exit 1; }
[ -n "${FF_PASSPHRASE:-}" ] || { echo "FF_PASSPHRASE not set" >&2; exit 1; }
openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 100000 -base64 \
  -in "$1" -pass pass:"$FF_PASSPHRASE"
