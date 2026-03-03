---
name: retry-minion
description: Re-run a failed minion task with additional context and guidance
argument-hint: [task-id] [guidance]
allowed-tools: Read, Write, Agent, Bash
---

# Retry Minion

Re-run a failed minion task with user-provided guidance.

## Process

1. **Parse arguments**: `$ARGUMENTS[0]` = task ID, rest = additional guidance from user.

2. **Find manifest**: Look in `~/.claude/minions/manifests/` for the manifest containing this task ID.

3. **Read original task** from manifest (prompt, model, context_files, test_stub, test_files).

4. **Re-write test stub** (if present): Write the `test_stub` content back to the test file path before spawning the agent. The previous attempt may have modified or broken the stub — restore it to the original.

5. **Get error context** from the conversation history (the previous failure report). Truncate to 20 lines max.

6. **Spawn Agent** with:
   - `isolation: "worktree"`
   - `model:` from the task's model field
   - Prompt: minion-prompt template + original task prompt + additional section:
     ```
     PREVIOUS ATTEMPT FAILED. Error context (truncated to 20 lines):
     <error lines>

     Additional guidance from reviewer:
     <user's guidance>
     ```

7. **Report result** in the same format as dispatch-minions.
