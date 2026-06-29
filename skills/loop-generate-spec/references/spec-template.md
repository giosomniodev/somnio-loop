# <feature-title>

> **Status:** DRAFT | PENDING IMPLEMENTATION | IN PROGRESS | DONE
> **Slug:** <kebab-case-slug>
> **Author:** <name>
> **Created:** <YYYY-MM-DD>

---

## 1. Objetivo

What is being built and what user outcome it enables. No ambiguity. One paragraph max.

## 2. Alcance

### Incluido en esta fase

- Bullet list of what THIS spec delivers.

### Fuera de scope

- Bullet list of what is NOT in this spec. Be exhaustive — out-of-scope is load-bearing.

## 3. Tecnologías y convenciones del proyecto

### Stack

- Language: `<lang>` `<version>`
- Package manager: `<npm|pnpm|yarn|cargo|pip|...>`
- Framework / runtime: `<...>`
- UI library: `<...>`
- State management: `<...>`
- API client: `<...>`
- Forms / validation: `<...>`
- Testing: `<framework>` `<version>`

### Versiones relevantes (pinned)

| Dep | Version | Cited from |
|---|---|---|
| ... | ... | `package.json:42` |

### Patrones existentes a respetar

- Name the patterns by example file path. No generic "follow conventions".

## 4. Dependencias previas

Checkbox list of everything that must already exist before implementation can start.

- [ ] Module `<path>` exists with `<contract>`
- [ ] Endpoint `<METHOD> <path>` returns `<schema>`
- [ ] Type `<Name>` is defined in `<path>`
- [ ] Env var `<NAME>` configured

If a prerequisite is missing, the spec is BLOCKED until it lands.

## 5. Arquitectura

### Patrón aplicado

`<BLoC | MVVM | Clean | Hexagonal | CQRS | Feature-Sliced | ...>`

### Capas afectadas

| Capa | ¿Afectada? | Descripción |
|---|---|---|
| UI / Presentation | yes / no | ... |
| Application / Use case | yes / no | ... |
| Domain | yes / no | ... |
| Infrastructure | yes / no | ... |

### Flujo esperado

Numbered steps from user action to UI result.

1. User does X.
2. Component calls Y.
3. Service Z performs A.
4. Response renders B.

### Layout de archivos nuevos

```
<project root>
├── <new path 1>
└── <new path 2>
```

## 6. Archivos a crear o modificar

| Ruta | Acción | Propósito | Ejemplo del proyecto a seguir |
|---|---|---|---|
| `src/<file>.ts` | NUEVO | ... | `src/<existing-similar-file>.ts` |
| `src/<other>.ts` | MODIFICAR | ... | — |

### Detalle por archivo

#### `src/<file>.ts`

- **Responsabilidad:** ...
- **Sigue el patrón de:** `<existing path>` (read this before writing)
- **NO mezclar con:** `<other concern>`
- **Tests requeridos en:** `<test path>`

(One subsection per file.)

## 7. API Contract

Reference `api-contract.md` as single source of truth, OR `Sin API surface — no aplica.`

### Resumen

One paragraph summarizing the endpoints.

### Endpoints

- `<METHOD> <path>` — `<purpose>`

## 8. Criterios de éxito

### Funcional

- [ ] User flow X works end-to-end.
- [ ] All edge cases from §11 are handled.

### Tests requeridos

- [ ] `<test file path>` covers `<scenario>`
- [ ] Coverage threshold: `<N%>` (project standard)

### Comandos de verificación

EXACT commands the implementer (or self-healing loop) runs to confirm done:

```bash
<lint command>
<typecheck command>
<test command>
<build command>
```

