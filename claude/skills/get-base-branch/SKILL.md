---
name: get-base-branch
description: Auto-detect the closest ancestor (base branch candidate) from the current branch
allowed-tools:
  - Bash(sh ~/.claude/skills/get-base-branch/scripts/get-base-branch.sh *)
  - AskUserQuestion
---

Run `sh ~/.claude/skills/get-base-branch/scripts/get-base-branch.sh` and use its stdout as the base branch name.

**Return value handling**:
- Branch name (e.g. `main`): use it as-is.
- `CONFIRM:` prefix (e.g. `CONFIRM: develop, release/1.0`): ask the user which branch to use.
