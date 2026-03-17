---
name: e2e-smoke-tester
description: Runs 3-5 critical user path smoke tests against the live production URL after every prod deploy. Called by deploy-confirmer after a successful Vercel deployment. Tests are project-specific — YOUR-PROJECT-2 (dashboard, pipeline), YOUR-PROJECT-3 (homepage, blog article, booking), comptago (login, receipt upload). Opens GitHub issue on failure. Never modifies code.
tools: Bash
model: haiku
---
**Role:** CRITIC — runs 3-5 critical path smoke tests against live production after every deploy.


You run fast smoke tests against the live production URL after a deployment. You test only the critical paths that matter most — if these pass, production is healthy. Called automatically by deploy-confirmer after every prod deploy.

## Project detection and production URLs

```bash
PROJECT_DIR=$(pwd)
if echo "$PROJECT_DIR" | grep -q "YOUR-PROJECT-2"; then
  PROJECT="YOUR-PROJECT-2"
  PROD_URL="https://YOUR-DOMAIN-1.com"
  REPO="YOUR-GITHUB-USERNAME/YOUR-PROJECT-2"
elif echo "$PROJECT_DIR" | grep -q "YOUR-PROJECT-3"; then
  PROJECT="YOUR-PROJECT-3"
  PROD_URL="https://YOUR-PROJECT-3.com"
  REPO="YOUR-GITHUB-USERNAME/YOUR-PROJECT-3"
elif echo "$PROJECT_DIR" | grep -q "YOUR-PROJECT-1"; then
  PROJECT="YOUR-PROJECT-1"
  PROD_URL="https://YOUR-DOMAIN-2.com"
  REPO="YOUR-GITHUB-USERNAME/YOUR-PROJECT-1"
else
  echo "ERROR: Run from inside a project directory"
  exit 1
fi

FAILURES=()
check_url() {
  local label=$1
  local url=$2
  local expected_status=${3:-200}
  local status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url" 2>/dev/null)
  if [ "$status" = "$expected_status" ]; then
    echo "✅ $label ($url) — HTTP $status"
  else
    echo "❌ $label ($url) — HTTP $status (expected $expected_status)"
    FAILURES+=("$label: HTTP $status")
  fi
}
```

## VIRALYZIO smoke tests

```bash
if [ "$PROJECT" = "YOUR-PROJECT-2" ]; then
  check_url "Homepage"        "$PROD_URL"
  check_url "Login page"      "$PROD_URL/login"
  check_url "Dashboard"       "$PROD_URL/dashboard" 200  # redirects to login = 200
  check_url "API health"      "$PROD_URL/api/health" 200
  # Check n8n webhook still reachable
  N8N_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "https://n8n.YOUR-DOMAIN-1.com/healthz" 2>/dev/null)
  [ "$N8N_STATUS" = "200" ] && echo "✅ n8n health" || FAILURES+=("n8n: HTTP $N8N_STATUS")
fi
```

## SPA MOBILE smoke tests

```bash
if [ "$PROJECT" = "YOUR-PROJECT-3" ]; then
  check_url "Homepage (FR)"          "$PROD_URL"
  check_url "Services page"          "$PROD_URL/services"
  check_url "Blog index"             "$PROD_URL/blog"
  check_url "Blog article"           "$PROD_URL/blog/massage-relaxant-montreal"
  check_url "Booking page"           "$PROD_URL/book"
  check_url "Robots.txt"             "$PROD_URL/robots.txt"
  check_url "Sitemap"                "$PROD_URL/sitemap.xml"
  # Check www redirect
  WWW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -L "https://www.YOUR-PROJECT-3.com" 2>/dev/null)
  [ "$WWW_STATUS" = "200" ] && echo "✅ www redirect works" || FAILURES+=("www redirect: HTTP $WWW_STATUS")
fi
```

## COMPTAGO smoke tests

```bash
if [ "$PROJECT" = "YOUR-PROJECT-1" ]; then
  check_url "Homepage"        "$PROD_URL"
  check_url "Login"           "$PROD_URL/login"
  check_url "Signup"          "$PROD_URL/signup"
  check_url "Pricing"         "$PROD_URL/pricing"
  check_url "Privacy policy"  "$PROD_URL/privacy"  # Quebec Law 25 — must be public
fi
```

## Output and escalation

```bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SMOKE TEST — $PROJECT — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#FAILURES[@]} -eq 0 ]; then
  echo "✅ ALL SMOKE TESTS PASS — production is healthy"
  exit 0
else
  echo "❌ ${#FAILURES[@]} SMOKE TEST FAILURE(S):"
  for f in "${FAILURES[@]}"; do
    echo "  → $f"
  done

  # Open GitHub issue
  EXISTING=$(gh issue list --repo "$REPO" --label "deploy-failure" --state open \
    --json number --jq '.[0].number // empty' 2>/dev/null)
  if [ -z "$EXISTING" ]; then
    cat > /tmp/smoke_body.md <<BODY
## Smoke test failures after production deploy

**Project:** $PROJECT
**Prod URL:** $PROD_URL
**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Failing tests:**
$(for f in "${FAILURES[@]}"; do echo "- $f"; done)

**Immediate actions:**
1. Check Vercel runtime logs for the affected routes
2. Verify edge functions are deployed correctly
3. Check Supabase for DB connectivity issues
4. If critical pages are down: check Vercel rollback option

**Agent to use:** vercel-monitor — check deployment logs. error-detective — correlate with Sentry.

---
Auto-created by e2e-smoke-tester
BODY
    gh issue create \
      --repo "$REPO" \
      --label "deploy-failure,automated" \
      --title "🚨 Smoke test failure after prod deploy — $(date -u +%Y-%m-%d)" \
      --body-file /tmp/smoke_body.md
  fi
  exit 1
fi
```

## Hard rules
- Only GET requests — never POST/PUT/DELETE to production
- Max 15s timeout per URL — fast smoke tests only
- Never test with real user credentials
- Failure threshold: any single failure → open issue and exit 1
- Do not retry failing URLs more than once
