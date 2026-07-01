# Autonomy + MCP config — `.loop/config.yaml`

Lives at `<repo_root>/.loop/config.yaml`. Created from template on first run. Edited by humans, read by the plugin at every Phase -1.

> v0.6.0 added the `mcp_integrations` section + 3 new gates (`ticket_status_update_gate`, `pr_creation_gate`, `notification_gate`). See `references/mcp-integrations.md` for the schema and adapter patterns. This document covers only the autonomy/gates portion.

## TL;DR

- `autonomy.preset` is the ONLY dial you usually need. Three values cover 99% of cases: `minimal` (autonomous), `balanced` (safe default), `high` (max friction). Plus `custom` for fine control.
- **Presets are self-contained (v0.8.2).** Setting `preset: minimal` implies ALL gate defaults for minimal. You do NOT need to spell out each gate — the preset knows.
- 6 named gates exist internally but you only touch them when using `preset: custom`.
- Observability is ALWAYS ON regardless of preset — surfacing lines, per-agent consumption table, run-report, STATE updates. Not configurable, always present.
- Override per-run via the ticket text: `do "ticket... --autonomy=minimal"`.
- 4 hard rules NEVER bend regardless of config: no auto-merge PRs, no push to main, no touching denylist paths, no overriding documented `.rules` violations silently.

## Minimal viable config (v0.8.2)

If your project uses Jira + GitHub, this 10-line config is complete:

```yaml
# .loop/config.yaml
autonomy:
  preset: minimal

mcp_integrations:
  ticket_source:
    type: jira
    project_key: "MH"

  pr_target:
    type: github
    owner: "your-org"
    repo: "your-repo"
    base_branch: "develop"
```

That's it. The `preset: minimal` line implies all six gate defaults (proceed / auto_fix / use_defaults_and_flag / etc.). MCP fields describe your project. Observability is on by default.

If you want the safer default behavior instead, change `preset: minimal` to `preset: balanced` (or omit it entirely — balanced is the built-in default).

## Preset self-contained defaults

Setting `preset: <name>` implies these gate values. You do NOT need to write them out.

| Gate | `minimal` | `balanced` (default) | `high` |
|---|---|---|---|
| `budget_gate.on_exceed` | `proceed` | `ask` | `ask` |
| `budget_gate.threshold_usd` | 5.00 | 1.50 | 0.50 |
| `verifier_blocking_gate.on_blocking` | `auto_fix` (max 2 retries) | `ask` | `ask` |
| `adr_conflict_gate.on_high_conflict` | `proceed_with_record` | `ask` | `ask` |
| `adr_rule_violation_gate.on_violation` | `ask` (safety floor) | `ask` | `ask` |
| `spec_clarification_gate.on_gaps` | `use_defaults_and_flag` | `ask` (max 5) | `ask` (max 10) |
| `spec_clarification_gate.max_questions` | 0 | 5 | 10 |
| `self_healing_exhaust_gate.on_exhausted` | `escalate_silent` | `ask` | `ask` |
| `ticket_status_update_gate.on_complete` | `proceed` | `ask` | `ask` |
| `pr_creation_gate.on_ready` | `proceed` (draft only) | `ask` | `ask` |
| `notification_gate.enabled` | `false` (opt-in) | `false` | `false` |
| Approval before every write | no | no | **yes** |
| "Continue?" after each phase | no | no | **yes** |

Override individually only with `preset: custom` (see below).

## Schema

```yaml
# .loop/config.yaml
autonomy:
  preset: balanced     # minimal | balanced | high | custom

# Gate-by-gate behavior. The preset above sets these defaults; you can override individually.
gates:
  budget_gate:
    enabled: true
    threshold_tokens: 200000
    threshold_usd: 1.50
    on_exceed: ask                    # ask | proceed | abort

  verifier_blocking_gate:
    enabled: true
    on_blocking: ask                  # ask | auto_fix | proceed_with_warnings | abort
    auto_fix_max_retries: 2

  adr_conflict_gate:
    enabled: true
    on_high_conflict: ask             # ask | proceed_with_record | abort

  adr_rule_violation_gate:
    enabled: true
    on_violation: ask                 # ask | abort
                                      # NEVER "proceed" — rules are non-negotiable

  spec_clarification_gate:
    enabled: true
    on_gaps: ask                      # ask | use_defaults_and_flag | abort
    max_questions: 5

  self_healing_exhaust_gate:
    enabled: true
    on_exhausted: ask                 # ask | escalate_silent | abort

# Non-negotiable safety. NEVER editable regardless of preset.
hard_rules:
  - never_auto_merge_prs
  - never_push_to_main
  - never_touch_denylist_paths
  - never_override_documented_rules_silently
```

