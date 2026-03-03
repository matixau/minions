# Minions

Agentic workflow system for Claude Code that orchestrates parallel coding agents using git worktrees. Inspired by [Stripe's Minions architecture](https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents).

## How It Works

Minions adds 5 skills (slash commands) to Claude Code that turn a single interactive session into a parallel development pipeline. You plan a feature, break it into atomic tasks, dispatch headless agents to build them simultaneously in isolated git worktrees, then merge the results into a feature branch.

```
/plan-feature → /decompose → /dispatch-minions → /review-minions → merge to main
 (interactive)   (interactive)   (parallel agents)   (interactive)     (manual)
```

## Installation

```bash
git clone https://github.com/z89/minions.git ~/Documents/Github-Projects/minions
cd ~/Documents/Github-Projects/minions
chmod +x install.sh
./install.sh
```

This symlinks all skills to `~/.claude/skills/`. Restart Claude Code to pick them up.

### Verify

Type `/` in any Claude Code session and you should see: `plan-feature`, `decompose`, `dispatch-minions`, `retry-minion`, `review-minions`.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) VSCode extension or CLI
- Git
- A project with a `package.json` and lint/typecheck/test scripts
- A `CLAUDE.md` in your project root (minion agents read this for conventions)

## Workflow

### 1. Plan a Feature

```
/plan-feature development a settings page with user profile editing and notification preferences. Ask me important implementation questions
```

Opens an interactive planning session. Claude will:
- Read your project's CLAUDE.md and explore existing feature patterns
- Ask clarifying questions about scope
- Suggest best practices and use cases you may have missed
- Output a structured feature spec splitting work into **Visual** (needs live preview) and **Non-visual** (can be built headless by agents)

The plan stays in conversation context and feeds into the next step.

### 2. Decompose into Tasks

```
/decompose
```

Takes the feature plan and breaks it into atomic tasks for parallel agents. Each task:
- Touches 1-3 files
- Has one clear outcome
- Is independently implementable
- Is verifiable by lint + typecheck + tests

For complex tasks (hooks, API functions), the decomposer writes **test stubs**: pre-defined `describe`/`it` blocks with comment annotations specifying expected behavior. These are written to the worktree before the minion starts, so the minion can't lower the success bar by writing weak tests. See [Red/Green TDD Approach](#tdd-approach) below.

Outputs a task manifest to `~/.claude/minions/manifests/<project>/<feature>.json` and shows a summary table:

```
| ID    | Name                  | Tier   | Model  | Deps    | Files | Tests  |
|-------|-----------------------|--------|--------|---------|-------|--------|
| sp-01 | settings-types-atoms  | auto   | haiku  | none    | 2     | minion |
| sp-02 | user-profile-hook     | auto   | sonnet | sp-01   | 2     | stub   |
| sp-03 | settings-page         | skip   | -      | sp-01,02| 1     | -      |
```

`Tests` column: `stub` = decomposer wrote test stubs (red/green TDD), `minion` = minion writes freely, `-` = skipped.

You review and adjust before proceeding, by moving tasks between tiers, merging small tasks, or splitting larger ones.

### 3. Dispatch Minions

```
/dispatch-minions
```

Before spawning any agents, it validates the manifest:
- Verifies all `context_files` exist on disk (removes stale references instead of letting agents fail mid-execution)
- Checks all `depends_on` references are valid task IDs

Then creates the feature branch and spawns agents in parallel git worktrees. Tasks execute in dependency waves:
- **Wave 1**: Tasks with no dependencies (types, atoms, constants)
- **Wave 2**: Tasks depending on Wave 1 (hooks, API functions)
- **Wave N**: Remaining tasks in dependency order

All tasks in a wave are dispatched **simultaneously** in a single message. This is true parallel isolated execution, not sequential.

Each agent: implements, fills test stubs (or writes own tests), lints, typechecks, runs tests, and reports back.

Progress displays in your session:
```
Wave 1: sp-01 ✓ | sp-02 ✓
Wave 2: sp-04 ✓ | sp-05 ✓ | sp-03 ✗ (lint failed after 2 attempts)
```

You can continue working in a separate Claude Code session while minions run.

### 4. Retry Failed Tasks

```
/retry-minion sp-03 "install zod first, then implement the validation schema"
```

Re-runs a failed task with your additional context. The agent gets the original task prompt plus your guidance and the previous error output (truncated to 20 lines). If a test stub was part of the original task, it's restored to the original before retrying, preventing a previous failed attempt from corrupting the test contract.

