#!/bin/bash

# CC Full System — One-command installer
# Run: bash install.sh

set -e

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CC Full System — Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Claude Code is installed
if ! command -v claude &> /dev/null; then
  echo "❌ Claude Code not found."
  echo "   Install it at: https://claude.ai/code"
  exit 1
fi

echo "✅ Claude Code found"

# Create ~/.claude directories if they don't exist
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/memory"

# Copy agents
echo ""
echo "Installing 105 agents..."
cp -r "$SCRIPT_DIR/agents/"* "$CLAUDE_DIR/agents/"
echo "✅ Agents installed ($(ls "$CLAUDE_DIR/agents/" | wc -l | tr -d ' ') total)"

# Copy hooks
echo "Installing hooks..."
cp "$SCRIPT_DIR/hooks/"* "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh
echo "✅ Hooks installed"

# Copy skills
echo "Installing skills..."
cp -r "$SCRIPT_DIR/skills/"* "$CLAUDE_DIR/skills/"
echo "✅ Skills installed"

# Copy settings (ask first if one already exists)
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  echo ""
  echo "⚠️  You already have a settings.json."
  read -p "   Overwrite it? (y/n): " overwrite
  if [ "$overwrite" = "y" ]; then
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "✅ Settings updated"
  else
    echo "   Skipped settings.json"
  fi
else
  cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/"
  echo "✅ Settings installed"
fi

# Copy CLAUDE.md (ask first)
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo ""
  echo "⚠️  You already have a CLAUDE.md."
  read -p "   Overwrite it? (y/n): " overwrite
  if [ "$overwrite" = "y" ]; then
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "✅ CLAUDE.md updated"
  else
    echo "   Skipped CLAUDE.md"
  fi
else
  cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/"
  echo "✅ CLAUDE.md installed"
fi

# Memory starter
if [ ! -f "$CLAUDE_DIR/memory/MEMORY.md" ]; then
  cp "$SCRIPT_DIR/memory/"* "$CLAUDE_DIR/memory/"
  echo "✅ Memory system initialized"
fi

# Set up .env file if it doesn't exist
if [ ! -f "$CLAUDE_DIR/.env" ]; then
  cp "$SCRIPT_DIR/.env.example" "$CLAUDE_DIR/.env"
  echo "✅ .env file created (fill in your API keys)"
fi

# Customize project names
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Customize for your projects"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Enter your details (press Enter to skip any):"
echo ""

read -p "GitHub username: " GITHUB_USER
read -p "Project 1 repo name (e.g. my-app): " PROJECT1
read -p "Project 2 repo name (optional): " PROJECT2
read -p "Project 3 repo name (optional): " PROJECT3
read -p "Your main domain (e.g. myapp.com): " DOMAIN1

if [ -n "$GITHUB_USER" ]; then
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i '' "s/YOUR-GITHUB-USERNAME/$GITHUB_USER/g" 2>/dev/null || \
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i "s/YOUR-GITHUB-USERNAME/$GITHUB_USER/g"
fi

if [ -n "$PROJECT1" ]; then
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i '' "s/YOUR-PROJECT-1/$PROJECT1/g" 2>/dev/null || \
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i "s/YOUR-PROJECT-1/$PROJECT1/g"
fi

if [ -n "$PROJECT2" ]; then
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i '' "s/YOUR-PROJECT-2/$PROJECT2/g" 2>/dev/null || \
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i "s/YOUR-PROJECT-2/$PROJECT2/g"
fi

if [ -n "$PROJECT3" ]; then
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i '' "s/YOUR-PROJECT-3/$PROJECT3/g" 2>/dev/null || \
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i "s/YOUR-PROJECT-3/$PROJECT3/g"
fi

if [ -n "$DOMAIN1" ]; then
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i '' "s/YOUR-DOMAIN-1.com/$DOMAIN1/g" 2>/dev/null || \
  find "$CLAUDE_DIR/agents/" -name "*.md" | xargs sed -i "s/YOUR-DOMAIN-1.com/$DOMAIN1/g"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Fill in ~/.claude/.env with your API keys"
echo "  2. Edit ~/.claude/CLAUDE.md with your project details"
echo "  3. Open Claude Code in any project: cd ~/Projects/your-project && claude"
echo "  4. Type: run session-commander"
echo ""
echo "Your AI team is ready."
echo ""
