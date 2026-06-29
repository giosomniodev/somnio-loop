# somnio-loop — v0.7.0

**Tomá un ticket (por ID o por texto), de cualquier source (Jira / Linear / GitHub Issues / pegado a mano). El plugin lo fetchea, lo ejecuta de punta a punta con la autonomía que VOS elegís, opcionalmente crea el PR draft y actualiza el status — sin tocar nada que no debas tocar.**

## Changelog v0.7.0 — Rebrand a Somnio

Renombrado del plugin y del entry point. **Breaking change** (la invocación cambia), pero la funcionalidad y la arquitectura quedan idénticas a v0.6.0.

| Antes (v0.6.0) | Ahora (v0.7.0) |
|---|---|
| Plugin: `loop-engineering` | Plugin: `somnio-loop` |
| Author: `Giolabs` | Author: `Somnio` |
| Entry skill: `loop-do` | Entry skill: `do` |
| Invocación: `loop-engineering:loop-do TKT-123` | Invocación: `somnio-loop:do TKT-123` |

Las **skills internas mantienen sus nombres** (`loop-orchestrator`, `loop-plan-execute`, `loop-self-healing`, `loop-generate-spec`, `loop-adr`) — esas no son user-facing, las invoca el runtime internamente. La disciplina sigue siendo "Loop Engineering" (concepto inspirado en Cobus Greyling, Addy Osmani, Boris Cherny / Anthropic).

### Cómo invocás ahora

```
# Por ticket ID (si Jira/GitHub MCP está configurado)
somnio-loop:do TKT-123

# Por texto pegado
somnio-loop:do "Investigá X y entregame Y"

# Con override de autonomía
somnio-loop:do TKT-123 --autonomy=minimal
```

En Claude Code, si no hay colisión, también funciona invocación corta:

```
do TKT-123
```

### Por qué la rebrand

`somnio-loop` es el nombre del producto de Somnio. La disciplina "Loop Engineering" sigue siendo la base teórica del plugin — solo cambia el nombre del paquete y del owner.

### Migration desde v0.6.0

Si tenías invocaciones guardadas (en docs, scripts, slash commands custom):
- Buscá `loop-engineering:` → reemplazá por `somnio-loop:`
- Buscá `loop-do` (como comando) → reemplazá por `do`
- `.loop/config.yaml` queda EXACTAMENTE igual — schema no cambia
- `.loop/state.md` y `.loop/run-log.md` quedan idénticos — no hay migración de datos

## Changelog v0.6.0

**Integración con MCPs de Jira, GitHub Issues, Linear, GitHub PRs, GitLab MRs, Slack/Teams** — sin bundlear ningún MCP propio. El plugin descubre via `ToolSearch` lo que el usuario ya tenga conectado a Claude Code y se adapta. Cero si no hay nada conectado (fallback a manual).

### Tres puntos de integración

| Integración | Para qué | Tools que busca |
|---|---|---|
| **Ticket source** | Fetch del ticket por ID (`do TKT-123` en vez de pegar texto) | Jira (Atlassian Remote), Linear, GitHub Issues, GitLab Issues |
| **PR target** | Crear PR draft post-self-healing | GitHub, GitLab |
| **Notification** | Postear resumen del run a un canal | Slack, Teams, Discord |

### Cómo se configura

`.loop/config.yaml` suma una sección nueva:

```yaml
mcp_integrations:
  ticket_source:
    type: jira | linear | github_issues | gitlab_issues | none
    cloud_id: "abc-123-..."          # Jira/Atlassian — auto-discovered si vacío
    project_key: "PROJ"
    update_status_on_complete: true
    status_in_review: "In Review"
    custom_field_acceptance_criteria: "customfield_10001"
  pr_target:
    type: github | gitlab | none
    owner: "myorg"
    repo: "myrepo"
    base_branch: "main"
    draft_default: true              # siempre true (safety floor)
    pr_template_path: ".github/pull_request_template.md"
  notification:
    type: slack | teams | discord | none
    channel: "#dev-loops"
    notify_on: [completed, partial, aborted]
```

Si la sección no existe o tiene `type: none`, el plugin funciona exactamente como v0.5.0 (manual).

### Tres nuevos gates

```yaml
gates:
  ticket_status_update_gate:
    on_complete: ask | proceed | proceed_with_record | skip
  pr_creation_gate:
    on_ready: ask | proceed | skip      # `proceed` siempre crea DRAFT
  notification_gate:
    enabled: false                       # off por default
    on_complete: proceed | skip
```

Con `preset: minimal`: todos `proceed`. Con `balanced`: todos `ask`. Con `high`: todos `ask` + PR siempre draft.

### Flow nuevo: ticket por ID

Antes (v0.5.0):
```
do "Migrar auth a Riverpod 2. Acceptance criteria: ..."
```

Ahora (v0.6.0):
```
do TKT-123
```

El plugin:
1. Detecta que es un ID
2. Lee `mcp_integrations.ticket_source` → tipo Jira
3. `ToolSearch` por `jira issue get` → cachea `mcp__atlassian__getJiraIssue`
4. Fetchea el ticket completo (summary + description + custom fields de acceptance criteria + labels)
5. Surface: `🎫 Ticket fetched from jira: TKT-123 — "Migrar auth a Riverpod 2"`
6. Sigue el flow normal

Si el fetch falla (network, auth, MCP offline), te pide el texto del ticket manualmente — nunca aborta silenciosamente.

### Flow nuevo: PR creation gated

Después de que self-healing entrega verde, en Phase 7b:

- `gates.pr_creation_gate.on_ready: proceed` → llama a `mcp__github__create_pull_request` con la branch `loop/TKT-123`, el `PR_DESCRIPTION.md` como body, **`draft: true`** (no negociable).
- Captura la URL y la imprime en el resumen: `🌿 PR: https://github.com/owner/repo/pull/456`
- Si hay un `pr_template_path` configurado, el spec-writer dev-mode usa SU estructura en vez de la canónica.

