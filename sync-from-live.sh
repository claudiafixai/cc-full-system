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

# Scrub function — removes personal references from a file in place
scrub_file() {
  local file="$1"
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
    "$file" 2>/dev/null || true
}

# ─── AGENTS ────────────────────────────────────────────────────────────────
echo "Checking agents/ for changes..."
echo ""

CHANGED_AGENTS=()
ADDED_AGENTS=()

for live_file in "$LIVE_DIR/agents/"*.md; do
  filename=$(basename "$live_file")
  repo_file="$REPO_DIR/agents/$filename"

  if [ ! -f "$repo_file" ]; then
    ADDED_AGENTS+=("$filename")
  elif ! diff -q "$live_file" "$repo_file" > /dev/null 2>&1; then
    CHANGED_AGENTS+=("$filename")
  fi
done

# ─── SKILLS ────────────────────────────────────────────────────────────────
echo "Checking skills/ for changes..."
echo ""

CHANGED_SKILLS=()
ADDED_SKILLS=()

for live_skill_dir in "$LIVE_DIR/skills/"*/; do
  skill_name=$(basename "$live_skill_dir")
  live_file="$live_skill_dir/SKILL.md"
  repo_file="$REPO_DIR/skills/$skill_name/SKILL.md"

  [ -f "$live_file" ] || continue

  if [ ! -f "$repo_file" ]; then
    ADDED_SKILLS+=("$skill_name")
  elif ! diff -q "$live_file" "$repo_file" > /dev/null 2>&1; then
    CHANGED_SKILLS+=("$skill_name")
  fi
done

# ─── REPORT ────────────────────────────────────────────────────────────────
TOTAL_CHANGES=$(( ${#ADDED_AGENTS[@]} + ${#CHANGED_AGENTS[@]} + ${#ADDED_SKILLS[@]} + ${#CHANGED_SKILLS[@]} ))

if [ "$TOTAL_CHANGES" -eq 0 ]; then
  echo "✅ Everything is up to date. No changes to sync."
  exit 0
fi

if [ ${#ADDED_AGENTS[@]} -gt 0 ]; then
  echo "🆕 New agents (not in repo yet):"
  for f in "${ADDED_AGENTS[@]}"; do echo "   + $f"; done
  echo ""
fi

if [ ${#CHANGED_AGENTS[@]} -gt 0 ]; then
  echo "📝 Changed agents (updated since last sync):"
  for f in "${CHANGED_AGENTS[@]}"; do echo "   ~ $f"; done
  echo ""
fi

if [ ${#ADDED_SKILLS[@]} -gt 0 ]; then
  echo "🆕 New skills (not in repo yet):"
  for s in "${ADDED_SKILLS[@]}"; do echo "   + $s/SKILL.md"; done
  echo ""
fi

if [ ${#CHANGED_SKILLS[@]} -gt 0 ]; then
  echo "📝 Changed skills (updated since last sync):"
  for s in "${CHANGED_SKILLS[@]}"; do echo "   ~ $s/SKILL.md"; done
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

# Copy and scrub agents
for filename in "${ADDED_AGENTS[@]}" "${CHANGED_AGENTS[@]}"; do
  cp "$LIVE_DIR/agents/$filename" "$REPO_DIR/agents/$filename"
  scrub_file "$REPO_DIR/agents/$filename"
  echo "  ✅ agents/$filename"
done

# Copy and scrub skills
for skill_name in "${ADDED_SKILLS[@]}" "${CHANGED_SKILLS[@]}"; do
  mkdir -p "$REPO_DIR/skills/$skill_name"
  cp "$LIVE_DIR/skills/$skill_name/SKILL.md" "$REPO_DIR/skills/$skill_name/SKILL.md"
  scrub_file "$REPO_DIR/skills/$skill_name/SKILL.md"
  echo "  ✅ skills/$skill_name/SKILL.md"
done

# Commit and push
echo ""
read -p "Commit and push to GitHub now? (y/n): " push_confirm
if [ "$push_confirm" = "y" ]; then
  cd "$REPO_DIR"
  git add agents/ skills/

  AGENT_COUNT=$(( ${#ADDED_AGENTS[@]} + ${#CHANGED_AGENTS[@]} ))
  SKILL_COUNT=$(( ${#ADDED_SKILLS[@]} + ${#CHANGED_SKILLS[@]} ))

  git commit -m "Chore: sync from live system — ${AGENT_COUNT} agents, ${SKILL_COUNT} skills updated $(date +%Y-%m-%d)"
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
