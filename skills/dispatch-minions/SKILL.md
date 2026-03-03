---
name: dispatch-minions
description: Spawn parallel minion agents in worktrees to execute decomposed tasks
allowed-tools: Read, Write, Agent, Bash
disable-model-invocation: true
---

# Dispatch Minions

Orchestrate parallel minion agents to execute the task manifest.

## Process

### 1. Find the manifest

Look in `~/.claude/minions/manifests/` for the most recent manifest matching the current project (match by `project_dir` or project name). If ambiguous, ask the user which feature to dispatch.

### 2. Validate the manifest

Before doing anything else, verify:
- All `context_files` entries exist on disk. Remove any that don't (the minion would waste time on a missing file read).
- All `depends_on` references point to valid task IDs in the manifest.
- The `project_dir` exists.

If validation fails, report the issues and abort. Do NOT proceed to dispatch.

### 3. Create the feature branch

```bash
git checkout -b <manifest.branch> <manifest.base>
```

If it already exists, check it out.

### 4. Filter tasks

Only dispatch `auto` and `notify` tiers. Skip `skip` tier entirely.

### 5. Resolve dependency waves

- Wave 1: tasks with empty `depends_on`
- Wave 2: tasks whose `depends_on` are all in Wave 1
- Wave N: tasks whose `depends_on` are all in Waves 1..N-1

### 6. Write test stubs

For each task with a non-null `test_stub` field, write the stub file to the project before spawning agents. The minion's worktree will include this file:

```bash
mkdir -p <project_dir>/<test_file_dir>
# write test_stub content to <project_dir>/<test_file_path>
```

This happens BEFORE any agents are spawned so the stubs are present in every worktree.

### 7. Dispatch each wave in parallel

**CRITICAL**: All tasks in a wave MUST be dispatched in a **single message** with multiple Agent tool calls. Do NOT dispatch tasks sequentially — send them all at once so they run truly in parallel.

For each task in the wave, spawn an Agent call with:
- `isolation: "worktree"` — each task gets its own isolated git worktree
- `model:` from the task's `model` field (`"haiku"` or `"sonnet"`)
- Prompt: content of [minion-prompt.md](minion-prompt.md), then a **PROJECT CONFIG** block, then the task's `prompt` field

The PROJECT CONFIG block must be prepended to every minion prompt:
```
PROJECT CONFIG:
- Package manager: <detected pm>
- Test framework: <manifest.test_framework>
- Test command: <manifest.test_run_cmd>  (replace {file} with your test file path)
```

- If `context_files` remain after validation, append: `"Read these files for context: <path> (look for: <hint>)"` for each

Wait for all agents in the wave to complete before dispatching the next wave.

### 8. Parse results

Each agent ends with `DONE: <status> | files: <list>`. Parse this line for status tracking.

### 9. Display progress

After each wave completes:
```
Wave 1: fd-01 ✓ | fd-02 ✓ | fd-03 ✗ (lint failed after 2 attempts)
Wave 2: fd-04 ✓ | fd-05 ✓ | fd-06 — skipped (dep fd-03 failed)
```

### 10. Final summary

```
Dispatch complete: 8/10 tasks succeeded, 1 failed, 1 skipped
Failed:  fd-03 — use /retry-minion fd-03 "your guidance"
Skipped: fd-06 (depends on fd-03)
Ready for: /review-minions
```

## Rules

- If a task's dependency failed, skip that task and mark it `skipped (dep failed)`.
- Do NOT merge anything — that's `/review-minions`' job.
- Keep worktrees alive after dispatch for review.
- Do NOT retry failures automatically — report them and let the user decide.
