#!/bin/bash
# ~/.claude/hooks/docs-drift-check.sh
# Stop hook — injected into CC context after each response.
# Checks for documentation drift so CC can self-correct before session ends.

WARNINGS=()

# Only run inside a project directory
if [ ! -f "CLAUDE.md" ] && [ ! -f "docs/CC_PROMPTS.md" ]; then
  exit 0
fi

PROJECT_DIR=$(pwd)

# --- Check 1: Migration without SCHEMA.md update ---
# Look at commits on development not yet on main, or just staged/unstaged changes
MIGRATION_CHANGED=$(git diff --name-only HEAD 2>/dev/null | grep "supabase/migrations/" | head -1)
MIGRATION_STAGED=$(git diff --cached --name-only 2>/dev/null | grep "supabase/migrations/" | head -1)

if [ -n "$MIGRATION_CHANGED" ] || [ -n "$MIGRATION_STAGED" ]; then
  SCHEMA_CHANGED=$(git diff --name-only HEAD 2>/dev/null | grep -i "SCHEMA.md\|MIGRATIONS.md" | head -1)
  SCHEMA_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -i "SCHEMA.md\|MIGRATIONS.md" | head -1)
  if [ -z "$SCHEMA_CHANGED" ] && [ -z "$SCHEMA_STAGED" ]; then
    WARNINGS+=("⚠️  DRIFT: Migration file changed but SCHEMA.md / MIGRATIONS.md not updated. Run knowledge-updater or npm run docs:schema.")
  fi
fi

# --- Check 2: Uncommitted changes exist at all ---
UNCOMMITTED=$(git status --porcelain 2>/dev/null | grep -v "^?" | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -gt 0 ]; then
  WARNINGS+=("📋  REMINDER: $UNCOMMITTED uncommitted file(s). Commit before closing or knowledge files may lag behind.")
fi

# --- Check 3: Commits on development not pushed ---
UNPUSHED=$(git log --oneline origin/development..HEAD 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNPUSHED" -gt 0 ]; then
  WARNINGS+=("🚀  REMINDER: $UNPUSHED commit(s) on development not yet pushed to remote.")
fi

# --- Check 4: Fix commits + failed CI runs since last lesson extraction ---
LAST_RUN=$(cat ~/.claude/.lesson-extractor-last-run 2>/dev/null || echo "1 week ago")
FIX_COMMITS=$(git log --oneline --since="$LAST_RUN" --grep="^Fix:" development 2>/dev/null | wc -l | tr -d ' ')
if [ "$FIX_COMMITS" -gt 0 ]; then
  WARNINGS+=("🧠  LEARN: $FIX_COMMITS Fix: commit(s) since last extraction. Run lesson-extractor before closing.")
fi

# Check for failed CI runs (requires gh CLI)
if command -v gh &>/dev/null; then
  REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/\.git//')
  if [ -n "$REPO" ]; then
    FAILED_RUNS=$(gh run list --repo "$REPO" --status failure --limit 5 --json databaseId 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
    if [ "$FAILED_RUNS" -gt 0 ]; then
      WARNINGS+=("⚙️  CI: $FAILED_RUNS failed workflow run(s) detected. Run lesson-extractor CI to extract patterns into CC_TRAPS.")
    fi
  fi
fi

# --- Check 5: In-session findings not yet captured ---
SESSION_FINDINGS="$HOME/.claude/session-findings.md"
if [ -f "$SESSION_FINDINGS" ]; then
  FINDING_COUNT=$(grep -c "^## " "$SESSION_FINDINGS" 2>/dev/null || echo "0")
  if [ "$FINDING_COUNT" -gt 0 ]; then
    WARNINGS+=("🧠  SESSION: $FINDING_COUNT in-session finding(s) in scratchpad. Run session-learner before closing to commit them to CC_TRAPS.md.")
  fi
fi

# --- Output ---
if [ ${#WARNINGS[@]} -eq 0 ]; then
  exit 0
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DOCS DRIFT CHECK                        ║"
echo "╚══════════════════════════════════════════╝"
for w in "${WARNINGS[@]}"; do
  echo "  $w"
done
echo ""
echo "  ⚡ When this session wraps up (Claudia says done / thanks / bye):"
echo "     AUTO-RUN without being asked (in this order):"
echo "     1. session-learner — in-session findings → CC_TRAPS.md (captures what PostToolUse hook logged)"
echo "     2. lesson-extractor — Fix: commits → CC_TRAPS.md traps"
echo "     3. knowledge-updater — sync FEATURE_STATUS / SCHEMA / KNOWN_ISSUES / DECISIONS"
echo ""
echo "  🔁 NEXT SESSION REMINDER:"
echo "     Say 'restart the crons' to recreate all 13 scheduled crons."
echo "     (Crons are session-only — they died when this session closes.)"
echo ""
