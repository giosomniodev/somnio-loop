---
name: loop-adr
description: Internal archetype skill for the somnio-loop plugin. Creates a new Architecture Decision Record (ADR) with codebase gap/trade-off analysis, acceptance criteria derived from existing UAT/test history, sequential numbering, and PR/MR conflict detection. Invoked by loop-runtime as Phase 0 of development tickets that involve a meaningful architectural decision — new technology adoption, API design choices, data model changes, infrastructure decisions, or cross-cutting concerns. The ADR becomes upstream of generate-spec — its `## Decision` populates spec §10 (Decisiones tomadas) as locked input.
---

# loop-adr — Architecture Decision Record generator

This skill is invoked internally by `loop-runtime` as **Phase 0 of any development ticket the triage classifies as containing a meaningful architectural decision**. The user never invokes it directly.

The ADR is the upstream contract for `loop-generate-spec`: the `## Decision` section becomes spec §10 (Decisiones tomadas — locked); the `## Acceptance Criteria` seed the spec §8 tests.

## Inputs (from the runtime)

```yaml
phase: adr
archetype: adr
ticket: "<verbatim ticket text>"
title: "<short imperative phrase, may be inferred from the ticket>"
spec_or_requirement: "<optional context, can be the full ticket body>"
remote_adrs_url: "<optional GitHub/GitLab URL to another repo's docs/adr/>"
repo_url: "<optional GitHub/GitLab URL of the current repo, for PR/MR conflict scan>"
output_lang: "es" | "en"   # inherited from project detection — do NOT ask the user
run_dir: "/tmp/loop-runs/<ts>/"
```

## Execution protocol

Dispatch the `adr-author` sub-agent (Sonnet) with all of the above. It runs the 12 steps below. This skill itself is just the orchestration entry point — the sub-agent does the work.

### Step 1 — Language is INHERITED, do NOT ask

The conversation language and the ADR output language are determined by the project (`CLAUDE.md`, README detection, or the spec already produced upstream). The triage emits `output_lang` in the plan; the ADR sub-agent obeys it. No `AskUserQuestion` call for language.

### Step 2 — Resolve ADR number

**Local:** `Glob` for `<repo_root>/docs/adr/ADR-*.md`. Parse the highest existing NNN and increment by 1. Default to `001` if none exist. Create `docs/adr/` if missing.

**Remote (if `remote_adrs_url` provided):** `WebFetch` the directory listing. For GitHub: `https://api.github.com/repos/<owner>/<repo>/contents/docs/adr` with header `Accept: application/vnd.github+json`. For GitLab: `https://gitlab.com/api/v4/projects/<encoded-path>/repository/tree?path=docs/adr`. Parse filenames to find the highest remote NNN. Use `max(local, remote) + 1`. Fetch the two most recent remote ADRs for style reference; note them in `## Referencias`.

### Step 3 — Slugify title

`<title>` → lowercase, hyphen-separated, ASCII-only. Example: `"Use Redis for session caching"` → `use-redis-for-session-caching`. No spaces, no special characters.

### Step 4 — Discover project conventions (EXPANDED in v0.3.1)

**Goes well beyond stack inference.** The adr-author sub-agent runs a 4-layer scan to extract: tech stack + architectural facts + AI-behavior rules + design conventions + locked decisions. The full procedure is documented in `agents/adr-author.md` Step 3 — the headlines are:

**Layer 1 — Architecture & design docs.** Read every existing file from:
- Root: `CLAUDE.md`, `AGENTS.md`, `AGENT.md`, `ARCHITECTURE.md`, `DESIGN.md`, `CONVENTIONS.md`, `STYLE.md`
- `docs/` variants of the above + `docs/COMPONENTS.md`, `docs/PATTERNS.md`, `docs/STATE.md`, `docs/FRONTEND.md`, `docs/MOBILE.md`, `docs/BACKEND.md`
- Nested: `**/CLAUDE.md` (per-package memory)
- `.claude/CLAUDE.md`

**Layer 2 — AI-behavior rules files (`.rules` family).** These often encode locked architectural decisions. Read every existing file from:
- `.cursorrules`, `.cursor/rules/**/*.mdc`
- `.windsurfrules`, `.windsurf/rules/**`
- `.clinerules`, `.clinerules-*`
- `.roorules`, `.roo/rules/**`
- `.aider.conf.yml`, `.aider.conf.yaml`
- `.github/copilot-instructions.md`
- `.continue/config.json`

Treat each rule as a constraint on `## Alternatives Considered`. Alternatives that violate explicit rules are listed but marked "rejected by project rule: <source>:<line>".

**Layer 3 — Ticket classification.** Determine `<project_type>` (backend / frontend / mobile / full-stack) and `<sub_type>` (e.g. flutter, react, nestjs) from manifests + folder structure + ticket text. The sub_type drives Layer 4.

