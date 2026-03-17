#!/bin/bash
# PreToolUse hook — impact check before editing shared files
#
# Reads JSON from stdin (Claude Code format):
#   { "tool_name": "Edit", "tool_input": { "file_path": "...", ... }, "cwd": "..." }
#
# Outputs a warning that gets injected into CC context before the edit.
# Exit 0 always — warn only, never block.

HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // .tool_input.new_file_path // empty' 2>/dev/null)
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Only run on Edit or Write tool calls
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

if [ -z "$FILE_PATH" ] || [ -z "$CWD" ]; then exit 0; fi

# Resolve absolute path
if [[ "$FILE_PATH" != /* ]]; then
  FILE_PATH="$CWD/$FILE_PATH"
fi
RELATIVE_PATH="${FILE_PATH#$CWD/}"

# Patterns that indicate a shared/high-risk file
SHARED_PATTERNS="_shared|/lib/|/utils/|/hooks/|/context/|/store/|/types/|supabase\.ts$|database\.types\.ts$|\.config\.(ts|js)$|vite\.config|tailwind\.config"

if ! echo "$RELATIVE_PATH" | grep -qE "$SHARED_PATTERNS"; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

# --- Fast path: check DEPENDENCY_MAP.md ---
# All 3 projects keep this in docs/ — fall back to root for any legacy layout
if [ -f "$CWD/docs/DEPENDENCY_MAP.md" ]; then
  DEPMAP="$CWD/docs/DEPENDENCY_MAP.md"
else
  DEPMAP="$CWD/DEPENDENCY_MAP.md"
fi
if [ -f "$DEPMAP" ]; then
  # Find the section for this file
  SECTION=$(awk "/### .*$FILENAME/,/^###|^##|^---/" "$DEPMAP" 2>/dev/null | head -20)
  if [ -n "$SECTION" ]; then
    TIER=$(echo "$SECTION" | grep -oE "TIER [0-9]|🔴|🟠|🟡|🟢" | head -1)
    USED_BY=$(echo "$SECTION" | grep -i "Used by" | head -1)
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️  SHARED FILE — IMPACT CHECK                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo "  File: $RELATIVE_PATH"
    if [ -n "$TIER" ]; then echo "  Risk: $TIER"; fi
    if [ -n "$USED_BY" ]; then echo "  $USED_BY"; fi
    echo ""
    echo "  Before editing:"
    echo "  1. List every caller this change affects"
    echo "  2. Confirm interface change is backwards-compatible OR update all callers in same commit"
    echo "  3. Run: npx tsc --noEmit after editing"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    exit 0
  fi
fi

# --- Slow path: madge reverse lookup (for files not in DEPENDENCY_MAP) ---
if command -v npx &>/dev/null && [ -d "$CWD/src" ]; then
  MADGE_OUTPUT=$(cd "$CWD" && timeout 10 npx madge --depends "$RELATIVE_PATH" src/ --extensions ts,tsx 2>/dev/null | tail -n +2 | grep -v "^$" | wc -l | tr -d ' ')
  if [ -n "$MADGE_OUTPUT" ] && [ "$MADGE_OUTPUT" -gt 3 ] 2>/dev/null; then
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️  SHARED FILE — IMPACT CHECK (madge)              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo "  File: $RELATIVE_PATH"
    echo "  Imported by: ~$MADGE_OUTPUT files (run: npx madge --depends \"$RELATIVE_PATH\" src/)"
    echo ""
    echo "  Confirm no interface changes break callers before editing."
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
  fi
fi

# --- Trap check: surface relevant CC_TRAPS.md entries for this file BEFORE editing ---
TRAPS_FILE=""
if [ -f "$CWD/docs/CC_TRAPS.md" ]; then TRAPS_FILE="$CWD/docs/CC_TRAPS.md"; fi
GLOBAL_TRAPS="$HOME/.claude/memory/global_traps.md"

RELEVANT_TRAPS=""
for tf in "$TRAPS_FILE" "$GLOBAL_TRAPS"; do
  [ -z "$tf" ] || [ ! -f "$tf" ] && continue
  # Find trap section headers (### lines) that appear near mentions of this filename or path
  MATCHES=$(grep -B3 "$FILENAME\|${RELATIVE_PATH}" "$tf" 2>/dev/null | \
    grep "^### " | head -3)
  [ -n "$MATCHES" ] && RELEVANT_TRAPS="${RELEVANT_TRAPS}${MATCHES}\n"
done

if [ -n "$RELEVANT_TRAPS" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ⚡ TRAP CHECK — relevant traps for $FILENAME"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "$RELEVANT_TRAPS" | while read -r line; do
    [ -n "$line" ] && echo "  $line"
  done
  echo "  → Read full trap in docs/CC_TRAPS.md or ~/.claude/memory/global_traps.md"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
fi

exit 0
