---
name: loop-generate-spec
description: Turn a raw feature idea or development ticket into a complete 20-section spec validated by a Sonnet judge. Invoked internally by the loop-runtime as Phase 1 of development tickets — never produces code. Composes spec-refiner (Haiku) + 20-section canonical template at references/spec-template.md + spec-validator (Sonnet) with PASS / PASS_WITH_WARNINGS / BLOCK verdict. Writes the spec under .planning/phases/[slug]/spec.md plus api-contract.md when an API surface exists. Use when the development triage detects "feature implementation" archetype.
---

# loop-generate-spec — Raw idea → validated 20-section spec

This skill is invoked internally by `loop-runtime` as **Phase 1 of any development ticket**. Its output is a validated spec that the implementation workers in Phase 2 will treat as the contract.

**Hard rule: NEVER implement code.** Stop after the validated spec is written.

## Inputs

- `raw_idea` — the ticket text verbatim
- `run_dir` — where intermediates go (`/tmp/loop-runs/<ts>/`)
- `repo_root` — absolute path to the project root (must contain `.planning/`)
- `adr_decision_summary` — *(optional, from upstream Phase 0)* — one-paragraph extract of the ADR's `## Decision`. If present, this MUST be transcribed verbatim into spec §10 (Decisiones tomadas) as the locked decision. The implementer cannot override it.
- `adr_acceptance_seeds` — *(optional)* — bullet list from the ADR's `## Acceptance Criteria`. Seed spec §8 (Tests requeridos) and §11 (Edge cases) with these.
- `adr_technical_gaps` — *(optional)* — list of items from the ADR's `## Technical Gaps`. Each becomes a checkbox in spec §4 (Dependencias previas) marked **BLOCKING** until resolved.
- `adr_path` — *(optional)* — relative path to the ADR file from repo root, e.g. `docs/adr/ADR-005-use-redis-for-session-caching.md`. Reference in spec §10 as `Ver ADR-005`.

## Execution protocol

### Step 1 — Lock the ticket

Read `raw_idea`. Restate in one sentence what is being built. Hold it as `LOCKED_IDEA`. No clarifying questions yet.

### Step 2 — Detect or create the spec location

This plugin uses the `.planning/` convention by default:

- Target dir: `<repo_root>/.planning/phases/<slug>/`
- Spec filename: `spec.md`
- API contract: `api-contract.md` (same dir, when applicable)

If `<repo_root>/.planning/` does NOT exist, create it. If `<repo_root>/.planning/phases/` does NOT exist, create it. If a sibling spec already exists in `.planning/phases/*/spec.md`, read the most recent one as `SPEC_EXAMPLE_BODY` for style mirroring. Otherwise the canonical template at `references/spec-template.md` is the only style anchor.

Detect spec language: scan `SPEC_EXAMPLE_BODY` + project `README.md`. ≥60% in one non-English language → use it. Otherwise English. State the detection: `Spec language: <lang> (<evidence>)`.

### Step 3 — Refine the idea (Haiku sub-agent)

Invoke the `spec-refiner` sub-agent (Haiku, read-only) with: `LOCKED_IDEA`, `SPEC_EXAMPLE_BODY` (if found), the canonical template at `references/spec-template.md`, AND the `<conventions>` dictionary if Phase 0 ran (otherwise the spec-refiner produces its own via the same 4-layer discovery documented in `agents/spec-refiner.md`).

In v0.3.1, the spec-refiner reads the `.rules` family (`.cursorrules`, `.windsurfrules`, `.clinerules`, `.roorules`, `.aider.conf.yml`, `.github/copilot-instructions.md`, etc.) plus all architecture/design docs (root + `docs/`) plus per-sub-type deep-scan (frontend → component lib + state mgmt; mobile → pubspec/app.json deep-read; backend → ORM/API schema). The brief includes a new `provided_by_conventions` status for sections already settled by the project's documented rules — those sections SKIP the user clarification step (no point asking for something already documented).

### Step 4 — Clarify with the user (configurable per `.loop/config.yaml`)

Walk every section in `BRIEF`. For each:

