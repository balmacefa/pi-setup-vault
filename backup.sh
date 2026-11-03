#!/usr/bin/env bash
# Respalda TODO el setup de pi, cifrado AES-256, dividido en partes, y lo sube al repo privado.
# Uso: bash backup.sh ["mensaje de commit"]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSFILE="${PI_VAULT_PASS:-$HOME/.pwmgr/vault-pass}"
CHUNK="${PI_VAULT_CHUNK:-90m}"

[ -f "$PASSFILE" ] || { echo "ERROR: no existe passfile en $PASSFILE (set PI_VAULT_PASS)"; exit 1; }

# Fuentes del setup de pi (relativas a $HOME para que tar guarde rutas limpias)
SRCS=( ".pi/agent" ".agents" )
for s in "${SRCS[@]}"; do
  [ -e "$HOME/$s" ] || { echo "WARN: no existe $HOME/$s (se omite)"; }
done

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "[1/5] Empaquetando (tar+gzip, sin node_modules)..."
tar czf "$STAGE/pi-setup.tar.gz" \
  --exclude='.pi/agent/node_modules' \
  --exclude='*/node_modules' \
  -C "$HOME" "${SRCS[@]}"

echo "[2/5] Cifrando AES-256-CBC (pbkdf2)..."
# openssl es build nativo de Windows: necesita rutas estilo Windows
wpath(){ cygpath -w "$1" 2>/dev/null || echo "$1"; }
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
  -in "$(wpath "$STAGE/pi-setup.tar.gz")" \
  -out "$(wpath "$STAGE/pi-setup.tar.gz.enc")" \
  -pass file:"$(wpath "$PASSFILE")"

echo "[3/5] Dividiendo en partes de $CHUNK..."
rm -f "$HERE"/data/pi-setup.tar.gz.enc.part-*
split -b "$CHUNK" -d -a 3 "$STAGE/pi-setup.tar.gz.enc" "$HERE/data/pi-setup.tar.gz.enc.part-"

echo "[4/5] Generando MANIFEST..."
{
  echo "generated_utc: $(date -u +%FT%TZ)"
  echo "host:          $(hostname)"
  echo "sources:       ${SRCS[*]}"
  echo "cipher:        aes-256-cbc pbkdf2 iter=200000"
  echo "plaintext_sha256: $(sha256sum "$STAGE/pi-setup.tar.gz" | cut -d' ' -f1)"
  echo "enc_sha256:       $(sha256sum "$STAGE/pi-setup.tar.gz.enc" | cut -d' ' -f1)"
  echo "enc_bytes:        $(wc -c < "$STAGE/pi-setup.tar.gz.enc")"
  echo "parts:"
  (cd "$HERE/data" && for f in pi-setup.tar.gz.enc.part-*; do
    echo "  $f  $(wc -c < "$f")  sha256:$(sha256sum "$f" | cut -d' ' -f1)"
  done)
} > "$HERE/MANIFEST.txt"
cat "$HERE/MANIFEST.txt"

echo "[5/5] Commit + push..."
cd "$HERE"
git add -A
if git diff --cached --quiet; then
  echo "Sin cambios; nada que commitear."
  exit 0
fi
MSG="${1:-backup pi-setup $(date -u +%FT%TZ)}"
git commit -q -m "$MSG"
if git remote get-url origin >/dev/null 2>&1; then
  git push -q origin main && echo "Pushed OK."
else
  echo "Sin remoto 'origin' configurado todavia. Commit local hecho."
fi
