#!/bin/bash
# PostToolUse hook — session-findings-logger.sh
#
# Fires after every Bash tool call.
# Detects finding-worthy patterns in output and appends structured entries
# to ~/.claude/session-findings.md for session-learner to process at Stop.
#
# Lightweight — exits immediately if no signal found.
# Input (stdin): CC JSON: { tool_name, tool_input, tool_response, cwd }

HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only fire on Bash tool
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

TOOL_OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_response.output // empty' 2>/dev/null)
TOOL_CMD=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
TOOL_DESC=$(echo "$HOOK_INPUT" | jq -r '.tool_input.description // empty' 2>/dev/null)
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Nothing to analyze
if [ -z "$TOOL_OUTPUT" ]; then exit 0; fi

# Determine project from CWD
PROJECT="global"
if echo "$CWD" | grep -q "YOUR-PROJECT-2"; then PROJECT="YOUR-PROJECT-2"
elif echo "$CWD" | grep -q "YOUR-PROJECT-3"; then PROJECT="YOUR-PROJECT-3"
elif echo "$CWD" | grep -q "comptago"; then PROJECT="YOUR-PROJECT-1"
fi

FINDINGS_FILE="$HOME/.claude/session-findings.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CONTEXT="${TOOL_DESC:-${TOOL_CMD:0:80}}"

# Initialize findings file if it doesn't exist
if [ ! -f "$FINDINGS_FILE" ]; then
  echo "# Session Findings Scratchpad" > "$FINDINGS_FILE"
fi

# Helper: append a finding block
append_finding() {
  local type="$1"
  local lines="$2"
  {
    echo ""
    echo "## $TIMESTAMP | $PROJECT | $CONTEXT"
    echo "**$type:**"
    echo "$lines" | head -5
    echo "---"
  } >> "$FINDINGS_FILE"
}

FOUND=0

# --- Pattern 1: CRITICAL findings ---
CRITICALS=$(echo "$TOOL_OUTPUT" | grep -iE "^CRITICAL:|: CRITICAL |CRITICAL —|CRITICAL fix" | head -5)
if [ -n "$CRITICALS" ]; then
  append_finding "CRITICAL" "$CRITICALS"
  FOUND=1
fi

# --- Pattern 2: Silently broken chains or agent invocation failures ---
BROKEN=$(echo "$TOOL_OUTPUT" | grep -iE "silently broken|broken chain|chain broken|cannot spawn sub-agent|tools.*Bash.*cannot|frontmatter.*broken|fix required.*chain" | head -3)
if [ -n "$BROKEN" ]; then
  append_finding "BROKEN-CHAIN" "$BROKEN"
  FOUND=1
fi

# --- Pattern 3: Tier audit FAIL results ---
TIER_FAILS=$(echo "$TOOL_OUTPUT" | grep -E "Tier [1-4].*FAIL|FAIL.*Tier [1-4]|T[1-4].*❌|❌.*T[1-4]" | head -5)
if [ -n "$TIER_FAILS" ]; then
  append_finding "TIER-FAIL" "$TIER_FAILS"
  FOUND=1
fi

# --- Pattern 4: YAML alias/parse errors (GHA workflow bugs) ---
YAML_ERRORS=$(echo "$TOOL_OUTPUT" | grep -iE "while scanning an alias|yaml.*error|mapping values.*not allowed|alias token|literal block.*terminated" | head -3)
if [ -n "$YAML_ERRORS" ]; then
  append_finding "YAML-ERROR" "$YAML_ERRORS"
  FOUND=1
fi

# --- Pattern 5: TypeScript compile errors ---
TS_ERRORS=$(echo "$TOOL_OUTPUT" | grep -E "error TS[0-9]+:" | head -5)
if [ -n "$TS_ERRORS" ]; then
  append_finding "TS-ERROR" "$TS_ERRORS"
  FOUND=1
fi