### 5. Review and Merge

```
/review-minions
```

Shows each completed task's diff stats **inline** before asking to approve, so you see what changed before committing to merge:

```
sp-01 ✓ settings-types-atoms
      settings.types.ts (+28)  settings.atoms.ts (+12)  settings.types.test.ts (+31)

sp-02 ✓ user-profile-hook
      use-user-profile.ts (+45)  use-user-profile.test.ts (+67)

sp-03 ✗ notification-prefs-hook
      Error: Type 'string' is not assignable to type 'NotificationChannel'
```

You can approve all, exclude specific tasks, or request a full file diff for any task before deciding. Merges approved tasks into the feature branch with `--no-ff`, cleans up worktrees, and lists remaining visual tasks for interactive work.

### 6. Ship

Test the feature branch manually (`pnpm dev`), then merge to main when satisfied.

## TDD Approach

Minions uses a split test strategy based on task complexity:

| Model  | Test approach         | Rationale                                              |
|--------|-----------------------|--------------------------------------------------------|
| haiku  | Minion writes freely  | Formulaic tasks: type guards, simple utils, atoms      |
| sonnet | Decomposer writes stub| Complex logic: decomposer sets the success bar         |

### Why This Matters

With "write tests after" (the naive approach), the minion decides what constitutes passing. A minion can write weak tests that are trivially easy to pass while missing the actual intent.

With **test stubs**, the decomposer (which has full feature context from the planning session) defines the success criteria. The minion fills in the assertions and implements code to make them pass. It cannot lower the bar.

### Project Test Framework

Minions uses the **project's own test framework**, not an independent one. The decomposer detects this before writing any stubs:

1. Reads `package.json` devDependencies to identify the framework (Vitest, Jest, Mocha, etc.)
2. Reads an existing test file to extract the import style and mock API in use
3. Writes all stubs using the project's conventions, stored with `test_framework` and `test_run_cmd` in the manifest

The `test_run_cmd` is passed to every minion so it uses the correct command to run its specific test file (e.g., `pnpm run test -- --run {file}` for Vitest vs `npx jest --testPathPattern {file}` for Jest).

### Stub Format

Stubs mirror the project's existing test style. Example for a Vitest project:

```typescript
// @ts-nocheck — stub: fill in assertions, do not rename tests
import { describe, it, expect, vi } from 'vitest'

describe('useUserProfile', () => {
  it('returns user profile with correct shape', async () => {
    // IMPLEMENT: mock API response, render hook, assert result.current.data matches UserProfile
    // Expected shape: { id: string, name: string, email: string, avatarUrl: string }
  })

  it('uses 60s stale time', () => {
    // IMPLEMENT: assert staleTime === 60_000 in query config
  })

  it('returns error state on API failure', async () => {
    // IMPLEMENT: mock API to throw, assert result.current.error is set and isLoading is false
  })
})
```

Same stub for a Jest project would use `jest.mock` and Jest globals instead of `vi`. The decomposer adapts to whatever the project uses.

The `// @ts-nocheck` header prevents TypeScript errors before implementation. The minion removes it once types resolve correctly. The `describe`/`it` structure is contractual: the minion fills in the `expect()` calls.

## Task Tiers

| Tier | What | Agent Behavior |
|------|------|----------------|
| `auto` | Pure logic: types, hooks, utils, atoms, API functions | Agent builds + tests autonomously |
| `notify` | Structural: routes, barrel exports, shared files | Agent builds, you review diff before merge |
| `skip` | Visual: UI components, layouts, styling | Not dispatched; you build these interactively |

## Model Selection

Minions automatically assigns the right model to each task to optimize token usage (Claude models only for now):

| Model | Used For | Why |
|-------|----------|-----|
| Haiku | Types, atoms, constants, simple utils, barrel exports | Formulaic tasks: fast, cheap, accurate enough |
| Sonnet | Hooks, API functions, complex business logic | Needs reasoning for correct implementation |

This is set per-task in the manifest and can be overridden during review.

## Manifest Format

Manifests are stored at `~/.claude/minions/manifests/<project>/<feature>.json`:

