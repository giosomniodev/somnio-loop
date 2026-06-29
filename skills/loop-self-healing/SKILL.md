---
name: loop-self-healing
description: Internal archetype skill for development tickets. Implements the write → verify → read-failure → re-dispatch cycle with git worktree isolation per worker (closes "parallel collision" anti-pattern). Triggered by loop-runtime when triage selects "self-healing" for a phase. After each wave of worker writes, the verification commands from the spec §8 are executed via Bash; if any command fails, a corrective worker is dispatched with the failure output as input. Hard cap on retries per file. Language-agnostic — consults references/universal-commands.md to discover the project's commands rather than assuming any stack. Use when the deliverable is code that must satisfy executable acceptance criteria. NOT for prose deliverables.
---

# loop-self-healing — write → verify → re-dispatch (with worktree isolation)

This skill is invoked internally by `loop-runtime` when a phase needs to converge on executable acceptance criteria. The user never triggers it directly.

## v0.4 critical changes

1. **Worktree isolation per worker.** Each `worker-dev` writes in its OWN `git worktree add` allocation. Workers cannot collide on shared files. The runtime merges the worktrees back to the main checkout at the end.
2. **Verifier runs the suite itself.** The verification phase is not "read the report" — it is "execute the project's verification commands via Bash and report exit codes". Closes the "verifier theater" anti-pattern.
3. **Language-agnostic.** Commands come from the spec §8 (which itself was discovered from the project's task runner / scripts / Makefile). The fallback table in `references/universal-commands.md` covers 15+ stacks.

## When the triage picks this archetype

The triage picks `self-healing` when the phase is "implement N files with verification commands available". The signals: §6 names files to create/modify, §8 names verification commands (in the project's actual stack).

## Inputs (from the runtime)

```yaml
phase: implement
archetype: self-healing
spec_path: <repo_root>/.planning/phases/<slug>/spec.md
api_contract_path: <repo_root>/.planning/phases/<slug>/api-contract.md  # or null
repo_root: <absolute path>
files:
  - path: <relative path from repo_root>
    action: NUEVO | MODIFICAR
    follow_example: <relative path>
    worker_id: w1
  - ...
verification_commands:                   # from §8 of the spec — language-agnostic, comes from project's task runner
  - cmd: "<verbatim command from project>"
    label: typecheck | tests | lint | format | build | custom
  - ...
max_retries_per_file: 3
budget:
  max_total_tokens: 60000
```

## Execution protocol

### Step 1 — Create worktrees (one per worker)

For each entry in `files`, run:

```bash
git -C <repo_root> worktree add <run_dir>/wt-<worker_id> -b loop-wt-<run_id>-<worker_id> HEAD
```

If the repo isn't a git repo (rare but possible — Mercurial, Fossil, or no VCS), fall back: `cp -r <repo_root> <run_dir>/wt-<worker_id>` and warn in the report that worktree isolation is approximated by copy. NEVER skip isolation entirely — parallel collision is a critical bug.

The worker receives `workdir: <run_dir>/wt-<worker_id>` as its scope.

### Step 2 — Dispatch initial workers (parallel wave)

For each file, dispatch a `worker-dev` sub-agent. Single message, N invocations for true parallelism. Each worker receives the inputs documented in `agents/worker-dev.md` plus its assigned `workdir`.

Workers write ONLY inside their worktree. They do NOT run verification.

### Step 3 — Merge worktrees back

After all workers return, merge changes back to the main checkout:

```bash
# For each worker that wrote files:
git -C <repo_root> checkout -B loop-merge-<run_id> HEAD
# Apply each worker's diff
for wt in <run_dir>/wt-*; do
  git -C <repo_root> apply --3way <(git -C $wt format-patch HEAD~1 --stdout) || \
    error "merge conflict from worker $(basename $wt)"
done
```

If conflicts arise (multiple workers touched the same lines), surface to runtime — this is a triage-level bug (files should have been disjoint), not a self-healing concern. Pause and let the runtime decide.

Common case: workers wrote disjoint files → clean merge.

### Step 4 — Run verification (Bash, language-agnostic)

Execute every `verification_commands[i].cmd` via Bash from `<repo_root>`. Capture stdout, stderr, exit code per command.

For each command:
- `exit_code == 0` → mark `<label>: green`
- `exit_code != 0` → mark `<label>: red` with stderr captured

The verification commands themselves are stack-specific (from §8), but the orchestration here is not. Whether the project runs `npm test`, `pytest`, `cargo test`, `flutter test` or `bundle exec rspec` — the loop is the same.

### Step 5 — If anything is red, dispatch corrective workers

For each red verification:

1. Parse stderr for affected file paths (regex matches per language: `<path>:<line>:<col>` for most; XML-ish for some Java/.NET tooling; Dart uses ` • lib/...`).
2. Identify the responsible worker by file path.
3. Create a FRESH worktree from the latest merged HEAD for that worker:
   ```bash
   git -C <repo_root> worktree remove --force <run_dir>/wt-<worker_id>
   git -C <repo_root> worktree add <run_dir>/wt-<worker_id>-r1 HEAD
   ```
4. Dispatch the corrective `worker-dev` with: the original spec context, the previous attempt's code (the merged HEAD state), the verification command that failed, the full stderr. Workdir is the new retry worktree.
5. Increment per-file retry counter.
6. After all corrective workers return, re-merge worktrees, re-run ALL verification commands (a fix can break a previously-green check).

### Step 6 — Loop (configurable per `.loop/config.yaml`)

Repeat Step 5 until:
- All verifications green → exit success
- Any file hits `max_retries_per_file` → consult `gates.self_healing_exhaust_gate` from the active config:
  - `ask` (default in `balanced`/`high`) → `AskUserQuestion` to user: "Try a different approach" / "Mark file as blocked and continue with others" / "Abort"
  - `escalate_silent` (default in `minimal`) → add the file to STATE `## High Priority (waiting on human)` so next run picks it up; continue with the other files in this run
  - `abort` → stop the phase, mark `status: partial`
- Cumulative tokens exceed `budget.max_total_tokens` → exit budget breach with `status: budget_exhausted`

### Step 7 — Final merge to user-visible branch

Once green, cherry-pick or merge the merged checkout into a branch the user can see:

```bash
git -C <repo_root> branch -f loop/<ticket_id> HEAD
git -C <repo_root> worktree remove --force <run_dir>/wt-*       # cleanup
```

The user's working tree is NOT modified (we never push or checkout). The branch `loop/<ticket_id>` is the artifact.

### Step 8 — Emit self-healing report

Write `run_dir/self-healing-report.md`:

```markdown
## loop-self-healing — Phase output

- Files implemented: <count>
- Initial workers: <N> (parallel wave, each in isolated worktree)
- Total corrective rounds: <N>
- Final verification status: green | red
- Verification matrix:
  | Command | Initial | Round 1 | Round 2 | Round 3 | Final |
  |---|---|---|---|---|---|
  | <typecheck cmd> | red | red | green | — | green |
  | <test cmd> | red | green | green | — | green |
  | <lint cmd> | green | green | green | — | green |
- Per-file retry counts: { w1: 1, w2: 2 }
- Worktrees used: <N>, all cleaned up: yes | no
- Final branch: loop/<ticket_id>
- Tokens used: <N>K
- Final code paths:
  - <path 1>
  - <path 2>
```

Return ONLY the path to this report. Cap reply at 200 words.

## Anti-patterns to avoid (now enforced)

- ~~Letting workers run verification commands themselves~~ → runtime orchestrates verification, workers only write code.
- ~~Re-dispatching ALL workers when one file fails~~ → only the file the error points to gets a corrective dispatch.
- ~~Allowing the worker to refactor unrelated code~~ → explicit instruction "fix ONLY what the error names" prevents scope creep.
- ~~Workers writing to a shared tree~~ → worktree isolation per worker. PARALLEL COLLISION anti-pattern closed.
- ~~Hardcoded npm/Jest commands~~ → all verification commands come from spec §8 / project task runner. STACK-AGNOSTIC.

## Hard rules

- You NEVER write code. Workers do that, in their isolated worktrees.
- You NEVER skip verification. Even after the last corrective round.
- You ALWAYS emit the self-healing-report, even on failure.
- Workers must NOT touch files outside their assigned path.
- Workers must NOT add dependencies (the spec §18 forbids it).
- If repo isn't a git repo, fall back to copy-isolation with a warning — but NEVER skip isolation.
- Verification commands come from the spec. If §8 is empty, abort the phase with `status: missing_verification_commands` — do NOT guess.
