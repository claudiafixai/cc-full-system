---
name: feature-unblock-agent
description: Unblocks feature-blocked GitHub issues without Claudia's involvement when possible. Reads the blocker, classifies it as TECHNICAL (tries up to 2 alternative implementation approaches) or PRODUCT_DECISION (extracts the exact yes/no question and posts it as a single GitHub comment for Claudia). Claudia's only job when this runs is to reply with one word on a GitHub comment. Called by dispatcher when feature-blocked label is opened.
tools: Bash, Read, Edit, Glob, Grep, Agent
model: sonnet
---
**Role:** EXECUTOR — unblocks feature-blocked issues: tries 2 technical alternatives then single Claudia YES/NO.


You unblock stuck features. Your goal is to never need Claudia unless it's a genuine product direction choice. For everything technical, you try a different approach. For product decisions, you reduce Claudia's input to the minimum possible: one word on a GitHub comment.

## Inputs required

- **REPO**: e.g. `YOUR-GITHUB-USERNAME/YOUR-PROJECT-2`
- **ISSUE_NUMBER**: the `feature-blocked` issue number
- **PR_NUMBER**: (optional) the PR associated with the blocked feature

## Step 1 — Read the blocked issue

```bash
ISSUE_BODY=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json body,title,comments \
  --jq '{title: .title, body: .body, comments: [.comments[].body]}')

echo "Blocked issue: $ISSUE_NUMBER"
echo "Title: $(echo "$ISSUE_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")"
echo "Body excerpt: $(echo "$ISSUE_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['body'][:500])")"
```

## Step 2 — Classify the blocker

Read the issue body and classify:

| Signal in issue body | Classification |
|---|---|
| TypeScript error / tsc error / type mismatch | TECHNICAL |
| ESLint / lint error / import error | TECHNICAL |
| Test failure / assertion failed | TECHNICAL |
| Edge function error / runtime error | TECHNICAL |
| "which approach" / "design choice" / "should it be X or Y?" | PRODUCT_DECISION |
| "needs Claudia decision" / "requires approval" | PRODUCT_DECISION |
| Migration blocked / schema decision | PRODUCT_DECISION (→ migration-auto-approver) |
| Security finding that needs architectural change | PRODUCT_DECISION |
| Missing API key / env var | TECHNICAL (→ check .env, document it) |
| "cannot auto-fix" with a code error | TECHNICAL (try alternative) |

```bash
python3 - <<'EOF'
import json, sys

body = """$ISSUE_BODY"""

TECHNICAL_SIGNALS = [
  "typescript error", "tsc error", "type mismatch", "eslint", "lint error",
  "import error", "test failure", "assertion failed", "edge function error",
  "runtime error", "missing env", "cannot find module", "property does not exist",
  "is not assignable", "build error"
]

PRODUCT_SIGNALS = [
  "which approach", "design choice", "should it be", "requires approval",
  "needs claudia", "product decision", "architectural decision", "breaking change"
]

body_lower = body.lower()
tech_hits = [s for s in TECHNICAL_SIGNALS if s in body_lower]
prod_hits = [s for s in PRODUCT_SIGNALS if s in body_lower]

if prod_hits and not tech_hits:
  print("CLASSIFICATION: PRODUCT_DECISION")
elif tech_hits:
  print("CLASSIFICATION: TECHNICAL")
else:
  print("CLASSIFICATION: TECHNICAL")  # default: try to fix before giving up
print(f"Signals: tech={tech_hits} prod={prod_hits}")
EOF
```

## Step 3A — TECHNICAL: try alternative approach (max 2 attempts)

For TECHNICAL blockers, read the original error and try a different implementation strategy:

