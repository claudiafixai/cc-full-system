#!/bin/bash
# PreToolUse hook — session-briefer.sh
#
# Fires on the FIRST tool call of every new CC session.
# Uses a marker file to fire only once per hour (= once per session).
# Tells CC to run the session-briefer agent for a pre-session intelligence update.
#
# Input (stdin): CC JSON from PreToolUse hook

MARKER_FILE="$HOME/.claude/.session-briefer-last-run"
NOW=$(date +%s)

# Check if we've already briefed in the last 50 minutes (session guard)
if [ -f "$MARKER_FILE" ]; then
  LAST_RUN=$(cat "$MARKER_FILE" 2>/dev/null || echo "0")
  ELAPSED=$(( NOW - LAST_RUN ))
  if [ "$ELAPSED" -lt 3000 ]; then
    exit 0  # Already briefed this session — silent
  fi
fi

# Update marker immediately (prevent double-fire on parallel tool calls)
echo "$NOW" > "$MARKER_FILE"

# Check if there are leftover session findings (fast check — no agent needed)
FINDING_COUNT=$(grep -c "^## " "$HOME/.claude/session-findings.md" 2>/dev/null || echo "0")

# Check for new traps added in the last 7 days
NEW_TRAPS=$(grep -rl "SESSION-LEARNED\|SL-[0-9]\|GT-SL-" \
  "$HOME/Projects/YOUR-PROJECT-2/docs/CC_TRAPS.md" \
  "$HOME/Projects/YOUR-PROJECT-3/docs/CC_TRAPS.md" \
  "$HOME/Projects/YOUR-PROJECT-1/docs/CC_TRAPS.md" \
  "$HOME/.claude/memory/global_traps.md" 2>/dev/null | wc -l | tr -d ' ')

# Always auto-run /start at session open (marker ensures once per session only)
echo ""
echo "IMPORTANT: This is the start of a new session. Before doing ANYTHING else,"
echo "automatically invoke the /start skill RIGHT NOW. Do not wait for the user to ask."
echo "/start will: restart all crons, run dispatcher to clear backlog, then run"
echo "session-commander to brief Claudia on what needs attention."
if [ "$FINDING_COUNT" -gt 0 ]; then
  echo "ALSO: $FINDING_COUNT unprocessed findings in session-findings.md — /start will surface these."
fi
echo ""

exit 0
