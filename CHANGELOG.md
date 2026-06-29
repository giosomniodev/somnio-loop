# Changelog

All notable changes to `somnio-loop` are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.8.0] — 2026-06-27 — Git Flow integration + HEAD invariant fix

### Added

- `references/git-flow.md` — full Git Flow integration documentation: 8 ticket types, branch patterns, base branches, PR targets, conventional commit messages.
- Triage classifies every code ticket into one of 8 types: `feature`, `bugfix`, `hotfix`, `release`, `chore`, `docs`, `refactor`, `spike`. Emits `ticket_type` and `slug` in plan.yml.
- `.loop/config.yaml` schema extended with `git_flow.*` section: `base_branch`, `main_branch`, `branch_patterns`, `pr_targets`, `commit_message`, `follow_up`. Defaults assume Driessen's Git Flow (main + develop).
- GitHub Flow and trunk-based development supported via config overrides (set `base_branch: main` for all types).
- Spec-writer PR description gains `## Branch & target` section showing branch name + PR target + back-merge follow-up.
- Conventional commit message generation per ticket_type (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, etc.).
- Hotfix and release back-merge to develop gated via `follow_up.hotfix_back_merge_to_develop` and `follow_up.release_back_merge_to_develop`.

### Fixed (CRITICAL)

- **Self-healing no longer touches the user's HEAD.** v0.7.0 used `git checkout -B loop-merge-<id> HEAD`, which silently switched the user's working tree from their current branch (e.g. develop) to the merge branch. v0.8.0 uses a dedicated merge worktree at `<run_dir>/merge-wt`, leaving the user's checkout invariant. After each run, the runtime verifies `git rev-parse HEAD` and `git branch --show-current` are unchanged; if not, aborts with `INVARIANT VIOLATED`.

### Safety floor extensions (non-configurable)

7. **Hotfix detection always surfaces confirmation.** Even on `autonomy: minimal`, triage requires explicit user confirmation before creating a `hotfix/*` branch from main.
8. **User's HEAD is invariant.** Any operation that switches the user's working tree is forbidden and detected post-run.

### Migration from v0.7.x

Zero action required for default Git Flow users. If `git_flow.enabled: false` (or section omitted), behavior matches v0.7.x: single `loop/<ticket_id>` branch, no type classification. For GitHub Flow, set `git_flow.base_branch: main` and all `pr_targets.*: main`.

## [0.7.0] — 2026-06-27 — Rebrand to Somnio

### Changed (breaking)

- Plugin renamed: `loop-engineering` → `somnio-loop`.
- Author renamed: `Giolabs` → `Somnio`.
- Entry skill renamed: `loop-do` → `do`. Invocation is now `somnio-loop:do TKT-123` (or short `do TKT-123` if no collision).
- Output file: `loop-engineering.plugin` → `somnio-loop.plugin`.

### Unchanged

- Internal skills keep their names (`loop-orchestrator`, `loop-plan-execute`, `loop-self-healing`, `loop-generate-spec`, `loop-adr`).
- `.loop/` spine (state.md, run-log.md, config.yaml, budget.md) — schema identical, zero data migration.
- All sub-agent identities and model assignments.

### Migration

```bash
# In any saved scripts / docs / slash commands
sed -i 's/loop-engineering:/somnio-loop:/g; s/loop-do/do/g' your-files.md
```

## [0.6.0] — 2026-06-27 — MCP integrations

### Added

- `mcp_integrations` section in `.loop/config.yaml`.
- Ticket fetch by ID from Jira / Linear / GitHub Issues / GitLab Issues via discovered MCPs.
- PR creation (always draft) via GitHub / GitLab MCPs — gated.
- Slack / Teams / Discord notifications — gated, off by default.
- ADR conflict detection now prefers GitHub/GitLab MCP over raw `WebFetch`.
- Three new gates: `ticket_status_update_gate`, `pr_creation_gate`, `notification_gate`.
- `references/mcp-integrations.md` documenting discovery patterns and vendor adapters.

### Safety floor (non-configurable)

- PR always opened in draft.
- Never `auto-merge` / `gh pr merge` / `--squash` from any preset.
- Never push to `main` / `master` / protected branches.
- Ticket status cap = `In Review`. Never `Done` / `Closed` automatically.

## [0.5.0] — 2026-06-27 — Autonomy presets + configurable gates

### Added

