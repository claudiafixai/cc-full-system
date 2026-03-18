# Optional Integrations

The agents work out of the box — no integrations required to get started. But each integration below **unlocks new agent capabilities** that make the system significantly more powerful.

Add integrations one at a time as you're ready. The agents automatically detect which ones are configured via your `.env` file.

---

## Tier 1 — Most Impactful (add these first)

### Sentry — Production Error Detection
**What it unlocks:** `sentry-monitor` automatically detects new production errors and dispatches `sentry-fix-issues` to investigate and fix them. You get notified before your users report bugs.

1. Create account at sentry.io → **Settings → API → Auth Tokens**
2. Click **Create New Token** → select `project:read`, `event:read`
3. Add to `~/.claude/.env`:
```
SENTRY_DSN=https://your-dsn@sentry.io/project-id
SENTRY_AUTH_TOKEN=your_token_here
SENTRY_ORG=your-org-slug
```

---

### Vercel — Deployment Monitoring
**What it unlocks:** `vercel-monitor` checks every deployment, `e2e-smoke-tester` runs critical path tests after each deploy, and `biz-ux-friction-detector` can post feedback directly on your Vercel preview URLs.

1. Go to vercel.com → **Settings → Tokens**
2. Click **Create** → name it "Claude Code" → scope: Full Account
3. Add to `~/.claude/.env`:
```
VERCEL_TOKEN=your_token_here
```

---

### Supabase — Database + Auth Monitoring
**What it unlocks:** `database-health-monitor` watches query performance, `rls-scanner` checks for missing security policies, `supabase-monitor` catches edge function errors, and all business agents (`biz-churn-detector`, `biz-user-behavior-analyst`, etc.) can read your real user data.

