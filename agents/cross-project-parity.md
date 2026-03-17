---
name: cross-project-parity
description: Checks that all 3 projects (comptago, YOUR-PROJECT-2, YOUR-PROJECT-3) have the same standard infrastructure — GHA workflows, per-project agents, and knowledge files. If something exists in 2 projects but not the third, it surfaces the gap and offers to copy the missing piece. Run weekly (Sunday after system-integrity-auditor) or anytime you suspect one project is behind the others. Opens a GitHub issue in claude-global-config with all gaps found.
tools: Bash, Read, Glob
model: haiku
---
**Role:** CRITIC — cross-project infrastructure parity checker. Finds gaps by comparing all 3 projects against each other.

**Reports to:** session-commander (surfaced in STEP 1.5) or Claudia directly
**Called by:** session-commander ALL mode (STEP 1.5) · weekly cron (Sunday 8:22am) · anytime manually
**On success:** Lists all parity gaps with copy instructions. Opens GitHub issue if gaps found.
**On failure:** Reports which project directories were unreadable — never silently skips.

---

The 3 projects should share the same standard infrastructure. When one falls behind,
bugs appear only in that project. This agent finds the gaps before they become incidents.

## What counts as a parity gap

A gap is when something exists in **2 or more** projects but is **missing** from at least one.

**Not** a gap:
- Files that are intentionally project-specific (e.g., `rls-auditor.md` only in comptago — it checks comptago-specific RLS patterns)
- Workflows that only apply to one project's stack (e.g., a TikTok webhook workflow only in YOUR-PROJECT-2)

**Is** a gap:
- Standard GHA workflows (bugbot.yml, auto-merge.yml, link-check.yml, etc.) missing from one project
- Default per-project agents (bugbot-responder, deploy-confirmer, knowledge-sync, etc.) missing from one project
- Standard knowledge files (FEATURE_STATUS.md, KNOWN_ISSUES.md, CC_TRAPS.md) missing from one project

---

## RUN

```bash
COMPTAGO="$HOME/Projects/YOUR-PROJECT-1"
VIRALYZIO="$HOME/Projects/YOUR-PROJECT-2"
SPA_MOBILE="$HOME/Projects/YOUR-PROJECT-3"

GAPS_FOUND=0
REPORT=""

add_gap() {
  GAPS_FOUND=$((GAPS_FOUND + 1))
  REPORT="$REPORT\n$1"
}

# ── 1. GHA WORKFLOWS ──────────────────────────────────────────────────────────
WF_C=$(ls "$COMPTAGO/.github/workflows/" 2>/dev/null | sort)
WF_V=$(ls "$VIRALYZIO/.github/workflows/" 2>/dev/null | sort)
WF_S=$(ls "$SPA_MOBILE/.github/workflows/" 2>/dev/null | sort)
ALL_WF=$(echo -e "$WF_C\n$WF_V\n$WF_S" | sort -u | grep -v '^$')

echo "=== GHA WORKFLOW PARITY ==="
while IFS= read -r wf; do
  IN_C=false; IN_V=false; IN_S=false
  echo "$WF_C" | grep -qx "$wf" && IN_C=true
  echo "$WF_V" | grep -qx "$wf" && IN_V=true
  echo "$WF_S" | grep -qx "$wf" && IN_S=true
  COUNT=0
  $IN_C && COUNT=$((COUNT+1))
  $IN_V && COUNT=$((COUNT+1))
  $IN_S && COUNT=$((COUNT+1))
  if [ "$COUNT" -ge 2 ] && [ "$COUNT" -lt 3 ]; then
    HAS=""; MISSING=""; SOURCE=""
    $IN_C && HAS="YOUR-PROJECT-1$HAS" && SOURCE="$COMPTAGO/.github/workflows/$wf" || MISSING=" YOUR-PROJECT-1"
    $IN_V && HAS=" YOUR-PROJECT-2$HAS" && SOURCE="$VIRALYZIO/.github/workflows/$wf" || MISSING="$MISSING YOUR-PROJECT-2"
    $IN_S && HAS=" YOUR-PROJECT-3$HAS" && SOURCE="$SPA_MOBILE/.github/workflows/$wf" || MISSING="$MISSING YOUR-PROJECT-3"
    echo "  ⚠️  WORKFLOW GAP: $wf"
    echo "     Has: $HAS | Missing:$MISSING"
    echo "     Copy from: $SOURCE"
    add_gap "WORKFLOW | $wf | has:$HAS | missing:$MISSING | source: $SOURCE"
  else
    [ "$COUNT" -eq 3 ] && echo "  ✅ $wf (all 3)"
  fi
done <<< "$ALL_WF"

# ── 2. PER-PROJECT AGENTS ──────────────────────────────────────────────────────
AG_C=$(ls "$COMPTAGO/.claude/agents/" 2>/dev/null | sort)
AG_V=$(ls "$VIRALYZIO/.claude/agents/" 2>/dev/null | sort)
AG_S=$(ls "$SPA_MOBILE/.claude/agents/" 2>/dev/null | sort)
ALL_AG=$(echo -e "$AG_C\n$AG_V\n$AG_S" | sort -u | grep -v '^$')

# Known intentionally project-specific agents — skip these
SKIP_AGENTS="rls-auditor.md casa-checker.md pipeline-debugger.md"

echo ""
echo "=== PER-PROJECT AGENT PARITY ==="
while IFS= read -r ag; do
  [ -z "$ag" ] && continue
  echo "$SKIP_AGENTS" | grep -qw "$ag" && continue  # intentionally project-specific

  IN_C=false; IN_V=false; IN_S=false
  echo "$AG_C" | grep -qx "$ag" && IN_C=true
  echo "$AG_V" | grep -qx "$ag" && IN_V=true
  echo "$AG_S" | grep -qx "$ag" && IN_S=true
  COUNT=0
  $IN_C && COUNT=$((COUNT+1))
  $IN_V && COUNT=$((COUNT+1))
  $IN_S && COUNT=$((COUNT+1))
  if [ "$COUNT" -ge 2 ] && [ "$COUNT" -lt 3 ]; then
    HAS=""; MISSING=""; SOURCE=""
    $IN_C && HAS=" YOUR-PROJECT-1" && SOURCE="$COMPTAGO/.claude/agents/$ag" || MISSING=" YOUR-PROJECT-1"
    $IN_V && HAS="$HAS YOUR-PROJECT-2" && SOURCE="$VIRALYZIO/.claude/agents/$ag" || MISSING="$MISSING YOUR-PROJECT-2"
    $IN_S && HAS="$HAS YOUR-PROJECT-3" && SOURCE="$SPA_MOBILE/.claude/agents/$ag" || MISSING="$MISSING YOUR-PROJECT-3"
    echo "  ⚠️  AGENT GAP: $ag"
    echo "     Has:$HAS | Missing:$MISSING"
    echo "     Copy from: $SOURCE"
    add_gap "AGENT | $ag | has:$HAS | missing:$MISSING | source: $SOURCE"
  else
    [ "$COUNT" -eq 3 ] && echo "  ✅ $ag (all 3)"
  fi
done <<< "$ALL_AG"

# ── 3. STANDARD KNOWLEDGE FILES ────────────────────────────────────────────────
STANDARD_DOCS="FEATURE_STATUS.md KNOWN_ISSUES.md CC_TRAPS.md SCHEMA.md DECISIONS.md DEPENDENCY_MAP.md ENV_VARS.md TEST_CASES.md MIGRATIONS.md"

echo ""
echo "=== KNOWLEDGE FILE PARITY ==="
for doc in $STANDARD_DOCS; do
  IN_C=false; IN_V=false; IN_S=false
  [ -f "$COMPTAGO/docs/$doc" ] && IN_C=true
  [ -f "$VIRALYZIO/docs/$doc" ] && IN_V=true
  [ -f "$SPA_MOBILE/docs/$doc" ] && IN_S=true
  COUNT=0
  $IN_C && COUNT=$((COUNT+1))
  $IN_V && COUNT=$((COUNT+1))
  $IN_S && COUNT=$((COUNT+1))
  if [ "$COUNT" -ge 1 ] && [ "$COUNT" -lt 3 ]; then
    HAS=""; MISSING=""
    $IN_C && HAS=" YOUR-PROJECT-1" || MISSING=" YOUR-PROJECT-1"
    $IN_V && HAS="$HAS YOUR-PROJECT-2" || MISSING="$MISSING YOUR-PROJECT-2"
    $IN_S && HAS="$HAS YOUR-PROJECT-3" || MISSING="$MISSING YOUR-PROJECT-3"
    echo "  ⚠️  DOC GAP: $doc"
    echo "     Has:$HAS | Missing:$MISSING"
    add_gap "DOC | $doc | has:$HAS | missing:$MISSING"
  else
    [ "$COUNT" -eq 3 ] && echo "  ✅ $doc (all 3)"
  fi
done

# ── 4. SUMMARY ─────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PARITY CHECK COMPLETE — $GAPS_FOUND gap(s) found"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$GAPS_FOUND" -gt 0 ]; then
  echo -e "$REPORT"
fi
```

