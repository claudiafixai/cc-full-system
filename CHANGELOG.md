# Changelog

## v1.0.0 — 2026-03-17

### Initial release

- 105 global agents across 4 layers (monitoring, healing, growth, learning)
- 6 lifecycle hooks (session-briefer, session-learner, impact-check, agent-registry-sync, docs-drift-check, session-findings-logger)
- 5 slash commands (/improve, /start, /pr, /bug, /health)
- 6 GitHub Actions workflows (auto-pr, auto-merge, bugbot, auto-label, auto-fix, codeql)
- One-command installer (install.sh)
- Per-project template folder
- Global memory system with traps and patterns
- Full setup guide (SETUP.md)

### Agents by layer

**Monitoring (19):** health-monitor, global-radar, vercel-monitor, sentry-monitor, github-ci-monitor, supabase-monitor, n8n-monitor, cloudflare-monitor, resend-monitor, infra-health-check, ssl-certificate-monitor, database-health-monitor, api-quota-monitor, stripe-monitor, oauth-token-monitor, cost-monitor, dev-drift-monitor, observability-engineer, cc-update-monitor

**Healing (15):** build-healer, n8n-healer, stripe-webhook-healer, feature-unblock-agent, migration-auto-approver, incident-commander, debugger, error-detective, sentry-fix-issues, post-mortem-generator, knowledge-sync-enforcer, docs-sync-monitor, rls-scanner, dependency-auditor, backup-verifier

**Growth (21 biz- agents):** biz-product-strategist, biz-market-researcher, biz-ux-friction-detector, biz-copy-writer, biz-user-behavior-analyst, biz-ideal-customer-profiler, biz-churn-detector, biz-revenue-optimizer, biz-competition-monitor, biz-corporation-reporter, biz-legal-compliance-monitor, biz-onboarding-optimizer, biz-feature-validator, biz-pricing-strategist, biz-device-auditor, biz-launch-coordinator, biz-daily-standup, biz-customer-interviewer, biz-growth-experimenter, biz-support-triage, biz-brainstorm-facilitator

**Learning (50+):** session-learner, lesson-extractor, knowledge-updater, knowledge-curator, session-briefer, sprint-planner, feature-orchestrator, integration-orchestrator, pr-review-loop, draft-quality-gate, and more
