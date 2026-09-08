#!/usr/bin/env bash
# Installs this configuration into ~/.claude by SYMLINKING, not copying.
#
# Why links and not copies: if you copy, every fix you make in the heat of the moment
# stays in ~/.claude and the repo goes stale without telling you. With symlinks, editing
# your config IS editing the repo, and there is nothing to remember to sync.
#
# Usage:
#   ./install.sh            install
#   ./install.sh --dry-run  show what it would do, without touching anything
#
# Anything that already exists and is not a symlink is saved as <file>.bak first.

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
  say "link:   ${dst/#$HOME/\~} → ${src/#$REPO_DIR/.}"
  run ln -sfn "$src" "$dst"
}

printf '\nInstalling into %s\n\n' "$CLAUDE_DIR"
run mkdir -p "$CLAUDE_DIR/skills"

link "$REPO_DIR/claude/settings.json"        "$CLAUDE_DIR/settings.json"
link "$REPO_DIR/claude/CLAUDE.md"            "$CLAUDE_DIR/CLAUDE.md"
link "$REPO_DIR/claude/hooks"                "$CLAUDE_DIR/hooks"
link "$REPO_DIR/claude/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"

# Skills are linked one by one, so they coexist with your own in the same directory.
for d in "$REPO_DIR"/claude/skills/*/; do
  link "${d%/}" "$CLAUDE_DIR/skills/$(basename "$d")"
done

cat <<'FIN'

Done. Two things before you use it:

  1. The hooks need `jq` and `gh` (GitHub CLI) on your PATH.
  2. The hooks act in no repo until you tell them to. In your shell:

       export CLAUDE_PROTECTED_REPOS="myorg/my-repo"
       export CLAUDE_DEV_SERVER_DIRS="$HOME/work/my-project"

     With CLAUDE_PROTECTED_REPOS unset, the protected-branch hook acts in EVERY repo,
     which may be exactly what you want. Read it before deciding:
     claude/hooks/block-protected-branch.sh

And the part that matters: this is a starting point, not a finished configuration.
FIN
