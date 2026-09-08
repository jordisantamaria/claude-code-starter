#!/usr/bin/env bash
# Asks for confirmation before Claude starts a dev server.
#
# The problem it solves: with several sessions open on the same project, an `npm run dev`
# launched in the background by Claude takes the port you were using to look at your own
# branch — and it's hard to find out who holds it. When ports are pinned by external
# configuration (OAuth callbacks registered per port, say), "just use another port" isn't
# an option.
#
# It doesn't block: it returns `ask`, so Claude can propose it and you decide on the spot.
#
# ── Configuration ────────────────────────────────────────────────────────────
# CLAUDE_DEV_SERVER_DIRS: path prefixes where this applies, space-separated.
#   Empty = applies in every directory.
#   Example: export CLAUDE_DEV_SERVER_DIRS="$HOME/work/shop $HOME/work/api"
DEV_SERVER_DIRS="${CLAUDE_DEV_SERVER_DIRS:-}"
#
# Deliberately allowed through:
#   - builds, tests, lint, tsc (nothing listens on a port)
#   - inspecting or killing what already listens (ss, lsof, kill, pgrep)
#   - mentioning the command inside a grep/echo

set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$dir" ] && dir=$PWD

# `cd /other/project && npm run dev` acts on THAT directory, not the session's.
cd_target=$(printf '%s' "$cmd" | grep -oE '^[[:space:]]*cd[[:space:]]+[^&;|]+' | sed -E 's/^[[:space:]]*cd[[:space:]]+//; s/[[:space:]]+$//' | tr -d '"'"'"'')
[ -n "$cd_target" ] && [ -d "$cd_target" ] && dir=$cd_target

if [ -n "$DEV_SERVER_DIRS" ]; then
  match=0
  for prefix in $DEV_SERVER_DIRS; do
    case "$dir" in "$prefix"*) match=1 ;; esac
  done
  [ "$match" = "0" ] && exit 0
fi

# Checked segment by segment: `ss -lptn ... | grep vite` starts nothing.
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

jq -nc --arg reason "This starts a dev server in $dir, and that port may belong to a session that isn't yours. Ask before starting it, say which port it will take and why you need it; if you only need to check types or tests, use build/tsc/vitest instead." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $reason
  }
}'
exit 0
