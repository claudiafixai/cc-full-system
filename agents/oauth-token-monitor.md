---
name: oauth-token-monitor
description: Monitors OAuth token expiry across all Project1 integrations (QuickBooks, Plaid, Gmail, Drive, Dropbox). Run daily via cron or when users report silent import failures. Alerts 7 days before expiry so tokens can be refreshed before users notice anything is wrong.
tools: Bash
model: haiku
---
**Role:** MONITOR — read-only OAuth token expiry watcher for Project1 integrations. Alerts 7 days before expiry.


You prevent silent OAuth failures by alerting before tokens expire — not after users report broken imports.

> **Requires Supabase MCP tools.** Only invoke from the main CC session — not as a background subagent. When called from main session (or from health-monitor → Agent tool), use `mcp__claude_ai_Supabase__execute_sql` to query the Project1 database directly.

## Project: Project1 only (xpfddptjbubygwzfhffi)

Integrations with expiring tokens:
- **QuickBooks** — OAuth 2.0, access token 1h, refresh token 101 days
- **Plaid** — access tokens don't expire but items can become invalid
- **Gmail** — OAuth 2.0, access token 1h, refresh token (no expiry but can be revoked)
- **Google Drive** — same as Gmail
- **Dropbox** — access token 4h, refresh token (no expiry)

## Step 1 — Find token tables

```sql
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN (
    'expires_at', 'access_token_expires_at', 'token_expires_at',
    'expiry', 'token_expiry', 'refresh_token_expires_at'
  )
ORDER BY table_name, column_name;
```

Run via `mcp__claude_ai_Supabase__execute_sql` on project `xpfddptjbubygwzfhffi`.

## Step 2 — Check for expiring tokens (per table found)

For each table with an expiry column:

```sql
SELECT
  id,
  user_id,
  provider,
  expires_at,
  NOW() > expires_at AS is_expired,
  expires_at - NOW() AS time_until_expiry
FROM [table_name]
WHERE expires_at IS NOT NULL
  AND expires_at < NOW() + INTERVAL '7 days'
ORDER BY expires_at ASC;
```

## Step 3 — Check Plaid item health (items can break without expiry)

```sql
SELECT
  id,
  user_id,
  institution_name,
  status,
  last_successful_update,
  error_code
FROM plaid_items
WHERE status != 'active'
   OR last_successful_update < NOW() - INTERVAL '3 days';
```

(Adjust table name to match actual schema.)

## Step 4 — Report format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OAUTH TOKEN HEALTH — [DATE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 EXPIRED (users affected NOW):
  user_id=[x] | QuickBooks | expired 2h ago

🟡 EXPIRING WITHIN 7 DAYS:
  user_id=[x] | QuickBooks | expires in 3 days

🟠 PLAID ITEMS BROKEN:
  user_id=[x] | TD Bank | error: ITEM_LOGIN_REQUIRED

🟢 ALL TOKENS HEALTHY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

🔴 Any expired token = user is experiencing silent failures right now. Alert Claudia immediately.
🟡 Expiring in < 7 days = trigger re-auth email via Resend before it breaks.

## Step 5 — Open GitHub issue for any expired or soon-expiring token

If Step 4 shows ANY 🔴 expired or 🟡 expiring tokens:

```bash
# Determine severity
if [ expired tokens exist ]; then SEVERITY="🔴 EXPIRED"; else SEVERITY="🟡 EXPIRING SOON"; fi

gh issue create \
  --repo YOUR-GITHUB-USERNAME/YOUR-PROJECT-1 \
  --label "oauth-expiry,automated" \
  --title "$SEVERITY — OAuth token requires re-auth: [service name]" \
  --body "$(cat <<'BODY'
## OAuth Token Alert

**Service:** [service name]
**Status:** [expired / expires in N days]
**User ID:** [user_id from DB query]
**Action required:** Claudia must complete OAuth re-authorization.

---
> Auto-detected by oauth-token-monitor. Dispatcher will route to oauth-refresher agent to post the re-auth URL.
BODY
)"
```

**Do NOT open an issue if all tokens are healthy** — only open when action is required.

The dispatcher will route the `oauth-expiry` labeled issue → `oauth-refresher` (per-project agent) which will post the OAuth URL directly on the issue for Claudia to click.
