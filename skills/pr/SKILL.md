---
name: pr
description: Fix all open PR review threads (BugBot + CodeRabbit), reply inline to every thread, resolve them, and enable auto-merge. Pass a PR number or it will find the most recent open PR. Examples: /pr 114, /pr YOUR-PROJECT-1 114, /pr
---

You are fixing a PR. Run the full review loop.

## How to use

- `/pr` — finds the most recent open PR across all repos
- `/pr 114` — targets PR #114 in the most likely repo (YOUR-PROJECT-1 if in that dir)
- `/pr YOUR-PROJECT-1 114` — targets YOUR-PROJECT-1 PR #114
- `/pr YOUR-PROJECT-2 23` — targets YOUR-PROJECT-2 PR #23
- `/pr YOUR-PROJECT-3 45` — targets YOUR-PROJECT-3 PR #45

## What this does

Run the pr-review-loop agent for the specified PR:

```
Run pr-review-loop for [repo] PR#[N].

The loop must:
1. Read all unresolved inline BugBot threads via GraphQL reviewThreads
2. Read all unresolved CodeRabbit threads via GraphQL reviewThreads
3. For BugBot: verify each finding still exists in HEAD (GT-BUGBOT-03) before fixing
4. Fix real bugs. Reply to stale/false-positive findings with evidence.
5. Reply to each inline thread using the CORRECT endpoint:
   POST /repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments with -F in_reply_to={COMMENT_ID}
   NOT /pulls/comments/{id}/replies (404) · NOT -f in_reply_to= string (422)
6. Resolve all threads via GraphQL resolveReviewThread
7. Verify zero unresolved threads remain
8. Enable auto-merge if CI is green
```

## After threads resolved — start pr-watch

Once zero unresolved threads are confirmed AND CI is green, immediately create a pr-watch cron:

```
CronCreate cron="*/5 * * * *" prompt="Run pr-watch agent for [repo] PR#[N]" recurring=true
```

Tell Claudia: "✅ PR#[N] clean — pr-watch started (job ID: [id]). You'll be notified when it merges."

This cron auto-stops when the PR merges (pr-watch detects merged state and reports back).

## If no PR number given

```bash
# Find most recent open PR across all repos
gh pr list --repo YOUR-GITHUB-USERNAME/YOUR-PROJECT-1 --state open --json number,title --limit 1
gh pr list --repo YOUR-GITHUB-USERNAME/YOUR-PROJECT-2 --state open --json number,title --limit 1
gh pr list --repo YOUR-GITHUB-USERNAME/YOUR-PROJECT-3 --state open --json number,title --limit 1
```

Pick the most recent one and confirm with Claudia before proceeding.