# --- Pattern 6: Frontmatter parse errors (agent file syntax) ---
FM_ERRORS=$(echo "$TOOL_OUTPUT" | grep -iE "frontmatter.*error|yaml.*frontmatter|description.*colon.*parse|mapping.*expected" | head -3)
if [ -n "$FM_ERRORS" ]; then
  append_finding "FRONTMATTER-ERROR" "$FM_ERRORS"
  FOUND=1
fi

# --- Pattern 7: jq null bugs or logic errors ---
JQ_BUGS=$(echo "$TOOL_OUTPUT" | grep -iE 'jq.*null|returns.*null.*string|"null".*empty|// empty' | head -3)
if [ -n "$JQ_BUGS" ]; then
  append_finding "JQ-NULL-BUG" "$JQ_BUGS"
  FOUND=1
fi

# --- Pattern 8: Security findings ---
SEC_FINDINGS=$(echo "$TOOL_OUTPUT" | grep -iE "security.*HIGH|HIGH.*security|OWASP|XSS found|SQL injection|auth bypass|RLS.*missing|missing.*RLS" | head -3)
if [ -n "$SEC_FINDINGS" ]; then
  append_finding "SECURITY" "$SEC_FINDINGS"
  FOUND=1
fi

# --- Pattern 9: CI / GHA workflow failures ---
CI_FAILS=$(echo "$TOOL_OUTPUT" | grep -E "Process completed with exit code [1-9]|##\[error\]|FAILED.*workflow|workflow.*FAILED|Run.*failed" | head -3)
if [ -n "$CI_FAILS" ]; then
  append_finding "CI-FAILURE" "$CI_FAILS"
  FOUND=1
fi

# --- Pattern 10: PR review thread resolutions (capture WHAT was fixed) ---
if echo "$TOOL_CMD" | grep -q "resolveReviewThread"; then
  THREAD_CONTEXT="${TOOL_DESC:-unknown thread}"
  {
    echo ""
    echo "## $TIMESTAMP | $PROJECT | PR-thread-resolved"
    echo "**RESOLVED-THREAD:** $THREAD_CONTEXT"
    echo "**Command:** $(echo "$TOOL_CMD" | grep -o 'threadId.*"[^"]*"' | head -1)"
    echo "---"
  } >> "$FINDINGS_FILE"
  FOUND=1
fi

# --- Pattern 11: Audit result summaries (from Python/bash audit scripts) ---
AUDIT_RESULTS=$(echo "$TOOL_OUTPUT" | grep -E "^(CRITICAL|HIGH|MEDIUM|LOW): |issues? found|findings? found|\[FAIL\]|\[BROKEN\]" | head -5)
if [ -n "$AUDIT_RESULTS" ]; then
  append_finding "AUDIT-RESULT" "$AUDIT_RESULTS"
  FOUND=1
fi

# --- Pattern 12: BugBot stale-finding confirmation (GT-BUGBOT-03) ---
# Fires when gh pr review replies are posted with "Already fixed" evidence,
# indicating BugBot found stale issues on a long-running PR.
if echo "$TOOL_CMD" | grep -q "pulls/reviews\|pulls/comments.*replies"; then
  STALE=$(echo "$TOOL_OUTPUT" | grep -iE "already fixed|stale|prior commit|subsequent commit|already resolved" | head -3)
  if [ -n "$STALE" ]; then
    append_finding "BUGBOT-STALE-FINDING" "BugBot finding confirmed already-fixed in HEAD (GT-BUGBOT-03): $STALE"
    FOUND=1
  fi
fi

# --- Pattern 13: vercel.json SPA rewrite catch-all detected ---
if echo "$TOOL_OUTPUT" | grep -qE '"source".*"/\(\.\*\)"'; then
  append_finding "VERCEL-REWRITE-CATCHALL" "vercel.json rewrite /(.*) detected — check for /api/ exclusion (GT-VERCEL-01)"
  FOUND=1
fi

exit 0
