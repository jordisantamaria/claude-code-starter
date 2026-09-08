# Global instructions

> A template. What matters here is the **shape**, not the content: good rules come from
> your own mistakes, not from this file. Delete all of it and add your own.

## How a rule gets added here

When something goes wrong — Claude edits a file it shouldn't have, repeats a mistake you
already corrected, uses a convention that isn't the project's — **fix it right then**, in
that session. The next day you no longer have the context to know whether the rule you
wrote actually works.

And before writing it here, the question is **where it belongs**:

| If it's… | It goes to… |
|---|---|
| A fact that must not be forgotten | memory |
| A procedure that repeats | a skill |
| Something that becomes an accident if ignored | a hook or a repo script |
| A general preference | here |

Everything you put here competes for priority with everything else here. A file with
forty rules doesn't have forty rules: it has forty things of equal weight.

## Links

Write URLs in full (`https://...`), never as `[text](url)`: terminals only make literal
URLs clickable.

## Git

- Commit format: `<type>: <description>` — `feat`, `fix`, `refactor`, `docs`, `test`,
  `chore`, `perf`, `ci`.
- No AI signatures in commit messages or PR descriptions.
- Before opening a PR, read the branch's full history, not just the last commit.

## Before calling something done

- Errors are handled explicitly; nothing is swallowed in silence.
- External input is validated at the system boundary.
- No credentials written into the code.
- If there are tests, they pass. If they don't, say so — don't call it done anyway.
