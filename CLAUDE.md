# [YOUR COMPANY NAME] — Claude Code Global Config

## My projects

| Project | Repo | Live URL | Stack |
|---|---|---|---|
| [Project 1 name] | YOUR-GITHUB-USERNAME/YOUR-PROJECT-1 | https://YOUR-DOMAIN-1.com | [e.g. React + Supabase + Vercel] |
| [Project 2 name] | YOUR-GITHUB-USERNAME/YOUR-PROJECT-2 | https://YOUR-DOMAIN-2.com | [e.g. React + Supabase + Vercel] |
| [Project 3 name] | YOUR-GITHUB-USERNAME/YOUR-PROJECT-3 | https://YOUR-DOMAIN-3.com | [e.g. React + Supabase + Vercel] |

## Global agents

Agents live in `~/.claude/agents/` and are available in every project.

See the full agent list in `agents/` folder.

## Session workflow

**Start of day:**
```
run session-commander
```

**End of session:**
```
/improve
```

**Quick health check:**
```
/start
```

## Rules

- Never push directly to `main` — always go through a PR
- Never commit `.env` files or API keys
- Always work on `development` branch, merge to `main` via PR