**Layer 4 — Type-specific deep-scan.**
- Frontend: tailwind.config, Storybook config, design tokens, state-mgmt deps (redux/zustand/jotai/tanstack-query), routing deps, form/validation deps, component library detection (shadcn/mui/chakra/radix/headlessui).
- Mobile Flutter: pubspec.yaml versions (bloc/riverpod/provider/go_router/dio), analysis_options.yaml, state pattern in `lib/`, navigation pattern, platform plugins.
- Mobile RN/Expo: app.json, react-navigation vs expo-router, EAS config, metro customs.
- Backend: Prisma/TypeORM/SQLAlchemy schemas, OpenAPI/GraphQL/tRPC, auth middleware/guards, observability deps.

**Output: `<conventions>` dictionary** held in memory (NOT written to disk; consumed directly by Steps 5–11):

```yaml
project_type: mobile | frontend | backend | full-stack
sub_type: flutter | react | nestjs | ...
stack:
  language: <name + version cite>
  framework: <name + version cite>
  key_deps: { name: version, ... }   # all cited
architecture_facts:
  - "<fact citing existing code path>"
ai_rules:
  - source: <.cursorrules | AGENTS.md | etc.>:<line>
    rule: "<the rule verbatim>"
design_conventions:
  styling: <tailwind | css-modules | ...>
  components_lib: <shadcn | mui | ...>
  state_mgmt: <redux | riverpod | bloc | ...>
  navigation: <react-router | go_router | ...>
locked_decisions:
  - "<decision (per <file>:<line>)>"
```

**Why this matters for the ADR.** Without Layer 2 (rules) the ADR is blind to encoded decisions and may propose alternatives that violate documented constraints. Without Layer 3 (classification) the ADR scans generic patterns instead of frontend/mobile-specific ones. Without Layer 4 (deep scan) the ADR misses state-management / navigation / component library specifics — exactly the dimensions most ADRs are actually about.

**Hard rule:** if `ai_rules` contains a rule that contradicts the proposed decision, the adr-author MUST trigger Phase E (human-in-the-loop) — never silently override a documented rule.

If LITERALLY NONE of the convention files exist, fall back to the v0.3.0 behavior (infer stack from manifests only) and flag `## Technical Gaps`: *"Project has no architecture docs or `.rules` files — recommend adding `CLAUDE.md` or `AGENTS.md` to encode decisions."*

### Step 5 — Analyze codebase against the decision

Using the targets from Step 4:

a. **Dependency/technology scan** — `Grep` decision keywords across dependency manifests, schema files, infrastructure files. Identify present-vs-new.

b. **Pattern conflict scan** — Extract 3–6 domain keywords from title + ticket. Examples: cache → `cache`, `TTL`, `eviction`, `Redis`; auth → `guard`, `jwt`, `session`, `token`. `Grep` across source root. List every hit with a one-line snippet. Flag cross-module hits as boundary risks.

c. **Module boundary check** — `Bash ls` source root top-level dirs. For each dir matching keywords from (b), verify whether the decision crosses ownership boundaries. Flag each crossing.

d. **Test/UAT history scan** — `Grep` test files for decision keywords. List: file path, `describe` label, `it` label per match. These seed the acceptance criteria.

Produce three structured lists for the sub-agent's working notes:
- Trade-offs identified — `[option A vs option B]: <impact>`
- Technical gaps — `[gap]: <what must be built or clarified first>`
- Affected tests — file path + test descriptions

### Step 6 — Find related local ADRs

`Glob` `<repo_root>/docs/adr/ADR-*.md`. `Grep` each file for keywords from title + ticket. Rank by hit count. Top 5 go into `## Referencias` / `## Links`.

### Step 7 — Build acceptance criteria (Given/When/Then)

From Step 5d + the ticket, derive SMART criteria:

```
GIVEN <precondition>
WHEN <action>
THEN <expected outcome>
```

For each criterion, link to an existing test if found (`[existing-test: path/to/spec]`) or mark `[to be validated]`.

### Step 8 — ADR template (bilingual)

Use the template appropriate to `output_lang`. Both variants are in `references/adr-template.md` if present; otherwise the sub-agent builds from the structure below.

#### English template

```markdown
# ADR-NNN: <Title>

- **Status**: proposed
- **Date**: <YYYY-MM-DD>
- **Deciders**: <from Step 10 git log>
- **Tags**: <keywords>
- **Stack**: <technologies detected in Step 4>

## Context
<Problem or situation. Cite codebase facts from Step 5.>

## Decision
<Chosen option. One paragraph.>

## Alternatives Considered
| Option | Pros | Cons | Fit with detected stack |
|--------|------|------|------------------------|
| A | ... | ... | ... |
| B | ... | ... | ... |

## Trade-offs
- **[dimension]**: <A> gives <benefit> at cost of <downside> vs <B>

## Technical Gaps
- [ ] **[gap]**: <description> — Owner: TBD

## Acceptance Criteria
- [ ] GIVEN ... WHEN ... THEN ... `[existing-test: path]`
- [ ] GIVEN ... WHEN ... THEN ... `[to be validated]`

## Consequences
### Positive
-
### Negative
-
### Neutral
-

## PR / Branch Conflicts
<table from Step 9>

## Links
- Related ADR: ...
- Remote ref: ...
- Upstream ticket: <run_dir>/ticket.txt
```

#### Spanish template