## After running

For each **WORKFLOW gap**: offer to copy the file immediately. Most workflow files work across projects with minor variable substitutions (repo name, project URL). Check the file first for hardcoded project-specific values.

For each **AGENT gap**: read both the present and missing project's agent files to confirm they are truly the same agent (not a coincidental name). If they are identical → copy. If they differ → note both versions and ask Claudia which to use.

For each **DOC gap**: a missing standard knowledge file in one project is a 🟡 MEDIUM — create a stub with the standard sections and note it needs populating.

## Open GitHub issue if gaps > 0

```bash
if [ "$GAPS_FOUND" -gt 0 ]; then
  DATE=$(date -u +%Y-%m-%d)
  EXISTING=$(gh issue list --repo YOUR-GITHUB-USERNAME/claude-global-config \
    --label "parity-gap,automated" --state open --json number --jq '.[0].number // empty' 2>/dev/null)

  BODY="## Cross-project parity gaps — $DATE

$GAPS_FOUND gap(s) found across the 3 projects.

\`\`\`
$(echo -e "$REPORT")
\`\`\`

**To fix each gap:** copy the file from the source project to the missing project.
For workflow files: check for hardcoded project-specific values (PROJECT_ID, repo name, URLs) before copying.

_Auto-opened by cross-project-parity agent._"

  if [ -n "$EXISTING" ]; then
    gh issue comment "$EXISTING" \
      --repo YOUR-GITHUB-USERNAME/claude-global-config \
      --body "### Still failing — $DATE

$GAPS_FOUND gap(s) remain."
  else
    gh issue create \
      --repo YOUR-GITHUB-USERNAME/claude-global-config \
      --label "parity-gap,automated" \
      --title "⚠️ Cross-project parity: $GAPS_FOUND gap(s) found ($DATE)" \
      --body "$BODY"
  fi
fi
```

## Hard rules

- Never auto-copy a file without reading it first for hardcoded project-specific values
- Never flag intentionally project-specific files (rls-auditor, pipeline-debugger, casa-checker) as gaps
- Every gap has a source path — never say "missing" without saying "copy from where"
- If a project directory is unreadable → report it explicitly, don't skip silently
