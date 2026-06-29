# Maturity model — L0 / L1 / L2 / L3

Adapted from [cobusgreyling/loop-engineering — Loop Design Checklist](https://github.com/cobusgreyling/loop-engineering/blob/main/docs/loop-design-checklist.md). The triage agent assigns a `readiness_level` to every ticket. This level gates what the plugin will and will not do.

## The 4 levels

| Level | What it does | What it does NOT do | Default for |
|---|---|---|---|
| **L0 — Draft** | Documents intent only. Produces a `plan.yml` and a one-page report explaining what *would* happen. No agent dispatch beyond triage. | Anything that writes user-facing artifacts. | Brainstorming, "what would this look like?" tickets. |
| **L1 — Report** | Runs research/triage/discovery phases. Produces analysis artifacts: reports, audits, comparisons. Reads code, never writes code. | Code writes, spec writes, ADR writes, git operations. | First-time use of a workflow. Default for any project with no prior STATE history. |
| **L2 — Assisted** | Produces specs, ADRs, code changes — but every write goes through an approval gate (`AskUserQuestion`) before the spec-writer commits. Workers run in worktrees; merges are explicit. | Auto-merging PRs. Pushing to protected branches. Acting on denylisted paths. | Tickets with known structure where the user has reviewed L1 outputs at least once. |
| **L3 — Unattended** | Full autonomy. No approval gate. Self-healing converges without human input. Writes everything to the outputs folder. | Auto-merging PRs (NEVER — even L3). Touching `.env`, `secrets/`, `infra/production/`. | Trivial tickets the user has run a successful version of before (rename, typo, single CSS class). |

## Per-level gates

| Capability | L0 | L1 | L2 | L3 |
|---|---|---|---|---|
| Triage emits plan | ✅ | ✅ | ✅ | ✅ |
| Sub-agent dispatch | ❌ | ✅ (research/audit only) | ✅ | ✅ |
| Spec write to `.planning/` | ❌ | ❌ | ✅ (after approval) | ✅ |
| ADR write to `docs/adr/` | ❌ | ❌ | ✅ (after approval) | ✅ |
| Worker writes to code paths | ❌ | ❌ | ✅ (in worktree) | ✅ (in worktree) |
| Self-healing retries | ❌ | ❌ | ✅ (max 3) | ✅ (max 3) |
| PR description write | ❌ | ❌ | ✅ | ✅ |
| Append to `.loop/state.md` | ✅ | ✅ | ✅ | ✅ |
| Append to `.loop/run-log.md` | ✅ | ✅ | ✅ | ✅ |
| Touch denylisted paths | NEVER | NEVER | NEVER | NEVER |
| Merge to main/protected branches | NEVER | NEVER | NEVER | NEVER |

## Path denylist (NEVER touch, regardless of level)

- `.env`, `.env.*`
- `secrets/`, `secret/`, `private/`
- `infra/production/`, `terraform/production/`, `k8s/production/`
- `.git/objects/`, `.git/hooks/`
- Any path starting with `.ssh/`, `.aws/`, `.gcloud/`, `.kube/`
- Any path the project's `.gitignore` covers in `*-secret*` patterns

The triage and worker-dev agents enforce this via Grep+denylist check before any Write.

## How triage assigns the level

### Rules in order (first match wins)

1. **User explicitly requested a level** in the ticket (e.g. *"run as L1 first"*, *"this is autonomous, L3"*) → honor it.
2. **Ticket touches denylisted paths** → cap at L1 regardless of request.
3. **`.loop/run-log.md` shows ≥3 successful runs of this ticket-archetype** → default L2 (or L3 if the user marked the previous runs as `success_no_review_needed`).
4. **`.loop/run-log.md` shows ≥1 successful run of this ticket-archetype** → default L2 with approval gate.
5. **No history OR <1 successful run** → default L1 (report-only).
6. **Ticket is purely conversational** (Q&A, "explain X") → L0 — no agents needed.

### Surfacing the choice

After picking a level, the triage MUST tell the user which level was chosen and why. Single sentence in the chat resumen:

> *"Asignando L2 (assisted) — esta archetype tiene 2 runs previos exitosos; gate humano antes de cada write."*

User can downshift via `AskUserQuestion` ("Want me to run L1 instead?"). Upshift requires explicit confirmation.

## Phased rollout pattern (Cobus's advice)

When using the plugin in a new project for the first time:

- **Week 1:** Run all tickets at L1. Review the artifacts manually. Build trust.
- **Week 2:** For ticket types you've successfully reviewed twice, move to L2.
- **Week 3+:** For trivial recurring tickets (rename, single-file), move to L3.

The plugin does not enforce this rollout — it surfaces the data (run history in `.loop/run-log.md`) and recommends. You decide.
