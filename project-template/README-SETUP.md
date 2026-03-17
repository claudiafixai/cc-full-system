# Per-Project Setup

Copy everything in this folder into your project repo.

## What goes where

```
your-project/
  .claude/
    CLAUDE.md          ← fill this in with your project details
    agents/            ← per-project agents (already filled in)
  .github/
    workflows/         ← copy from cc-full-system/.github/workflows/
```

## Steps

1. Copy `.claude/` folder into your project root
2. Edit `.claude/CLAUDE.md` — replace everything in `[SQUARE BRACKETS]`
3. Copy `.github/workflows/` from the cc-full-system repo into your project
4. Commit and push

That's it. Claude Code will automatically load your project context next time you open it.
