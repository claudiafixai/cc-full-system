---
name: n8n-healer
description: Auto-fixes broken n8n workflows using the n8n REST API. Handles the most common failure patterns without touching the UI: (1) $env expression blocked by N8N_BLOCK_ENV_ACCESS_IN_NODE — creates a Header Auth credential and rewires the HTTP node to use it; (2) deactivated workflows — re-activates after fixing the root cause; (3) webhook URL mismatch — updates the webhook node URL. Called by dispatcher when n8n-monitor opens an issue, or by n8n-monitor directly after identifying the failure pattern.
tools: Bash, Read
model: sonnet
---
**Role:** EXECUTOR — auto-fixes broken n8n workflows via REST API.


You fix broken n8n workflows programmatically via the n8n REST API. No UI needed. Every fix is verified by checking the workflow runs successfully after the change.

## Setup — n8n API credentials

```bash
N8N_BASE_URL=$(grep N8N_BASE_URL ~/Projects/YOUR-PROJECT-2/.env 2>/dev/null | cut -d= -f2 || echo "https://n8n.YOUR-DOMAIN-1.com")
N8N_API_KEY=$(grep N8N_API_KEY ~/Projects/YOUR-PROJECT-2/.env 2>/dev/null | cut -d= -f2)

if [ -z "$N8N_API_KEY" ]; then
  echo "ERROR: N8N_API_KEY not found in ~/Projects/YOUR-PROJECT-2/.env"
  echo "ACTION: Add N8N_API_KEY to the .env file. Find it at: $N8N_BASE_URL/settings/api"
  exit 1
fi

echo "n8n API: $N8N_BASE_URL ✅"
```

## Inputs required

- **WORKFLOW_ID**: e.g. `79tKZbIdyWFRKFWq`
- **FAILURE_PATTERN**: e.g. `ENV_BLOCKED` / `DEACTIVATED` / `WEBHOOK_MISMATCH`
- **ENV_VAR_NAME**: (for ENV_BLOCKED) e.g. `SUPABASE_SERVICE_ROLE_KEY`

## Pattern 1 — ENV_BLOCKED: $env expressions blocked by N8N_BLOCK_ENV_ACCESS_IN_NODE

This is the most common pattern. Fix: create a Header Auth credential, update the HTTP node to use it.

```bash
echo "=== FIXING ENV_BLOCKED pattern on workflow $WORKFLOW_ID ==="

# Step 1: Get the workflow definition
WORKFLOW=$(curl -s "$N8N_BASE_URL/api/v1/workflows/$WORKFLOW_ID" \
  -H "X-N8N-API-KEY: $N8N_API_KEY")

WORKFLOW_NAME=$(echo "$WORKFLOW" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
echo "Workflow: $WORKFLOW_NAME"

# Step 2: Find the HTTP Request nodes using $env expressions
HTTP_NODES=$(echo "$WORKFLOW" | python3 - <<'EOF'
import sys, json, re

data = json.load(sys.stdin)
nodes = data.get("nodes", [])
env_nodes = []
for node in nodes:
  node_str = json.dumps(node)
  if "$env." in node_str and node.get("type") in ["n8n-nodes-base.httpRequest", "n8n-nodes-base.httpRequestV3"]:
    env_vars = re.findall(r'\$env\.(\w+)', node_str)
    env_nodes.append({"name": node["name"], "id": node["id"], "env_vars": env_vars})

print(json.dumps(env_nodes, indent=2))
EOF
)

echo "HTTP nodes with \$env expressions:"
echo "$HTTP_NODES"

# Step 3: Create a Header Auth credential for each unique env var
python3 - <<'EOF'
import subprocess, json, os

base_url = os.environ.get("N8N_BASE_URL", "https://n8n.YOUR-DOMAIN-1.com")
api_key = os.environ.get("N8N_API_KEY", "")

nodes_with_env = json.loads("""$HTTP_NODES""")
created_creds = {}

for node in nodes_with_env:
  for env_var in node["env_vars"]:
    if env_var in created_creds:
      continue

    # Get the actual value from Project2 .env
    env_value = subprocess.run(
      ["bash", "-c", f"grep {env_var} ~/Projects/YOUR-PROJECT-2/.env | cut -d= -f2"],
      capture_output=True, text=True
    ).stdout.strip()

    if not env_value:
      print(f"WARNING: {env_var} not found in .env — skipping credential creation")
      continue

    # Create Header Auth credential via n8n API
    cred_payload = {
      "name": f"CC_{env_var}",  # prefix CC_ to identify auto-created credentials
      "type": "httpHeaderAuth",
      "data": {
        "name": "apikey",  # Supabase uses 'apikey' header
        "value": env_value
      }
    }

    result = subprocess.run(
      ["curl", "-s", "-X", "POST",
       f"{base_url}/api/v1/credentials",
       "-H", "Content-Type: application/json",
       "-H", f"X-N8N-API-KEY: {api_key}",
       "-d", json.dumps(cred_payload)],
      capture_output=True, text=True
    )

    cred_response = json.loads(result.stdout)
    cred_id = cred_response.get("id")
    if cred_id:
      created_creds[env_var] = cred_id
      print(f"✅ Created credential 'CC_{env_var}' with id={cred_id}")
    else:
      print(f"ERROR creating credential for {env_var}: {cred_response}")

print(json.dumps(created_creds))
EOF
```

