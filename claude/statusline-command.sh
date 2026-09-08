#!/usr/bin/env bash
# Claude Code status line — mirrors a Starship-style prompt.
#
# Shows: directory · git branch · model · context used.
#
# The context percentage is the point. Managing context is most of what using Claude Code
# is, and you can't manage a number you can't see. Colour thresholds: green below 50%,
# yellow 50-80%, red above 80% — 50% is where compacting on your own terms beats having
# it happen automatically in the middle of something.
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip optional lock to avoid conflicts)
branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
fi

# Build parts
dir_part=$(printf '\033[34m%s\033[0m' "$short_cwd")

branch_part=""
if [ -n "$branch" ]; then
  branch_part=$(printf ' \033[35m\xef\xad\xa5 %s\033[0m' "$branch")
fi

model_part=""
if [ -n "$model" ]; then
  model_part=$(printf ' \033[36m[%s]\033[0m' "$model")
fi

ctx_part=""
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  if [ "$used_int" -ge 80 ]; then
    ctx_part=$(printf ' \033[31mctx:%s%%\033[0m' "$used_int")
  elif [ "$used_int" -ge 50 ]; then
    ctx_part=$(printf ' \033[33mctx:%s%%\033[0m' "$used_int")
  else
    ctx_part=$(printf ' \033[32mctx:%s%%\033[0m' "$used_int")
  fi
fi

printf '%b%b%b%b' "$dir_part" "$branch_part" "$model_part" "$ctx_part"
