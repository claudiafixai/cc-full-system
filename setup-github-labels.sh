#!/bin/bash

# Creates all GitHub labels needed for the dispatcher to route issues automatically
# Run: bash setup-github-labels.sh YOUR-GITHUB-USERNAME/YOUR-REPO-NAME

REPO=${1:-""}

if [ -z "$REPO" ]; then
  echo "Usage: bash setup-github-labels.sh YOUR-USERNAME/YOUR-REPO"
  exit 1
fi

echo "Setting up labels for $REPO..."

create_label() {
  gh label create "$1" --color "$2" --description "$3" --repo "$REPO" --force 2>/dev/null
  echo "  ✅ $1"
}

echo ""
echo "── Routing labels (dispatcher uses these) ──"
create_label "bugbot-review"        "d93f0b" "BugBot found issues — routes to bugbot-responder"
create_label "build-failure"        "e11d48" "Build or CI failed — routes to build-healer"
create_label "sentry-error"         "f97316" "Sentry production error — routes to sentry-fix-issues"
create_label "deploy-failure"       "dc2626" "Deploy failed — routes to incident-commander"
create_label "feature-blocked"      "7c3aed" "Feature stuck — routes to feature-unblock-agent"
create_label "feature-stuck"        "8b5cf6" "No progress 7+ days — routes to feature-health-auditor"
create_label "db-health"            "0891b2" "DB performance issue — routes to database-optimizer"
create_label "api-quota"            "d97706" "API quota near limit — routes to api-quota-monitor"
create_label "ssl-expiry"           "dc2626" "SSL cert expiring — routes to ssl-certificate-monitor"
create_label "broken-link"          "f59e0b" "Broken page detected — routes to link-checker"
create_label "support-ticket"       "0ea5e9" "User support request — routes to biz-support-triage"
create_label "parity-gap"           "6366f1" "Missing workflow/agent vs other projects"
create_label "knowledge-update"     "10b981" "Cross-project pattern found — routes to knowledge-sync"
create_label "claudia-decision"     "ec4899" "Needs your YES/NO decision"
create_label "claudia-decision-resolved" "86efac" "Decision made"
create_label "cost-optimization"    "84cc16" "Opportunity to reduce API or platform spend"
create_label "agent-chain-broken"   "ef4444" "Agent handoff broken — routes to agent-chain-auditor"
create_label "system-integrity"     "6366f1" "System-wide integrity issue"

echo ""
echo "── PR/Issue type labels ──"
create_label "bug"                  "d93f0b" "Something is broken"
create_label "feature"              "7c3aed" "New feature request"
create_label "fix"                  "16a34a" "Bug fix"
create_label "chore"                "94a3b8" "Maintenance task"
create_label "docs"                 "60a5fa" "Documentation update"
create_label "security"             "dc2626" "Security issue"
create_label "performance"          "f59e0b" "Performance improvement"
create_label "hotfix"               "ef4444" "Urgent production fix"
create_label "ux-fix"               "a855f7" "UX/design improvement"
create_label "copy-update"          "ec4899" "Marketing copy change"
create_label "idea"                 "fbbf24" "New idea — routes to biz-brainstorm-facilitator"
create_label "brainstorm"           "fbbf24" "Brainstorm request"

echo ""
echo "✅ All labels created for $REPO"
echo ""
echo "The dispatcher will now automatically route issues to the right agents."