- **Resolved** = concrete content (real paths, version pins, named behaviors)
- **Provided_by_conventions** (v0.3.1) = settled by CLAUDE.md / `.rules` / manifest discovery; cite source, no question
- **Unresolved** = vague, TBD, generic phrases ("follow existing patterns", "handle errors gracefully")

For Unresolved sections, consult `gates.spec_clarification_gate` from the active config:

- `ask` (default in `balanced`/`high`) → batch up to `max_questions` per `AskUserQuestion` call. Keep asking until every Unresolved section is resolved OR user says stop.
- `use_defaults_and_flag` (default in `minimal`) → mark each Unresolved section as `TBD — ver Open questions` immediately. No clarification call. The §20 checklist explicitly lists every TBD so the implementer knows what's missing.
- `abort` → if the count of Unresolved sections exceeds `max_questions`, stop the run with `status: spec_blocked`. Useful for `custom` policies that want guaranteed full specs or abort.

The `max_questions` limit applies in `ask` mode too — if Unresolved count exceeds it, batch the most important questions first (those that affect §3 stack, §4 prerequisites, §6 files, §8 verification commands) and mark the rest as TBD.

### Step 5 — Compose the spec

Read `references/spec-template.md`. Write all 20 sections in order to `<repo_root>/.planning/phases/<slug>/spec.md`. Mirror tone, heading depth, bullet style from `SPEC_EXAMPLE_BODY` when present.

**Do not leave raw `[...]` placeholders.** Replace every placeholder with verified content or `TBD — ver Open questions`. If a section truly does not apply, keep its heading and write `No aplica — <reason>`.

When section 7 (API Contract) has real API surface, write a separate `api-contract.md` next to the spec. One section per endpoint with: HTTP method, URL, auth, request body schema, success response schema + status code, error response schemas + status codes + error codes.

### Step 6 — Validate (Sonnet sub-agent)

Invoke the `spec-validator` sub-agent (Sonnet, read-only) with: absolute path to the new spec, absolute path to `api-contract.md` (or `no aplica`), `SPEC_EXAMPLE_PATH` (if any), the 20-section checklist verbatim.

The validator returns a structured report with:

- **Verdict**: `PASS` | `PASS_WITH_WARNINGS` | `BLOCK`
- **Per-section scores**: `PASS` | `WEAK` | `MISSING`
- **Required fixes** (for BLOCK)
- **Suggested improvements** (for WARNINGS)
- **Style divergences** from the example

### Step 7 — React to the verdict

- **PASS** → emit `loop-generate-spec-report.md` and return.
- **PASS_WITH_WARNINGS** → ask the user: `Address now` / `Keep as-is`. If addressed, fix and re-validate.
- **BLOCK** → fix required items (ask user for missing info OR rewrite directly). Re-validate. **Cap at 3 re-validation cycles.** If still blocked after 3, write the final validator report and stop with `status: blocked` — do NOT return success.

### Step 8 — Emit report

Write `run_dir/loop-generate-spec-report.md`:

```markdown
## loop-generate-spec — Phase 1 output

- Slug: <kebab-case>
- Spec path: <repo_root>/.planning/phases/<slug>/spec.md
- API contract: <path> | no aplica
- Validator verdict: PASS | PASS_WITH_WARNINGS | BLOCK
- Re-validation cycles used: <N>/3
- Open questions: <count>
- Tokens used: <N>K (refiner Haiku + validator Sonnet + compose)

Sections requiring follow-up:
- <list of TBD sections, if any>
```

Return ONLY the path to this report. Cap reply at 200 words.

## Hard rules

- NEVER edit application code. Tools available are `Read`/`Grep`/`Glob`/`Bash`/`Write`/`Edit` — Write/Edit ONLY for spec files, `api-contract.md`, and `.planning/` scaffolding.
- NEVER skip the validator. The spec is not "done" without `PASS` or `PASS_WITH_WARNINGS`.
- NEVER invoke implementation-route skills (anything that writes code).
- If the user can't or won't provide a missing prerequisite, mark it `TBD` and surface in section §20 open questions — do NOT invent.
- Slugs and filenames are always English kebab-case, regardless of spec language.
