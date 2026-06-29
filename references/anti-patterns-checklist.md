# Anti-patterns checklist (baked into triage)

Adapted from [cobusgreyling/loop-engineering — docs/anti-patterns.md](https://github.com/cobusgreyling/loop-engineering/blob/main/docs/anti-patterns.md). The triage agent MUST run this checklist against every emitted `plan.yml` before returning. Any match → either restructure the plan to avoid the anti-pattern, or surface to the user with a brief explanation.

## The 10 anti-patterns

### 1. Same agent implements and verifies

Plan must NEVER assign the implementation worker AND the verifier to the same sub-agent. In our plugin: `worker-dev` writes; `verifier` audits. They are different sub-agents with different models (Sonnet vs Haiku) and different system prompts.

**Self-check:** if the plan has a phase where the same `agent_id` writes code AND runs verification → restructure.

### 2. No attempt cap

Plan must NEVER have an unbounded retry budget. `loop-self-healing` enforces `max_retries_per_file: 3` (configurable down, never up to ∞).

**Self-check:** any phase missing a `max_retries_per_*` cap → fail closed.

### 3. Vague triage output

Plan must NEVER use generic phrasing ("the workers will handle this", "appropriate context"). Every worker has a narrow scope and a save path. Every phase has a rationale.

**Self-check:** scan the emitted `plan.yml` for forbidden phrases: `"handle appropriately"`, `"as needed"`, `"if relevant"`, `"reasonable defaults"`. Match → fail.

### 4. L3 before L1 quality

Plan must respect the `readiness_level` of the ticket. If first-time use of a workflow → default L1 (report-only). L3 (unattended writes) is opt-in via explicit flag.

**Self-check:** if no STATE.md history exists for this ticket type, default `readiness_level: L1` regardless of what the user asked for. Surface this in the chat resumen.

### 5. Shared state without schema

The plan must NEVER have two phases writing to the same artifact path without schema. If two phases produce a `<x>-report.md`, they must produce distinct files (e.g. `loop-adr-report.md` vs `verify-report.md`).

**Self-check:** distinct artifact paths per phase.

### 6. MCP with write-everything scope

The plan must NEVER expand connector scope mid-run. If a ticket needs new MCP permissions, surface BEFORE planning, not after.

**Self-check:** plan's `tools` list per worker is the minimum scope needed. No `*` or "all tools".

### 7. No kill switch

`do/SKILL.md` Phase 2 (approval gate) MUST be enabled for any plan with `readiness_level >= L2` OR `estimated_cost_usd > $1.00`. If neither gate applies, the plan can proceed autonomously — but the orchestrator MUST honor SIGINT (Ctrl+C) cleanly.

**Self-check:** budget cap + gate threshold in the plan.

### 8. Fixing flakes with code

`loop-self-healing` MUST classify failures. A test that fails 1 of 3 reruns is a flake, not a bug. The plan's retry policy includes: on persistent inconsistent failure, quarantine + escalate (do not modify code to "fix" flakes).

**Self-check:** retry policy includes flake classification.

### 9. Auto-merge without allowlist

The plugin NEVER merges PRs autonomously. The `pr-description` Phase 3 produces a description, never a `git push --force` or `gh pr merge`. The plugin's tool grants exclude `gh pr merge` and `git push origin main`.

**Self-check:** tool grants of all sub-agents exclude merge-on-main capabilities.

### 10. No run log

EVERY run appends to `.loop/run-log.md` (created if missing). Triage's first action: read `.loop/state.md` + tail of `.loop/run-log.md`. Spec-writer's last action: append to `.loop/run-log.md`.

**Self-check:** plan's last phase includes a `loop-state-append` step.

## How triage uses this

After producing `plan.yml`, run a quick self-check (one Sonnet call) against this checklist. If any anti-pattern matches:

- Auto-fixable (e.g. missing `max_retries_per_file` → add it) → fix and continue.
- Requires user input (e.g. ticket wants L3 but no history) → surface via `AskUserQuestion`.

Cap retries on this self-check at 1 — if it still fails, output the plan with explicit warnings and let the runtime decide.
