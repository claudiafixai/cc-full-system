#!/bin/bash

# Sync updated agents from your live ~/.claude/ to this repo
# Run monthly or after a batch of improvements
# Usage: bash sync-from-live.sh

LIVE_DIR="$HOME/.claude"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CC Full System — Sync from live ~/.claude/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -d "$LIVE_DIR/agents" ]; then
  echo "❌ ~/.claude/agents/ not found. Are you running this on the right machine?"
  exit 1
fi

# Find agents that changed in live vs repo
echo "Checking for changes..."
echo ""

CHANGED=()
ADDED=()

for live_file in "$LIVE_DIR/agents/"*.md; do
  filename=$(basename "$live_file")
  repo_file="$REPO_DIR/agents/$filename"

  if [ ! -f "$repo_file" ]; then
    ADDED+=("$filename")
  elif ! diff -q "$live_file" "$repo_file" > /dev/null 2>&1; then
    CHANGED+=("$filename")
  fi
done

# Report
if [ ${#ADDED[@]} -eq 0 ] && [ ${#CHANGED[@]} -eq 0 ]; then
  echo "✅ Everything is up to date. No changes to sync."
  exit 0
fi

if [ ${#ADDED[@]} -gt 0 ]; then
  echo "🆕 New agents (not in repo yet):"
  for f in "${ADDED[@]}"; do echo "   + $f"; done
  echo ""
fi

if [ ${#CHANGED[@]} -gt 0 ]; then
  echo "📝 Changed agents (updated since last sync):"
  for f in "${CHANGED[@]}"; do echo "   ~ $f"; done
  echo ""
fi

# Ask to proceed
read -p "Copy all changes to repo? (y/n): " confirm
if [ "$confirm" != "y" ]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Copying and scrubbing personal references..."

# Copy and scrub
for filename in "${ADDED[@]}" "${CHANGED[@]}"; do
  cp "$LIVE_DIR/agents/$filename" "$REPO_DIR/agents/$filename"

  # Scrub personal references
  sed -i '' \
    -e 's|comptago-assistant|YOUR-PROJECT-1|g' \
    -e 's|viralyzio|YOUR-PROJECT-2|g' \
    -e 's|spa-mobile|YOUR-PROJECT-3|g' \
    -e 's|claudiafixai|YOUR-GITHUB-USERNAME|g' \
    -e 's|ClaudiaLasante|YOUR-USERNAME|g' \
    -e 's|viralyx\.io|YOUR-DOMAIN-1.com|g' \
    -e 's|comptago\.ai|YOUR-DOMAIN-2.com|g' \
    -e 's|spa-mobile\.com|YOUR-DOMAIN-3.com|g' \
    -e 's|n8n\.viralyx\.io|YOUR-N8N-URL|g' \
    -e 's|support@claudiafix\.ai|YOUR-EMAIL|g' \
    -e 's|Claudia Fix AI Solutions|YOUR-COMPANY|g' \
    -e 's|Spa Mobile Inc|YOUR-COMPANY-2|g' \
    "$REPO_DIR/agents/$filename" 2>/dev/null || true

  echo "  ✅ $filename"
done

# Commit and push
echo ""
read -p "Commit and push to GitHub now? (y/n): " push_confirm
if [ "$push_confirm" = "y" ]; then
  cd "$REPO_DIR"
  git add agents/

  ADDED_COUNT=${#ADDED[@]}
  CHANGED_COUNT=${#CHANGED[@]}

  git commit -m "Chore: sync agents from live system — ${ADDED_COUNT} new, ${CHANGED_COUNT} updated $(date +%Y-%m-%d)"
  git push
  echo ""
  echo "✅ Pushed to GitHub."
else
  echo ""
  echo "Changes copied locally. Run 'git push' when ready."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Sync complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
