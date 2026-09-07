---
name: issue
description: |
  Create a GitHub Issue in the current repository.
  Triggers: "create an issue", "new issue", "bug report", "feature request"
argument-hints: [--batch]
allowed-tools:
  - Bash(gh issue create:*)
  - Bash(gh issue view:*)
  - Bash(gh issue edit:*)
  - Bash(gh api:*)
  - Bash(gh label list:*)
  - Bash(git remote:*)
  - AskUserQuestion
---

# /issue

Create a GitHub Issue in the current repository.

## Arguments

- `--batch`: Ask all questions at once instead of one by one.

## Context

Current repo:
!`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]//;s/.git$//'`

Current user:
!`gh api user -q '.login'`

Available labels:
!`gh label list --limit 50 --json name -q '.[].name' 2>/dev/null`

Milestones:
!`gh api repos/{owner}/{repo}/milestones --jq '.[].title' 2>/dev/null || echo "none"`

## Steps

### 1. Detect repository

Extract `{owner}/{repo}` from the Context above. All `gh` commands will use `-R {owner}/{repo}`.

### 2. Gather information

Use AskUserQuestion to collect the following. Optional fields can be skipped.

**Collection mode:**
- **Default**: ask questions **one by one**
- **`--batch`**: ask **all at once** (group up to 4 per AskUserQuestion)

1. **Title** (required) - concise issue title
2. **Type** (required) - Bug / Feature / Task
3. **Assignee** (optional) - "me", a username, or skip
4. **Labels** (optional) - from available labels, or create new
5. **Milestone** (optional) - from available milestones, or skip
6. **Description** (required) - motivation and what needs to be done

### 3. Preview and confirm

Show the issue preview to the user:

```
Title: {title}
Type: {type}
Labels: {labels}
Assignee: {assignee or none}
Milestone: {milestone or none}

--- Body ---
## Purpose
{purpose/motivation}

## Tasks
{what needs to be done, as checklist}
```

Ask for confirmation with AskUserQuestion:
- Approved → create the issue
- Needs changes → ask for corrections, show preview again

### 4. Create Issue

```bash
gh issue create -R {owner}/{repo} \
  --title "{title}" \
  --body "{body}" \
  --assignee "{assignee}" \
  --label "{labels}" \
  --milestone "{milestone}"
```

- `--assignee`: only if specified (`@me` for self)
- `--label`: only if specified
- `--milestone`: only if specified

### 5. Done

Display the created Issue URL.

## Notes

- Ask questions in the user's configured language
- **Title and body must be in the same language as the project's existing issues** (check recent issues if unsure)
- Show the Issue URL when done
