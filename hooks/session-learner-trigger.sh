#!/bin/bash
# session-learner-trigger.sh — runs at session Stop
# Checks if any Fix: commits exist in this session across any project.
# If yes: outputs a reminder to run session-learner to extract patterns to CC_TRAPS.md.
# session-learner is an agent (not a script) so this hook cannot invoke it directly —
# it prints a clear prompt that CC will read and act on when the session closes.

# Check each project for Fix: commits since last push
HAS_FIX_COMMITS=false
FIX_REPOS=()

for proj_dir in ~/Projects/YOUR-PROJECT-2 ~/Projects/YOUR-PROJECT-3 ~/Projects/YOUR-PROJECT-1 ~/.claude; do
  if [ -d "$proj_dir/.git" ] || [ -f "$proj_dir/.git" ]; then
    FIX_COUNT=$(git -C "$proj_dir" log --oneline --since="8 hours ago" 2>/dev/null | grep -c "^[a-f0-9]* Fix:" || echo 0)
    if [ "$FIX_COUNT" -gt 0 ]; then
      HAS_FIX_COMMITS=true
      FIX_REPOS+=("$(basename $proj_dir): $FIX_COUNT Fix: commit(s)")
    fi
  fi
done

# Always auto-run /improve at session close
echo ""
echo "IMPORTANT: The session is ending. Automatically invoke the /improve skill RIGHT NOW."
echo "Do not wait for the user to ask. Run /improve immediately before the session closes."
if $HAS_FIX_COMMITS; then
  echo "Fix: commits detected in: ${FIX_REPOS[*]}"
  echo "lesson-extractor must be run as part of /improve."
fi
echo "/improve will: capture findings, write traps, fix agents, update memory, commit everything."
echo ""

exit 0
