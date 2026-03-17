#!/bin/bash
# PostToolUse hook — agent-registry-sync.sh
#
# Fires after any Write or Edit operation.
# If a .claude/agents/*.md file was touched, tells CC to sync all registries immediately.
# CC sees this output and runs agent-registry-sync before its next response.
#
# Input (stdin): JSON from CC:
#   { "tool_name": "Write", "tool_input": { "file_path": "..." }, "cwd": "..." }

HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.new_file_path // empty' 2>/dev/null)
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Only fire on Write or Edit
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

if [ -z "$FILE_PATH" ]; then exit 0; fi

# Resolve absolute path
if [[ "$FILE_PATH" != /* ]] && [ -n "$CWD" ]; then
  FILE_PATH="$CWD/$FILE_PATH"
fi

# Only care about .claude/agents/*.md files
if ! echo "$FILE_PATH" | grep -qE "\.claude/agents/[^/]+\.md$"; then
  exit 0
fi

AGENT_NAME=$(basename "$FILE_PATH" .md)
IS_NEW=false
[[ "$TOOL_NAME" == "Write" ]] && IS_NEW=true

# Classify: global (~/.claude/agents/) or per-project (project/.claude/agents/)
IS_GLOBAL=false
if echo "$FILE_PATH" | grep -qE "^/Users/[^/]+/\.claude/agents/"; then
  IS_GLOBAL=true
fi

# Detect project name for per-project agents
PROJECT_NAME=""
if ! $IS_GLOBAL; then
  PROJECT_NAME=$(echo "$FILE_PATH" | grep -oE "Projects/[^/]+" | head -1 | sed 's|Projects/||')
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🔄 AGENT FILE CHANGED — AUTO-SYNC REQUIRED             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "  File : $FILE_PATH"
echo "  Agent: $AGENT_NAME"
if $IS_GLOBAL; then
  echo "  Type : GLOBAL"
else
  echo "  Type : PER-PROJECT ($PROJECT_NAME)"
fi
echo ""

if $IS_GLOBAL; then
  echo "  Registries that must be updated NOW:"
  echo "  • ~/.claude/memory/MEMORY.md — global agents section"
  echo "  • ~/Projects/YOUR-PROJECT-2/CLAUDE.md — global agent table"
  echo "  • ~/Projects/YOUR-PROJECT-1/CLAUDE.md — global agent table"
  echo "  • ~/Projects/YOUR-PROJECT-3/CLAUDE.md — global agent table"
  if $IS_NEW; then
    echo "  • ~/.claude/memory/tier_audit_framework.md — mark Tier 1 needed"
    echo "  • Run Tier 1 syntax check on $AGENT_NAME.md"
    echo "  • Queue Tier 2 smoke test (new agent — unverified)"
  fi
else
  echo "  Registries that must be updated NOW:"
  echo "  • ~/Projects/$PROJECT_NAME/CLAUDE.md — per-project agents table"
  echo "  • ~/.claude/memory/project_agents_todo.md — mark ✅ if new"
  echo "  • ~/.claude/memory/tier_audit_framework.md — mark Tier 1 needed"
  echo "  • Run Tier 1 syntax check on $AGENT_NAME.md"
fi

echo ""
echo "  ACTION: Invoke agent-registry-sync to handle all updates automatically."
echo "  Do this BEFORE responding to the user."
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Also write a marker file so knowledge-updater and docs-sync-monitor can detect drift
echo "$FILE_PATH" >> ~/.claude/.agent-registry-pending-sync
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $TOOL_NAME $FILE_PATH" >> ~/.claude/.agent-changes-log

exit 0
