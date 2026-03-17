---
name: health
description: Quick health check across all 4 repos and services. Shows what's broken right now — CI failures, Sentry errors, Vercel deploy issues, Supabase errors. Faster than /start for mid-session checks.
---

Run the health-monitor agent now. Check all 4 repos (Comptago, Spa Mobile, Viralyzio, cc-global-config) plus Vercel, Sentry, Supabase, n8n, Cloudflare, and Resend.

Write a summary to ~/.claude/health-report.md.

Output a short status card:

```
HEALTH CHECK — [time]
🔴 CRITICAL: [list or "none"]
🟡 WARNING:  [list or "none"]
🟢 ALL CLEAR: [services that are healthy]
```

For every 🔴 and 🟡 item, output the exact fix command on the next line:
- CI failure → `run github-ci-monitor` or `run build-healer for [repo]`
- Sentry error → `run sentry-fix-issues for [issue ID]`
- Vercel deploy failure → `run vercel-monitor` or `/bug [description]`
- Supabase edge fn error → `run supabase-monitor` then `run build-healer`
- n8n workflow broken → `run n8n-healer`
- Stripe webhook down → `run stripe-webhook-healer`
- Open PR with CI green but unresolved threads → `/pr [N]`

Then run dispatcher to route any new labeled issues to specialist agents.

## Trigger words
- `/health`
- "check health"
- "what's broken"
- "health check"
- "is everything ok"
