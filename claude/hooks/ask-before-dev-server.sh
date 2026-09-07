#!/usr/bin/env bash
# Pide confirmación antes de que Claude arranque un dev server.
#
# El problema que resuelve: con varias sesiones abiertas sobre el mismo proyecto, un
# `npm run dev` lanzado de fondo por Claude ocupa el puerto en el que tú estabas mirando
# tu rama, y encima cuesta descubrir quién lo tenía. Cuando los puertos están fijados por
# configuración externa (callbacks de OAuth registrados por puerto, por ejemplo), no vale
# el «usa otro puerto».
#
# No bloquea: devuelve `ask`, así que Claude puede proponerlo y tú decides en el momento.
#
# ── Configuración ────────────────────────────────────────────────────────────
# CLAUDE_DEV_SERVER_DIRS: prefijos de ruta donde aplica, separados por espacios.
#   Vacío = aplica en todos los directorios.
#   Ejemplo: export CLAUDE_DEV_SERVER_DIRS="$HOME/work/tienda $HOME/work/api"
DEV_SERVER_DIRS="${CLAUDE_DEV_SERVER_DIRS:-}"
#
# Deja pasar a propósito:
#   - builds, tests, lint, tsc (no escuchan en ningún puerto)
#   - inspeccionar o matar lo que ya está escuchando (ss, lsof, kill, pgrep)
#   - mencionar el comando dentro de un grep/echo

set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$dir" ] && dir=$PWD

# `cd /otro/proyecto && npm run dev` actúa sobre ESE directorio, no sobre el de la sesión.
cd_target=$(printf '%s' "$cmd" | grep -oE '^[[:space:]]*cd[[:space:]]+[^&;|]+' | sed -E 's/^[[:space:]]*cd[[:space:]]+//; s/[[:space:]]+$//' | tr -d '"'"'"'')
[ -n "$cd_target" ] && [ -d "$cd_target" ] && dir=$cd_target

if [ -n "$DEV_SERVER_DIRS" ]; then
  match=0
  for prefix in $DEV_SERVER_DIRS; do
    case "$dir" in "$prefix"*) match=1 ;; esac
  done
  [ "$match" = "0" ] && exit 0
fi

# Se mira segmento a segmento: `ss -lptn ... | grep vite` no arranca nada.
matched=""
while IFS= read -r seg || [ -n "$seg" ]; do
  seg=${seg#"${seg%%[![:space:]]*}"}
  case "$seg" in
    grep*|rg*|echo*|cat*|printf*|awk*|sed*|ps\ *|pgrep*|pkill*|kill*|ss\ *|lsof*|which*|jq*) continue ;;
  esac
  if printf '%s' "$seg" | grep -qE '(^|[[:space:]])(npm|pnpm|yarn|bun)([[:space:]]+run)?[[:space:]]+(start|dev|serve|preview)([[:space:]]|$)' \
     || printf '%s' "$seg" | grep -qE '(^|[[:space:]]|/)(vite|react-scripts|http-server)([[:space:]]|$)' \
     || printf '%s' "$seg" | grep -qE '(^|[[:space:]])next[[:space:]]+dev([[:space:]]|$)' \
     || printf '%s' "$seg" | grep -qE 'http\.server'; then
    matched=$seg
    break
  fi
done < <(printf '%s' "$cmd" | sed 's/&&/\n/g; s/||/\n/g; s/;/\n/g; s/|/\n/g')

[ -z "$matched" ] && exit 0

jq -nc --arg reason "Esto levanta un dev server en $dir, y ese puerto puede estar ocupado por una sesión que no es la tuya. Pregunta antes de arrancarlo, di qué puerto va a ocupar y por qué lo necesitas; si solo hace falta comprobar tipos o tests, usa build/tsc/vitest en su lugar." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $reason
  }
}'
exit 0
