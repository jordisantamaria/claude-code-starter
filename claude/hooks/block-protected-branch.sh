#!/usr/bin/env bash
# Stops Claude from merging or pushing to the branch that ships to production.
#
# The idea: preparing the release is the AI's job; publishing it is a human decision.
# Claude can do all of it — branch, commits, PR, merges to your integration branch —
# and stops at the last step.
#
# This is deliberately NOT a rule in CLAUDE.md. A rule dilutes among the others and one
# day it doesn't apply; a hook denies every time, and the denial is not negotiable.
#
# ── Configuration ────────────────────────────────────────────────────────────
# CLAUDE_PROTECTED_REPOS: fragments that must appear in the `origin` remote URL for this
#   hook to act. Empty = acts in EVERY repo.
#   Example: export CLAUDE_PROTECTED_REPOS="myorg/shop myorg/api"
# CLAUDE_INTEGRATION_BRANCHES: branches you can merge into without being asked.
PROTECTED_REPOS="${CLAUDE_PROTECTED_REPOS:-}"
INTEGRATION_BRANCHES="${CLAUDE_INTEGRATION_BRANCHES:-develop dev staging}"
#
# Deliberately allowed through:
#   - `gh pr create --base main` (preparing the PR is exactly what you want)
#   - any merge or push to an integration branch
#   - reads: `gh pr view`, `git log main..HEAD`, `git diff main`…
#
# Known limitation: the hook inspects the command text, so a command that merely MENTIONS
# these operations (writing this very file with a heredoc, for instance) is denied too.
# That's the price of not parsing shell for real, and the false positive is preferred.

set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Cheap shortcut: if main/master isn't named, there's nothing to look at.
printf '%s' "$cmd" | grep -qE '\bmain\b|\bmaster\b|pr merge' || exit 0

dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$dir" ] && dir=$PWD

# A command starting with `cd /other/repo && ...` acts on THAT repo, not on the session's
# directory. Without this, looking at the wrong repo produced false positives: it couldn't
# find the PR, couldn't read its base, and denied a perfectly legitimate merge.
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

PROD_RULE='main ships, so a person takes that last step from GitHub. Prepare the branch, the commits and the PR (creating a PR with base main is allowed), leave it ready and say so.'

# ── direct push to the branch that ships ─────────────────────────────────────
# Covers the `origin main`, `-u origin main`, `HEAD:main` and `--force` variants.
# Pushing main INTO another branch (`main:develop`) isn't publishing, so it only counts
# when main is the DESTINATION — the part after the colon.
if printf '%s' "$cmd" | grep -qE '\bgit\s+push\b'; then
  if printf '%s' "$cmd" | grep -qE '(:|[[:space:]])(refs/heads/)?(main|master)([[:space:]]|$)'; then
    deny "Blocked: direct push to the branch that ships. $PROD_RULE"
  fi
fi

# ── merging a PR whose base is the branch that ships ─────────────────────────
# The base isn't in the command, so it gets looked up. If it can't be determined, deny:
# a false positive you clear by hand beats a deploy nobody asked for.
if printf '%s' "$cmd" | grep -qE '\bgh\s+pr\s+merge\b'; then
  pr=$(printf '%s' "$cmd" | grep -oE '\bgh\s+pr\s+merge\s+[0-9]+' | grep -oE '[0-9]+$' || true)
  # `--repo owner/name` wins over the directory: that's the repo gh will touch.
  repo_flag=$(printf '%s' "$cmd" | grep -oE '[-][-]repo[= ][^ ]+' | sed -E 's/^--repo[= ]//' || true)
  gh_args=""
  [ -n "$repo_flag" ] && gh_args="--repo $repo_flag"
  # With no number, gh takes the current branch's PR: ask about that one.
  base=$(cd "$dir" 2>/dev/null && gh pr view $pr $gh_args --json baseRefName --jq .baseRefName 2>/dev/null || true)
  ok=0
  for b in $INTEGRATION_BRANCHES; do [ "$base" = "$b" ] && ok=1; done
  if [ "$ok" = "0" ]; then
    case "$base" in
      main|master) deny "Blocked: that PR has base $base. $PROD_RULE" ;;
      *) deny "Blocked: couldn't determine that PR's base, and main ships here. Check it with 'gh pr view <n> --json baseRefName'; if it targets an integration branch, pass the number. $PROD_RULE" ;;
    esac
  fi
fi

# ── local merge/rebase while on the branch that ships ────────────────────────
if printf '%s' "$cmd" | grep -qE '\bgit\s+(merge|rebase)\b'; then
  current=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  case "$current" in
    main|master) deny "Blocked: you're on $current and this moves the branch that ships. $PROD_RULE" ;;
  esac
fi

exit 0