### Flow nuevo: ticket status update gated

Después de crear el PR (o si no se creó pero el run completó):

- `gates.ticket_status_update_gate.on_complete: proceed` →
  1. Cambia el status del ticket a `status_in_review` (NUNCA a "Done" / "Closed" — humanos cierran)
  2. Postea comentario con: resumen ejecutivo + tabla de consumo + link al PR + link al ADR
- Surface: `🎫 Ticket TKT-123: In Progress → In Review`

### Flow nuevo: ADR conflict detection upgraded

Antes (v0.3): ADR Step 9 usaba `WebFetch` directo a `/repos/{owner}/{repo}/pulls?state=open`.

Ahora (v0.6.0): prefiere `mcp__github__list_pull_requests` si está disponible — mejores rate limits, auth correcta, puede fetchear diffs para detectar overlap a nivel archivo. Fallback a WebFetch si MCP no está.

### Safety floor (NO negociable, incluso en minimal)

1. **PR siempre DRAFT por default.** Vos marcás "ready for review" manualmente.
2. **Nunca `--auto-merge`, `gh pr merge`, equivalente.**
3. **Nunca push a `main` / `master` / `production` / `release/*`.**
4. **Nunca delete branches.** Cleanup es opt-in via hooks que vos controlás.
5. **Nunca status a "Done" / "Closed" / "Resolved" automáticamente.** Máximo `status_in_review`.
6. **Ticket fetch failures NO son fatales** salvo `required: true`. Siempre podés pegar el texto manual.

### Lo que NO bundlea el plugin

- Ningún MCP server propio. Vos configurás Jira / GitHub / Linear / Slack en Claude Code via `claude mcp add ...` (o vía Anthropic Remote MCPs si están disponibles).
- Si no tenés nada conectado: cero pérdida. El plugin sigue funcionando manual igual que v0.5.0.

### Nuevos archivos

- `references/mcp-integrations.md` — schema completo + patterns de discovery + adapters por vendor (Atlassian Remote, Linear, GitHub, GitLab)

### Archivos cambiados

- `skills/do/SKILL.md` — Phase -1 suma discovery + ticket fetch; Phase 7 suma 7b (PR) + 7c (status) + 7d (notification); resumen suma 🎫 / 🌿 / 💬 lines
- `agents/adr-author.md` — Step 9 prefiere GitHub MCP sobre WebFetch
- `agents/spec-writer.md` — dev-mode lee `pr_template_path` y respeta estructura del template del proyecto
- `references/autonomy-config.md` — nota cross-reference a mcp-integrations.md

### Migration de v0.5.0

Cero acción requerida. Sin `mcp_integrations` en config = manual mode = v0.5.0 idéntico. Para empezar a usar:

```bash
# 1. Conectá tus MCPs a Claude Code (uno a uno)
claude mcp add atlassian-remote https://mcp.atlassian.com/...
claude mcp add github https://...

# 2. Editá .loop/config.yaml y declará types
# 3. Próximo do detecta y usa
```

## Changelog v0.5.0

**Autonomy configurable.** Los 6 gates del plugin (budget, verifier blocking, ADR conflicts, ADR rule violations, spec clarifications, self-healing exhaust) ahora se controlan desde `.loop/config.yaml` con 3 presets + custom. Override por ticket con `--autonomy=X`.

### Los 3 presets

| Preset | Cuándo usar | Comportamiento |
|---|---|---|
| **minimal** | Tickets repetitivos, batch, después de calibración | Solo para por hard errors. Auto-fix de verifier hasta 2 retries. PR conflicts → log + continuar. Clarifications → marca TBD y sigue. Self-healing exhaust → escalate to STATE para el próximo run. |
| **balanced** | Default · primeros días en un proyecto nuevo | Comportamiento v0.4.x exacto. Pregunta cuando el juicio humano agrega valor. |
| **high** | Tickets sensibles (auth, billing, infra) | Approval gate antes de CADA write. Hasta 10 clarification questions. Pregunta "continue?" después de cada fase. |

Plus `custom` con override per-gate.

### Las 6 gates configurables

```yaml
gates:
  budget_gate:              { on_exceed: ask | proceed | abort }
  verifier_blocking_gate:   { on_blocking: ask | auto_fix | proceed_with_warnings | abort }
  adr_conflict_gate:        { on_high_conflict: ask | proceed_with_record | abort }
  adr_rule_violation_gate:  { on_violation: ask | abort }    # NUNCA proceed
  spec_clarification_gate:  { on_gaps: ask | use_defaults_and_flag | abort }
  self_healing_exhaust_gate:{ on_exhausted: ask | escalate_silent | abort }
```

### Override por ticket

```
do "Migrar auth a Riverpod 2 --autonomy=minimal"
do "Cambiar pricing engine --autonomy=high"
```

Solo afecta ese run. La config del archivo queda intacta.

### Surfaceado en chat

Phase 1 ahora muestra readiness Y autonomy juntas:

```
🎚 Readiness level: L2 (assisted) — historial de 1 run exitoso.
🎛 Autonomy: minimal (override por --autonomy=minimal en el ticket)
```

Si el preset es `custom`, muestra qué gates están non-default.

### Lo que NO se puede configurar (safety floor)

Incluso en `preset: minimal`, estas 4 garantías son no-negotiables:

1. **No auto-merge PRs.** EVER.
2. **No push a main/master/protected branches.** EVER.
3. **No writes a paths del denylist** (`.env`, `secrets/`, `infra/production/`). EVER.
4. **No override silencioso de reglas documentadas en `.rules`.** `adr_rule_violation_gate.on_violation` solo acepta `ask` o `abort` — nunca `proceed`. Si querés bypassear una regla, editás el `.rules` primero (acto deliberado, separado).

