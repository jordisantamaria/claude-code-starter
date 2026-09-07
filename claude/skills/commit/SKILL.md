---
name: commit
description: Generate commit message from staged changes, select by number to confirm
allowed-tools:
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git branch:*)
  - Bash(git log:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - AskUserQuestion
---

# /commit

## Context

Staged changes:
!`git diff --cached`

Unstaged changes:
!`git diff`

Current branch:
!`git branch --show-current`

Recent commits:
!`git log --oneline -5`

## No AI signatures

**Never include in commit messages:**
- `Generated with [Claude Code]`
- `Co-Authored-By: Claude <noreply@anthropic.com>`
- Any other AI-generated signatures

## Flow

### 1. Check staged changes

#### A. Staged changes exist

Proceed to analysis.

#### B. No staged, but unstaged changes exist

AskUserQuestion:

> No staged changes found.
>
> Stage all unstaged changes?
>
> 1: Yes, add all
> 2: No, cancel

Rules:
- "1" → `git add -A`, re-check `git diff --cached`, proceed if non-empty
- "2" → "Cancelled." and stop
- Other → re-ask

#### C. No changes at all

"No changes to commit." and stop.

### 2. Analyze and generate candidates

Analyze the diff and generate **3 commit message candidates**:

1. Analyze staged changes only
2. Create 3 messages with different perspectives:
   - Conventional Commits format (`feat`/`fix`/`docs`/`refactor`/`chore` etc.)
   - Match the language of recent commits in the repo
   - If branch contains an issue number (e.g. `issue/123-foo`), include it: `feat: #123 description`
   - Each candidate offers a different angle (technical detail, business value, simple)

### 3. User selection

Present candidates via AskUserQuestion. User picks by number.

### 4. Commit

Execute the commit with the selected message.

## Constraints

- No AI co-authorship footer
- Single line (no body)
- Match existing commit style/language in the repo