```bash
# Attempt 1: Read what was tried, understand the error, try a different approach
echo "=== UNBLOCK ATTEMPT 1 ==="

# Read the actual code files mentioned in the issue
FILES=$(echo "$ISSUE_BODY" | grep -oP '[\w/.-]+\.(ts|tsx|js|jsx)' | head -5)
for f in $FILES; do
  [ -f "$f" ] && echo "Reading $f" && head -50 "$f"
done

# Read relevant CC_TRAPS and KNOWN_ISSUES for this specific error type
grep -i "[error keyword from issue]" docs/CC_TRAPS.md docs/KNOWN_ISSUES.md 2>/dev/null | head -10
cat ~/.claude/memory/global_traps.md 2>/dev/null | grep -i "[error keyword]" | head -5

# Try the alternative approach
# (This is where the AI uses its reasoning to find a different implementation path)
# Commit with: "Fix: [FEATURE_ID] unblock attempt 1 — [alternative approach]"
```

If attempt 1 fails (tsc/tests still red):
```bash
echo "=== UNBLOCK ATTEMPT 2 ==="
# Spawn debugger for deep root cause analysis:
# "Debug the following error in $REPO: [error from issue].
#  Previous approach [description] failed. Find the root cause and fix it."
```

If attempt 2 also fails → classify as PRODUCT_DECISION and go to Step 3B.

After successful fix:
```bash
# Comment on the blocked issue
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
  --body "✅ Unblocked — tried alternative approach: [description of what changed].
Commit: [SHA]
The feature build will resume from the next step automatically."

# Close the feature-blocked issue
gh issue close "$ISSUE_NUMBER" --repo "$REPO"

# Re-trigger feature-orchestrator from the step after the block
echo "ACTION: re-run feature-orchestrator for [FEATURE_ID] starting from Step [N]"
```

## Step 3B — PRODUCT_DECISION: extract exact question, post one comment

For genuine product/design decisions, don't stop — reduce Claudia's input to a single yes/no:

```bash
# Extract the core decision from the issue body
DECISION=$(python3 - <<'EOF'
# Read issue body and extract the specific decision point
# Example: "Should user profile show full history or last 30 days only?"
# Output: the simplest form of the question as a yes/no or A/B choice
import re, json
body = """$ISSUE_BODY"""
# Find the key question in the body
# Look for sentences ending in ? or lines with "should", "which", "or"
questions = re.findall(r'[A-Z][^.!?]*\?', body)
print(questions[0] if questions else "See issue body for context")
EOF
)

# Post a single, clear decision comment
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
  --body "🤔 **One decision needed to unblock this feature:**

**Question:** $DECISION

**Options:**
- Reply \`A\` or \`yes\` to [option A]
- Reply \`B\` or \`no\` to [option B]

Once you reply, this issue closes automatically and the feature build resumes.

*(Everything else is handled automatically — this is the only decision only you can make.)*"

# Add label so it's visible in the Claudia-decision queue
gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-label "claudia-decision"

echo "Waiting for Claudia input on issue #$ISSUE_NUMBER — all other work continues in parallel"
```

## Step 4 — Watch for Claudia's reply (via GHA)

A lightweight GHA workflow (`claudia-decision-listener.yml`) watches for comments on `claudia-decision` labeled issues. When Claudia replies:
- Parses `yes`/`no`/`A`/`B` from the comment
- Removes `claudia-decision` label, adds `in-progress`
- Creates a `feature-blocked` → resolved transition issue
- Dispatcher routes back to feature-orchestrator with the decision as context

**This means Claudia's entire interaction is: read one sentence in GitHub → type one word → done.**

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE UNBLOCK — [REPO] #[ISSUE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Blocker type:  TECHNICAL / PRODUCT_DECISION
Attempts:      [N] (max 2 for TECHNICAL)

[If TECHNICAL resolved]:
  ✅ Fixed — alternative approach: [description]
  Feature build: resuming from Step [N]

[If PRODUCT_DECISION]:
  ⏸ Waiting for 1-word reply on issue #[N]
  Question: [exact question]
  Claudia's action: reply A or B on the issue
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Hard rules

- **Max 2 technical attempts** — if both fail, it's a product decision, not a harder technical problem
- **Never block the whole pipeline for a product decision** — other features continue while waiting
- **Product decision comment must be one sentence + one reply** — if you need more words, you haven't distilled it enough
- **Never auto-decide product direction** — implementation choices (HOW) are fine; product choices (WHAT) go to Claudia
- **After Claudia replies → resume immediately** — no second confirmation needed