### Nuevos archivos

- `references/autonomy-config.md` — documentación completa del schema + presets + gate decision table

### Cambios en agents/skills existentes

- **`do/SKILL.md`** — Phase -1 lee config.yaml + override de ticket; Phase 1 surface autonomy line; Phase 2 budget gate configurable; Phase 4 verifier blocking gate configurable
- **`agents/triage.md`** — lee config.yaml; chequea conflicts readiness ↔ autonomy; plan incluye `autonomy_preset` field
- **`skills/loop-adr/SKILL.md`** — coordination_gate y rule_violation_gate consultan config
- **`skills/loop-generate-spec/SKILL.md`** — spec_clarification_gate configurable (ask / use_defaults / abort)
- **`skills/loop-self-healing/SKILL.md`** — self_healing_exhaust_gate configurable (ask / escalate_silent / abort)
- **`references/state-spine.md`** — documenta config.yaml

### Migration de v0.4.x

Cero acción requerida. Si `.loop/config.yaml` no existe, el plugin lo crea con `preset: balanced`. Comportamiento idéntico a v0.4.2. Para cambiar autonomy, editás el archivo OR pasás `--autonomy=X` en el ticket.

### Recomendación de adopción

1. Primera semana: dejá `balanced` (default). Calibrá viendo cómo decide.
2. Segunda semana: para tickets archetípicos que ya hiciste 2-3 veces sin sobresaltos, probá `--autonomy=minimal` por ticket.
3. Tercera semana: si los tickets de archetype X siempre van bien en minimal, cambiá el preset del archivo a `custom` con esos gates en non-ask.
4. Para tickets sensibles (auth, payments, prod infra), nunca uses minimal — usá `high` o quedate en balanced.

## Changelog v0.4.2

Patch chico: la tabla **`## Consumo por agente`** ahora es OBLIGATORIA en el chat resumen, no solo en el `run-report.md`. Una fila por Agent invocation con tiempo/tokens/costo real, sin agregaciones.

### Cómo se ve

Al final del run, en chat (no escondido en un archivo):

```
Listo. TKT-xxx completado en 6m 42s.

🎚 L2 (assisted)

## Resumen ejecutivo
- Plan: 2 fases (...)
- Verifier: 0 findings blocking
- Entregados: kanban-dashboard/index.html + run-report.md
- 📓 STATE: 1 agregado a Watch List · 0 resueltos · run-log: 5 entries total

## Consumo por agente

| Agente | Modelo | Invocaciones | Tiempo | Tokens | Costo |
|---|---|---|---|---|---|
| triage | sonnet | 1 | 12.4s | 5.2K | $0.03 |
| loop-runtime | sonnet | 1 (orq) | 8.1s | 3.7K | $0.02 |
| worker w1 (harden prototype) | sonnet | 1 | 4m 13s | 58.4K | $0.39 |
| verifier | haiku | 1 | 22.3s | 14.1K | $0.02 |
| spec-writer | opus | 1 | 1m 47s | 52.3K | $1.73 |
| **TOTAL** | — | **5** | **6m 42s** | **133.7K** | **$2.19** |

📦 Artefactos:
- [run-report.md](outputs/run-report.md)  ← desglose con prompts expandibles por worker
- [kanban-dashboard/index.html](outputs/kanban-dashboard/index.html)
```

### Reglas duras (mandatory)

1. **Una fila por Agent tool invocation.** Si fanaste 5 workers en paralelo → 5 filas distintas, NO "5x workers" agregado.
2. **Números reales.** `Tokens` viene del field `subagent_tokens`; `Tiempo` del `duration_ms`. JAMÁS estimados o inventados.
3. **Costo por modelo** con la fórmula 70/30 input/output: Haiku ~$1.76/M, Sonnet ~$6.60/M, Opus ~$33/M.
4. **TOTAL row en bold.** Validado: la suma de filas tiene que cuadrar con el TOTAL.
5. **Scope corto entre paréntesis** por worker (`worker w1 (Vite research)`, `worker w1 (email-validator.ts)`).
6. **Orden top-to-bottom igual al flow:** orquestación primero, workers en el medio, audit/synthesis al final.

### Lo que cierra

El gap más visible que había: vos veías "6 invocaciones · 133K tokens · $0.45" y tenías que abrir el `run-report.md` para saber qué worker te costó qué. Ahora la tabla viene embebida en chat, con un link al run-report.md para ver los prompts expandibles + el verifier-report detallado.

Bonus: en v0.4.0 el cost estimate era impreciso ($0.45 para 133K tokens incluyendo Opus es imposible). El cálculo ahora usa la fórmula efectiva con I/O ratio — más cercano a la realidad.

### Archivos cambiados

| Archivo | Cambio |
|---|---|
| `skills/do/SKILL.md` | Phase 8 output template + 6 reglas duras de tabla |
| `agents/loop-runtime.md` | Bookkeeping per-invocation BLOCKING + run-report.md per-row format |
| `.claude-plugin/plugin.json` | 0.4.1 → 0.4.2 |

## Changelog v0.4.1

Patch chico que cierra los 3 gaps de observabilidad descubiertos en el primer run real de v0.4.0 en Claude Code CLI.

### Fix 1 — Readiness level SIEMPRE visible

`triage` ahora debe emitir `readiness_level` + `readiness_rationale` en el plan.yml. `do` Phase 1 imprime una línea obligatoria **al inicio** del run:

```
🎚 Readiness level: L2 (assisted) — historial de 1 run exitoso; gate humano antes de cada write.
```

Sin esto el plugin actúa autónomamente sin contarte por qué — silencia el anti-pattern #4 ("L3 before L1 quality").

### Fix 2 — STATE spine en el resumen final

