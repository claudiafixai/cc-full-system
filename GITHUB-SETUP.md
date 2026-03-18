# GitHub Repository Setup

Configuring your GitHub repository correctly unlocks the full agent automation pipeline — PRs auto-review, CI runs automatically, and agents route work through GitHub Issues.

This takes about 15 minutes and you only do it once per project.

---

## Step 1 — Create your GitHub repository

1. Go to github.com → click **New repository**
2. Name it (e.g. `my-app`)
3. Set to **Private** (recommended) or Public
4. **Do not** initialize with README — you'll push your existing project
5. Click **Create repository**

---

## Step 2 — Repository Settings

Go to your repo → **Settings** and configure these:

### General → Pull Requests

| Setting | Value | Why |
|---------|-------|-----|
| Allow squash merging | ✅ ON | Feature branches merge cleanly |
| Allow merge commits | ✅ ON | dev→main merges use this (prevents history divergence) |
| Allow rebase merging | OFF | Causes divergence between dev/main |
| Always suggest updating PR branches | ✅ ON | Keeps PRs current automatically |
| Automatically delete head branches | ✅ ON | Cleans up branches after merge |
| Allow auto-merge | ✅ ON | Lets agents merge clean PRs without your input |

### General → Danger Zone

Leave defaults unless you need to transfer or delete.

---

## Step 3 — Branch Protection Rules

Go to **Settings → Branches** → **Add rule**

### Rule for `main`

**Branch name pattern:** `main`

| Setting | Value |
|---------|-------|
| Require a pull request before merging | ✅ ON |
| Required approving reviews | 0 (agents handle this) |
| Dismiss stale pull request approvals | ✅ ON |
| Require status checks to pass | ✅ ON (add checks below) |
| Require branches to be up to date | ✅ ON |
| Include administrators | ✅ ON |
| Restrict who can push to matching branches | Your username only |

**Required status checks to add** (after your first CI run):
- `typecheck`
- `test`
- `build`

### Rule for `development`

**Branch name pattern:** `development`

| Setting | Value |
|---------|-------|
| Require a pull request before merging | OFF (push directly to dev) |
| Allow force pushes | OFF |

---

## Step 4 — GitHub Labels

The agent dispatcher routes work through GitHub Issues. It needs specific labels to know which agent handles which issue.

Run this script once per repository:

```bash
bash setup-github-labels.sh YOUR-USERNAME/YOUR-REPO
```

This creates 30 labels:

**Routing labels (agents watch for these):**
- `bugbot-review` — routes to bugbot-responder
- `build-failure` — routes to build-healer
- `edge-fn-failure` — routes to build-healer
- `sentry-error` — routes to sentry-fix-issues
- `feature-stuck` — routes to feature-unblock-agent
- `feature-blocked` — routes to feature-unblock-agent
- `claudia-decision` — pauses agent, waits for YES/NO
- `claudia-decision-resolved` — marks decision complete
- `support-ticket` — routes to biz-support-triage
- `broken-link` — routes to link-checker
- `db-health` — routes to database-optimizer
- `a11y-violation` — routes to a11y-auditor
- `api-quota` — routes to api-quota-monitor
- `ssl-expiry` — routes to ssl-certificate-monitor
- `deploy-failure` — routes to e2e-smoke-tester
- `knowledge-update` — routes to knowledge-sync

**PR type labels:**
- `feature` · `fix` · `hotfix` · `docs` · `chore` · `security` · `refactor`

**Priority labels:**
- `critical` · `high` · `medium` · `low`

**Status labels:**
- `in-progress` · `needs-review` · `blocked` · `wont-fix`

---

## Step 5 — GitHub Actions Secrets

Go to **Settings → Secrets and variables → Actions** → **New repository secret**

Add these secrets:

| Secret name | Where to get it |
|-------------|----------------|
| `ANTHROPIC_API_KEY` | console.anthropic.com → API Keys |
| `SUPABASE_ACCESS_TOKEN` | supabase.com → Account → Access Tokens |
| `VERCEL_TOKEN` | vercel.com → Settings → Tokens |
| `SENTRY_AUTH_TOKEN` | sentry.io → Settings → API → Auth Tokens |
| `GITGUARDIAN_API_KEY` | gitguardian.com → API |
| `CORRIDOR_API_KEY` | corridor.so → Settings → API |

Not all are required. Add the ones matching your stack.

---

## Step 6 — Branch Setup

```bash
# In your project directory:
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
git push -u origin main

# Create development branch
git checkout -b development
git push -u origin development
```

From now on:
- **All your work** happens on `development`
- **PRs go** from `development` → `main`
- **Never push directly** to `main`

---

## Step 7 — Copy the GitHub Actions workflows

The `workflows/` folder in this repo contains 6 pre-configured workflows. Copy them to your project:

```bash
mkdir -p .github/workflows
cp /path/to/cc-full-system/.github/workflows/* .github/workflows/
git add .github/
git commit -m "Add CC automation workflows"
git push
```

### What each workflow does

| File | What it does |
|------|-------------|
| `auto-pr.yml` | Opens a PR automatically every time you push to `development` |
| `auto-merge.yml` | Enables auto-merge when all checks pass — feature PRs squash, dev→main merges |
| `bugbot.yml` | Triggers Claude BugBot to review every PR (catches real bugs) |
| `sync-main-to-development.yml` | After main merges, syncs the changes back to development (prevents divergence) |
| `auto-fix.yml` | When a `build-failure` or `edge-fn-failure` issue opens, routes to build-healer |
| `link-check.yml` | Daily at 9am — checks all routes for 404s, opens `broken-link` issues |

---

## Step 8 — Enable Claude BugBot

BugBot reviews every PR and catches real bugs before they reach production.

1. Go to claude.ai/code → **Settings → BugBot**
2. Click **Connect repository**
3. Select your GitHub repo
4. Done — BugBot automatically reviews every new PR

---

## Step 9 — Enable CodeRabbit (optional but recommended)

1. Go to coderabbit.ai
2. Click **Get started free**
3. Connect your GitHub account → select your repo
4. The `.coderabbit.yaml` in this repo already has the right settings

CodeRabbit reviews PRs from an AI architecture perspective. `coderabbit-responder` handles these reviews automatically.

---

## Your PR Workflow (once everything is set up)

This is what happens automatically every time you push code:

```
You push to development
    ↓
auto-pr.yml opens a PR
    ↓
BugBot reviews → finds issues → opens GitHub issue → dispatcher routes to bugbot-responder
CodeRabbit reviews → posts comments → coderabbit-responder handles them
CI runs (typecheck + test + build)
    ↓
pr-review-loop fixes all findings automatically
    ↓
All checks green → auto-merge fires
    ↓
sync-main-to-development.yml keeps branches in sync
    ↓
e2e-smoke-tester runs 3 critical path tests on production
    ↓
biz-launch-coordinator triggers GTM actions (copy update, usage baseline)
```

You write code. Everything else runs automatically.

---

## Troubleshooting

**Auto-merge not working:** Check that "Allow auto-merge" is ON in repo Settings → General.

**BugBot not reviewing:** Make sure the repo is connected at claude.ai/code → Settings → BugBot.

**PR not opening automatically:** Check that `GITHUB_TOKEN` has write permissions to your repo and that `auto-pr.yml` is in `.github/workflows/`.

**Agents not routing issues:** Run `bash setup-github-labels.sh YOUR-USERNAME/YOUR-REPO` — labels must exist before agents can use them.
