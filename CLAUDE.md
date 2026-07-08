# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**somnio-loop** is a Claude Code plugin that implements "Loop Engineering" — an agentic orchestration system where a user provides a ticket and the system autonomously runs multi-phase workflows (triage → runtime → verify → synthesize) to produce deliverables. Zero code to compile; everything is Markdown + YAML.

## Commands

### Plugin Build
```bash
./scripts/build-plugin.sh       # Produces somnio-loop.plugin (ZIP artifact)
```

### Docs Site (Next.js + Nextra)
```bash
cd docs && npm install
npm run dev                     # Local dev at localhost:3000
npm run build                   # Static export
npm run lint                    # ESLint
```

### Validation (CI equivalent)
The GitHub Actions workflow `.github/workflows/validate.yml` runs these checks locally representable as:
- JSON schema on `.claude-plugin/plugin.json`
- Frontmatter validation: every `.md` in `skills/` and `agents/` must have `name` + `description` and must NOT contain angle-bracket placeholders like `<X>` in frontmatter (parsed as XML by Claude Code)
- Required files presence
- Plugin build dry-run

## Architecture

### Execution Flow (8 phases, strictly ordered)

All user interaction is routed through **`skills/do/SKILL.md`** (the orchestrator). It never writes the final artifact — that is exclusively reserved for `agents/spec-writer.md`.

```
User ticket
    → Phase -1: Read .loop/ spine + MCP discovery
    → Phase 0:  Acknowledge (restate ticket, surface config, checkpoint run-log)
    → Phase 1:  triage agent → emits plan.yml (phases, archetypes, workers, budget)
    → Phase 2:  Budget gate (check cost thresholds, proceed/abort per gate config)
    → Phase 3:  loop-runtime agent → executes plan.yml, dispatches workers in parallel waves
    → Phase 4:  verifier agent → audits intermediates + EXECUTES lint/test/build commands
    → Phase 5:  spec-writer agent (Opus ONLY) → final deliverable
    → Phase 6-8: Consolidate, update .loop/ state, PR/ticket gates, notifications
```

### Five Archetypes (triage selects per phase)

| Archetype | Pattern | Key file |
|---|---|---|
| `orchestrator-workers` | N independent tasks in parallel | `skills/loop-orchestrator/SKILL.md` |
| `plan-execute` | Sequential pipeline with data flow | `skills/loop-plan-execute/SKILL.md` |
| `generate-spec` | 20-section validated spec | `skills/loop-generate-spec/SKILL.md` |
| `adr` | Architecture Decision Record (12-step) | `skills/loop-adr/SKILL.md` |
| `self-healing` | Write → verify → retry with worktree isolation | `skills/loop-self-healing/SKILL.md` |

### Model Ladder (strict — do not change per-agent model assignments)

- **Haiku**: verifier, spec-refiner — cheap audits and structure validation only
- **Sonnet**: triage, loop-runtime, worker-dev, adr-author, spec-validator — all domain work
- **Opus**: spec-writer ONLY — final synthesis; no workers ever use Opus

### Sub-agent Isolation Rules

- Workers for a single phase are dispatched **in a single `Agent` tool message** (true parallelism)
- Code workers (`worker-dev`) each get their own `git worktree` — never share the working tree
- The orchestrator (`do`) never directly writes user-facing artifacts
- `spec-writer` is the only agent that produces the final deliverable

### Durable State (`.loop/` directory)

Created at first run, excluded from `.gitignore`:
- `config.yaml` — autonomy preset + 9 gates + MCP integrations (user-editable)
- `state.md` — High Priority list, Watch List, conventions snapshot
- `run-log.md` — append-only history, one entry per run
- `budget.md` — daily/weekly token/cost caps + kill switch
- `traces/` — per-run JSON traces (substrate for meta-loop tooling)
- `plans/` — archived `plan.yml` per run

### Safety Floor (non-negotiable — cannot be overridden by any autonomy preset)

1. Never auto-merge PRs
2. Never push to `main`/`master`/`production`/`release/*`
3. Never write to denylist paths (`.env`, `secrets/`, `infra/production/`)
4. PRs opened as **draft only**
5. Ticket status capped at "In Review" (never "Done" automatically)
6. Hotfix always requires explicit user approval
7. Never `git checkout` on user's HEAD — use worktrees only

### References Directory (shared knowledge — all agents consume)

`references/` is the canonical knowledge base:
- `autonomy-config.md` — 3 presets (`minimal`, `ownership`, `custom`) + 9 gate definitions
- `anti-patterns-checklist.md` — 10 patterns triage enforces to detect and block
- `maturity-model.md` — L0/L1/L2/L3 readiness levels with per-level gate behavior
- `universal-commands.md` — 15+ stacks' lint/test/build commands (how tech-agnostic discovery works)
- `manifest-types.md` — 60+ manifest patterns for stack detection (`package.json`, `pubspec.yaml`, `go.mod`, etc.)
- `mcp-integrations.md` — Jira, GitHub, Linear, Slack adapter patterns
- `git-flow.md` — 8 ticket types → branch conventions + PR targets
- `state-spine.md` — `.loop/` file schema

## Documentation requirement before committing

Any change to a `skills/`, `agents/`, or `references/` file that introduces new behavior, a new field, a new gate, or a new execution path **must** be accompanied by its corresponding documentation update in `docs/pages/` before the commit is valid. The docs update must include:

1. **Explanation** — what the feature/change does and why it exists.
2. **User-facing examples** — at least one concrete example showing how a user invokes or configures it (e.g. a `config.yaml` snippet, a ticket invocation, a plan.yml excerpt).
3. **Cross-references** — links to any related pages or config fields that the change touches.

A commit that modifies plugin behavior without a matching `docs/` update must be considered incomplete and should not be merged.

## Release procedure

Always follow this order. Skipping step 1 causes CI to fail with "tag vX.Y.Z doesn't match plugin.json version".

1. Bump `"version"` in `.claude-plugin/plugin.json` to the new version.
2. Commit and push: `fix: bump plugin.json to X.Y.Z`
3. Create annotated tag: `git tag -a vX.Y.Z -m "..."` and push it.
4. Create GitHub release: `gh release create vX.Y.Z --title "..." --notes "..."`

## Plugin Manifest

The Claude Code plugin manifest is at `.claude-plugin/plugin.json`. Key constraint: frontmatter `description` fields across all `skills/` and `agents/` `.md` files must never contain `<angle-bracket>` tokens — they are interpreted as XML tags and will break parsing.

## Docs Site Structure

`docs/` is a Next.js + Nextra site. Pages live in `docs/pages/`. Theme config is `docs/theme.config.tsx`. Internal MDX links must NOT include the `basePath` prefix (`/somnio-loop/`) — Nextra resolves them relative to the pages root.
