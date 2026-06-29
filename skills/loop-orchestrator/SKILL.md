---
name: loop-orchestrator
description: Internal archetype skill that implements the Orchestrator-Workers loop pattern. Triggered by loop-runtime when triage selects "orchestrator-workers" for a phase. Use when sub-tasks are independent and can be fanned out in parallel — multi-source research, side-by-side comparisons, per-item analysis. NOT for sequential pipelines (use loop-plan-execute instead). Dispatches N parallel workers in waves, validates each intermediate artifact, never produces the final user-facing artifact.
---

# loop-orchestrator — Orchestrator-Workers archetype

This skill is invoked internally by `loop-runtime`. The user never triggers it directly.

## When the triage agent picks this archetype

The triage agent picks `orchestrator-workers` when the phase contains N independent sub-tasks that can run in parallel — e.g. researching 5 bundlers, summarizing 10 documents, generating variants of a design. The signal is independence: worker K's output does not depend on worker K-1.

## Inputs (from the runtime)

You receive a phase spec from `plan.yml`:

```yaml
phase: research
archetype: orchestrator-workers
workers:
  - id: w1
    model: sonnet
    prompt: "Research Vite as of 2026: maturity, performance, ecosystem, DX, ideal use cases."
  - id: w2
    model: sonnet
    prompt: "Research Turbopack as of 2026: ..."
  # ... up to N
artifact_dir: /tmp/loop-runs/<ts>/intermediates/research/
acceptance:
  - one .md per worker, 200-500 words
  - each must cite at least 2 sources
budget:
  max_total_tokens: 100000
  per_worker_timeout_s: 300
```

## Execution protocol

### Step 1 — Validate the spec

Confirm that every worker has a `model` and a `prompt`. If not, fail loudly and return to runtime — do not invent missing fields.

### Step 2 — Dispatch ALL workers in a single Agent tool message

This is the critical optimization. To get true parallelism, emit ONE assistant message that contains N `<invoke name="Agent">` blocks, not N sequential messages. Anthropic's research-agent post shows this is where 80% of latency reduction comes from.

Use `subagent_type: "general-purpose"` and pass the assigned model.

Each worker prompt MUST include:

- The narrow scope (one bundler, one document, one variant — not the whole task)
- Output format (markdown sections expected, word count target)
- Save path: `artifact_dir/<worker_id>.md`
- Cap on reply length (under 300 words — the artifact lives in the file, not the reply)

### Step 3 — Collect and validate intermediates

After all workers return, verify each artifact file exists and meets acceptance criteria. If any worker failed:

- Retry policy: dispatch ONE corrective worker (same model) with the failure mode in the prompt
- Max retries per worker: 1
- If still failing, surface the failure to runtime — do NOT silently drop a worker

### Step 4 — Return summary to runtime

Do NOT synthesize the workers' outputs. That is the spec-writer's job in Phase 5. Return ONLY:

- The list of artifact paths
- Worker token usage (for the trace)
- Any soft warnings (worker ran close to timeout, hit budget, etc.)

## Anti-patterns to avoid

- Spawning workers sequentially "to be safe" — kills the entire performance benefit.
- Letting workers write to the user's output folder — they write to `/tmp/loop-runs/...` only.
- Having workers cite each other ("worker 3 said X") — they ran in parallel, they cannot.
- Synthesizing the workers' outputs inside this skill — that's the spec-writer's exclusive job.

## Reference patterns

This archetype is the same pattern Anthropic used in their multi-agent research system (`anthropic.com/engineering/multi-agent-research-system`). Token count explained 80% of variance — invest in parallelism, not bigger models for the workers.
