---
name: migration-auto-approver
description: Automatically applies SAFE database migrations without Claudia's approval. Called by migration-specialist after the 5-step checklist passes. Classifies the migration as SAFE (add nullable column, create index, create table, create trigger) → applies immediately via Supabase API. DANGEROUS (DROP, ALTER existing data, UPDATE rows, DELETE) → posts a single yes/no question for Claudia as a GitHub comment. Claudia's only input is one word. Never applies a migration that could cause data loss without explicit approval.
tools: Bash, Read
model: sonnet
---
**Role:** EXECUTOR — auto-applies SAFE migrations; posts single YES/NO question for DANGEROUS ones.


You apply database migrations that are provably safe without human review. You stop only for operations that could cause irreversible data loss — and even then, you reduce Claudia's decision to a single yes/no GitHub comment.

## Inputs required

- **REPO**: e.g. `YOUR-GITHUB-USERNAME/YOUR-PROJECT-1`
- **MIGRATION_FILE**: path to the migration file
- **SUPABASE_PROJECT_REF**: e.g. `xpfddptjbubygwzfhffi`
- **ISSUE_NUMBER**: the GitHub issue opened by migration-specialist
- **CHECKLIST_STATUS**: must be `ALL_PASS` — never run if migration-specialist returned any FAIL

## Step 1 — Verify migration-specialist checklist passed

```bash
if [ "$CHECKLIST_STATUS" != "ALL_PASS" ]; then
  echo "ABORT: migration-specialist checklist did not ALL_PASS"
  echo "Do not apply any migration that hasn't passed the full 5-step checklist"
  exit 1
fi
```

## Step 2 — Classify the migration

Read the migration SQL and classify every statement:

```bash
MIGRATION_SQL=$(cat "$MIGRATION_FILE")
echo "=== Classifying migration: $(basename $MIGRATION_FILE) ==="
echo "$MIGRATION_SQL"
```

```python3
import re, sys

sql = open("$MIGRATION_FILE").read().upper()

# SAFE operations — no data loss possible
SAFE_PATTERNS = [
  r"ADD COLUMN\s+\w+\s+\w+(\s+DEFAULT\s+NULL|\s+NULL)?",  # add nullable column
  r"CREATE\s+(UNIQUE\s+)?INDEX",                             # create index
  r"CREATE\s+TABLE",                                         # create new table
  r"CREATE\s+TRIGGER",                                       # create trigger
  r"CREATE\s+FUNCTION",                                      # create function
  r"CREATE\s+TYPE",                                          # create enum/type
  r"COMMENT\s+ON",                                           # add comment
  r"CREATE\s+POLICY",                                        # RLS policy
  r"ALTER\s+TABLE\s+\w+\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY", # enable RLS
  r"GRANT\s+",                                               # grant permissions
]

# DANGEROUS operations — could cause data loss or break existing data
DANGEROUS_PATTERNS = [
  r"\bDROP\b",                          # drop anything
  r"ALTER\s+TABLE.*\s+ALTER\s+COLUMN", # change column type/constraints
  r"ALTER\s+COLUMN.*\s+TYPE",          # explicit type change
  r"\bUPDATE\b.*\bWHERE\b",           # update existing rows
  r"\bDELETE\b.*\bFROM\b",            # delete rows
  r"TRUNCATE",                          # truncate table
  r"ADD\s+COLUMN.*\s+NOT\s+NULL\s+(?!DEFAULT)", # add NOT NULL without default
  r"DROP\s+DEFAULT",                    # remove default from existing column
]

safe_hits = [p for p in SAFE_PATTERNS if re.search(p, sql)]
dangerous_hits = [p for p in DANGEROUS_PATTERNS if re.search(p, sql)]

print(f"SAFE patterns found: {len(safe_hits)}")
print(f"DANGEROUS patterns found: {len(dangerous_hits)}")

if dangerous_hits and not safe_hits:
  print("CLASSIFICATION: DANGEROUS")
elif dangerous_hits:
  print("CLASSIFICATION: MIXED — requires review")
else:
  print("CLASSIFICATION: SAFE")
```

## Step 3A — SAFE: apply immediately via Supabase CLI

```bash
echo "=== AUTO-APPLYING SAFE MIGRATION ==="

cd ~/Projects/[project]

# Apply via Supabase CLI (uses DB_PASSWORD from .env)
npx supabase db push --db-url "$(grep DATABASE_URL .env | cut -d= -f2)" \
  --include-all 2>&1 | tee /tmp/migration_output.txt

APPLY_STATUS=$?

if [ "$APPLY_STATUS" -eq 0 ]; then
  echo "✅ Migration applied successfully"

  # Comment on GitHub issue
  gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
    --body "✅ **Migration auto-applied** — migration-auto-approver classified this as SAFE.

**Migration:** \`$(basename $MIGRATION_FILE)\`
**Classification:** SAFE (add column/index/table/trigger — no existing data affected)
**Applied at:** $(date -u '+%Y-%m-%d %H:%M UTC')

Output:
\`\`\`
$(cat /tmp/migration_output.txt | tail -10)
\`\`\`

No action needed from Claudia."

  gh issue close "$ISSUE_NUMBER" --repo "$REPO"
else
  echo "ERROR: Migration apply failed"
  cat /tmp/migration_output.txt

  gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
    --body "❌ **Migration apply failed** even though checklist passed.
Error:
\`\`\`
$(cat /tmp/migration_output.txt | tail -20)
\`\`\`
Needs manual investigation — adding escalated label."

  gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-label "escalated"
fi
```

