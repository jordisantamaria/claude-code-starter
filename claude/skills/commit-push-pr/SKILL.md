---
name: commit-push-pr
description: Commit staged changes, push to remote, and create a draft PR in one flow
argument-hints: [base branch name]
allowed-tools:
  - Skill(commit)
  - Skill(pr)
---

# /commit-push-pr

Commit, push, and create a PR in a single flow.

## Steps

### 1. Commit

Run the `/commit` skill. If the user cancels or there are no changes, stop.

### 2. Create PR

Run the `/pr` skill (which handles push and PR creation).
Pass `$ARGUMENTS` as the base branch if provided.

## Notes

- If commit fails or is cancelled, do not proceed to PR
- All commit and PR rules from the individual skills apply
