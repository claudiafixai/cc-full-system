---
name: improve
description: End-of-session learning ritual. Captures everything learned, fixes any agent/workflow gaps found, updates all knowledge files, and closes the session smarter than it opened. Use after any PR fix, audit, or debugging session with the magic words "what have you learned".
---

You are running the full session improvement ritual. This makes the system smarter every single session.

## What this does

Every insight, gap, and fix found this session becomes permanent architecture — written into agents, traps, workflows, and memory so future sessions never repeat the same discovery manually.

## Step 1 — Scan the conversation for verbal findings

Read the current conversation from the top. Find everything that was discovered verbally — things I said, explained, or concluded that were NOT triggered by a Bash command and therefore NOT captured by the PostToolUse hook.

For each verbal finding, append to `~/.claude/session-findings.md`:
```
## [timestamp] | [project] | verbal-capture
**VERBAL-FINDING:** [what was discovered — symptom, root cause, and fix in one paragraph]
---
```

Verbal findings to look for:
- "X was already fixed" / "Y was a false positive" → stale BugBot pattern
- "The agent doesn't do X" / "The workflow missed Y" → architecture gap
- "The correct way is Z" → pattern that should be a trap
- Any correction Claudia gave me during the session
- Any "I didn't know that" moment

## Steps 2, 3, 5 — Run in PARALLEL (no dependencies between them)

Launch all three as background agents simultaneously:

**Background agent A — session-learner:**
```
Run session-learner agent now. Process all entries in ~/.claude/session-findings.md.
Write new trap entries to the correct CC_TRAPS.md (per project) and global_traps.md.
Cross-project patterns get GT- IDs in global_traps.md.
```

**Background agent B — lesson-extractor:**
```
If a PR number was involved in this session:
  Run lesson-extractor in PR mode for PR#[N] in [repo].
  Read all resolved BugBot and CodeRabbit threads.
  Write trap entries for every resolved finding (HIGH + MEDIUM mandatory, LOW if non-obvious).
If no specific PR: run lesson-extractor in COMMIT mode — reads Fix: commits since last run.
```

**Background agent C — knowledge-updater:**
```
Run knowledge-updater agent. Update all knowledge files that changed this session:
- docs/FEATURE_STATUS.md if a feature was completed
- docs/INTEGRATION_PROCESS.md if an integration was touched
- CLAUDE.md if agent list changed
- Any other docs/ file relevant to work done
```

While all 3 run in background, proceed immediately to Step 4 (architecture gap analysis) — do NOT wait.

## Step 4 — Architecture gap analysis

Answer these 5 questions about this session:

1. **Did I have to do something manually that an agent should have caught automatically?**
   → If yes: identify which agent should own it, add the check to that agent's Step 2, write a trap.

2. **Did any agent produce wrong output / miss a finding?**
   → If yes: read that agent file, fix the specific step that failed, commit the change.

3. **Did CI/GHA miss something that should have failed the PR?**
   → If yes: add a check to the appropriate GHA workflow file, commit.

4. **Did a BugBot/CodeRabbit finding turn out to be stale or a false positive?**
   → If yes: is the pattern documented in global_traps.md? If not, add it.

5. **Is there a prompt/invocation pattern Claudia used that was weaker than it could be?**
   → If yes: write the stronger version to memory (feedback type).

For each YES answer: make the fix NOW (edit agent file, GHA, or trap), then commit.

## Step 4.5 — Speed audit (Claudia's time → fewer sessions, more done)

Answer these 3 speed questions:

1. **Did I run agents sequentially that could have run in parallel?**
   → If yes: identify which agent calls can be parallelized and update the agent/skill that launched them.
   → session-learner + lesson-extractor + knowledge-updater always run in parallel (no dependencies).
   → pr-review-loop runs bugbot-responder + coderabbit-responder in parallel — check it did so.

2. **Did I wait for a human prompt to start something that could auto-start?**
   → If yes: add a cron, GHA trigger, or session-commander auto-start rule.
   → Examples: dispatcher already runs hourly, pr-watch already runs every 5min during open PRs.
   → If a pattern was: "Claudia told me to X, then I did Y, then Z" — ask: should Y and Z have triggered automatically from a GHA event or cron?

