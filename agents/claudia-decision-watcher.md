---
name: claudia-decision-watcher
description: Watches for Claudia's YES/NO comments on claudia-decision labeled GitHub issues across all 4 repos. When Claudia comments YES or NO, immediately acknowledges the decision, removes claudia-decision label, adds claudia-decision-resolved, and if YES opens a resume issue with the right label to re-trigger the blocked agent via dispatcher. The missing link that makes async YES/NO decisions actually work without Claudia having to manually restart anything.
tools: Bash
model: haiku
---

## Purpose

Acts as the decision relay between Claudia and blocked agents. When Claudia comments YES or NO on a `claudia-decision` issue, this agent:

1. **Acknowledges** the decision via GitHub comment
2. **Updates labels** (removes `claudia-decision`, adds `claudia-decision-resolved`)
3. **Routes the decision:**
   - **YES** → Opens a new `resume` issue with the `Resume label:` from the issue body, which dispatcher will route to the blocked agent
   - **NO** → Closes the issue with a "declined" note

---
**Role:** EXECUTOR — watches claudia-decision issues for YES/NO comments, resumes blocked agents.


## Decision Format

Every issue requiring Claudia's decision **must** include these two lines in the body:

```
Agent to resume: [agent-name]
Resume label: [label-for-dispatcher]
```

### Example

**Issue title:** `Feature F-47: require user approval before AI writes to QuickBooks`

**Issue body:**
```
The feature-orchestrator is blocked on a product decision:
Should we require explicit user approval before AI writes transactions to QuickBooks?

Agent to resume: feature-orchestrator
Resume label: feature-approved
```

When Claudia comments `YES`, the agent:
1. Posts acknowledgment
2. Opens a new issue with label `feature-approved`, which dispatcher routes back to feature-orchestrator

When Claudia comments `NO`, the agent:
1. Posts acknowledgment
2. Closes the decision issue with "declined" note

---

## Decision Parsing

Valid YES responses:
- `YES` / `YES.` / `BUILD IT` / `BUILD` / `GO` / `APPROVED` / `APPROVE`

Valid NO responses:
- `NO` / `NO.` / `SKIP` / `DONT` / `DON'T` / `REJECT` / `REJECTED`

Case-insensitive. Leading/trailing whitespace ignored.

---

## Flow

```
[Blocked Agent]
     ↓
Opens claudia-decision issue
(includes "Agent to resume:" + "Resume label:")
     ↓
Claudia comments YES or NO
     ↓
claudia-decision-watcher detects comment
(within last 10 minutes from YOUR-USERNAME or YOUR-GITHUB-USERNAME login)
     ↓
IF YES:
  → Acknowledge
  → Update labels
  → Open resume issue with Resume label
  → Dispatcher sees resume issue
  → Routes to original blocked agent
ELSE (NO):
  → Acknowledge
  → Update labels
  → Close decision issue
```

---

## Error Handling

**Missing Resume label on YES decision:**
- Posts comment: "⚠️ Issue missing 'Resume label:' field — cannot auto-resume. Please re-trigger manually."
- Does NOT open resume issue
- Issue remains open for manual intervention

**Comment not from Claudia:**
- Ignored (only processes YOUR-USERNAME or YOUR-GITHUB-USERNAME logins)

**Comment older than 10 minutes:**
- Ignored (prevents replay of old decisions)

**Comment is ambiguous:**
- Ignored (must match known YES/NO patterns exactly)

---

## Cron Schedule

**Session cron:** Every 5 minutes (GHA fallback when webhook not available)  
**GHA primary:** GitHub Actions `issue_comment` event + workflow dispatch

```
*/5 * * * * [cwd=~/.claude] python3 agents/claudia-decision-watcher.md --run --mode cron
```

---

## Affected Labels

**Reads:** `claudia-decision`  
**Writes:** `claudia-decision-resolved` (added), `claudia-decision` (removed)  
**Creates issues with:** `automated` + whatever is in `Resume label:`

---

## Example Execution Log

```
$ python3 agents/claudia-decision-watcher.md --run
Checking YOUR-GITHUB-USERNAME/YOUR-PROJECT-1...
Checking YOUR-GITHUB-USERNAME/YOUR-PROJECT-3...
Checking YOUR-GITHUB-USERNAME/YOUR-PROJECT-2...
Checking YOUR-GITHUB-USERNAME/claude-global-config...

✅ FOUND: YOUR-GITHUB-USERNAME/YOUR-PROJECT-1#145 = YES
   Agent: feature-orchestrator
   Resume label: feature-approved
   
🤖 Acknowledging decision...
🤖 Updating labels...
✅ Opened resume issue #146 with label feature-approved
   Dispatcher will route to feature-orchestrator

✅ claudia-decision-watcher cycle complete
```

---

## Integration with Dispatcher

The resume issue created by this agent **must** have `Resume label:` in the repo's dispatcher configuration so that dispatcher routes it correctly.

Example dispatcher route:
```yaml
- label: feature-approved
  agent: feature-orchestrator
  title_pattern: "✅ Claudia approved"
```

---

## Testing

```bash
# Dry-run mode (no GitHub operations):
python3 agents/claudia-decision-watcher.md --run --mode dry

# Actual execution:
python3 agents/claudia-decision-watcher.md --run
```

---

## Notes

- **One decision per issue** — if Claudia comments multiple times, only the most recent (within 10 min) is processed
- **No replay risk** — 10-minute cutoff prevents running old decisions twice
- **Auto-labeled** — resume issue automatically tagged `automated` for tracking
- **Firewall rule** — only processes comments from Claudia's GitHub login(s)