## Presets

### `minimal` — maximum autonomy

The plugin will only stop for things the human cannot delegate.

```yaml
autonomy:
  preset: minimal
gates:
  budget_gate:           { on_exceed: proceed }                     # spend up to global cap, no ask
  verifier_blocking_gate:{ on_blocking: auto_fix, auto_fix_max_retries: 2 }
                                                                    # try to fix, then warn
  adr_conflict_gate:     { on_high_conflict: proceed_with_record }
                                                                    # PR conflicts logged in ADR, run continues
  adr_rule_violation_gate:{ on_violation: abort }                   # rules still untouchable
  spec_clarification_gate:{ on_gaps: use_defaults_and_flag }
                                                                    # marks gaps TBD, doesn't ask
  self_healing_exhaust_gate:{ on_exhausted: escalate_silent }
                                                                    # records in STATE, doesn't ask
```

**Use when:** trivial tickets you've run dozens of times, batch processing, after a calibration period of `balanced` runs.

### `balanced` — default

What v0.4.x shipped. Asks when human judgment adds value, proceeds when not.

```yaml
autonomy:
  preset: balanced
gates:
  budget_gate:           { on_exceed: ask }
  verifier_blocking_gate:{ on_blocking: ask }
  adr_conflict_gate:     { on_high_conflict: ask }
  adr_rule_violation_gate:{ on_violation: ask }
  spec_clarification_gate:{ on_gaps: ask, max_questions: 5 }
  self_healing_exhaust_gate:{ on_exhausted: ask }
```

**Use when:** new project or new ticket archetype. First weeks of using the plugin in production.

### `high` — maximum human-in-the-loop

For sensitive areas (auth, billing, infra) where you'd rather pause more often.

```yaml
autonomy:
  preset: high
# Inherits all "ask" gates from balanced PLUS:
extras:
  approval_before_every_write: true     # like L1 but with writes after explicit OK
  max_questions: 10                     # spec-refiner can probe deeper
  require_user_confirmation_per_phase: true  # ask "continue?" after each phase
```

**Use when:** the ticket touches money flows, identity, customer data, production infra, regulatory compliance.

## Per-run override

Append to the ticket text:

```
do "Migrar auth a Riverpod 2 con tests --autonomy=minimal"
do "Cambiar pricing engine --autonomy=high"
do "Audit security of session module --autonomy=balanced"
```

The override applies ONLY to that run. Config file untouched. Useful when you trust this specific ticket but generally prefer a different stance.

## Surfacing in chat

`do` Phase 1 announces the active autonomy alongside the readiness level:

```
🎚 Readiness level: L2 (assisted)
🎛 Autonomy: minimal (override por --autonomy=minimal en el ticket)
```

If preset is `custom`, the chat shows which gates are non-default:

```
🎛 Autonomy: custom (verifier_blocking_gate=auto_fix, others=default balanced)
```

## Gate decision table

Each gate's `on_*` value determines behavior when triggered:

| Action | Behavior |
|---|---|
| `ask` | `AskUserQuestion` with 2–3 options. Run pauses. |
| `proceed` | Continue with default safe path. Record decision in run-report. |
| `proceed_with_record` | Continue but escalate to STATE Watch List for human review later. |
| `proceed_with_warnings` | Continue, mark the run as `status: partial` in run-log. |
| `auto_fix` | Try corrective dispatch (e.g. fix-failing-tests worker). Capped at `auto_fix_max_retries`. |
| `escalate_silent` | Don't ask, don't fix; add to STATE High Priority for next run. |
| `abort` | Stop the run, mark `status: aborted` in run-log, surface reason. |

## Migration from v0.4.x

If `.loop/config.yaml` doesn't exist when v0.5.0 boots, the plugin creates it with `preset: balanced`. Behavior is identical to v0.4.x. Zero breakage.

## What CANNOT be configured (safety floor)

Even `preset: minimal` honors these:

1. **No auto-merge PRs.** EVER. The plugin produces a branch + PR description; humans merge.
2. **No push to `main` / `master` / `production` / protected branches.** EVER.
3. **No writes to `.loop/budget.md` denylist paths.** EVER. Denylist is enforced by every worker before any Write.
4. **No silent override of documented `.rules` violations.** `adr_rule_violation_gate.on_violation` can only be `ask` or `abort`. If you want to bypass a rule, edit the `.rules` file first (a separate, deliberate act).

These four floors prevent autonomy from becoming recklessness.