`do` Phase 7 ahora computa stats de las operaciones STATE y las surfacea en el resumen:

```
- 📓 STATE: 1 agregado a Watch List · 0 resueltos · run-log: 5 entries total
   (snapshot refreshed: no)
```

Si `.loop/` no es escribible (FS read-only), surface explícito: `📓 STATE: skipped — .loop/ no escribible (<reason>)`. Cero silencios.

### Fix 3 — `present_files` fallback para Claude Code CLI

`do` Phase 6 ahora rama por entorno:

- **Branch A — Cowork** con `mcp__cowork__present_files` disponible → card de artefactos como antes.
- **Branch B — Claude Code CLI / otros entornos** → fallback inline:
  ```
  📦 Artefactos:
  - [run-report.md](path/relative/to/repo_root)
  - [artifact-1.ext](path/relative)

  📁 Carpeta de outputs: <absolute path>
  📓 Intermedios + trace: <absolute path .loop/traces/> y /tmp/loop-runs/
  ```

Hard rule nueva: NUNCA links externos tipo `claude.ai/...` o `github.com/...` — esos no sobreviven session boundaries. SIEMPRE paths relativos al repo + absolutos para outputs.

### Archivos cambiados

| Archivo | Cambio |
|---|---|
| `skills/do/SKILL.md` | Phase 1 + Phase 6 + Phase 7 + output template |
| `agents/triage.md` | Reforzado `readiness_level` + `readiness_rationale` mandatorios en plan.yml |
| `.claude-plugin/plugin.json` | 0.4.0 → 0.4.1 |

### Lo que NO cambió

Arquitectura, topología, los 5 arquetipos, asignación de modelos, discovery de 4 capas, worktree isolation, verifier execution. Todo igual. Es solo observabilidad.

## Changelog v0.4.0

Release grande. Seis fixes batched, todos con un principio rector: **tech-agnostic + project-agnostic total.** El plugin ya no asume Node/Jest/TypeScript en ninguna parte estructural — adapta a cualquier stack que el proyecto declare.

### 1. Tech-agnostic harden — el principio rector

Nuevas referencias compartidas en `references/`:

- **`universal-commands.md`** — discovery patterns para lint/typecheck/test/build/run en 15+ stacks: TS/JS, Python, Go, Rust, Ruby, Java, Kotlin, .NET, Elixir, PHP, Flutter, RN/Expo, Swift, Haskell, Nix + monorepo orchestrators (Nx, Turbo, Bazel). Prioriza siempre comandos descubiertos del proyecto (Makefile, justfile, package.json scripts, pyproject.toml, mix aliases, etc.) sobre la tabla fallback.
- **`manifest-types.md`** — 60+ tipos de manifests por ecosistema. Cubre desde `package.json` hasta `*.cabal`, `Project.toml`, `flake.nix`, `BUILD` (Bazel), `nx.json`, `turbo.json`.

Cambios concretos en agents/skills:

- `worker-dev` ahora declara explícitamente que NO asume Node/TS — los snippets, type declarations y self-check commands los deriva del stack del spec §3 + `references/universal-commands.md`.
- `loop-self-healing` saca todas las menciones hardcoded de `npm/jest/pnpm`. Los verification commands vienen del spec §8 (que a su vez los descubre del task runner del proyecto).
- `triage` self-check #12: "Is the plan tech-AGNOSTIC?" — falla si el plan asume un stack específico.

### 2. Worktree isolation por worker (cierra Cobus failure mode S2 "Parallel Collision")

Cuando `loop-self-healing` fanea N workers para escribir N archivos en paralelo, cada uno corre en su propio `git worktree add` allocation. Cero colisiones posibles.

- Cada worker recibe `workdir: <run_dir>/wt-<worker_id>`
- Workers solo escriben dentro de SU worktree
- El runtime mergea los worktrees al final via `git apply --3way`
- Si dos workers tocaron las mismas líneas (raro, indica bug de triage) → conflict surface al usuario, no se silencia
- Para repos sin git → fallback a `cp -r` con warning explícito en el report
- Cleanup automático: `git worktree remove` después del merge final
- Branch final visible al usuario: `loop/<ticket_id>` (NO toca tu working tree)

### 3. Verifier upgrade — EJECUTA los commands (cierra Cobus "Verifier theater")

Verifier v0.3 solo leía artefactos — eso es exactamente "verifier theater" (rubber-stamping). v0.4 suma `Bash` al verifier y agrega Check #7:

> Ejecuta cada verification command del spec §8 vía Bash desde repo_root. Captura stdout/stderr/exit code. Reporta GREEN | RED (con stderr) | SKIPPED (comando no disponible) | TIMEOUT (>5min).

Check #7 es **BLOCKING**: cualquier red command setea `BLOCKING > 0` regardless de los checks de calidad de artefactos.

Edge cases manejados: command not found (gap de entorno, no falla de código), timeout, output excesivo (truncate a primeras 30 + últimas 10 líneas), comandos destructivos detectados (`rm`, `--force`, `drop table`) → refuse y flag el spec §8 como malformado.

### 4. STATE spine — `.loop/` durable, tech-agnostic

Nueva convención compartida: el plugin posee `<repo_root>/.loop/`:

```
.loop/
├── state.md            ← High Priority / Watch List / Recent Noise / Conventions snapshot
├── run-log.md          ← Append-only history (una entrada por run)
├── budget.md           ← Daily/weekly caps + kill switch + denylist paths
├── traces/<ts>.json    ← Machine-readable trace por run (consumible por /loop:improve futuro)
└── plans/<ts>.yml      ← Archivo del plan.yml emitido (para hill-climbing)
```

