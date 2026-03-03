---
name: review-minions
description: Review minion results and merge successful tasks into the feature branch
allowed-tools: Read, Bash, Glob
---

# Review Minions

Review completed minion work and merge into the feature branch.

## Process

### 1. Find manifest

Look in `~/.claude/minions/manifests/` for the most recent manifest for this project.

### 2. List worktrees

Run `git worktree list` and match minion worktrees to task IDs by branch name (`minion/<task-id>`).

### 3. Show results with inline diffs

For each dispatched task, show a compact summary **with diff stat inline** — the user sees what changed before being asked to approve:

```
fd-01 ✓ dashboard-types-atoms
      dashboard.types.ts (+28)  dashboard.atoms.ts (+12)  dashboard.types.test.ts (+31)

fd-02 ✓ fleet-summary-api
      use-fleet-summary.ts (+45)  use-fleet-summary.test.ts (+67)

fd-03 ✗ activity-feed-hook
      Error: Type 'string' is not assignable to type 'VehicleStatus'
      src/features/dashboard/hooks/use-activity-feed.ts:14
```

Run `git diff --stat <feature-branch>...<minion-branch>` for each successful task to get the file change stats.

### 4. Ask user to confirm merge

Present options:
- **Approve all** — merge all successful tasks
- **Approve selective** — user lists which task IDs to include/exclude
- **Show full diff** for a specific task: `git diff <feature-branch>...<minion-branch> -- <file>` (show inline, not just stat)

### 5. Merge approved tasks

```bash
git checkout <feature-branch>
git merge --no-ff <minion/task-id> -m "minion: <task-name>"
```

If merge conflict: report the conflicting files, do NOT auto-resolve. Let the user decide whether to skip or resolve manually.

### 6. Clean up merged worktrees

```bash
git worktree remove <path>
git branch -d minion/<task-id>
```

Only clean up after successful merge. Leave failed/excluded task worktrees intact for inspection.

### 7. Final report

```
Merged 8/10 tasks into feature/fleet-dashboard
  ✓ fd-01 dashboard-types-atoms
  ✓ fd-02 fleet-summary-api
  ✗ fd-03 activity-feed-hook (failed — worktree preserved at .claude/worktrees/minion-fd-03)
  — fd-10 dashboard-page (skip — visual task)

Next steps:
  - Retry failed: /retry-minion fd-03 "fix VehicleStatus import"
  - Visual tasks to build interactively: dashboard-page (src/features/dashboard/DashboardPage.tsx)
  - Test the feature: <pm> run dev
  - When ready: git checkout main && git merge --no-ff feature/fleet-dashboard
```
