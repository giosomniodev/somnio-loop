# State spine — `.loop/` convention

Tech-agnostic. Works in any repo regardless of language, framework or build tool. Inspired by [cobusgreyling/loop-engineering — STATE.md + LOOP.md + run-log + budget patterns](https://github.com/cobusgreyling/loop-engineering).

## Layout

The plugin owns a single directory at the repo root: `.loop/`. Everything in it is plain text (Markdown / YAML), inspectable without the plugin.

```
<repo_root>/.loop/
├── state.md            ← human-readable durable state (read at run start, written at run end)
├── run-log.md          ← append-only history (one entry per run)
├── budget.md           ← daily/weekly caps + kill switch
├── config.yaml         ← autonomy presets + gate behavior (v0.5.0) — see references/autonomy-config.md
├── traces/             ← machine-readable JSON traces, one per run
│   └── <ts>-<ticket_hash>.json
└── plans/              ← archived plan.yml per run (useful for /loop:improve later)
    └── <ts>-<ticket_hash>.yml
```

If `.loop/` does not exist at run start, the plugin creates it with templates and a one-line note in `state.md` explaining that this is the first run.

## `state.md` schema

```markdown
# Loop state — <project-name>

Last run: <ISO-8601 timestamp>
Last status: completed | partial | aborted
Last readiness level: L1 | L2 | L3

## High Priority (waiting on human)

- [ ] **<ticket_id>** — <one-line summary>. Blocked on: <reason>. Last touched: <ts>.

## Watch List

- **<ticket_id>** — <one-line summary>. Reason: <why we're watching>. Next planned action: <description>.

## Recent Noise (ignored this run)

- <one-line description> — Reason for ignoring: <reason>.

## Conventions snapshot

- project_type: <backend | frontend | mobile | full-stack>
- sub_type: <flutter | react | nestjs | ...>
- spec_dir: <path> (e.g. `.planning/phases/`)
- adr_dir: <path> (e.g. `docs/adr/`)
- task_runner: <Makefile | justfile | npm-scripts | mix | ...>
- verification:
  - lint: <command>
  - typecheck: <command>
  - test: <command>
  - build: <command>
```

The "Conventions snapshot" section is written once per run by the convention discovery phase. It serves as a fast cache so subsequent runs don't re-scan from scratch (they validate it against current files, refresh only on mismatch).

## `run-log.md` schema (append-only)

```markdown
# Run log — <project-name>

## <ISO-8601 timestamp> — <ticket_id>

- **Status:** completed | partial | aborted
- **Readiness level:** L1 | L2 | L3
- **Archetype phases:** <comma-separated list> (e.g. `adr → generate-spec → self-healing → pr-description`)
- **Duration:** <Xm Ys>
- **Tokens:** <N> total — Haiku: <H>, Sonnet: <S>, Opus: <O>
- **Cost estimate:** $<X.XX>
- **Artifacts produced:**
  - <relative path 1>
  - <relative path 2>
- **Verifier blocking findings:** <N>
- **Self-healing retries:** <N>
- **User overrides:** <list> (e.g. "rejected ADR HIGH-conflict gate, continued with risks recorded")
- **Trace:** `.loop/traces/<filename>.json`
- **Plan archive:** `.loop/plans/<filename>.yml`

---
```

Entries are appended at the END of the file. The plugin NEVER edits or deletes existing entries.

## `budget.md` schema

```yaml
# Daily/weekly token + cost caps. Plugin checks this BEFORE every run.
# Kill switch: any field set to 0 disables the plugin until manually reset.

daily:
  max_tokens: 500000
  max_cost_usd: 5.00
  max_runs: 20
weekly:
  max_tokens: 2000000
  max_cost_usd: 25.00
per_run:
  max_tokens: 250000
  max_cost_usd: 3.00
  max_duration_seconds: 1800
kill_switch:
  enabled: false        # set to true to pause the plugin
  reason: ""            # optional explanation
  paused_until: ""      # ISO-8601 timestamp to auto-resume
denylist_paths:
  - .env
  - .env.*
  - secrets/
  - infra/production/
  # ... project-specific additions
```

If `kill_switch.enabled: true`, the plugin shows the reason and refuses to run until disabled. If `paused_until` is set and in the future, the plugin shows time-to-resume.

## Tech-agnostic guarantees

- No file in `.loop/` references a specific language, framework or build tool *structurally*. The CONVENTIONS SNAPSHOT inside `state.md` carries project-specific data, but the schema is generic.
- The plugin reads/writes only via `Read`/`Write`/`Edit` — no language-specific tooling required.
- Both Linux and macOS path conventions work — the plugin uses forward slashes throughout.
- `.loop/` should be added to `.gitignore` UNLESS the team wants to share state across collaborators (then commit it — schema is review-friendly).

## How the plugin uses this

### Triage at run START

1. Read `.loop/state.md` (or create from template if missing).
2. Read tail of `.loop/run-log.md` (last 10 entries) to assess readiness level for this ticket type.
3. Read `.loop/budget.md` and check kill_switch + remaining daily budget.
4. If budget exhausted OR kill_switch enabled → abort with clear message.

### Triage after PLAN emitted

5. Validate emitted plan against `denylist_paths` from `budget.md`. Any worker writing to a denylisted path → reject plan.

### Spec-writer (or last phase) at run END

6. Append entry to `.loop/run-log.md`.
7. Update `.loop/state.md`: move resolved items from "High Priority" to history; add new items to "Watch List" if the run surfaced open questions.
8. Save `trace.json` to `.loop/traces/`.
9. Save the original `plan.yml` to `.loop/plans/`.

This is the "durable spine" — the plugin's memory across sessions. Without it, every run is amnesic.
