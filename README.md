# somnio-loop

> **Ticket in. Deliverable out.** Autonomous agentic loop orchestration for Claude Code — research, docs, code, or architecture decisions, in any stack.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.8.0-3ee8c5)](CHANGELOG.md)
[![Validate](https://github.com/giosomniodev/somnio-loop/actions/workflows/validate.yml/badge.svg)](https://github.com/giosomniodev/somnio-loop/actions/workflows/validate.yml)

---

## What it does

You hand `somnio-loop` a ticket — a free-text prompt, a Jira/Linear/GitHub Issues ID, or a paragraph pasted directly — and the plugin runs the full loop end-to-end without further input:

1. **Triage** decomposes the ticket into phases and picks the right archetype per phase
2. **Sub-agents fan out in parallel** waves (Sonnet for analysis, Haiku for audit, Opus for final synthesis)
3. **Self-healing** runs your project's verification commands (lint, typecheck, tests, build) and retries on failure — language-agnostic
4. **Spec generator** produces a validated 20-section spec when the ticket implies code work
5. **ADR generator** records architectural decisions with codebase analysis and PR conflict detection
6. **Verifier executes the suite** (no theater) before the spec-writer (Opus) assembles the final artifact
7. **Run report** with per-agent consumption, prompts, and a machine-readable trace lands in `.loop/`

The plugin is **technology-agnostic** by design. It discovers your stack from manifests (`package.json`, `pubspec.yaml`, `go.mod`, `Cargo.toml`, `mix.exs`, `*.csproj`, and 60+ others) and your conventions from `CLAUDE.md`, `AGENTS.md`, and the `.rules` family (`.cursorrules`, `.windsurfrules`, `.clinerules`, `.roorules`). It works on Flutter, React, Next.js, NestJS, Rails, Spring, Go services, Rust binaries — anything with a discoverable manifest.

## Quick install

```bash
# 1) Add the marketplace
claude plugin marketplace add giosomniodev/somnio-loop

# 2) Install the plugin
claude plugin install somnio-loop@somnio-loop

# 3) Verify
claude plugin list | grep somnio-loop
```

That's it. No further configuration required for first run.

## First run

In any project, inside Claude Code:

```
somnio-loop:do "Investigate the last 3 TypeScript releases and write a 300-word summary."
```

(Or simply `do "..."` if your environment resolves without collision.)

You will see, in order:

```
🎚 Readiness level: L1 (report-only) — first run on this repo.
🎛 Autonomy: balanced (default from .loop/config.yaml)
```

Then triage → workers → verifier → spec-writer → consolidated summary with the per-agent consumption table.

Expected: ~3–5 minutes, ~$0.30–$0.50 USD for a research ticket of this size.

## The five archetypes

| Archetype | When triage picks it | Example |
|---|---|---|
| **orchestrator-workers** | N independent sub-tasks | Research 5 bundlers in parallel |
| **plan-execute** | Sequential pipeline with data flow between steps | Extract → transform → load |
| **generate-spec** | Development ticket needs a contract before code | Implement a feature with tests |
| **adr** | Architectural decision detected (verbs like *adopt*, *migrate*, *replace*; new tech, infra, data model, API design) | "Use Redis for session caching" |
| **self-healing** | Code phase with verification commands | Workers in isolated `git worktree`s + verifier executes the suite + retry on failure (max 3 per file) |

Triage may combine archetypes into a 2–4 phase plan: ADR → spec → self-healing → PR description.

## Autonomy presets

Configurable per-project in `.loop/config.yaml` or per-run via `--autonomy=<preset>` appended to the ticket.

| Preset | Behavior | Use when |
|---|---|---|
| `minimal` | Maximum autonomy. Verifier auto-fix up to 2 retries. PR conflicts logged and continued. Spec clarifications marked TBD instead of asking. Status updates posted without confirmation. | Repetitive tickets, batch jobs, after a calibration period. |
| `balanced` *(default)* | Asks when human judgment adds value, proceeds when it doesn't. The behavior shipped through v0.4.x. | First weeks in any new project or ticket archetype. |
| `high` | Approval gate before every write. Up to 10 clarification questions. "Continue?" after each phase. | Sensitive areas — auth, billing, production infra, regulatory compliance. |
| `custom` | Per-gate override. | When presets don't fit your specific risk profile. |

```bash
# Override per ticket
do "Migrate auth to Riverpod 2 --autonomy=minimal"
do "Change pricing engine --autonomy=high"
```

Six configurable gates: `budget_gate`, `verifier_blocking_gate`, `adr_conflict_gate`, `adr_rule_violation_gate`, `spec_clarification_gate`, `self_healing_exhaust_gate`. Full schema in [`references/autonomy-config.md`](references/autonomy-config.md).

## Optional MCP integrations

The plugin **does not bundle its own MCP servers**. It discovers whatever you have connected to Claude Code via `ToolSearch` and adapts.

| Integration | Tools the plugin uses | Benefit |
|---|---|---|
| **Jira (Atlassian Remote)** | `getJiraIssue`, `editJiraIssue`, `addCommentToJiraIssue` | `do TKT-123` fetches the full ticket; status auto-updates to `In Review` post-run |
| **GitHub** | `get_issue`, `create_pull_request`, `list_pull_requests` | Ticket fetch from issues, PR draft creation, ADR conflict detection at diff level |
| **Linear** | `get_issue`, `update_issue`, `create_comment` | Same flow as Jira |
| **Slack / Teams / Discord** | `send_message` | Post run summaries to your team's channel |

Configure them in `.loop/config.yaml` under `mcp_integrations`. Full vendor adapter details in [`references/mcp-integrations.md`](references/mcp-integrations.md).

## Git Flow integration (v0.8.0)

Triage classifies every code-writing ticket into one of 8 types and applies the corresponding Git Flow convention. Defaults assume Vincent Driessen's Git Flow (main + develop); GitHub Flow and trunk-based dev are supported via config overrides.

| Type | Branch | Base | PR target |
|---|---|---|---|
| `feature` | `feature/{ticket_id}-{slug}` | develop | develop |
| `bugfix` | `bugfix/{ticket_id}-{slug}` | develop | develop |
| `hotfix` | `hotfix/{ticket_id}-{slug}` | main | main + back-merge to develop |
| `release` | `release/{version}` | develop | main + back-merge to develop |
| `chore` | `chore/{ticket_id}-{slug}` | develop | develop |
| `docs` | `docs/{ticket_id}-{slug}` | develop | develop |
| `refactor` | `refactor/{ticket_id}-{slug}` | develop | develop |
| `spike` | `spike/{ticket_id}-{slug}` | develop | develop |

Critical guarantee: **your HEAD is invariant.** The plugin works in a dedicated git worktree, never `git checkout`s your repo. After each run, `git status` on your working tree shows no changes (unless your repo had untracked files before — those stay).

Full schema in [`references/git-flow.md`](references/git-flow.md).

## Safety floor (non-negotiable)

These eight rules apply to every preset, including `minimal`:

1. **Never auto-merge PRs.** Plugin produces a branch and a PR description; humans merge.
2. **Never push to `main`, `master`, `production`, or `release/*`.**
3. **Never write to denylist paths** (`.env`, `secrets/`, `infra/production/` + project-specific additions).
4. **Never silently override a documented rule** in `.rules`/`AGENTS.md`/`CLAUDE.md`. The plugin asks or aborts — never `proceed`.
5. **PR always opened as draft.** You upgrade to "ready for review" manually.
6. **Ticket status capped at `In Review`.** Never `Done` / `Closed` automatically.
7. **Hotfix detection always surfaces confirmation** — even on `autonomy: minimal`. Production paths warrant friction.
8. **User's HEAD is invariant.** The plugin verifies before-and-after that `git rev-parse HEAD` and `git branch --show-current` are unchanged. Violation aborts the run with `INVARIANT VIOLATED`.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  do (entry skill — user-facing)                             │
│  Phase -1: STATE + config + MCP discovery + ticket fetch    │
│  Phase  1: triage → plan.yml + readiness + autonomy         │
│  Phase  2: budget gate                                      │
│  Phase  3: runtime executes phases                          │
│  Phase  4: verifier executes + blocking gate                │
│  Phase  5: spec-writer (Opus) assembles final               │
│  Phase  6: present artifacts (Cowork or inline)             │
│  Phase  7: STATE update + PR/status/notification gates      │
│  Phase  8: chat resumen with per-agent consumption table    │
└─────────────────────────────────────────────────────────────┘
                              │
       ┌──────────────────────┼──────────────────────┐
       ▼                      ▼                      ▼
  triage (Sonnet)      runtime (Sonnet)      verifier (Haiku)
       │                      │                      │
       │                      ▼                      ▼
       │              N×worker-dev (Sonnet)     spec-writer (Opus)
       │              in isolated git           ── final artifact
       │              worktrees + merge
       │
       └─→ adr-author (Sonnet) — if ADR-worthy
       └─→ spec-refiner (Haiku) + spec-validator (Sonnet) — if dev ticket
```

**Model ladder:** Opus runs once per ticket (spec-writer only). Sonnet runs N workers + triage + runtime + analysis. Haiku runs the cheap audit. The triage refuses to assign Opus to anything but the spec-writer.

## Project structure

```
somnio-loop/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (consumed by Claude Code)
│   └── marketplace.json     # marketplace catalog
├── skills/
│   ├── do/                  # user-facing entry skill
│   ├── loop-orchestrator/   # orchestrator-workers archetype
│   ├── loop-plan-execute/   # plan-execute archetype
│   ├── loop-self-healing/   # self-healing archetype (git worktree isolation)
│   ├── loop-generate-spec/  # 20-section spec generator
│   │   └── references/
│   │       └── spec-template.md
│   └── loop-adr/            # ADR generator (12 steps)
├── agents/
│   ├── triage.md            # Sonnet — emits plan.yml
│   ├── loop-runtime.md      # Sonnet — executes plan
│   ├── spec-writer.md       # Opus — final artifact only
│   ├── verifier.md          # Haiku — audit + execute verification commands
│   ├── spec-refiner.md      # Haiku — per-section gap analysis
│   ├── spec-validator.md    # Sonnet — PASS / WARNINGS / BLOCK verdict
│   ├── adr-author.md        # Sonnet — 12-step ADR flow
│   └── worker-dev.md        # Sonnet — code writer, one file per invocation
├── references/              # shared knowledge, consumed by agents
│   ├── universal-commands.md       # 15+ stacks' lint/test/build commands
│   ├── manifest-types.md           # 60+ manifest patterns
│   ├── state-spine.md              # .loop/ schema
│   ├── autonomy-config.md          # 6 gates + 3 presets
│   ├── mcp-integrations.md         # adapter patterns per vendor
│   ├── anti-patterns-checklist.md  # 10 anti-patterns baked into triage
│   └── maturity-model.md           # L0/L1/L2/L3 levels + per-level gates
├── scripts/
│   └── build-plugin.sh      # CI uses this to produce somnio-loop.plugin
├── .github/
│   ├── workflows/
│   │   ├── validate.yml     # runs on every push/PR
│   │   └── release.yml      # runs on tag push, attaches .plugin to release
│   └── ISSUE_TEMPLATE/
├── CHANGELOG.md             # full version history (v0.1.0 → v0.7.0)
├── CONTRIBUTING.md
├── LICENSE                  # MIT
└── README.md                # this file
```

## Conventions read on first run

The plugin reads the following on every run (all optional — it falls back to manifest inference if none exist):

**Layer 1 — Architecture docs**
`CLAUDE.md`, `AGENTS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `CONVENTIONS.md`, plus `docs/` equivalents, plus nested `**/CLAUDE.md`.

**Layer 2 — AI behavior rules**
`.cursorrules`, `.windsurfrules`, `.clinerules`, `.roorules`, `.aider.conf.yml`, `.github/copilot-instructions.md`, `.continue/config.json`. Each rule becomes a constraint on the ADR's `Alternatives Considered` table.

**Layer 3 — Project type classification**
Frontend (React/Vue/Svelte/Solid/Angular/Qwik), Mobile (Flutter/React Native/Expo/Swift/Kotlin), Backend (NestJS/Express/Django/FastAPI/Rails/Spring/Go/Rust), Full-stack (monorepos with Nx/Turbo/Bazel).

**Layer 4 — Sub-type deep scan**
Per-stack additional context: state management deps, routing, testing framework, ORM/schema, infrastructure as code.

## State spine — `.loop/`

The plugin owns a single directory at your repo root, created on first run:

```
.loop/
├── state.md              # high priority / watch list / conventions snapshot
├── run-log.md            # append-only history (1 entry per run)
├── budget.md             # daily/weekly caps + kill switch + denylist paths
├── config.yaml           # autonomy preset + 6 gates + MCP integrations
├── traces/<ts>.json      # machine-readable trace per run
└── plans/<ts>.yml        # archived plan.yml per run
```

`state.md`, `run-log.md`, `budget.md`, and `config.yaml` are inspectable text files — review-friendly, commit them if your team wants shared memory. `traces/` and `plans/` are excluded by the default `.gitignore`.

## Documentation

- **[CHANGELOG.md](CHANGELOG.md)** — full version history v0.1.0 → v0.7.0
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — four categories of contribution, naming conventions, release process
- **[references/](references/)** — seven canonical knowledge docs the agents consume:
  - [`universal-commands.md`](references/universal-commands.md) — verification commands across 15+ stacks
  - [`manifest-types.md`](references/manifest-types.md) — 60+ manifest patterns for stack discovery
  - [`state-spine.md`](references/state-spine.md) — `.loop/` schema
  - [`autonomy-config.md`](references/autonomy-config.md) — gates + presets + safety floor
  - [`mcp-integrations.md`](references/mcp-integrations.md) — Jira / Linear / GitHub / Slack adapters
  - [`anti-patterns-checklist.md`](references/anti-patterns-checklist.md) — 10 anti-patterns triage refuses
  - [`maturity-model.md`](references/maturity-model.md) — L0/L1/L2/L3 readiness levels
  - [`git-flow.md`](references/git-flow.md) — Git Flow integration: 8 ticket types, branch patterns, base + PR target per type

## Roadmap

| Version | Focus |
|---|---|
| **v0.7.x** *(current)* | Bug fixes, ergonomics, public stabilization |
| v0.8 | `loop:audit` skill (Loop Readiness Score) + `loop:cost` (pre-run token estimator) |
| v0.9 | `loop:improve` — meta-loop that reads `.loop/traces/` history and refactors prompts/topologies (hill-climbing) |

## Foundations

`somnio-loop` is a productization of "Loop Engineering" — the design discipline articulated by:

- **Addy Osmani** — [Loop Engineering essay](https://addyosmani.com/blog/loop-engineering/)
- **Boris Cherny** (Head of Claude Code, Anthropic) — *"I don't prompt Claude anymore. I have loops running that prompt Claude. My job is to write loops."*
- **Cobus Greyling** — [loop-engineering reference repository](https://github.com/cobusgreyling/loop-engineering) — anti-patterns and failure modes baked into the triage agent's self-check.
- **LangChain** — [The Art of Loop Engineering](https://www.langchain.com/blog/the-art-of-loop-engineering)

This plugin formalizes their patterns as a one-command interface on top of Claude Code's sub-agent and skill primitives, with strong safety floors, configurable autonomy, and durable state.

## Contributing

Patterns, MCP adapters, language-specific verification commands, and anti-patterns from production incidents are all welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## License

[MIT](LICENSE) — Copyright (c) 2026 Somnio
