---
name: start
description: Session start ritual — one command that does everything. Restarts all crons, routes all backlogged issues (including GHA-opened triggers for inbox scan + dispatcher sweep), runs health check, fixes open PRs, and gives you a ranked briefing. Runs automatically when you open the terminal. Also triggered by "good morning", "let's start", "what should I work on today".
---

You are starting a new Claude Code session for Claudia. Everything happens automatically — she does not need to ask.

Run all 3 steps in this order. Do not narrate each sub-step — just do the work and output a clean summary at the end.

## Step 1 — Restart all session crons (silent)

Recreate all crons from ~/.claude/memory/cron_schedule.md. Create all of them except pr-watch (manual only). Do this in the background — no output until all are created.

## Step 2 — Run dispatcher (clears backlog)

Run the dispatcher agent. It reads ALL open labeled GitHub issues across all 4 repos:
- claudiafixai/comptago-assistant
- claudiafixai/spa-mobile
- claudiafixai/viralyzio
- claudiafixai/claude-global-config

This includes GHA-opened trigger issues (inbox-scan, dispatcher-trigger) from overnight.
Each issue is routed to the correct specialist agent automatically.

## Step 3 — Run session-commander (briefing)

Run the session-commander agent. It:
- Checks health across all 4 repos (health-monitor Layer 1)
- Checks open PRs with unresolved BugBot/CodeRabbit threads → auto-dispatches pr-review-loop
- Checks blocked decisions waiting for Claudia's YES/NO
- Ranks everything: 🔴 CRITICAL → 🟡 HIGH → 🟢 LOW
- Auto-starts agents for CRITICAL items
- Outputs a plain-English recommendation of what needs Claudia's attention

## Step 4 — Check open PRs for silently blocked auto-merge

After session-commander, run this check for all 3 project repos:

```bash
for repo in claudiafixai/comptago-assistant claudiafixai/spa-mobile claudiafixai/viralyzio; do
  gh pr list --repo $repo --state open --json number,title | jq -r '.[] | .number' | while read n; do
    RESULT=$(gh api graphql -f query="{repository(owner:\"claudiafixai\",name:\"$(echo $repo | cut -d/ -f2)\"){pullRequest(number:$n){reviewThreads(first:20){nodes{isResolved}}}}}" \
      | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)] | length')
    CI_PENDING=$(gh pr view $n --repo $repo --json statusCheckRollup --jq '[.statusCheckRollup[] | select(.status=="IN_PROGRESS")] | length')
    CI_FAILED=$(gh pr view $n --repo $repo --json statusCheckRollup --jq '[.statusCheckRollup[] | select(.conclusion=="FAILURE")] | length')
    if [ "$CI_PENDING" = "0" ] && [ "$CI_FAILED" = "0" ] && [ "$RESULT" -gt "0" ]; then
      echo "⚠️  $repo PR#$n — CI green but $RESULT unresolved review thread(s) blocking auto-merge → run /pr $n"
    fi
  done
done
```

If any PRs are silently blocked → alert Claudia in the output. "All CI green" ≠ "PR clean".

## Output format (after all 4 steps)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SESSION READY — [date time]
✅ [N] crons live
✅ Dispatcher: [N] issues routed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[session-commander briefing here]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Trigger words

- `/start`
- "start the session" / "good morning" / "let's start"
- "what should I work on today" / "restart the crons"
- *(also auto-triggered by session-briefer hook at session open)*
