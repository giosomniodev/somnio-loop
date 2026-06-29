---
name: loop-plan-execute
description: Internal archetype skill that implements the Plan-Execute loop pattern. Triggered by loop-runtime when triage selects "plan-execute" for a phase. Use when sub-tasks are sequential with clear dependencies — phase B needs phase A's output, replan on phase failure. NOT for independent fan-out (use loop-orchestrator instead). Uses TaskCreate/TaskUpdate as the loop state machine. Surfaces replan decisions to the runtime, never produces the final user-facing artifact.
---

# loop-plan-execute — Plan-Execute archetype

This skill is invoked internally by `loop-runtime`. The user never triggers it directly.

## When the triage agent picks this archetype

The triage agent picks `plan-execute` when the phase is a sequence of steps where step N consumes step N-1's output, and a step failure may require replanning subsequent steps. Examples: research → outline → draft → revise, or extract → transform → load → validate.

## Inputs (from the runtime)

```yaml
phase: pipeline
archetype: plan-execute
steps:
  - id: s1
    name: research
    model: sonnet
    prompt: "..."
    output: /tmp/loop-runs/<ts>/intermediates/research.md
    depends_on: []
  - id: s2
    name: build-matrix
    model: sonnet
    prompt: "Read {{s1.output}}, extract structured comparison matrix."
    output: /tmp/loop-runs/<ts>/intermediates/matrix.csv
    depends_on: [s1]
  - id: s3
    name: draft-recommendation
    model: sonnet
    prompt: "Read {{s2.output}}, draft recommendation section."
    output: /tmp/loop-runs/<ts>/intermediates/recommendation.md
    depends_on: [s2]
replan_policy: on_failure
budget:
  max_total_tokens: 80000
```

## Execution protocol

### Step 1 — Materialize the plan as TaskCreate calls

For every step in the spec, call `TaskCreate` (or have the runtime do it before invoking this skill). Use `addBlockedBy` to wire dependencies. This makes the loop state inspectable and survives session compaction.

### Step 2 — Execute one step at a time

Loop:

1. Read the task list. Pick the next step whose dependencies are `completed`.
2. Set its status to `in_progress` via TaskUpdate.
3. Dispatch its worker via the Agent tool with the configured model. Substitute `{{sN.output}}` placeholders with actual paths.
4. When the worker returns, verify the output file exists and is non-empty. On success, TaskUpdate to `completed`.
5. On failure: trigger replan (Step 3).
6. Stop when all steps are `completed` or replan exhausts retries.

### Step 3 — Replan on failure

When a step fails:

- If `replan_policy: on_failure` (default), dispatch a small "replanner" worker (Sonnet) with: the failed step, the failure reason, the remaining downstream steps. It returns either: (a) "retry with adjusted prompt", (b) "skip this step, downstream still viable", or (c) "abort phase, escalate to user".
- If `replan_policy: strict`, abort immediately.
- Max replans per phase: 2. Beyond that, abort and escalate.

### Step 4 — Return summary to runtime

Return ONLY:

- The final TaskList state (completed / failed / skipped per step)
- The path to each step's output artifact
- Replan log if any
- Total token usage

Do NOT synthesize — the spec-writer assembles the final artifact.

## Anti-patterns to avoid

- Running steps in parallel when they depend on each other — race conditions, silent data loss.
- Skipping the TaskCreate/Update bookkeeping — the loop becomes uninspectable and post-mortem is impossible.
- Letting the replanner rewrite the whole plan — its scope is "fix this step and the immediate downstream", not "redesign the phase".
- Allowing infinite replans — cap at 2 to prevent burning the budget.

## Reference patterns

Plan-Execute as a discrete pattern is well-documented in LangChain's agent library and in Anthropic's "Building Effective Agents" post (Dec 2024). The TaskCreate/TaskUpdate-as-state-machine wrinkle is specific to Claude Code and unlocks compaction-survival.
