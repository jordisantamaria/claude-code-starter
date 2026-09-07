#!/usr/bin/env bash
# Impide que Claude mergee o empuje a la rama que publica a producción.
#
# La idea: preparar el release es trabajo de la IA; publicarlo es una decisión humana.
# Claude puede hacerlo todo —ramas, commits, PRs, merges a la rama de integración— y
# para en el último escalón.
#
# Esto NO es una regla escrita en CLAUDE.md, a propósito. Una regla se diluye entre las
# demás y algún día no se aplica; un hook deniega siempre, y la denegación no se negocia.
#
# ── Configuración ────────────────────────────────────────────────────────────
# CLAUDE_PROTECTED_REPOS: fragmentos que deben aparecer en la URL del remote `origin`
#   para que el hook actúe. Vacío = actúa en TODOS los repos.
#   Ejemplo: export CLAUDE_PROTECTED_REPOS="miorg/tienda miorg/api"
# CLAUDE_INTEGRATION_BRANCHES: ramas a las que sí se puede mergear sin preguntar.
PROTECTED_REPOS="${CLAUDE_PROTECTED_REPOS:-}"
INTEGRATION_BRANCHES="${CLAUDE_INTEGRATION_BRANCHES:-develop dev staging}"
#
# Deja pasar a propósito:
#   - `gh pr create --base main` (preparar el PR es justo lo que se quiere)
#   - cualquier merge o push a una rama de integración
#   - lecturas: `gh pr view`, `git log main..HEAD`, `git diff main`…
#
# Nota conocida: el hook mira el texto del comando, así que un comando que solo MENCIONA
# estas operaciones (escribir este mismo fichero con un heredoc, por ejemplo) también se
# deniega. Es el precio de no parsear shell de verdad, y se prefiere el falso positivo.

set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Atajo barato: si no se nombra main/master, no hay nada que mirar.
printf '%s' "$cmd" | grep -qE '\bmain\b|\bmaster\b|pr merge' || exit 0

dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$dir" ] && dir=$PWD

# Un comando que empieza por `cd /otro/repo && ...` actúa sobre ESE repo, no sobre el
# directorio de la sesión. Sin esto, mirar el repo equivocado daba falsos positivos: no
# encontraba el PR, no podía leer su base y denegaba un merge perfectamente legítimo.
cd_target=$(printf '%s' "$cmd" | grep -oE '^[[:space:]]*cd[[:space:]]+[^&;|]+' | sed -E 's/^[[:space:]]*cd[[:space:]]+//; s/[[:space:]]+$//' | tr -d '"'"'"'')
[ -n "$cd_target" ] && [ -d "$cd_target" ] && dir=$cd_target

if [ -n "$PROTECTED_REPOS" ]; then
  origin=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
  match=0
  for frag in $PROTECTED_REPOS; do
    case "$origin" in *"$frag"*) match=1 ;; esac
  done
  [ "$match" = "0" ] && exit 0
fi

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

PROD_RULE='main publica, así que ese último paso lo da una persona desde GitHub. Prepara la rama, el commit y el PR (crear el PR con base main sí está permitido), déjalo listo y avisa.'

# ── push directo a la rama que publica ───────────────────────────────────────
# Cubre las variantes con `origin main`, `-u origin main`, `HEAD:main` y `--force`.
# Empujar main HACIA otra rama (`main:develop`) no es publicar, así que solo cuenta
# cuando main es el DESTINO — la parte después de los dos puntos.
if printf '%s' "$cmd" | grep -qE '\bgit\s+push\b'; then
  if printf '%s' "$cmd" | grep -qE '(:|[[:space:]])(refs/heads/)?(main|master)([[:space:]]|$)'; then
    deny "Bloqueado: push directo a la rama que publica. $PROD_RULE"
  fi
fi

# ── merge de un PR cuya base es la rama que publica ──────────────────────────
# La base no viene en el comando, así que se consulta. Si no se puede averiguar, se
# deniega: preferimos un falso positivo que se destraba a mano a un deploy que nadie pidió.
if printf '%s' "$cmd" | grep -qE '\bgh\s+pr\s+merge\b'; then
  pr=$(printf '%s' "$cmd" | grep -oE '\bgh\s+pr\s+merge\s+[0-9]+' | grep -oE '[0-9]+$' || true)
  # `--repo owner/name` manda sobre el directorio: es el repo que gh va a tocar.
  repo_flag=$(printf '%s' "$cmd" | grep -oE '[-][-]repo[= ][^ ]+' | sed -E 's/^--repo[= ]//' || true)
  gh_args=""
  [ -n "$repo_flag" ] && gh_args="--repo $repo_flag"
  # Sin número, gh toma el PR de la rama actual: se pregunta por esa.
  base=$(cd "$dir" 2>/dev/null && gh pr view $pr $gh_args --json baseRefName --jq .baseRefName 2>/dev/null || true)
  ok=0
  for b in $INTEGRATION_BRANCHES; do [ "$base" = "$b" ] && ok=1; done
  if [ "$ok" = "0" ]; then
    case "$base" in
      main|master) deny "Bloqueado: ese PR tiene como base $base. $PROD_RULE" ;;
      *) deny "Bloqueado: no he podido comprobar la base de ese PR, y aquí main publica. Compruébala con 'gh pr view <n> --json baseRefName'; si va a una rama de integración, indica el número. $PROD_RULE" ;;
    esac
  fi
fi

# ── merge/rebase local estando en la rama que publica ────────────────────────
if printf '%s' "$cmd" | grep -qE '\bgit\s+(merge|rebase)\b'; then
  current=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  case "$current" in
    main|master) deny "Bloqueado: estás en $current y eso mueve la rama que publica. $PROD_RULE" ;;
  esac
fi

exit 0
