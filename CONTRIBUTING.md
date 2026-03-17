# Contributing to CC Full System

This system gets better when more people use it and share what they find.

---

## Ways to contribute

### 1. Submit a new agent
Built an agent that solves a problem not covered here? Submit it.

**Requirements:**
- Works with Claude Code (has proper frontmatter)
- Solves a real problem you had
- No hardcoded personal info (use placeholders like `YOUR-PROJECT-1`)
- Includes a comment at the top explaining what it does and when to use it

**How:**
1. Fork this repo
2. Add your agent to `agents/` or `project-template/.claude/agents/`
3. Open a PR with title: `Agent: [agent-name] — [one line description]`
4. Describe what problem it solves in the PR description

---

### 2. Improve an existing agent
Found an agent that doesn't work right, misses a case, or could be smarter?

**How:**
1. Fork this repo
2. Edit the agent file
3. Open a PR with title: `Fix: [agent-name] — [what you fixed]`
4. Describe what was wrong and what you changed

---

### 3. Report a broken agent
Something doesn't work? Open an issue.

**Include:**
- Which agent
- What you expected it to do
- What it actually did
- Your stack (Vercel? Supabase? n8n?)

---

### 4. Share your stack-specific agents
Built agents for a specific stack (Django, Railway, PlanetScale, Firebase)?
Open a PR adding a `stack-templates/` folder with your setup.

---

## PR rules

- One agent per PR (easier to review)
- No personal info in agent files
- Test it yourself before submitting — at minimum run it once
- Keep descriptions plain English — this project is built for non-technical founders too

---

## What gets merged

- Agents that solve real problems
- Fixes with clear explanations
- Stack-specific templates for popular tools
- Improvements that make setup easier

---

## Questions?

Open an issue or start a Discussion. I respond personally.

---

*Every contribution makes the system better for everyone using it.*
