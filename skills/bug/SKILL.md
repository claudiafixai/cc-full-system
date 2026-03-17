---
name: bug
description: Instantly log an emergency bug or urgent issue to GitHub so it gets auto-routed to the right agent — even if the terminal is busy. Usage: /bug [description]. Examples: /bug login broken on mobile, /bug comptago stripe webhook failing, /bug spa images not loading
---

You are logging an emergency issue and enriching it with Sentry context automatically.

## Step 1 — Detect which project

From the description, detect the project:
- mentions "comptago" / "accounting" / "receipts" / "quickbooks" / "plaid" → `claudiafixai/comptago-assistant`
- mentions "spa" / "booking" / "salon" / "mobile" → `claudiafixai/spa-mobile`
- mentions "viralyzio" / "video" / "tiktok" / "clips" → `claudiafixai/viralyzio`
- unclear → `claudiafixai/claude-global-config`

## Step 2 — Detect severity

- "broken" / "down" / "crash" / "can't login" / "payment failing" / "data loss" → `critical,bug-report`
- "not working" / "error" / "failing" → `bug-report`
- "slow" / "weird" / "looks wrong" → `bug-report`

## Step 3 — Query Sentry for related errors (run in parallel with Step 4)

Map project to Sentry project slug:
- `comptago-assistant` → `comptago`
- `spa-mobile` → `spa-mobile`
- `viralyzio` → `viralyzio`

```bash
# Load env
source ~/.claude/.env 2>/dev/null || true
SENTRY_TOKEN="${SENTRY_AUTH_TOKEN:-}"
SENTRY_ORG="${SENTRY_ORG:-claudia-fix-ai}"

# Search for unresolved issues matching keyword from Claudia's description
curl -s "https://sentry.io/api/0/projects/${SENTRY_ORG}/[SENTRY_SLUG]/issues/?query=[KEYWORD_FROM_DESCRIPTION]&is_unresolved=true&limit=3" \
  -H "Authorization: Bearer ${SENTRY_TOKEN}" | \
  jq -r '.[] | "ID: \(.id) | \(.title) | count:\(.count) | last:\(.lastSeen)"'
```

If Sentry returns results → capture top 3 as `SENTRY_CONTEXT`.
If Sentry returns empty or errors → set `SENTRY_CONTEXT="No matching Sentry issues found"`.
Never block on Sentry failure — always proceed to Step 4.

## Step 4 — Open the GitHub issue immediately

```bash
gh issue create \
  --repo [REPO] \
  --title "🐛 [description from Claudia]" \
  --label "[severity labels]" \
  --body "**Reported:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Description:** [Claudia's exact words]
**Source:** /bug skill — emergency report

## Sentry Context
[SENTRY_CONTEXT]

Dispatcher will route this to the correct agent automatically."
```

## Step 5 — Confirm in 1 line

Output only: `✅ Bug logged → [repo]#[N] — [N] Sentry issues attached` (or "no Sentry match" if empty)

## Rules
- No analysis, no investigation, no questions — just log it
- Sentry lookup must not delay the issue creation by more than 5 seconds — if slow, skip it
- If critical: also open in `claudiafixai/claude-global-config` with `critical` label so it surfaces in the next health check
- Under 15 seconds total (10s + 5s Sentry budget)

## Trigger words
- `/bug [description]`
- "log this bug"
- "emergency: [description]"
- "quick issue: [description]"
