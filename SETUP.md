# Setup Guide — CC Full System

**You now have 105 AI specialists. Here's how to activate them in under 30 minutes.**

No terminal knowledge required. Everything is step by step.

---

## What you're installing

This drops into your `~/.claude/` folder — the global config directory for Claude Code. Once installed, every project you open in Claude Code automatically has access to all 105 agents.

---

## Before you start

You need:
- [ ] [Claude Code](https://claude.ai/code) installed on your computer
- [ ] A GitHub account
- [ ] Your project already on GitHub

---

## Step 1 — Download the files (2 min)

1. Click the green **"Code"** button on this page → **"Download ZIP"**
2. Unzip the file on your computer
3. You'll see a folder called `cc-full-system-main`

---

## Step 2 — Copy files into Claude Code (5 min)

Open your terminal (Mac: press `Cmd + Space`, type "Terminal", press Enter):

```bash
# Copy all agent files
cp -r ~/Downloads/cc-full-system-main/agents/* ~/.claude/agents/

# Copy hooks
cp ~/Downloads/cc-full-system-main/hooks/* ~/.claude/hooks/

# Copy skills
cp -r ~/Downloads/cc-full-system-main/skills/* ~/.claude/skills/
```

---

## Step 3 — Customize for your projects (10 min)

The agents use placeholder names you need to replace with your actual project names.

Open your terminal and run these commands — replace the values in quotes with YOUR project names:

```bash
# Replace placeholders with your actual project names
# Run these one at a time

find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-PROJECT-1/my-first-project/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-PROJECT-2/my-second-project/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-PROJECT-3/my-third-project/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-GITHUB-USERNAME/your-github-name/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-DOMAIN-1.com/yoursite1.com/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-DOMAIN-2.com/yoursite2.com/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-DOMAIN-3.com/yoursite3.com/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-EMAIL/your@email.com/g'
find ~/.claude/agents/ -name "*.md" | xargs sed -i '' 's/YOUR-COMPANY-NAME/Your Company Name/g'
```

---

## Step 4 — Set up your environment file (5 min)

Create a file at `~/.claude/.env` with your API keys:

```bash
# Open in TextEdit
open -a TextEdit ~/.claude/.env
```

Add these (fill in the ones you use):

```
# Required for health monitoring
ANTHROPIC_API_KEY=your_key_here

# Optional — adds uptime history to SSL monitor
UPTIMEROBOT_API_KEY=

# Optional — adds traffic data to metrics
PLAUSIBLE_API_KEY=

# Optional — Slack alerts for incidents
SLACK_WEBHOOK_URL=
```

---

## Step 5 — Test it works (2 min)

Open Claude Code in any project folder:

```bash
cd ~/Projects/your-project
claude
```

Then type: `/start`

If you see a health briefing, everything is working.

---

## The 3 commands you'll use every day

| Command | What it does |
|---|---|
| `/start` | Start of day briefing — shows everything broken, what to fix first |
| `/improve` | End of session — captures everything learned, commits it |
| `/improve` | End of session — captures everything learned, commits it |

---

## Getting help

If something doesn't work, open an issue on this repo and describe what you see. We'll fix it.

---

## What's included

| Folder | Contents |
|---|---|
| `agents/` | 105 specialist agents |
| `hooks/` | 6 lifecycle hooks (auto-trigger agents on events) |
| `skills/` | 5 slash commands (/improve, /start, /pr, /bug, /health) |

The memory system (`memory/`) is not included — it builds up automatically as you use the system. Each session adds new patterns and learnings specific to your projects.