- `.loop/config.yaml` with `autonomy: { preset: minimal | balanced | high | custom }`.
- Six configurable gates (budget, verifier_blocking, adr_conflict, adr_rule_violation, spec_clarification, self_healing_exhaust).
- Per-run override via `--autonomy=<preset>` suffix in the ticket text.
- Chat surfacing: `🎛 Autonomy: <preset>` after the readiness line in Phase 1.
- `references/autonomy-config.md`.

### Safety floor (non-configurable)

- `adr_rule_violation_gate.on_violation` can only be `ask` or `abort` — never `proceed`. Documented `.rules` violations always require deliberate human action.
- Denylist paths (`.env`, `secrets/`, `infra/production/`) enforced by every worker before any Write.

## [0.4.2] — 2026-06-26 — Per-agent consumption table in chat

### Added

- Mandatory `## Consumo por agente` table in chat resumen with one row per Agent invocation (model, time, tokens, cost). Six rules: one row per dispatch, real `subagent_tokens` / `duration_ms`, effective cost formula (70/30 in/out), validated TOTAL, scope in parens, top-to-bottom order matches flow.

### Fixed

- v0.4.0 cost estimate was unrealistic (showing $0.45 for runs that included Opus). Now uses effective per-model rates: Haiku $1.76/M, Sonnet $6.60/M, Opus $33/M.

## [0.4.1] — 2026-06-26 — Observability hardening

### Added

- Mandatory `🎚 Readiness level: ...` surfacing at Phase 1 (anti-pattern #4 closure).
- Mandatory STATE deltas in chat resumen (Watch List adds, items resolved, run-log total).
- `present_files` fallback to inline relative-path links when running outside Cowork.

## [0.4.0] — 2026-06-26 — Tech-agnostic harden, worktree isolation, verifier upgrade, STATE spine, maturity model, anti-patterns

### Added

- `references/universal-commands.md` covering 15+ stacks (TS/JS, Python, Go, Rust, Ruby, Java/JVM, .NET, Elixir, PHP, Flutter, RN/Expo, Swift, Haskell, Nix, monorepo orchestrators).
- `references/manifest-types.md` (60+ manifest patterns).
- Git worktree isolation per code-writing worker (closes "parallel collision" anti-pattern).
- Verifier upgrade: Bash + Check #7 (executes verification commands, not just reads).
- `.loop/` durable state spine (`state.md`, `run-log.md`, `budget.md`, `traces/`, `plans/`).
- L0/L1/L2/L3 maturity model with explicit per-level gates.
- Ten anti-patterns from cobusgreyling/loop-engineering baked into triage self-check.

### Changed

- All hardcoded npm/jest references removed. Commands come from spec §8 (which discovers from project task runner).

## [0.3.1] — 2026-06-26 — 4-layer convention discovery

### Added

- Reads `.rules` family (`.cursorrules`, `.windsurfrules`, `.clinerules`, `.roorules`, `.aider.conf.yml`, `.github/copilot-instructions.md`, `.continue/config.json`).
- Project type classification: backend / frontend / mobile / full-stack with sub-type deep-scan.
- ADR refuses to silently override documented `.rules` — always asks human first.

## [0.3.0] — 2026-06-26 — ADR generator

### Added

- `loop-adr` skill — Phase 0 of development tickets when an architectural decision is detected.
- `adr-author` Sonnet sub-agent — 12 steps including codebase analysis, PR/MR conflict detection, Deciders inference.
- ADR `## Decision` locks spec §10 downstream.
- Coordination gate when HIGH PR/MR conflicts detected.

## [0.2.0] — 2026-06-26 — Development mode + spec generator + self-healing

### Added

- `loop-generate-spec` skill — 20-section validated spec from raw ticket.
- `loop-self-healing` skill — write → verify → re-dispatch with hard retry cap.
- `worker-dev` sub-agent for code-writing workers.
- Dev-mode `spec-writer` outputs PR description.

## [0.1.1] — 2026-06-26 — Observability + context isolation

### Added

- User-facing `run-report.md` with per-worker table and expandable prompts.
- Context isolation rule: triage and spec-writer ignore CLAUDE.md and memory.
- Inline citation rule (blocking) for numeric claims.
- `final_artifacts` enumeration mandatory in plan.yml.

## [0.1.0] — 2026-06-26 — Initial release

- Single entry point + triage/runtime/spec-writer/verifier topology.
- Two archetypes: `orchestrator-workers` and `plan-execute`.
- Model ladder: Haiku / Sonnet / Opus with Opus reserved for spec-writer.
