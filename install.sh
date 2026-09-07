#!/usr/bin/env bash
# Instala esta configuración en ~/.claude ENLAZANDO, no copiando.
#
# Por qué enlaces y no copias: si copias, cada arreglo que hagas en caliente se queda solo
# en ~/.claude y el repo se va quedando viejo sin avisar. Con enlaces, editar la
# configuración ES editar el repo, y no hay nada que acordarse de sincronizar.
#
# Uso:
#   ./install.sh            instala
#   ./install.sh --dry-run  enseña qué haría, sin tocar nada
#
# Lo que ya existe y no es un enlace se guarda como <fichero>.bak antes de sustituirlo.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say()  { printf '  %s\n' "$*"; }
run()  { if [ "$DRY" = "1" ]; then say "· $*"; else "$@"; fi }

link() {
  local src=$1 dst=$2
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    say "backup: $dst → $dst.bak"
    run mv "$dst" "$dst.bak"
  fi
  say "enlace: ${dst/#$HOME/\~} → ${src/#$REPO_DIR/.}"
  run ln -sfn "$src" "$dst"
}

printf '\nInstalando en %s\n\n' "$CLAUDE_DIR"
run mkdir -p "$CLAUDE_DIR/skills"

link "$REPO_DIR/claude/settings.json"        "$CLAUDE_DIR/settings.json"
link "$REPO_DIR/claude/CLAUDE.md"            "$CLAUDE_DIR/CLAUDE.md"
link "$REPO_DIR/claude/hooks"                "$CLAUDE_DIR/hooks"
link "$REPO_DIR/claude/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"

# Las skills se enlazan una a una: así conviven con las tuyas en el mismo directorio.
for d in "$REPO_DIR"/claude/skills/*/; do
  link "${d%/}" "$CLAUDE_DIR/skills/$(basename "$d")"
done

cat <<'FIN'

Listo. Dos cosas antes de usarlo:

  1. Los hooks necesitan `jq` y `gh` (GitHub CLI) en el PATH.
  2. Los hooks no actúan en ningún repo hasta que se los digas. En tu shell:

       export CLAUDE_PROTECTED_REPOS="miorg/mi-repo"
       export CLAUDE_DEV_SERVER_DIRS="$HOME/work/mi-proyecto"

     Sin CLAUDE_PROTECTED_REPOS el hook de rama protegida actúa en TODOS los repos,
     que puede ser justo lo que quieres. Léelo antes de decidir:
     claude/hooks/block-protected-branch.sh

Y lo más importante: esto es un punto de partida, no una configuración terminada.
FIN
