# CRON-SETUP.md — Keeping Your Agents Running 24/7

> How to make your agents run on a schedule — even when Claude Code is closed.

---

## The key distinction — two types of crons

| Type | Survives CC exit? | Who creates it | Best for |
|---|---|---|---|
| **LaunchAgent** (persistent) | ✅ YES — survives restarts, sleep, terminal close | You (plist file) | Daily standups, weekly reports, overnight monitors |
| **CC session cron** (ephemeral) | ❌ NO — dies when CC exits or `/clear` runs | CC via `CronCreate` | PR watchers, decision relays, active-session helpers |

**Simple rule:**
- Agent must run while you sleep → **LaunchAgent**
- Agent only makes sense when CC is active → **CC session cron** (CC recreates these at `/start`)

---

## How CC session crons work (automatic)

When you run `/start` at the beginning of every Claude Code session, CC automatically recreates all session crons from your `memory/cron_schedule.md`. You don't need to do anything — just run `/start` and they're live.

Session crons include: `health-monitor` (hourly), `pr-triage` (every 15 min), `claudia-decision-watcher` (every 5 min), and ~45 others.

**These die when you close Claude Code.** That's expected. `/start` brings them back.

---

## How to make an agent run 24/7 (LaunchAgent)

Use this when you want a business agent to run on schedule regardless of whether Claude Code is open.

### Step 1 — Create the plist file

Replace `[your-name]`, `[agent-name]`, the schedule, and the prompt with your values:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.[your-name].[agent-name]</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>source ~/.zshrc && cd ~/.claude && claude --permission-mode bypassPermissions --print "Run the [agent-name] agent. [paste full prompt from cron_schedule.md here]." >> /tmp/[agent-name]-last-run.log 2>&1</string>
    </array>

    <!-- Daily at 8:00am -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>8</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>WorkingDirectory</key>
    <string>/Users/[your-mac-username]/.claude</string>

    <key>StandardOutPath</key>
    <string>/tmp/com.[your-name].[agent-name].out</string>

    <key>StandardErrorPath</key>
    <string>/tmp/com.[your-name].[agent-name].err</string>

    <key>RunAtLoad</key>
    <false/>

    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

### Step 2 — Install it

```bash
# Save to LaunchAgents folder
cp [agent-name].plist ~/Library/LaunchAgents/com.[your-name].[agent-name].plist

# Set correct permissions (required)
chmod 644 ~/Library/LaunchAgents/com.[your-name].[agent-name].plist

# Load it (registers with macOS scheduler)
launchctl load ~/Library/LaunchAgents/com.[your-name].[agent-name].plist

# Verify it loaded
launchctl list | grep [agent-name]
# Shows "-" = scheduled but not running now (correct)
# No output = failed to load (check permissions + plist syntax)
```

### Step 3 — Verify it works

```bash
# Trigger it immediately (skip the schedule, run now)
launchctl start com.[your-name].[agent-name]

# Check output after it runs
cat /tmp/com.[your-name].[agent-name].out
cat /tmp/com.[your-name].[agent-name].err
```

---

## Schedule examples

```xml
<!-- Daily at 8:00am -->
<key>StartCalendarInterval</key>
<dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>

<!-- Monday at 10:00am -->
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key><integer>1</integer>
    <key>Hour</key><integer>10</integer>
    <key>Minute</key><integer>0</integer>
</dict>

<!-- Friday at 5:00pm -->
<key>StartCalendarInterval</key>
<dict>
    <key>Weekday</key><integer>5</integer>
    <key>Hour</key><integer>17</integer>
    <key>Minute</key><integer>0</integer>
</dict>

<!-- Every 5 minutes -->
<key>StartInterval</key>
<integer>300</integer>

<!-- 1st of every month at 9:00am -->
<key>StartCalendarInterval</key>
<dict>
    <key>Day</key><integer>1</integer>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
</dict>
```

---

## Stop, restart, unload

```bash
# Stop permanently (removes from schedule)
launchctl unload ~/Library/LaunchAgents/com.[your-name].[agent-name].plist

# Restart (after editing the plist)
launchctl unload ~/Library/LaunchAgents/com.[your-name].[agent-name].plist
launchctl load ~/Library/LaunchAgents/com.[your-name].[agent-name].plist

# List all your agents
launchctl list | grep [your-name]
```

---

## Recommended agents to run persistently

These are the agents most worth running 24/7 — they produce value whether or not CC is open:

| Agent | Recommended schedule | Why persistent |
|---|---|---|
| `biz-daily-standup` | Daily 8am | Morning digest before you open CC |
| `biz-product-strategist` | Monday 10am | Weekly strategy before work starts |
| `biz-competition-monitor` | Friday 3pm | Catches competitor moves over the weekend |
| `biz-revenue-pulse` | Daily 8am | Revenue alert before you open the laptop |
| `inbox-intelligence` | Daily 7:30am | Email classified before your first coffee |
| `health-monitor` | Every hour | Catch failures even when CC is closed |
| `n8n-health-guardian` | Every 4 hours | Auto-fixes n8n auth failures overnight |

The prompts for each are in `memory/cron_schedule.md`.

---

## Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| Agent didn't run | `launchctl list \| grep [your-name]` — is it listed? | If missing: unload + reload the plist |
| Agent ran but did nothing | `cat /tmp/com.[your-name].[agent-name].err` | Usually: CC not logged in, or wrong working directory |
| "Permission denied" on plist | `ls -la ~/Library/LaunchAgents/[plist]` | Run `chmod 644` on it, then reload |
| CC session cron missing | Check CC is active + run `/start` | Session crons die when CC exits — `/start` recreates them |
| Agent ran but CC wasn't authenticated | `cc-login-watchdog` alerts on this | Run `claude --print "ping"` to verify auth |
| Plist loaded but never fires | Check the schedule (Weekday 0=Sunday, 1=Monday) | Test immediately with `launchctl start` |

---

## After installing a new LaunchAgent

1. Verify it's listed: `launchctl list | grep [agent-name]`
2. Test it fires: `launchctl start com.[your-name].[agent-name]`
3. Check logs: `cat /tmp/com.[your-name].[agent-name].out`
4. Add a row to your `memory/cron_schedule.md` so you remember it exists

---

*Session crons (/start) and persistent crons (LaunchAgent) are complementary — you need both for full coverage.*