(Pull from this project's existing scripts in `package.json` / Makefile / etc.)

## 9. Criterios de UX

### Loading

When and how loading is shown. Skeleton vs spinner vs progress bar.

### Formularios

Behavior: validation timing (onBlur / onSubmit / live), submit button states, success feedback.

### Passwords (if applicable)

Masking, show/hide, strength meter, rules visible.

### Errores

Inline vs toast vs modal. Wording style.

### Navegación

Route changes, back button behavior, deep links.

### Accesibilidad

ARIA roles, keyboard nav, focus management, screen reader announcements.

## 10. Decisiones tomadas (locked)

Design choices locked for this spec. Include the *why*. Implementer must NOT change these.

- **Decision X:** rationale.
- **Decision Y:** rationale.

## 11. Edge cases

Expected behavior under each scenario.

### Datos inválidos

What happens when input is malformed.

### API errors

| Status | UI behavior | Logging | Recovery |
|---|---|---|---|
| 400 | ... | ... | ... |
| 401 | ... | ... | ... |
| 403 | ... | ... | ... |
| 404 | ... | ... | ... |
| 409 | ... | ... | ... |
| 422 | ... | ... | ... |
| 429 | ... | ... | ... |
| 500 | ... | ... | ... |

### Sin conexión

Behavior when offline.

### Timeout

Behavior when request hangs.

### Respuesta vacía o inesperada

How to render empty / null / unexpected payload.

### Doble submit

How to prevent duplicate submission.

## 12. Estados de UI requeridos

| Estado | Qué se muestra | Qué puede hacer el usuario |
|---|---|---|
| idle | ... | ... |
| loading | ... | ... |
| success | ... | ... |
| error | ... | ... |
| empty | ... | ... |
| disabled | ... | ... |
| offline | ... | ... |

## 13. Validaciones

### Validaciones de cliente

| Campo | Regla | Mensaje |
|---|---|---|
| ... | ... | ... |

### Validaciones de servidor

Defer to `api-contract.md`. Define server-error-to-field mapping:

| Error code | Field | UI behavior |
|---|---|---|
| ... | ... | ... |

## 14. Seguridad y permisos

- Secret handling: `<how>`
- Sensitive payload masking: `<what>`
- Permission checks: `<where, how>`
- 401 / 403 flow: `<UX>`

## 15. Observabilidad y logging

Logging mechanism in this project: `<cite path>`.

### Qué loguear

- Event X with fields a, b, c (PII-stripped).

### Qué NUNCA loguear

- Passwords, tokens, full payloads with PII.

## 16. i18n / textos visibles

Translation system: `<cite path/library>`. No hardcoded strings.

| Key | Texto (default lang) |
|---|---|
| `feature.x.title` | "..." |
| `feature.x.cta`   | "..." |

## 17. Performance

- Renders: avoid `<patterns>`.
- API calls: debounce `<N>ms`, cancel on unmount.
- Main-thread work: defer `<heavy ops>`.
- Caching: `<cache strategy>` matching project pattern.

## 18. Restricciones (hard "do not" rules)

The implementer MUST NOT:

- Change the API contract.
- Introduce new global abstractions.
- Add new dependencies without explicit approval.
- Refactor unrelated code.
- Change global styles or nav structure.
- Use undocumented APIs.

## 19. Entregables

- [ ] Code (files listed in §6)
- [ ] Tests (files listed in §8)
- [ ] Translations (keys listed in §16)
- [ ] Types / interfaces
- [ ] API integration wired
- [ ] All UI states implemented (§12)
- [ ] All edge cases handled (§11)
- [ ] Docs updated (`<paths>`)

## 20. Checklist final para el agente

Pre-delivery verification — implementer must check ALL.

- [ ] Read this spec end-to-end before starting.
- [ ] Reviewed `api-contract.md`.
- [ ] Confirmed all §4 prerequisites exist.
- [ ] Modified only files listed in §6.
- [ ] Followed the real project examples cited in §6.
- [ ] All UI states from §12 implemented.
- [ ] All edge cases from §11 handled.
- [ ] No unauthorized dependencies added.
- [ ] No decisions from §10 changed.
- [ ] Ran lint / typecheck / tests / build per §8. All green.
- [ ] No temporary logs / console.log / debug statements.
- [ ] No unjustified TODOs left in code.

---

## Open questions (TBD)

If any section was left as `TBD`, list the unresolved question here.

- [ ] ...

## Implementation hints (optional)

Skills mentioned during refinement that the implementer should consider invoking.

- `/<skill-name>` — <rationale>
