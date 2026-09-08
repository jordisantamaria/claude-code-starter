# claude-code-starter

> ### 📄 This repo is the companion to an article
>
> **Read it first — it explains why each file is where it is:**
>
> ### https://zenn.dev/jordisantamaria/articles/claude-code-config-layers
>
> *Written in Japanese. 「Claude Codeの設定を、記憶352件・スキル71個まで育てました」*
>
> The repo is the starting point. **The article is the method.** Copying the files
> without the method gets you someone else's config, which is the one thing the
> article argues against.

---

A working Claude Code configuration, extracted from the one I actually use every day.

**This is a starting point, not a formula.** There is no config you can paste that fixes
your setup, because someone else's config is the answer to someone else's mistakes. What
you can copy is the *shape*: what goes where, and why.

[`affaan-m/ECC`](https://github.com/affaan-m/ECC) was my start line — I no longer run it.
What's left is five months of fixing things the moment they broke, and this repo is the
part of that which is generic enough to be useful to anyone.

## What's here

| | |
|---|---|
| `claude/settings.json` | Permissions (68 allow / 16 deny), hooks, statusline |
| `claude/CLAUDE.md` | A template — structure, not content |
| `claude/hooks/` | Two `PreToolUse` hooks that actually stop things |
| `claude/skills/` | 4 skills for day-to-day git and PR work |
| `claude/statusline-command.sh` | Status line showing **context used** — the number you steer by |
| `install.sh` | Symlinks it into `~/.claude` |

## Install

```bash
git clone https://github.com/<you>/claude-code-starter
cd claude-code-starter
./install.sh --dry-run   # see what it would do
./install.sh
```

It **symlinks** instead of copying, and that is the whole point. If you copy, every fix
you make in the heat of the moment stays in `~/.claude` and your repo silently goes stale
— until the day you restore it on a new machine and get back a config that no longer
matches reality. With symlinks, editing your config *is* editing the repo.

Requires `jq` and `gh` for the hooks.

## The hooks

Rules in `CLAUDE.md` are requests. Hooks are not.

- **`block-protected-branch.sh`** — Claude can prepare everything (branch, commits, PR,
  merges to your integration branch) and stops at the last step: the merge that publishes.
  Set `CLAUDE_PROTECTED_REPOS` to scope it, or leave it empty to apply everywhere.
- **`ask-before-dev-server.sh`** — asks before starting a dev server, because with several
  sessions open the port you were using is not yours alone. Scope with
  `CLAUDE_DEV_SERVER_DIRS`.

Both are commented with *why* they exist and what they deliberately let through. Read them
before enabling them; a hook you don't understand is a hook that will block you at 2am.

## The skills

Git and PR work only. Deliberately few: these are the ones that are useful without
knowing anything about my projects.

| Skill | What it does |
|---|---|
| `commit` | Generates commit message candidates from staged changes, you pick one |
| `commit-push-pr` | Commit, push and open a draft PR in one go |
| `get-base-branch` | Detects the closest ancestor branch |
| `issue` | Writes a GitHub issue from a description |


## How to actually use this

Install it, then **break it**. Delete the skills you don't use, rewrite the rules that
don't match your projects, and — the only part that really matters — every time Claude
does something wrong, fix the config *right then*, in that session, while you still have
the context to know whether the fix works.

That habit is the whole thing. The files are just where it accumulates.

## License

MIT.
