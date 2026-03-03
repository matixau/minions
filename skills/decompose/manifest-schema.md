# Manifest Schema

```json
{
  "feature": "fleet-dashboard",
  "description": "Short description of the feature",
  "project": "m1",
  "project_dir": "/home/archie/Documents/Github-Projects/m1",
  "branch": "feature/fleet-dashboard",
  "base": "main",
  "test_framework": "vitest",
  "test_run_cmd": "pnpm run test -- --run {file}",
  "tasks": [
    {
      "id": "fd-01",
      "name": "dashboard-types-atoms",
      "tier": "auto",
      "model": "haiku",
      "description": "Human-readable summary",
      "files": [
        "src/features/dashboard/dashboard.types.ts",
        "src/features/dashboard/dashboard.atoms.ts"
      ],
      "depends_on": [],
      "prompt": "Terse spec-format prompt with inlined context snippets...",
      "context_files": [
        {"path": "src/features/fleet/fleet.types.ts", "hint": "Vehicle types to reference"}
      ],
      "test_files": [
        "src/features/dashboard/__tests__/dashboard.types.test.ts"
      ],
      "test_stub": null
    },
    {
      "id": "fd-02",
      "name": "fleet-summary-api",
      "tier": "auto",
      "model": "sonnet",
      "description": "TanStack Query hook for fleet summary",
      "files": [
        "src/features/dashboard/hooks/use-fleet-summary.ts"
      ],
      "depends_on": ["fd-01"],
      "prompt": "Terse spec-format prompt with inlined type signatures...",
      "context_files": [],
      "test_files": [
        "src/features/dashboard/__tests__/use-fleet-summary.test.ts"
      ],
      "test_stub": "// @ts-nocheck — stub: fill in assertions, do not rename tests\nimport { describe, it, expect, vi } from 'vitest'\n\ndescribe('useFleetSummary', () => {\n  it('returns fleet summary with correct shape', async () => {\n    // IMPLEMENT: mock API, render hook, assert result.current.data matches FleetSummary\n  })\n\n  it('uses 30s stale time', () => {\n    // IMPLEMENT: assert staleTime === 30_000\n  })\n\n  it('returns error state on API failure', async () => {\n    // IMPLEMENT: mock API to throw, assert result.current.error is set\n  })\n})"
    }
  ]
}
```

## Field Reference

### Manifest root
- **test_framework**: Detected test framework (`vitest`, `jest`, `mocha`, etc.)
- **test_run_cmd**: Command to run a specific test file. Use `{file}` as the placeholder: e.g., `pnpm run test -- --run {file}` (Vitest) or `npx jest --testPathPattern {file}` (Jest)

### Task fields
- **id**: `<2-letter-prefix>-<2-digit>` (e.g., `fd-01`)
- **tier**: `auto` (pure logic, auto-merge) | `notify` (structural, show diff before merge) | `skip` (visual, not dispatched)
- **model**: `haiku` (simple/formulaic tasks) | `sonnet` (complex logic tasks)
- **depends_on**: Array of task IDs that must complete before this task starts
- **prompt**: Self-contained spec for the minion. Include inlined context snippets — no conversation context available.
- **context_files**: Files the minion should read for broader patterns. Prefer inlining snippets in `prompt` instead. Only include when minion needs full file context.
- **test_files**: Expected test file paths the minion should create or fill in.
- **test_stub**: String (file content) of the pre-written test stub for `sonnet` tasks. `null` for `haiku` tasks. Written using the project's detected framework/import style. The dispatcher writes this file to the worktree before the minion runs.
- **skip_reason**: Only for `tier: "skip"` — why this needs interactive work.

## Branch Naming
- Feature branch: `feature/<feature-name-kebab>`
- Minion branches (auto): `minion/<task-id>` (created in worktrees)

## TDD Convention

| Model  | Test approach         | Rationale                                              |
|--------|-----------------------|--------------------------------------------------------|
| haiku  | Minion writes freely  | Formulaic tasks — type guards, simple utils            |
| sonnet | Decomposer writes stub| Complex logic — decomposer sets the success criteria   |

The stub defines WHAT must pass. The minion decides HOW to make it pass.
