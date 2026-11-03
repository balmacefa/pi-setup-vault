# pi-setup-vault

Respaldo **cifrado** del setup completo de pi (agente Pike) en repo privado.

Todo el contenido real va **cifrado AES-256** y partido en trozos; en GitHub solo
viven blobs ilegibles (`data/*.part-*`) + estos scripts. Sin la passphrase no se
puede leer nada.

## Que incluye
- `~/.pi/agent` -> AGENTS.md, extensions, prompts, scripts, agents, mcp.json,
  settings, keybindings, memory (db + L2/L3), sessions, auth (cifrado).
- `~/.agents`   -> skills, skills-archived, presets.
- Excluye `node_modules` (restaurable con `npm install`).

## Cifrado
- `openssl enc -aes-256-cbc -pbkdf2 -iter 200000`
- Passphrase: archivo local **no sincronizado** `~/.pwmgr/vault-pass`
  (misma que el vault de pwmgr). Override con env `PI_VAULT_PASS`.
- **La passphrase NO esta en este repo.** Sin ella el backup es inservible.

## Actualizar el respaldo
```bash
bash backup.sh ["mensaje opcional"]
```
Reempaqueta, cifra, parte en trozos de 90MB, commitea y hace push.

## Restaurar
```bash
bash restore.sh [DIR_DESTINO]   # default: ~/pi-setup-restored
```
Reensambla las partes, descifra y extrae. Luego `npm install` en `.pi/agent`.

## Automatizar (opcional)
Programar `backup.sh` con el Task Scheduler de Windows o un cron de git-bash,
p.ej. diario. Solo sube si hay cambios.

> Nota: `~/.pi/overnight`, `~/.pi/olimpo` y otros tienen su propio repo/estado y
> no se incluyen aqui a proposito (esto es el *setup* del agente, no su runtime).
