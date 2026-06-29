# Contributing to somnio-loop

Thanks for your interest. This plugin's surface area is small but heavily opinionated — contributions should respect that.

## Before you open a PR

1. **Read the architecture.** Start with `README.md`, then `references/` (especially `maturity-model.md`, `state-spine.md`, `autonomy-config.md`, `anti-patterns-checklist.md`, `mcp-integrations.md`). The plugin's behavior is documented; if a change requires editing a hard rule, expect strong scrutiny.
2. **Identify the kind of change.** Most contributions fall into one of:
   - **Adapter** — new MCP vendor (Linear-alt, GitLab-on-prem, JetBrains Space, etc.). Add to `references/mcp-integrations.md` patterns table + (if needed) per-vendor adapter section. No core changes.
   - **Convention** — new manifest type, new `.rules` family file, new task runner. Add to `references/manifest-types.md` or `references/universal-commands.md`. No core changes.
   - **Archetype** — new loop pattern (e.g. evaluator-optimizer, ralph, compaction). Add a new `skills/loop-<name>/SKILL.md` + register it in `triage.md` decision rules.
   - **Safety floor** — extending what the plugin will never do regardless of preset. Documented in `references/autonomy-config.md` under "What CANNOT be configured". Always opens with a strong rationale.
3. **Run the validator.** Before opening a PR:

   ```bash
   ./scripts/build-plugin.sh
   claude plugin validate ./.claude-plugin/plugin.json
   ```

   The CI workflow at `.github/workflows/validate.yml` runs the same.

## Code style

- All skill descriptions are third-person English, ≤500 chars, with concrete trigger phrases the user might say.
- Skill bodies are written FOR Claude (instructions, not prose to users).
- Markdown headings: H1 only for the file title. Use H2/H3 inside.
- Spanish + English are both first-class for user-facing text — agents detect the project language and adapt.
- No hardcoded vendor names in core logic. Always go through the patterns in `references/`.

## Naming conventions

- Files / skills / slugs: `kebab-case` (English only, even when content is Spanish).
- Sub-agents: `kebab-case`, single word preferred.
- Phase numbers in skill bodies: use `Phase N — <name>` not `Step N` (preserves the loop vocabulary).
- Frontmatter `description` fields: **NEVER use angle brackets** (`<X>` is parsed as XML by some validators). Use `[X]` or quotes instead.

## Testing changes

The plugin is fundamentally non-deterministic (LLMs in the loop). Validation strategies:

1. **Schema validation** — run `claude plugin validate` (CI does this).
2. **Smoke test** — pick a small ticket archetype the change should affect, run `do "<ticket>"` against a throwaway repo, inspect the `run-report.md` and the `trace.json`.
3. **Comparative test** — for changes to prompts/rules, run the SAME ticket against the previous version and the new version. Compare run-reports.

## Releasing a new version

Maintainers only:

```bash
# 1. Update CHANGELOG.md with the new section
# 2. Bump version in .claude-plugin/plugin.json
# 3. Commit on main
git commit -am "vX.Y.Z — <one-line summary>"

# 4. Tag and push — CI builds .plugin and attaches to GitHub release
git tag vX.Y.Z -m "vX.Y.Z"
git push origin main vX.Y.Z
```

The release workflow at `.github/workflows/release.yml` packages `somnio-loop.plugin` and attaches it to the GitHub release automatically.

## Code of conduct

Be honest, be direct, be kind. Disagreements about architecture are welcome — disagreements about people are not.

## License

By contributing, you agree your contributions are licensed under MIT (see `LICENSE`).
