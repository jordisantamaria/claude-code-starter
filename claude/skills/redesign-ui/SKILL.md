---
name: redesign-ui
description: Builds a rich, copy-pasteable prompt for design-focused AI tools (v0, Figma AI, Google Stitch, Lovable, Galileo) using your project's real context — stack, brand, current component, actual copy. This skill does not design; it writes the prompt you paste into the tool. Use for "/redesign-ui <page>", "redesign the UI of X", "I need a prompt for v0/Stitch".
---

# /redesign-ui

Coding agents are good at logic and mediocre at visual hierarchy, typographic taste and
motion feel. Design-focused tools are better at those — but their output is generic unless
the prompt carries the product's context.

**The bottleneck is the prompt, not the tool.** This skill writes it.

## Input

Ask for whatever isn't given:

1. **Page or component** — a file path or a route.
2. **Goal** (default: "explore more visually appealing options"): denser or lighter,
   mobile-first, more corporate, warmer, better conversion, or free text.
3. **Target tool** (default: auto).

## Step 1 — Detect the stack

Never assume it. Read it:

```bash
test -f package.json && grep -oE '"(next|react|vue|svelte|tailwindcss)": *"[^"]+"' package.json
test -f tailwind.config.ts -o -f tailwind.config.js && echo "tailwind"
test -d components/ui && echo "shadcn-style component dir"
```

## Step 2 — Read the brand, if the project has one

Look for design documentation in the usual places (`docs/`, the README, a design-system
package). If there is none, say so and continue with defaults — but tell the user the
output stays generic until they write one down.

## Step 3 — Read what exists today

Open the component and its direct children, one level deep. Capture:

- The structure — what actually renders
- Which shared components it uses
- The prominent utility classes
- The data it paints
- **The real copy** — labels, placeholders, CTAs, verbatim

That last one matters most. Real copy is what stops the tool from inventing a product.

## Step 4 — Screenshot, if a dev server is up

```bash
curl -sf http://localhost:3000 >/dev/null && echo "dev server running"
```

If it is, offer to capture the page with a browser tool and attach the image to the
prompt. If not, skip it — a text prompt still works.

## Step 5 — Pick the tool

| Goal and stack | Tool |
|---|---|
| React + Tailwind, want code back | **v0** |
| Explore several options, no code | **Figma AI** |
| A whole mobile flow, not one screen | **Google Stitch** |
| A standalone app from scratch | **Lovable** |
| Fast low-fi wireframes | **Galileo / Uizard** |

A tool the user names always wins.

## Step 6 — Write the prompt

```markdown
# Redesign request: <PAGE / COMPONENT>

## Product context
- **Name**: <product>
- **One-liner**: <what it does>
- **Target user**: <who>
- **Primary UI language**: <language>

## Stack constraints (the output must respect these)
- <framework and version>
- <styling approach — utility classes only, no custom CSS, etc.>
- <component library in use>
- <responsive target, dark mode, icon set>

## Brand
### Visual tone
<palette, typography, density — from the project's own docs>
### Voice
<how the product talks; 3-5 bullets, not the whole document>
### Copy language
<language>. Real strings from the current screen:
- <3-4 verbatim strings>

## Current screen
<what it shows, what it lets you do, which states exist: loading, empty, error>
### Components present
- <list>
### Current copy (verbatim)
<paste real strings>
### Pain points
<what's wrong today; if unknown, say "dense, unclear hierarchy">

## Goal
<the user's request, unedited>

## Expected output
<per tool: a component, N frame variants, a full flow, a preview, annotated wireframes>

## Do NOT
- Invent features that aren't in the current screen
- Change the component's logic — presentation only
- Add urgency CTAs ("Limited offer!")
- Use generic stock imagery
```

## Step 7 — Hand it over

Save the prompt to a file, copy it to the clipboard if the environment has a clipboard
tool, and tell the user which tool to open, why, and to attach the screenshot if that tool
accepts image input.

| Tool | URL |
|---|---|
| v0 | https://v0.dev |
| Figma AI | https://figma.com |
| Google Stitch | https://stitch.withgoogle.com |
| Lovable | https://lovable.dev |
| Galileo | https://usegalileo.ai |

## Anti-patterns

- Writing the prompt without reading the current component — the output will be generic
- Assuming the stack instead of detecting it
- Pasting whole documentation files into the prompt — it overflows the tool's context;
  extract only what applies
- Asking for "a nicer design" with no goal — vague in, vague out
- Recommending a code-generating tool when the goal is exploring: it returns one variant,
  and exploring needs several

## When not to use it

- **Small tweaks** (colour, spacing) — do them directly
- **A visual bug** (clipped text, broken alignment) — that's debugging, not redesign
- **Before the product has any design direction** — write that down first, or the prompt
  comes out empty

Use it once per major feature, when it reaches "works but ugly". If the first variant
doesn't convince, fix the prompt rather than re-rolling the tool.
