#!/usr/bin/env bash
# Restaura el setup de pi desde el vault cifrado.
# Uso: bash restore.sh [DIR_DESTINO]   (default: $HOME/pi-setup-restored)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSFILE="${PI_VAULT_PASS:-$HOME/.pwmgr/vault-pass}"
DEST="${1:-$HOME/pi-setup-restored}"

[ -f "$PASSFILE" ] || { echo "ERROR: no existe passfile en $PASSFILE (set PI_VAULT_PASS)"; exit 1; }
ls "$HERE"/data/pi-setup.tar.gz.enc.part-* >/dev/null 2>&1 || { echo "ERROR: no hay partes en $HERE/data"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/3] Reensamblando partes..."
cat "$HERE"/data/pi-setup.tar.gz.enc.part-* > "$TMP/pi-setup.tar.gz.enc"

echo "[2/3] Descifrando..."
wpath(){ cygpath -w "$1" 2>/dev/null || echo "$1"; }
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$(wpath "$TMP/pi-setup.tar.gz.enc")" \
  -out "$(wpath "$TMP/pi-setup.tar.gz")" \
  -pass file:"$(wpath "$PASSFILE")"

echo "[3/3] Extrayendo en $DEST ..."
mkdir -p "$DEST"
tar xzf "$TMP/pi-setup.tar.gz" -C "$DEST"

echo "Restaurado en: $DEST"
echo "Para reponer dependencias: (cd \"$DEST/.pi/agent\" && npm install)"