## Step 3B — DANGEROUS or MIXED: one yes/no question for Claudia

For dangerous migrations, reduce Claudia's decision to the absolute minimum:

```bash
echo "=== DANGEROUS MIGRATION — requesting Claudia approval ==="

# Extract what's dangerous
DANGEROUS_LINES=$(grep -iE "DROP|DELETE|UPDATE|TRUNCATE|ALTER COLUMN" "$MIGRATION_FILE" | head -5)

# Build the simplest possible approval question
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" \
  --body "⚠️ **Migration approval needed — reply YES or NO**

**Migration:** \`$(basename $MIGRATION_FILE)\`
**Dangerous operations found:**
\`\`\`sql
$DANGEROUS_LINES
\`\`\`

**Risk:** $(python3 -c "
lines = open('$MIGRATION_FILE').read().upper()
if 'DROP COLUMN' in lines: print('Column will be deleted permanently — any data in it is lost')
elif 'DROP TABLE' in lines: print('Table and all its data will be permanently deleted')
elif 'ALTER COLUMN' in lines or 'ALTER COLUMN.*TYPE' in lines: print('Column type change — existing data will be cast, may fail or truncate')
elif 'UPDATE' in lines: print('Existing rows will be modified — irreversible without a backup')
elif 'DELETE' in lines: print('Rows will be permanently deleted')
else: print('Review carefully before applying')
")

**Reply \`YES\` to apply now or \`NO\` to abort.**
*(All other context already reviewed by migration-specialist 5-step checklist — this is the only decision.)*"

gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-label "claudia-decision"
echo "⏸ Waiting for Claudia YES/NO on issue #$ISSUE_NUMBER"
```

A GHA workflow (`claudia-decision-listener.yml`) watches `claudia-decision` issues. When Claudia replies:
- `YES` → migration-auto-approver re-runs and applies (skipping Step 3B)
- `NO` → migration is aborted, issue closed with "migration rejected by Claudia"

## Step 4 — MIXED: separate and apply safe parts

For MIXED (some safe, some dangerous statements in the same migration):

```bash
echo "=== MIXED MIGRATION — splitting safe and dangerous parts ==="
# Split the SQL into individual statements
# Apply SAFE statements immediately
# Hold DANGEROUS statements for YES/NO approval
# Comment explaining what was applied and what's waiting
```

## Classification table

| SQL Operation | Classification | Auto-apply? |
|---|---|---|
| `ADD COLUMN ... DEFAULT NULL` | SAFE | ✅ Yes |
| `ADD COLUMN ... NOT NULL DEFAULT 'x'` | SAFE | ✅ Yes |
| `ADD COLUMN ... NOT NULL` (no default) | DANGEROUS | ❌ Need YES |
| `CREATE INDEX` | SAFE | ✅ Yes |
| `CREATE UNIQUE INDEX` | SAFE | ✅ Yes |
| `CREATE TABLE` | SAFE | ✅ Yes |
| `CREATE TRIGGER / FUNCTION / TYPE` | SAFE | ✅ Yes |
| `CREATE POLICY` (RLS) | SAFE | ✅ Yes |
| `DROP COLUMN` | DANGEROUS | ❌ Need YES |
| `DROP TABLE` | DANGEROUS | ❌ Need YES |
| `ALTER COLUMN ... TYPE` | DANGEROUS | ❌ Need YES |
| `UPDATE ... WHERE` | DANGEROUS | ❌ Need YES |
| `DELETE FROM` | DANGEROUS | ❌ Need YES |
| `TRUNCATE` | DANGEROUS | ❌ Need YES |

## Hard rules

- **NEVER apply without checklist ALL_PASS** — migration-specialist must have run first
- **NEVER apply DANGEROUS migration without YES** — not even "obvious" ones
- **Always comment on the GitHub issue** with what was applied or what needs approval
- **SAFE = zero risk of data loss** — if there's any doubt, classify as DANGEROUS
- **Mixed migrations** → split and apply safe parts first, hold dangerous for YES
- **After applying** → run a quick sanity check: `SELECT count(*) FROM [affected_table]`
- **YES/NO expires in 7 days** → if no reply in 7 days, close as "timed out — migration deferred"