1. Go to supabase.com → Your project → **Settings → API**
2. Copy the **Service Role Key** (not anon key)
3. Go to supabase.com → **Account → Access Tokens**
4. Create a Personal Access Token
5. Add to `~/.claude/.env`:
```
SUPABASE_ACCESS_TOKEN=your_personal_access_token
SUPABASE_PROJECT_ID=your_project_id
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

---

### GitHub Token — Full Automation
**What it unlocks:** All agents that open/close GitHub issues, create PRs, check CI status, and route work through the dispatcher pipeline. Without this, the agents can only read public repos.

1. Go to github.com → **Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Click **Generate new token**
3. Permissions needed: Issues (R/W), Pull Requests (R/W), Actions (R), Contents (R/W), Metadata (R)
4. Add to `~/.claude/.env`:
```
GITHUB_TOKEN=your_token_here
```

---

## Tier 2 — Business Intelligence

### Stripe — Revenue Monitoring
**What it unlocks:** `biz-revenue-optimizer` reads your subscription distribution and upgrade rates. `stripe-monitor` detects when webhooks get silently disabled (Stripe does this after errors). `biz-corporation-reporter` includes real MRR in monthly reports.

1. Go to dashboard.stripe.com → **Developers → API Keys**
2. Copy **Secret key** (starts with `sk_live_` or `sk_test_`)
3. Go to **Developers → Webhooks** → copy your webhook signing secret
4. Add to `~/.claude/.env`:
```
STRIPE_SECRET_KEY=sk_live_your_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
```

---

### Resend — Email Delivery Health
**What it unlocks:** `resend-monitor` checks bounce rates and complaint rates daily, alerting before you hit blacklist thresholds (>2% bounces = email domain blacklisted).

1. Go to resend.com → **API Keys**
2. Click **Create API Key** → Full Access
3. Add to `~/.claude/.env`:
```
RESEND_API_KEY=re_your_key_here
```

---

### Plausible or PostHog — Web Traffic Analytics
**What it unlocks:** `metrics-synthesizer` includes real web traffic in weekly reports. `biz-user-behavior-analyst` can correlate page traffic with user signup patterns.

**Plausible:**
1. Go to plausible.io → **Settings → API Keys**
2. Add to `~/.claude/.env`:
```
PLAUSIBLE_API_KEY=your_key_here
PLAUSIBLE_DOMAIN=yourdomain.com
```

**PostHog:**
1. Go to posthog.com → **Project Settings → Personal API Keys**
2. Add to `~/.claude/.env`:
```
POSTHOG_API_KEY=phx_your_key_here
POSTHOG_PROJECT_ID=your_project_id
```

---

## Tier 3 — Incident Response + Security

### Slack Webhook — Incident Alerts
**What it unlocks:** `incident-commander` posts real-time updates to a Slack channel when a production incident is detected. You get notified even if Claude Code isn't open.

1. Go to api.slack.com → **Create an App** → **Incoming Webhooks**
2. Enable → **Add New Webhook to Workspace** → pick a channel
3. Copy the webhook URL
4. Add to `~/.claude/.env`:
```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url
```

---

### Corridor — Security Review on PRs
**What it unlocks:** Every PR gets an automated security review from Corridor before merging. Catches OWASP issues, secrets in code, and risky patterns.

1. Go to corridor.so → **Settings → API**
2. Copy your API key
3. Add to `.github/workflows/corridor.yml` (already included in this repo):
   - Add `CORRIDOR_API_KEY` to your GitHub repo → **Settings → Secrets and variables → Actions**

No `.env` needed — this runs entirely through GitHub Actions.

---

### CodeRabbit — AI Code Review
**What it unlocks:** Every PR gets a full AI code review. `coderabbit-responder` automatically reads these reviews, applies suggestions, and resolves threads — your PRs merge cleaner with zero manual review effort.

1. Go to coderabbit.ai → **Settings → Repositories**
2. Connect your GitHub repository
3. The `.coderabbit.yaml` in this repo already configures the review style

No API key needed — CodeRabbit reads your repo via GitHub App.

---

### GitGuardian — Secret Scanning
**What it unlocks:** Automatically scans every commit and PR for accidentally committed API keys, passwords, or credentials. Prevents secrets from ever reaching your repo.

1. Go to gitguardian.com → **API → Personal Access Tokens**
2. Copy your API key
3. Add `GITGUARDIAN_API_KEY` to your GitHub repo → **Settings → Secrets and variables → Actions**

Already wired into the GHA workflows in this repo.

---

## Tier 4 — AI Automation Stack (for advanced users)

### n8n — Workflow Automation
**What it unlocks:** `n8n-monitor` watches for failing workflows. `n8n-healer` automatically fixes common n8n errors (wrong credentials, deactivated workflows). Business agents can trigger n8n workflows to send win-back emails, post announcements, etc.

1. Self-host n8n or use n8n Cloud
2. Go to **Settings → API** → create an API key
3. Add to `~/.claude/.env`:
```
N8N_BASE_URL=https://your-n8n-instance.com
N8N_API_KEY=your_key_here
```

---

### Anthropic API — For Custom AI Features
**What it unlocks:** `api-quota-monitor` tracks your Claude API usage so you're never surprised by a bill. Lets you build AI features directly into your product using the same Claude models.

1. Go to console.anthropic.com → **API Keys**
2. Create a new key
3. Add to `~/.claude/.env`:
```
ANTHROPIC_API_KEY=your_key_here
```

---

### UptimeRobot — Uptime History
**What it unlocks:** `ssl-certificate-monitor` includes historical uptime data alongside cert expiry checks. Know exactly when your site was down and for how long.

1. Go to uptimerobot.com → **My Settings → API Settings**
2. Copy your **Read-Only API Key**
3. Add to `~/.claude/.env`:
```
UPTIMEROBOT_API_KEY=your_key_here
```

---

## Integration Priority for a New Project

If you're starting from scratch, add integrations in this order:

| Week | What to add | Why |
|------|-------------|-----|
| Week 1 | GitHub Token + Vercel | Core automation — PR pipeline + deploy monitoring |
| Week 1 | Supabase | User data for business agents |
| Week 2 | Sentry | Production error detection before users report |
| Week 2 | Resend | Email health before you hit blacklists |
| Week 3 | Stripe | Revenue visibility |
| Week 3 | Slack webhook | Incident alerts when terminal is closed |
| Month 2 | CodeRabbit + Corridor | Higher code quality on every PR |
| Month 2 | Plausible | Traffic trends in weekly reports |

---

*Questions? Open an issue and describe what you're trying to connect.*
