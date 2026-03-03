# Matix Minions

Agentic workflow system for Claude Code. Provides skills (slash commands) that orchestrate parallel coding agents using git worktrees.

## Skills
- `/plan-feature` — Interactive feature planning with best practices
- `/decompose` — Break feature into atomic tasks, output manifest JSON
- `/dispatch-minions` — Spawn parallel agents in worktrees
- `/retry-minion` — Re-run failed task with guidance
- `/review-minions` — Merge results into feature branch

## Architecture
Skills live in `skills/` and symlink to `~/.claude/skills/` via `install.sh`.
Manifests stored at `~/.claude/minions/manifests/<project>/<feature>.json`.
Project-agnostic — works in any GitHub project with a package.json.

## Token Optimization
- Haiku for simple tasks (types, atoms, constants)
- Sonnet for complex tasks (hooks, API, business logic)
- Minimal minion prompt (~120 tokens) — delegates to project CLAUDE.md
- Terse spec-format prompts, not prose
- Batch tiny tasks together
