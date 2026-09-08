#!/usr/bin/env bash
# Refuses to edit code while the session sits in the repository's main checkout.
#
# Why: several agent sessions on one repo collide in three ways, and all three are quiet.
#
#   - The git index is shared. Your `git add` gets swept into another session's commit.
#   - A pre-commit hook that typechecks the whole project fails on someone else's
#     half-finished refactor, so you can't commit even though your files are fine.
#   - Two sessions editing one file lose one of the two changes with no error.
#
# A worktree removes all three: its own index, its own tree, its own checkout.
#
# This is a hook and not a line in CLAUDE.md on purpose. "Work in a worktree" is followed
# most of the time, and the accidents live in the rest.
#
# ── Configuration ────────────────────────────────────────────────────────────
# CLAUDE_WORKTREE_REPOS: fragments that must appear in the `origin` remote URL for this
#   hook to act. Empty = acts in EVERY git repo, which is probably not what you want.
#   Example: export CLAUDE_WORKTREE_REPOS="myorg/app"
# CLAUDE_WORKTREE_BRANCHES: branches that are shared, and therefore protected here.
WORKTREE_REPOS="${CLAUDE_WORKTREE_REPOS:-}"
WORKTREE_BRANCHES="${CLAUDE_WORKTREE_BRANCHES:-main master develop dev}"
#
# Deliberately allowed through:
#   - editing from inside a worktree (that's the point)
#   - editing while on a task branch in the main checkout — you chose that
#   - reading, searching, running tests, git operations
#   - docs-only edits (*.md), which rarely collide

set -uo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$file" ] && exit 0

case "$file" in
  *.md|*.markdown|*.txt) exit 0 ;;
esac

dir=$(dirname "$file")
[ -d "$dir" ] || dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -d "$dir" ] || exit 0

git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

if [ -n "$WORKTREE_REPOS" ]; then
  origin=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
  match=0
  for frag in $WORKTREE_REPOS; do
    case "$origin" in *"$frag"*) match=1 ;; esac
  done
  [ "$match" = "0" ] && exit 0
fi

# In a linked worktree, --git-dir points inside the main repo's .git/worktrees/.
# In the main checkout it does not. That is the whole test.
gitdir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null || true)
case "$gitdir" in
  */.git/worktrees/*) exit 0 ;;
esac

branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
protected=0
for b in $WORKTREE_BRANCHES; do [ "$branch" = "$b" ] && protected=1; done
[ "$protected" = "0" ] && exit 0

jq -nc --arg reason "This edits the main checkout while it is on '$branch', which other sessions share: the git index, the pre-commit typecheck and the file itself are all shared, and each of those loses work silently. Create a worktree for this task and edit there, then land it when it is done." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
