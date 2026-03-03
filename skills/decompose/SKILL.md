---
name: decompose
description: Break a planned feature into atomic tasks for minion agents
allowed-tools: Read, Write, Glob, Grep
---

# Feature Decomposition

Take the feature plan from this conversation (output of `/plan-feature`) and break it into atomic tasks for parallel minion agents.

## Task Sizing Rules

Each task MUST:
- Touch 1-3 files maximum
- Have ONE clear outcome
- Be independently implementable (no build-time dependency on other tasks' output)
- Be verifiable by deterministic gates (lint + typecheck + tests)

## Decomposition Order

1. **Types/interfaces** first (no dependencies) → `model: "haiku"`
2. **Atoms/constants** (depend on types only) → `model: "haiku"`
3. **Utility functions** (depend on types) → `model: "haiku"` if simple, `"sonnet"` if logic-heavy
4. **API functions** (depend on types) → `model: "sonnet"`
5. **Hooks** (depend on types + maybe atoms/API) → `model: "sonnet"`
6. **Visual components** → `tier: "skip"` (done interactively)
7. **Route files / barrel exports** → `tier: "notify"`

## Batching

Combine tasks that would produce < 30 lines total into a single task. Common batches:
- Types + atoms for the same feature
- Simple constant file + its type

## Task Prompt Format

Write each prompt in **terse spec format** (not prose). Example:

```
Create: src/features/dashboard/dashboard.types.ts

Types:
- FleetSummary { totalVehicles: number, online: number, offline: number, idle: number }
- DashboardFilters { dateRange: DateRange, status?: VehicleStatus[] }

Imports: DateRange from @/shared/types, VehicleStatus from @/features/fleet/fleet.types
Export all types. Add type guard isFleetSummary().
```

Each prompt must be **self-contained** — the minion has no conversation history.

### Inline Context Snippets

**Prefer inlining relevant code directly in the prompt** over `context_files`. Read the referenced files now (you have full context) and extract only the relevant 5–15 lines:

```
Relevant types (from src/features/fleet/fleet.types.ts):
\`\`\`ts
export type Vehicle = { id: string; status: 'online' | 'offline' | 'idle' }
export type VehicleStatus = Vehicle['status']
\`\`\`
```

Only use `context_files` when the minion needs broader file context that can't be reasonably inlined (e.g., a full hook pattern to replicate).

## TDD: Test Stubs for Sonnet Tasks

For every `model: "sonnet"` task (hooks, API functions, complex utils):

1. **Generate a test stub** — a test file with `describe`/`it` structure and comment annotations specifying expected behavior. Store as `test_stub` in the manifest.
2. The stub is written to the worktree **before** the minion runs. The minion fills in assertions + implements code to make them pass.
3. The minion must NOT rename or restructure describe/it blocks.

### Test Stub Format

```typescript
// @ts-nocheck — stub: fill in assertions, do not rename tests
import { describe, it, expect, vi } from 'vitest'

describe('useFleetSummary', () => {
  it('returns fleet summary with correct shape', async () => {
    // IMPLEMENT: mock API, render hook, assert result.current.data matches FleetSummary shape
    // Expected shape: { totalVehicles: number, online: number, offline: number, idle: number }
  })

  it('uses 30s stale time', () => {
    // IMPLEMENT: assert queryClient config has staleTime === 30_000
  })

  it('returns error state on API failure', async () => {
    // IMPLEMENT: mock API to throw, assert result.current.error is set and isLoading is false
  })
})
```

Rules for stubs:
- `// @ts-nocheck` header (minion removes it when types resolve correctly)
- Comment annotations describe WHAT to assert, not HOW — the minion decides the implementation
- Cover: happy path, error case, and one config/contract assertion
- For Haiku tasks (types, atoms, constants): no stub needed — minion writes tests freely

## Detect Project Test Configuration

Before writing any test stubs or the manifest, detect the project's test setup:

1. **Read `package.json`**: Check `devDependencies` and `scripts.test` to identify the framework:
   - `vitest` → framework: `vitest`, run cmd: `<pm> run test -- --run {file}`
   - `jest` → framework: `jest`, run cmd: `<pm> run test -- --testPathPattern {file}`
   - `mocha` → framework: `mocha`, run cmd: `<pm> run test` (or check scripts)
   - `@playwright/test` → skip for unit test stubs (Playwright is e2e, not unit)
   - Unknown → use `<pm> run test` and let the minion detect

2. **Read one existing test file** from the project (find via `Glob "**/*.test.ts"` or `"**/*.spec.ts"`). Extract:
   - Import style (named imports from framework, globals, etc.)
   - Mock API (`vi.mock`, `jest.mock`, `sinon.stub`, etc.)
   - Any test utilities or custom render wrappers used consistently

3. Store `test_framework` and `test_run_cmd` in the manifest root (not per-task).

4. **Write all test stubs using the project's detected import style** — not Vitest by default. Example for Jest:
   ```typescript
   // @ts-nocheck — stub: fill in assertions, do not rename tests
   // Uses Jest globals (no imports needed)

   describe('useFleetSummary', () => {
     beforeEach(() => {
       jest.clearAllMocks()
     })

     it('returns fleet summary with correct shape', async () => {
       // IMPLEMENT: mock API with jest.mock, render hook, assert result.current.data
     })
   })
   ```

## Validation Before Writing Manifest

Before writing the manifest:
1. Read the feature plan context_files to verify they exist in the project
2. List any files referenced in task prompts that don't exist yet (that's fine — minions create them)
3. If a `context_files` entry doesn't exist, remove it and inline what you know from the plan instead

## Output

1. Detect the project name from the current working directory basename
2. Detect the `project_dir` from pwd
3. Write manifest JSON to: `~/.claude/minions/manifests/<project-name>/<feature-name>.json`
4. Use the schema from [manifest-schema.md](manifest-schema.md)
5. Display a summary table:

```
| ID    | Name                  | Tier   | Model  | Deps    | Files | Tests  |
|-------|-----------------------|--------|--------|---------|-------|--------|
| fd-01 | dashboard-types-atoms | auto   | haiku  | none    | 2     | minion |
| fd-02 | fleet-summary-api     | auto   | sonnet | fd-01   | 2     | stub   |
| fd-03 | dashboard-page        | skip   | —      | fd-01,02| 1     | —      |
```

`Tests` column: `stub` = decomposer wrote test stubs, `minion` = minion writes its own tests, `—` = skipped.

6. Wait for user approval. They may adjust tiers, merge/split tasks, or reorder.
7. Update the manifest with any changes before confirming.