3. **Is there a free tool, API, or integration that would have made this session faster?**
   → Check: Could an MCP server have done this in one call (Supabase MCP, GitHub MCP, Vercel MCP)?
   → Check: Could a GHA workflow have pre-computed this before the session started?
   → Check: Could an n8n automation have batched this (e.g. PR thread replies triggered by webhook)?
   → If yes to any: write a `project_speed_wins.md` memory with the specific integration to add.

For each YES: make the change NOW or write a GitHub issue to track it.

## Step 4.6 — Cost audit (API + platform spend → lower bill)

Answer these 4 cost questions:

1. **Did any GHA workflow call an AI API (Anthropic/OpenAI) more times than necessary?**
   → Check: `auto-label-issues.yml` calls Haiku once per issue (good — keep). Any loop-based calls?
   → Check: any agent ran in a loop when a single call would suffice?
   → Fix: add `if: github.event.issue.user.login != 'github-actions[bot]'` guards to prevent bot-triggered loops.

2. **Could Haiku replace Sonnet for any step that ran this session?**
   → Haiku is 20× cheaper than Sonnet. Use it for: classification, labeling, format checking, summarizing.
   → Sonnet is needed for: reasoning, code generation, multi-step debugging, agent orchestration.
   → If a Sonnet agent only classified or formatted — downgrade its model to haiku.

3. **Did any cron agent run unnecessarily (no new data, same result as last run)?**
   → Check: health-monitor, api-quota-monitor, database-health-monitor, resend-monitor.
   → Fix: add "silent when healthy" guard — these should output nothing and exit 0 when all thresholds pass.
   → If an agent opened issues for non-problems, add a dedup check against existing open issues before creating.

4. **Is there a cheaper platform alternative for any paid service touched this session?**
   → n8n self-hosted (already using) vs cloud = saves ~$20/month per project ✓
   → Vercel free tier vs Pro — check if any project needs Pro features or could downgrade
   → Supabase free vs Pro — check if db-health-monitor shows we're near free-tier limits
   → ElevenLabs/HeyGen — check api-quota-monitor output for waste (unused credits)
   → If yes to any: write a GitHub issue with label `cost-optimization` in the relevant project.

For each YES: write the cost finding to `memory/cost_savings.md` (create if missing) with the exact saving and how to implement it.

## Step 5 — Write memory

Write or update memory files for anything that should persist:
- `feedback_*.md` if Claudia corrected my approach
- `project_*.md` if project state changed
- Update `MEMORY.md` index if new files were written

## Step 6 — Commit everything and report

```bash
cd ~/.claude && git add memory/ agents/ hooks/ skills/ && git commit -m "Chore: session close — [N] traps, [N] agent fixes, [N] memory updates [date]"
```

Report to Claudia:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SESSION IMPROVE — [date]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TRAPS WRITTEN: [N]
  → [ID]: [name] ([project/global])

AGENTS FIXED: [N]
  → [agent name]: [what step was fixed]

GHA WORKFLOWS FIXED: [N]
  → [workflow]: [what check was added]

MEMORY UPDATED: [N files]
  → [filename]: [what was saved]

KNOWLEDGE FILES UPDATED: [N]
  → [filename]: [what changed]

NEXT SESSION WILL START KNOWING:
  → [2-3 bullet points of the most important things that changed]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## The magic words that trigger this skill

Any of these phrases invoke /improve:
- "/improve" · "/done" · "/capture"
- "what have you learned" · "what did we learn this session"
- "close the session / make it smarter"
- "capture" · "capture that" · "capture and improve" · "save that"
- "done" · "wrap up" · "we're done" · "close session" · "save and clear"

## Hard rules

- Never skip Step 4 (architecture gap analysis) — this is the most valuable step
- If an agent gap is found: fix the agent NOW, don't just write a trap about it
- If a GHA gap is found: add the CI check NOW, commit it before closing
- Every verbal finding from Step 1 must become either a trap, an agent fix, or a memory entry — nothing gets lost in chat
- The commit in Step 7 is non-negotiable — if findings exist, they get committed