Same structure with translated headings:
- Context → Contexto · Decision → Decisión · Alternatives Considered → Alternativas Consideradas · Trade-offs → Compensaciones · Technical Gaps → Brechas Técnicas · Acceptance Criteria → Criterios de Aceptación · Consequences → Consecuencias · PR / Branch Conflicts → Conflictos con PRs/Ramas · Links → Referencias

### Step 9 — Detect PR / MR conflicts

Runs if `repo_url` provided, OR if `git remote get-url origin` yields a usable URL. Normalize SSH (`git@github.com:org/repo.git`) to HTTPS. Detect platform.

**GitHub:** `WebFetch` `/repos/<owner>/<repo>/pulls?state=open&per_page=50` + `compare/main...develop` (fallback `master...develop`).
**GitLab:** `WebFetch` `/projects/<encoded>/merge_requests?state=opened` + `compare?from=main&to=develop`.

**Collision scoring:** for each open PR/MR and develop-only commit, extract title+description keywords, cross-match against ticket keywords. Score: **HIGH** (3+ matches), **MEDIUM** (1–2), **NONE**.

Risk types for non-zero overlap: *Duplicate intent · Conflicting approach · Shared files · Dependency order*.

Output table goes into `## PR / Branch Conflicts` section.

### Step 10 — Infer Deciders from git

`Bash git log --format="%an" -10 | sort | uniq -c | sort -rn | head -5`. Populate `## Deciders` with top contributors. Leave one slot as `<author>` for the person running the plugin.

### Step 11 — Write the ADR file

Write `<repo_root>/docs/adr/ADR-NNN-<slug>.md`. All sections populated from Steps 5–10. NO `[...]` placeholders. NO orphan headings — sections that genuinely don't apply get `No aplica — <reason>` / `Not applicable — <reason>`.

### Step 12 — Emit phase report

Write `run_dir/loop-adr-report.md`:

```markdown
## loop-adr — Phase 0 output

- ADR file: <repo_root>/docs/adr/ADR-NNN-<slug>.md
- Number: NNN (local max was M, remote max was K)
- Language: es | en
- Stack detected from: CLAUDE.md | ARCHITECTURE.md | manifest inference
- Trade-offs surfaced: <count>
- Technical gaps surfaced: <count> (BLOCKING if any are prerequisites for implementation)
- Acceptance criteria: <count> (<X> from existing tests, <Y> to validate)
- Related local ADRs: <count>
- Remote ADRs imported: <count>
- PR/MR conflicts: <HIGH count> HIGH, <MEDIUM count> MEDIUM
- Decision summary (for spec §10): "<one-paragraph version of ## Decision>"
```

Return ONLY the path to this report and the path to the ADR. Cap reply at 250 words.

## Composition with downstream phases

When `loop-runtime` sees a successful `loop-adr` report:

- The `## Decision` section becomes the spec §10 (Decisiones tomadas) — **locked**, the implementer cannot change it.
- The `## Acceptance Criteria` seed spec §8 (Tests requeridos) and §11 (Edge cases).
- The `## Technical Gaps` populate spec §4 (Dependencias previas) as blocking prerequisites.
- The `## PR / Branch Conflicts` HIGH-overlap entries become spec §18 (Restrictions) — implementer is told NOT to touch overlapping branches' files.
- The PR description (Phase 3 dev-mode spec-writer) **always** links the ADR by relative path.

If `loop-adr` reports `HIGH` conflicts, the runtime consults `.loop/config.yaml` `gates.adr_conflict_gate.on_high_conflict` (v0.5.0):

- `ask` → `AskUserQuestion`: *"Detecté N PRs en conflicto con esta decisión. ¿Pauso / continúo con registro / abort?"* (Default in `balanced` and `high`.)
- `proceed_with_record` → log conflicts in the ADR's `## PR / Branch Conflicts` section, add a Watch List item in `.loop/state.md` for human follow-up, continue. (Default in `minimal`.)
- `abort` → stop the run cleanly.

If the ticket proposes an alternative that violates a documented `ai_rule` (Phase E rule-violation gate), the config consulted is `gates.adr_rule_violation_gate.on_violation`:

- `ask` → present the conflict with 3 options: `Override the rule (and propose updating .rules)` / `Pick a different alternative` / `Abort the ADR`.
- `abort` → stop the run cleanly. No silent overrides EVER.

Note: `on_violation` cannot be set to `proceed` — overriding a documented rule must always be a deliberate human act, regardless of autonomy preset. This is enforced as a non-negotiable safety floor.

## Hard rules

- NEVER ask the user for `output_lang` — inherit from project detection.
- NEVER touch existing ADRs. Only add the new NNN. ADRs are append-only history.
- NEVER invent versions, packages, file paths, or test names in `## Context`. Cite Step 5 findings only.
- NEVER mark a Status higher than `proposed` — humans accept ADRs through review, not the plugin.
- If git remote auto-detection fails AND no `repo_url` provided, skip Step 9 with `## PR / Branch Conflicts` = `Conflict scan skipped — no repo URL available.` Do NOT invent conflicts.
- Numbering is monotonic. If between fetch-and-write someone else added ADR-N+1, retry the fetch and increment.