- `do` Phase -1 lee STATE + budget ANTES de hacer nada. Si `kill_switch.enabled` → abort con razón. Si budget exhausto → abort con cap hit.
- `do` Phase 7 (nueva) appenda al run-log + actualiza state.md al final del run.
- Schema 100% tech-agnostic. Plain text + YAML. Inspectable sin el plugin.
- Conventions snapshot cachea la discovery de 4 capas: subsequent runs validan en vez de re-scanear.

### 5. Maturity model L0 / L1 / L2 / L3 — gates explícitos

Triage asigna `readiness_level` a cada plan. El nivel gate-ea qué puede hacer el plugin:

| Level | Sub-agent dispatch | Spec write | Code writes | Self-healing |
|---|---|---|---|---|
| **L0 Draft** | ❌ (solo triage) | ❌ | ❌ | ❌ |
| **L1 Report** | ✅ (research/audit) | ❌ | ❌ | ❌ |
| **L2 Assisted** | ✅ | ✅ con approval | ✅ en worktree | ✅ (max 3 retries) |
| **L3 Unattended** | ✅ | ✅ | ✅ en worktree | ✅ (max 3 retries) |

**NUNCA** (en ningún nivel): auto-merge PRs, push a main, tocar `.env`/`secrets/`/`infra/production/`.

Asignación automática del nivel (primer match gana):
1. Usuario lo pidió explícito → honrar
2. Ticket toca denylist → cap a L1
3. ≥3 runs exitosos del archetype → L3
4. ≥1 run exitoso → L2
5. Sin historia → L1 (default cobus)
6. Ticket conversacional → L0

Surfaceado en el chat resumen: *"Asignando L2 — 2 runs exitosos. Gate humano antes de cada write."*

### 6. Anti-patterns checklist baked into triage

Las 10 anti-patterns del repo de Cobus se chequean automáticamente en el self-check #11 del triage:

1. Same agent implements and verifies → estructural en nuestro plugin ✓
2. No attempt cap → `max_retries_per_file: 3` enforced
3. Vague triage output → scan por frases prohibidas (`"as needed"`, `"handle appropriately"`, etc.)
4. L3 before L1 quality → defaults a L1 sin historia
5. Shared state without schema → paths distintos por phase
6. MCP write-everything scope → tool grants mínimos
7. No kill switch → approval gate L≥2 + SIGINT clean handle
8. Fixing flakes with code → classification + quarantine policy
9. Auto-merge without allowlist → NUNCA en NINGÚN nivel
10. No run log → mandatory `.loop/run-log.md` append en cada run

### Resumen de archivos nuevos / cambiados

**Nuevos (5):**
- `references/universal-commands.md`
- `references/manifest-types.md`
- `references/anti-patterns-checklist.md`
- `references/maturity-model.md`
- `references/state-spine.md`

**Patcheados (5):**
- `agents/worker-dev.md` — workdir input + tech-agnostic self-check
- `agents/verifier.md` — Bash + Check #7 (execute verification)
- `agents/triage.md` — STATE read + readiness_level + 12 self-checks + tech-agnostic mandate
- `skills/loop-self-healing/SKILL.md` — worktree per worker + merge protocol + lang-agnostic
- `skills/do/SKILL.md` — Phase -1 (STATE read) + Phase 7 (STATE update) + hard rules expandidas

### Lo que NO cambió

- La topología (triage → runtime → workers → verifier → spec-writer) — sigue siendo la misma
- Los 5 arquetipos (orchestrator-workers, plan-execute, self-healing, generate-spec, adr)
- La asignación de modelos por rol (Haiku/Sonnet/Opus ladder)
- Las reglas de citation inline + context isolation de v0.1.1
- La discovery de 4 capas de v0.3.1

## Changelog v0.3.1

**Convention discovery expandido en 4 capas.** Lo que antes era "leer CLAUDE.md para inferir stack" ahora es una scan estructurada que captura: tech stack + facts arquitectónicos + reglas AI explícitas + convenciones de diseño + decisiones lockeadas — diferenciando frontend / mobile / backend / full-stack y haciendo deep-scan por sub-tipo.

### Las 4 capas que el plugin ahora lee

**Capa 1 — Architecture & design docs**
Lee todo lo que exista de: `CLAUDE.md` (root + nested via `**/CLAUDE.md`), `AGENTS.md`, `AGENT.md`, `ARCHITECTURE.md`, `DESIGN.md`, `CONVENTIONS.md`, `STYLE.md`, `.claude/CLAUDE.md`, más los equivalentes en `docs/` (incluyendo `docs/COMPONENTS.md`, `docs/PATTERNS.md`, `docs/STATE.md`, `docs/FRONTEND.md`, `docs/MOBILE.md`, `docs/BACKEND.md`).

**Capa 2 — AI-behavior rules files (`.rules` family)**
Las reglas que vos le diste a tu IDE/agente son contratos arquitectónicos disfrazados. El plugin ahora lee: `.cursorrules`, `.cursor/rules/**/*.mdc`, `.windsurfrules`, `.windsurf/rules/**`, `.clinerules`, `.clinerules-*`, `.roorules`, `.roo/rules/**`, `.aider.conf.yml(.yaml)`, `.github/copilot-instructions.md`, `.continue/config.json`. Cada regla se trata como **constraint sobre alternativas**: alternatives que la violen quedan listadas en el ADR como "rejected by project rule: <source>:<line>". Si el ticket propone explícitamente una alternativa que rompe una regla, el plugin **siempre** dispara Phase E (human-in-the-loop) — nunca silencia una regla documentada.

**Capa 3 — Clasificación del ticket: frontend / mobile / backend / full-stack**
Detecta a partir de manifests + folder structure + texto del ticket:

| Tipo | Señales |
|---|---|
| **Frontend** | `package.json` con `react/vue/svelte/solid/angular/qwik/next/nuxt/sveltekit/astro/remix/tanstack-router`; `*.tsx/*.vue/*.svelte`; `components/`, `pages/`, `app/`, `ui/`, `design-system/`; tailwind/postcss/Storybook configs |
| **Mobile Flutter** | `pubspec.yaml`, `lib/`, `*.dart`, `analysis_options.yaml`, `ios/+android/` |
| **Mobile RN/Expo** | `package.json` con `react-native`/`expo`, `app.json`/`app.config.ts`, `ios/+android/` con Podfile+Gradle |
| **Mobile Native** | `Package.swift` (Swift), `build.gradle.kts`+`*.kt` (Kotlin), Cargo+mobile targets (Rust) |
| **Backend** | NestJS/`nest-cli.json`, FastAPI/Django/Flask via `pyproject.toml`, Rails/`Gemfile`, Spring/`pom.xml`, Go/`go.mod`, Rust web frameworks |
| **Full-stack** | Combinación — monorepo con `apps/web` + `apps/api` + `apps/mobile` |

**Capa 4 — Deep-scan por sub-tipo**
Lee los archivos que importan SEGÚN qué tipo de ticket es:
- **Frontend:** `tailwind.config.*`, `.storybook/main.*`/`preview.*`, design tokens, state-mgmt deps (redux/zustand/jotai/recoil/tanstack-query/swr/valtio/mobx), routing deps (react-router/tanstack-router/next-router/sveltekit-router), forms (react-hook-form/formik/zod/yup/valibot), component lib (shadcn/mui/chakra/radix/headlessui/mantine).
- **Mobile Flutter:** versiones de `pubspec.yaml` (bloc/riverpod/provider/get_it/go_router/dio/retrofit), `analysis_options.yaml`, patrón de state mgmt en estructura `lib/` (`blocs/` vs `providers/` vs `cubits/` vs `notifiers/`), navigation pattern (GoRouter declarations vs Navigator 2.0), platform plugins.
- **Mobile RN/Expo:** `app.json`/`app.config.ts`, react-navigation vs expo-router, EAS plugins, `metro.config.js`.
- **Backend:** Prisma schemas, TypeORM entities, SQLAlchemy models, ActiveRecord schemas, Alembic migrations, OpenAPI/GraphQL/tRPC schemas, auth middleware/guards, observability (Sentry/Datadog/OpenTelemetry).

### Cómo `<conventions>` afecta el ADR

| ADR section | Qué inyectan las conventions |
|---|---|
| `## Context` | Architecture facts + ai_rules más relevantes (citados) |
| `## Alternatives Considered` | Cada alternativa suma columna "Fit with detected stack". Las que violan un `ai_rule` quedan como **"rejected by project rule: <source>:<line>"** |
| `## Trade-offs` | Solo trade-offs que las conventions NO settlean. Si convention ya decide, pasa a `## Decision` directo |
| `## Technical Gaps` | Donde el ticket va más allá de lo que conventions cubren — esa es la decisión nueva siendo introducida |
| `## Consequences` | Positivos alineados con valores de las conventions (ej. "minimize external deps" → positivo "reuses existing in-house module") |
| `## Decision` | **NUNCA** elige alternativa que viole un `ai_rule`. Si ticket lo propone, gate humano obligatorio |

### Cambios en agents existentes

- **`adr-author`** — Step 3 reescrito de "stack discovery" a "4-layer convention discovery". Phase E ahora mandatory ante rule violations. Tabla nueva "How `<conventions>` shapes the ADR".
- **`spec-refiner`** — acepta `<conventions>` como input (propagado por adr Phase 0) o lo produce él mismo si no hay ADR upstream. BRIEF incluye nueva sección "Project conventions detected". Per-section status suma `provided_by_conventions` — los sections settled por conventions skip el clarification step.
- **`loop-generate-spec`** y **`loop-adr` SKILL.md** — documentan la discovery expandida.

### Por qué importa

Sin Capa 2 el plugin proponía alternativas que violaban reglas documentadas. Sin Capa 3 escaneaba patterns genéricos en vez de frontend/mobile-específicos. Sin Capa 4 perdía exactamente las dimensiones de las que la mayoría de los ADRs realmente son (state mgmt, navigation, component library).

## Changelog v0.3.0

Suma **Architecture Decision Records (ADRs)** como Phase 0 del flow de desarrollo. Antes de spec, antes de código, el plugin registra la decisión arquitectónica con análisis de codebase, conflict-detection contra PRs abiertos, e historial de UAT como seed de acceptance criteria.

### Nueva skill

- **`loop-adr`** — porteo del template `/adr-create` adaptado al flow. Cuando el triage detecta un ticket con decisión arquitectónica significativa (nueva tecnología, API design, data model, infra, cross-cutting concern como caching o auth), emite `archetype: adr` como Phase 0. La skill ejecuta 12 steps:
  1. Resuelve número ADR (local Glob + opcional remote WebFetch a GitHub/GitLab)
  2. Slugify del título
  3. Stack discovery desde `CLAUDE.md` / `ARCHITECTURE.md` / manifest inference
  4. Codebase scans: dependency, pattern conflict (3-6 domain keywords), module boundary, test/UAT history
  5. Acceptance criteria GIVEN/WHEN/THEN con links a tests existentes o `[to be validated]`
  6. PR/MR conflict detection (HIGH / MEDIUM / NONE) con 4 risk types: Duplicate intent · Conflicting approach · Shared files · Dependency order
  7. Deciders inferidos del git log
  8. Write `docs/adr/ADR-NNN-<slug>.md` bilingüe (inherit lang del proyecto, **no pregunta**)
  9. Phase report con `coordination_gate` flag

### Nuevo sub-agent

- **`adr-author`** (Sonnet, con `WebFetch` + `Bash` + `AskUserQuestion`) — ejecuta los 12 steps. Hard rules:
  - Status SIEMPRE `proposed` — la humana acepta por review, el plugin no
  - Numbering monotonic, retry on race
  - Citas inline obligatorias para cada Context claim (trace a Step 5)
  - NO inventa conflicts si el repo URL no se resuelve

