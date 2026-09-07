---
name: wtd
description: Refresh worktree dashboard — scan active worktrees and update ~/wt-board.md
allowed-tools:
  - Bash(git worktree list:*)
  - Bash(git -C * rev-parse:*)
  - Bash(git -C * log:*)
  - Bash(git -C * diff:*)
  - Bash(git -C * status:*)
  - Bash(gh pr list:*)
  - Bash(gh pr view:*)
  - Bash(gh issue view:*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# /wtd — Refresh Worktree Dashboard

Scan all active git worktrees, analyze the issue + code changes for each, and generate `~/wt-board.md` with **issue-specific** verification checklists.

## Steps

1. **List worktrees**: Run `git worktree list`. Identify the main worktree (has `.git` directory, not file).

2. **For each worktree (including the main one)**, gather:
   - Branch: `git -C <path> rev-parse --abbrev-ref HEAD`
   - Issue number: extract from `issue/<num>*` or `task/<num>*`
   - Status: `git -C <path> status --short`
   - Commits: `git -C <path> log --oneline -5`
   - Diff stat: `git -C <path> diff --stat main...HEAD`
   - PR (all states): `gh pr list --head <branch> --state all --json number,title,url,isDraft,state --limit 1`
   - Issue title+body: `gh issue view <num> --repo globeejp/abceed-issue --json title,body` (silent fail ok)

3. **Detect merged PRs**: If the PR state is `MERGED`, **remove** that task's section entirely from the board. Do NOT include it at all — it's done and shipped.

4. **Analyze the changes deeply** (this is the key step — only for non-merged tasks):
   - Read the full diff: `git -C <path> diff main...HEAD` to understand what was changed
   - Read the issue body to understand the requirement
   - Identify which components/pages/files were modified
   - **Determine if changes are legacy or modern**:
     - Files under `src/` → **legacy** (Vue 2, no Storybook) → verify on `localhost:8080`
     - Files under `workspaces/modern/` → **modern** (Vue 3) → can use Storybook `localhost:6006`
   - **For legacy changes**: find the route/page where the component is used. Read `src/routes.js` and trace the component usage to determine the navigation path in the app. Use the issue body's use cases to build a concrete step-by-step navigation: e.g. "Abrir libro X → lección Y → completar ejercicio → pantalla de resultados"
   - **For modern changes**: search for `.stories.ts` files matching the modified components. Build the Storybook URL: `http://localhost:6006/?path=/story/{story-id}`
   - If the issue has Figma links, extract them

5. **Generate issue-specific checklist** — NOT generic. Each item must be a concrete, verifiable action:
   - **Legacy components**: step-by-step navigation instructions to reach the screen on `localhost:8080` (based on issue use cases and route analysis). NO Storybook URLs for legacy.
   - **Modern components**: specific Storybook URLs for each relevant story variant
   - Specific app URLs (`localhost:8080/...`) for pages where the change is visible, with navigation steps
   - Edge cases specific to the change (e.g., for a slider: drag behavior, min/max bounds, touch vs mouse, RTL, disabled state)
   - Visual checks referencing Figma if link exists in the issue
   - Behavioral checks based on what the issue asks for
   - Regression checks for functionality that existed before and should still work
   - Always end with: diff review (`<leader>gv`) and PR status

6. **Read existing board**: Preserve `- [x]` checked items from existing `ACTIVE` sections — merge into new sections.

7. **Write** `~/wt-board.md`

## Board format

```markdown
# Worktree Dashboard

> Actualizado: {YYYY-MM-DD HH:MM}

- [ ] #{issue_number} — {title}
- [ ] #{issue_number} — {title}

---

## #{issue_number} — {title} `ACTIVE`

| | |
|---|---|
| **Branch** | `{branch}` |
| **Dir** | `{dirname}` |
| **PR** | {link or "ninguna"} |
| **Figma** | {figma link or omit row} |

### Verificar

- [ ] {specific action 1 — with URL, component name, expected behavior}
- [ ] {specific action 2}
- [ ] ...
- [ ] Revisar el diff: `<leader>gv` en neovim (diffview)
- [ ] PR creada en draft — revisar en GitHub

---
```

### Index checklist

- Appears right after the header, before the `---` separator and task sections — no heading, just the checklist lines
- One `- [ ]` line per ACTIVE task: `- [ ] #{number} — {title}`
- Quick overview to see which tasks are pending verification
- The user toggles these manually in neovim once they finish verifying a task
- Preserve existing `- [x]` checks from the previous board's index when refreshing

## Checklist generation rules

- Every checklist item must be **actionable and specific to this issue**
- **Legacy (`src/`)**: NO Storybook links — provide navigation steps on `localhost:8080` to reach the screen. Use the issue's use cases section to determine the exact flow.
- **Modern (`workspaces/modern/`)**: include Storybook URLs (`localhost:6006/?path=/story/...`)
- For all UI changes: include app URLs (`localhost:8080/...`) with step-by-step navigation
- For UI changes: check each visual state (default, hover, active, disabled, error)
- For component replacements: verify feature parity with the old implementation
- For bug fixes: verify the bug is fixed AND that the happy path still works
- For config/tooling changes: verify the tool works as expected, check CI if relevant
- NEVER use generic items like "comprobar que el cambio resuelve la issue" — be specific about WHAT to check and WHERE

## Merged task handling

- Check PR state for each worktree branch: `gh pr list --head <branch> --state all --json state --limit 1`
- If state is `MERGED`: **delete the entire section** from the board — do not keep it as DONE/REMOVED
- Also remove it from the Pendientes index
- This keeps the board clean — only actionable items remain

## Other rules

- KEEP checked `- [x]` from existing `ACTIVE` sections — merge into new sections
- `ACTIVE` sections without a matching worktree AND without a merged PR → change to `REMOVED`
- Sort: `ACTIVE` first (by issue number asc), then `REMOVED` at the bottom
- Write the file directly — do NOT ask for confirmation
- After writing, display a short summary table of all worktrees found