```json
{
  "feature": "user-settings",
  "description": "User settings page with profile editing and notification preferences",
  "project": "my-app",
  "project_dir": "/home/user/projects/my-app",
  "branch": "feature/user-settings",
  "base": "main",
  "tasks": [
    {
      "id": "sp-01",
      "name": "settings-types-atoms",
      "tier": "auto",
      "model": "haiku",
      "files": ["src/features/settings/settings.types.ts"],
      "depends_on": [],
      "prompt": "Create: src/features/settings/settings.types.ts\n\nTypes:\n- UserProfile { id: string, name: string, email: string }\n- NotificationPrefs { email: boolean, push: boolean }\n\nRelevant types (from src/types/user.ts):\n```ts\nexport type NotificationChannel = 'email' | 'push' | 'sms'\n```",
      "context_files": [],
      "test_files": ["src/features/settings/__tests__/settings.types.test.ts"],
      "test_stub": null
    },
    {
      "id": "sp-02",
      "name": "user-profile-hook",
      "tier": "auto",
      "model": "sonnet",
      "files": ["src/features/settings/hooks/use-user-profile.ts"],
      "depends_on": ["sp-01"],
      "prompt": "Create: src/features/settings/hooks/use-user-profile.ts\n\nTanStack Query hook...",
      "context_files": [
        {"path": "src/features/auth/hooks/use-current-user.ts", "hint": "TanStack Query hook pattern to follow"}
      ],
      "test_files": ["src/features/settings/__tests__/use-user-profile.test.ts"],
      "test_stub": "// @ts-nocheck — stub: fill in assertions, do not rename tests\n..."
    }
  ]
}
```

Key difference from naive approaches: `test_stub` is non-null for `sonnet` tasks. Context snippets are inlined directly in `prompt` rather than requiring the minion to read full files.

## Accuracy Best Practices

These are baked into the skill templates:

1. **Red/green TDD for complex tasks**: Decomposer writes test stubs (the contract); minions fill assertions and implement to pass. Prevents weak auto-generated tests.
2. **Context inlined in prompts**: Decomposer extracts the 5-15 relevant lines from reference files and embeds them in the task prompt. Minions don't read whole files for context.
3. **Manifest validation before dispatch**: All `context_files` verified to exist before any agent spawns. Fail fast on stale references.
4. **True parallel dispatch**: All tasks in a wave dispatched in a single message (not sequentially). Each agent runs in an isolated git worktree.
5. **Self-contained task prompts**: Each minion gets exact file paths, type signatures, and function signatures. No ambiguity.
6. **Scope constraints**: Agents only touch files specified in their task.
7. **Deterministic gates**: lint, typecheck, test run after every implementation.
8. **Capped retries**: Max 2 fix attempts per gate failure. Fail fast, report back.
9. **Truncated error reporting**: Gate failures report first 20 lines + file:line references only. No full lint dumps.
10. **Stub restoration on retry**: Failed task retries restore the original test stub before re-running. A previous bad attempt can't corrupt the test contract.
11. **Diff-first review**: File change stats shown inline before merge confirmation. You see what changed before approving.
12. **Types-first dependency order**: Type definitions complete before anything that imports them.
13. **Project CLAUDE.md**: Agents read your project's conventions file for coding standards.

## Task Sizing Guide

A task is the right size when it passes all of these:

- [ ] Touches 1-3 files
- [ ] Has ONE clear outcome
- [ ] Can be verified by a deterministic gate (lint/types/tests pass)
- [ ] Doesn't depend on another task's output at build time
- [ ] You could explain it in 2-3 sentences
- [ ] No ambiguous design decisions

```
TOO BIG:  "Build the user settings page"
RIGHT:    "Add UserProfile and NotificationPrefs types with type guard"
RIGHT:    "Add useUserProfile TanStack Query hook with 60s stale time"
TOO SMALL: "Add a single type alias" (batch with related types)
```

## Project Structure

```
minions/
├── skills/
│   ├── plan-feature/           # Interactive feature planning
│   │   ├── SKILL.md
│   │   └── plan-template.md
│   ├── decompose/              # Task breakdown → manifest + test stubs
│   │   ├── SKILL.md
│   │   └── manifest-schema.md
│   ├── dispatch-minions/       # Parallel agent orchestration
│   │   ├── SKILL.md
│   │   └── minion-prompt.md
│   ├── retry-minion/           # Re-run failed tasks
│   │   └── SKILL.md
│   └── review-minions/         # Diff-first review + merge
│       └── SKILL.md
├── install.sh                  # Symlinks skills to ~/.claude/skills/
├── CLAUDE.md
├── README.md
└── .gitignore
```

## Updating

Edit skill files directly in the `minions/skills/` directory. Changes take effect on the next Claude Code session (symlinks point to the source files).

```bash
cd ~/Documents/Github-Projects/minions
# edit skills/dispatch-minions/SKILL.md
# restart Claude Code — changes are live
```

## License

MIT