### Composición con el resto del flow

Cuando ADR Phase 0 corre, sus outputs se propagan downstream:

| Output del ADR | Va a |
|---|---|
| `## Decision` (one-paragraph summary) | Spec §10 (Decisiones tomadas) — **locked**, implementer no puede cambiar |
| `## Acceptance Criteria` | Spec §8 (Tests requeridos) + §11 (Edge cases) — seeds |
| `## Technical Gaps` | Spec §4 (Dependencias previas) — checkboxes BLOCKING hasta resolver |
| `## PR / Branch Conflicts` HIGH | Spec §18 (Restrictions) + PR description (si user aceptó "continue with risks recorded") |
| ADR path | PR description `## Architecture Decision` section, link relativo |

### Coordination gate

Si el ADR detecta HIGH-overlap conflicts (3+ keyword matches con PRs/MRs abiertos), el runtime gate-ea via `AskUserQuestion`:

> *"Detecté N PRs en conflicto con esta decisión arquitectónica. ¿Pauso para coordinar o continúo?"* → `pause` / `continue with risks recorded` / `abort`

Anti-pattern explícito que cierra: *Cognitive surrender* + *Parallel collision* del catálogo de Cobus Greyling.

### Cambios en agents existentes

- **`triage`** aprende a detectar ADR-worthy (verbs decide/adopt/migrate/replace/introduce + cross-cutting concerns + new tech + data model + infra + API design). Self-check #9 obligatorio. Si ticket es PURAMENTE decisión (no implementación), emite SOLO Phase 0 — ADR es el deliverable.
- **`spec-writer`** dev-mode suma sección `## Architecture Decision` en el PR description con link al ADR y quote del `## Decision`. Omite la sección por completo (silencio) si no hay ADR.
- **`loop-runtime`** suma branch para `archetype: adr` y la lógica de `coordination_gate`.
- **`loop-generate-spec`** acepta nuevos inputs (`adr_decision_summary`, `adr_acceptance_seeds`, `adr_technical_gaps`, `adr_path`) y los propaga a las secciones del spec correspondientes.

### Convenciones asumidas

- ADRs viven en `docs/adr/ADR-NNN-<slug>.md` (convención clásica Michael Nygard)
- Numbering: local + opcional remote para multi-repo continuity
- Bilingüe: detecta lang del proyecto, no pregunta al usuario
- Composable: ADR es opcional para tickets triviales (CSS class, rename, fix typo)

## Changelog v0.2.0

El plugin pasa de "research/docs autónomo" a **autonomía para tickets de desarrollo** con loop completo de write→verify→retry.

### Nuevas skills internas

1. **`loop-generate-spec`** — porteo del workflow `/generate-spec` adaptado al plugin. Convierte un ticket informal en un spec de 20 secciones validado (sub-agent `spec-refiner` Haiku + composición + sub-agent `spec-validator` Sonnet con verdict `PASS / PASS_WITH_WARNINGS / BLOCK`). Convención fija: `.planning/phases/<slug>/spec.md`. Cap de 3 ciclos de re-validación. Reutiliza la sección 6 (Archivos) como contrato para los workers de implementación y la sección 8 (Comandos de verificación) como criterio de éxito del self-healing.

2. **`loop-self-healing`** — nuevo arquetipo. Dispatch en paralelo de un `worker-dev` por archivo de §6, ejecuta los comandos de §8 vía Bash, lee stderr, dispatch correctivo del worker con el error como input, repite hasta verde o cap de 3 retries por archivo. Captura matriz de verificación por ronda en el trace.

### Nuevos sub-agents

- **`spec-refiner`** (Haiku) — read-only, produce un BRIEF por sección comparando la idea cruda contra el template canónico de 20 secciones.
- **`spec-validator`** (Sonnet) — read-only, audita el spec compuesto con 7 checks (estructura, concreción, versiones pinned, paths que existen, prerequisitos, consistencia de api-contract, mirror de estilo).
- **`worker-dev`** (Sonnet, con Bash) — escribe UN archivo por invocación. En retry round, fixea SOLO lo que el error nombra, no refactoriza. Hard rule: si la causa raíz está en otro archivo, lo declara y para.

### Cambios en agents existentes

- **`triage`** aprende a detectar tickets de desarrollo (verbs "implementá / build / fix / migrate", deliverable = código + tests). Cuando lo detecta, emite plan 3-fases: `generate-spec` → `self-healing` → `pr-description`.
- **`spec-writer`** suma "dev-mode": si el ticket es de código, su entregable final no es el código (eso lo hicieron los workers + self-healing) sino la **PR description** + §20 checklist marcado con la matriz de verificación real.
- **`loop-runtime`** suma branches para los dos arquetipos nuevos. El run-report registra cada retry round.

### Reference incluida

- `skills/loop-generate-spec/references/spec-template.md` — template canónico de 20 secciones. Portable a cualquier proyecto.

### Convenciones asumidas

- Estructura de specs: `.planning/phases/<slug>/spec.md` + `api-contract.md`
- No usa OpenSpec (skipped en este plugin — agregar en v0.2.1 si hace falta).
- Stack y versiones se leen del proyecto (`package.json` / `pubspec.yaml` / etc.) — el plugin no asume nada.

## Changelog v0.1.1

Cinco bugs cazados en el smoke test TEST-001 (comparativa de bundlers), cinco fixes:

1. **Context bleed eliminado** — triage y spec-writer ignoran `CLAUDE.md`, memoria y conversación. Sólo el ticket cuenta. Adiós a inventarse proyectos del usuario en la recomendación final.
2. **Artefactos completos** — `final_artifacts:` ahora es obligatorio en plan.yml, y el orchestrator no puede shipear con `produced < planned`.
3. **Citas inline bloqueantes** — toda claim numérica debe tener `([source](URL))` a ≤200 caracteres. El footer de "Fuentes" ya no cuenta como sustituto. El verifier flaggea sin piedad.
4. **Verifier audible** — `BLOCKING > 0` ahora gate-ea el run; el usuario decide fix / ship / abort. Silenciar al verifier era un bug crítico del orchestrator.
5. **Observabilidad de orquestación** — el plugin emite `run-report.md` user-facing con: plan + rationale por fase, tabla de cada worker (modelo, duración, tokens, artefacto, status), prompts completos expandibles, resumen verifier, resumen económico por agente, costo estimado en USD. Trace machine-readable en `/tmp/loop-runs/<ts>/trace.json` para el futuro `/loop:improve`.



`loop-engineering` materializa la disciplina de Loop Engineering ([LangChain, 2025](https://www.langchain.com/blog/the-art-of-loop-engineering)) como un único punto de entrada autónomo sobre Claude Code: el humano pega un ticket, el plugin decide la topología de loop adecuada, despacha sub-agents en olas paralelas, verifica el output y entrega el artefacto final.

## Filosofía

> *"The potential in agents is in the loops you build around them."*

Las capacidades brutas de un modelo son commodity. La ventaja competitiva está en los loops que vos diseñás alrededor. Este plugin convierte ese diseño en infraestructura reutilizable: **no tenés que saber qué es Orchestrator-Workers o Evaluator-Optimizer para usarlo** — el plugin elige el arquetipo por vos.

## Flujo end-to-end

```
ticket → triage → plan.yml → runtime (olas) → verifier → spec-writer → artefacto
                                                                            │
                                                                            └─→ trace.json (para hill-climbing futuro)
```

## Cómo se usa

En cualquier conversación de Claude Code, simplemente decí:

```
/loop:do "Investigá X y entregame Y como .md y .csv"
```

o pegá un ticket completo de Jira/Linear/un párrafo libre. El plugin:

1. **Triage** — analiza el ticket, lo descompone en fases, elige el arquetipo de loop por fase (Orchestrator-Workers, Plan-Execute en esta versión), asigna modelos por costo (Haiku para mecánico, Sonnet para análisis, Opus para síntesis final).
2. **Approval gate (opcional)** — te muestra el `plan.yml` resultante; vos decís *go* o *ajustá*.
3. **Runtime** — ejecuta cada fase con el arquetipo elegido, paraleliza cuando hay independencia, guarda traces.
4. **Verify** — el sub-agent `verifier` (Haiku) audita claims, citas, snippets y estadísticas.
5. **Assemble** — el sub-agent `spec-writer` (Opus, único frontier) sintetiza el artefacto final.

## Arquetipos soportados (v0.1.0)

| Arquetipo | Cuándo lo elige el triage |
|---|---|
| **Orchestrator-Workers** | Tareas con sub-tareas independientes (research multi-fuente, generación side-by-side) |
| **Plan-Execute** | Tareas multi-fase secuenciales con dependencias claras |

*Roadmap (Fases 2-4):* Self-Healing, Evaluator-Optimizer, Ralph (stop-hook self-loop), Compaction y `/loop:improve` (hill-climbing meta-loop).

## Asignación de modelos baked-in

Maximizar calidad del artefacto final minimizando consumo de tokens. **El único agente frontier es el spec-writer; todo lo demás es lo más barato que la tarea permita.**

| Sub-agent | Modelo | Rol |
|---|---|---|
| `triage` | Sonnet | Análisis del ticket, plan |
| `loop-runtime` | Sonnet | Coordina olas, despacha workers |
| `worker` (genérico) | Sonnet o Haiku | Ejecutado N veces; Haiku para search/grep/conteos |
| `verifier` | Haiku | Audita citas/snippets/stats |
| `spec-writer` | Opus | **Único** responsable del output final |

## Smoke test incluido — TEST-001

> *"Investigá el estado actual (2026) de cinco bundlers JavaScript modernos — Vite, Turbopack, Rspack, Bun y esbuild. Para cada uno: madurez, performance, ecosystem y DX, casos de uso ideales. Entregá: (a) un reporte `.md` comparativo de 1500 palabras con tabla side-by-side y recomendación final fundamentada, (b) un `.csv` con la matriz de comparación."*

Este ticket ejercita las dos primitivas de v0.1.0:

- **Orchestrator-Workers** para la fase de research (5 workers Sonnet en paralelo, uno por bundler).
- **Plan-Execute** para la pipeline research → tabla → CSV → recomendación → verificación → entrega.

Ejecutalo con:

```
/loop:do <pega-el-ticket>
```

y compará el artefacto contra `expectations.md` (si lo agregás vos).

## Componentes

```
loop-engineering/
├── .claude-plugin/plugin.json
├── README.md
├── skills/
│   ├── do/SKILL.md              ← entry point
│   ├── loop-orchestrator/SKILL.md    ← arquetipo Orchestrator-Workers
│   └── loop-plan-execute/SKILL.md    ← arquetipo Plan-Execute
└── agents/
    ├── triage.md          (Sonnet)
    ├── loop-runtime.md    (Sonnet)
    ├── spec-writer.md     (Opus)
    └── verifier.md        (Haiku)
```

## Roadmap

| Fase | Entrega |
|---|---|
| **v0.1 — MVP (esta versión)** | Loop autónomo end-to-end con Orchestrator-Workers + Plan-Execute |
| v0.2 | Self-Healing (PostToolUse hook) + Evaluator-Optimizer para code-gen |
| v0.3 | Ralph (stop-hook self-loop) + Compaction para sesiones largas |
| v0.4 | `/loop:trace` + `/loop:improve` — el meta-loop de hill-climbing |

## Licencia

MIT — Somnio, 2026.
