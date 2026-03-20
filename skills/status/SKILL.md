---
name: status
description: Mid-session agent activity snapshot. Shows in-flight issues, recent completions, stuck work, and decisions waiting for Claudia — all in under 10 seconds. Use anytime during a session to see what's happening right now without re-running session-commander.
---

You are running the /status skill. Execute all steps in parallel, then output the compact status block. No narration — just run the checks and print the result.

## What /status does

Shows a live snapshot of agent activity in under 10 seconds. Use this mid-session to check what agents are doing without triggering a full session-commander run.

## Step 1 — In-flight issues (parallel across all 4 repos)

Run all 4 queries simultaneously:

```bash
for repo in YOUR-GITHUB-USERNAME/YOUR-PROJECT-1 YOUR-GITHUB-USERNAME/YOUR-PROJECT-2 YOUR-GITHUB-USERNAME/YOUR-PROJECT-3 YOUR-GITHUB-USERNAME/claude-global-config; do
  gh issue list --repo "$repo" --label "in-flight" --state open \
    --json number,title,updatedAt \
    --jq ".[] | \"[$repo] #\(.number): \(.title) (updated: \(.updatedAt[:16]))\""
done
```

## Step 2 — Recent completions

```bash
tail -15 ~/.claude/memory/completions.log 2>/dev/null || echo "(completions.log not found)"
```

Show the last 5 entries in the output (most recent first).

## Step 3 — Stuck issues (in-flight with no activity >2h)

From the Step 1 results, filter for any issue where `updatedAt` is more than 2 hours ago:

```bash
NOW=$(date -u +%s)
for repo in YOUR-GITHUB-USERNAME/YOUR-PROJECT-1 YOUR-GITHUB-USERNAME/YOUR-PROJECT-2 YOUR-GITHUB-USERNAME/YOUR-PROJECT-3 YOUR-GITHUB-USERNAME/claude-global-config; do
  gh issue list --repo "$repo" --label "in-flight" --state open \
    --json number,title,updatedAt \
    --jq ".[] | select(now - (.updatedAt | fromdateiso8601) > 7200) | \"[$repo] #\(.number): \(.title)\""
done
```

## Step 4 — Decisions waiting for Claudia (parallel across all 4 repos)

```bash
for repo in YOUR-GITHUB-USERNAME/YOUR-PROJECT-1 YOUR-GITHUB-USERNAME/YOUR-PROJECT-2 YOUR-GITHUB-USERNAME/YOUR-PROJECT-3 YOUR-GITHUB-USERNAME/claude-global-config; do
  gh issue list --repo "$repo" --label "owner-decision" --state open \
    --json number,title \
    --jq ".[] | \"[$repo] #\(.number): \(.title)\""
done
```

## Step 5 — Active crons (session-level)

```bash
# CronCreate crons live only in-session — list them if the cron tool is available
# If not accessible, note that crons are session-local
echo "Session crons: owner-decision-watcher (5min) + mac-coordinator-agent (5min) + task-allocator-agent (15min) — live if /start was run this session"
```

## Output format

Print this exact block, populating from the steps above:

```
─── AGENT STATUS ── [timestamp] ───────────────────
🟢 IN-FLIGHT (N):
  [repo]#[issue]: [title] (updated HH:MM)
  ... or "none"

✅ RECENT COMPLETIONS (last 5):
  [timestamp] | [agent] | [repo#issue] | [STATUS] | [summary]
  ... or "(no completions logged yet)"

⏳ STUCK >2h (no activity):
  [repo]#[issue]: [title]
  ... or "none"

❓ YOUR DECISIONS NEEDED (N):
  [repo]#[issue]: [title]
  ... or "none"

⏱  Crons: [live / not started — run /start to activate]
────────────────────────────────────────────────────
```

- N in headers = actual count
- If all sections are empty/none: print "✅ All clear — no active agents, no decisions pending."
- Never narrate the steps — just output the status block

## Trigger words

- `/status`
- "what are agents doing" / "what's running" / "agent status"
- "what's in flight" / "what's stuck" / "any decisions for me"
- "quick status" / "status check"