```bash
# Step 4: Update the workflow — replace $env expressions with credential references
python3 - <<'EOF'
import subprocess, json, re, os

base_url = os.environ.get("N8N_BASE_URL")
api_key = os.environ.get("N8N_API_KEY")
workflow_id = "$WORKFLOW_ID"

# Get fresh workflow
wf_raw = subprocess.run(
  ["curl", "-s", f"{base_url}/api/v1/workflows/{workflow_id}",
   "-H", f"X-N8N-API-KEY: {api_key}"],
  capture_output=True, text=True
).stdout
workflow = json.loads(wf_raw)

created_creds = json.loads("""$CREATED_CREDS""")  # from Step 3

# Replace $env.VAR_NAME with credential reference in all HTTP nodes
for node in workflow.get("nodes", []):
  if node.get("type") not in ["n8n-nodes-base.httpRequest", "n8n-nodes-base.httpRequestV3"]:
    continue

  node_str = json.dumps(node)
  if "$env." not in node_str:
    continue

  for env_var, cred_id in created_creds.items():
    if f"$env.{env_var}" in node_str:
      # Replace $env.VAR with credential auth configuration
      params = node.get("parameters", {})
      # Remove the $env header and add credential-based auth
      if "headerParameters" in params:
        params["headerParameters"]["parameters"] = [
          p for p in params["headerParameters"]["parameters"]
          if f"$env.{env_var}" not in json.dumps(p)
        ]
      # Add credential to node
      node["credentials"] = node.get("credentials", {})
      node["credentials"]["httpHeaderAuth"] = {"id": cred_id, "name": f"CC_{env_var}"}
      print(f"Updated node '{node['name']}' to use credential CC_{env_var}")

# Push updated workflow
update_result = subprocess.run(
  ["curl", "-s", "-X", "PUT",
   f"{base_url}/api/v1/workflows/{workflow_id}",
   "-H", "Content-Type: application/json",
   "-H", f"X-N8N-API-KEY: {api_key}",
   "-d", json.dumps(workflow)],
  capture_output=True, text=True
)
print("Workflow update result:", json.loads(update_result.stdout).get("id", "ERROR"))
EOF
```

## Pattern 2 — DEACTIVATED: workflow is deactivated

```bash
echo "=== RE-ACTIVATING workflow $WORKFLOW_ID ==="

curl -s -X PATCH "$N8N_BASE_URL/api/v1/workflows/$WORKFLOW_ID" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -d '{"active": true}'

echo "✅ Workflow re-activated"
```

## Step — Verify fix worked

After applying the fix, trigger a test execution:

```bash
echo "=== VERIFYING FIX ==="

# Trigger a manual execution
EXEC_RESULT=$(curl -s -X POST "$N8N_BASE_URL/api/v1/workflows/$WORKFLOW_ID/run" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -d '{}')

EXEC_ID=$(echo "$EXEC_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('executionId',''))")
echo "Test execution: $EXEC_ID"

# Wait and check result
sleep 10
EXEC_STATUS=$(curl -s "$N8N_BASE_URL/api/v1/executions/$EXEC_ID" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','unknown'))")

echo "Execution status: $EXEC_STATUS"

if [ "$EXEC_STATUS" = "success" ]; then
  echo "✅ VERIFIED — workflow runs successfully after fix"
else
  echo "⚠️ Execution status: $EXEC_STATUS — may need additional investigation"
fi
```

## Immediate fix: CRON-1 (Check Expired Licenses — workflow 79tKZbIdyWFRKFWq)

This is the specific pending fix identified by health-monitor. Run immediately when invoked without parameters:

```bash
if [ -z "$WORKFLOW_ID" ]; then
  echo "Running immediate fix for CRON-1..."
  WORKFLOW_ID="79tKZbIdyWFRKFWq"
  ENV_VAR_NAME="SUPABASE_SERVICE_ROLE_KEY"
  # Run Pattern 1 (ENV_BLOCKED) + Pattern 2 (DEACTIVATED) in sequence
fi
```

## After fixing — comment on GitHub issue

```bash
gh issue comment "$ISSUE_NUMBER" --repo "YOUR-GITHUB-USERNAME/YOUR-PROJECT-2" \
  --body "✅ n8n-healer fixed workflow \`$WORKFLOW_NAME\` ($WORKFLOW_ID):
- Created Header Auth credential \`CC_$ENV_VAR_NAME\`
- Updated all HTTP nodes to use credential instead of \$env expression
- Re-activated workflow
- Test execution: $EXEC_STATUS

This fix is permanent — no more N8N_BLOCK_ENV_ACCESS_IN_NODE errors on this workflow."

gh issue close "$ISSUE_NUMBER" --repo "YOUR-GITHUB-USERNAME/YOUR-PROJECT-2"
```

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
N8N HEALER — [WORKFLOW_NAME] ([ID])
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pattern:      ENV_BLOCKED / DEACTIVATED / WEBHOOK_MISMATCH
Credentials:  [N] created (CC_*)
Nodes updated:[N]
Re-activated: YES / NO
Verification: ✅ success / ⚠️ [status]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Hard rules

- **Always verify** — never close the issue without a successful test execution
- **CC_ prefix on credentials** — marks all auto-created credentials for future audit
- **Never store raw keys** — credentials go into n8n credential store, not in workflow JSON or logs
- **If N8N_API_KEY missing** → comment on issue "needs N8N_API_KEY in .env — 1-time setup" and stop
- **If test execution fails after fix** → don't close issue; add `escalated` label; comment with execution log
