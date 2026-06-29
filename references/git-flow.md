# Git Flow integration — branches, naming, PR targets

The plugin classifies every code-writing ticket into one of eight types and applies the corresponding Git Flow convention. Behavior is fully configurable via `.loop/config.yaml`; defaults assume the Vincent Driessen Git Flow model (main + develop + feature/bugfix/hotfix/release branches).

## The eight ticket types

| Type | Branch pattern (default) | Base branch | PR target | Conventional commit prefix |
|---|---|---|---|---|
| **feature** | `feature/{ticket_id}-{slug}` | `develop` | `develop` | `feat:` |
| **bugfix** | `bugfix/{ticket_id}-{slug}` | `develop` | `develop` | `fix:` |
| **hotfix** | `hotfix/{ticket_id}-{slug}` | `main` | `main` (+ follow-up to `develop`) | `fix:` |
| **release** | `release/{version}` | `develop` | `main` (+ back-merge to `develop`) | `chore(release):` |
| **chore** | `chore/{ticket_id}-{slug}` | `develop` | `develop` | `chore:` |
| **docs** | `docs/{ticket_id}-{slug}` | `develop` | `develop` | `docs:` |
| **refactor** | `refactor/{ticket_id}-{slug}` | `develop` | `develop` | `refactor:` |
| **spike** | `spike/{ticket_id}-{slug}` | `develop` | `develop` (or none — throwaway) | `chore(spike):` |

Slugs are kebab-case English (max 50 chars). `{ticket_id}` is the ID from triage (e.g. `PROJ-127`). `{version}` for release branches is required explicitly in the ticket — never auto-incremented.

## Triage classification signals

The triage agent inspects the ticket and chooses a type using these signals. First match wins, evaluated top-to-bottom:

### 1. `hotfix` (highest priority — safety-critical)

Signals (ANY of):
- Explicit keyword: "hotfix", "hot fix", "production down", "prod broken", "P0", "P1", "critical", "incident"
- Ticket title contains "BROKEN IN PROD" / "URGENT FIX"
- Mentions of "main branch fix", "rollback", "patch production"

The plugin treats hotfixes as exceptional. Even with `autonomy: minimal`, triage **always** surfaces a confirmation:
> *"Detected as `hotfix` (base: main). PR will target main and require a follow-up back-merge to develop. Continue?"*

### 2. `release`

Signals (ANY of):
- Explicit keyword: "release v", "cut release", "prepare release", "version bump"
- Title matches regex `(release|version)\s+v?\d`

Release requires explicit version in the ticket — the plugin never auto-increments. If version is missing, triage asks once.

### 3. `bugfix`

Signals (ANY of):
- Verbs: "fix", "arreglar", "resolve", "bug", "error", "regression"
- No production urgency markers (otherwise → hotfix)

### 4. `docs`

Signals (ALL of):
- Verbs limited to: "document", "documentar", "explain", "describe", "rewrite docs", "update docs"
- Files mentioned are limited to `.md`, `.rst`, `.txt`, or `docs/` paths

### 5. `chore`

Signals (ANY of):
- Dependency updates: "bump", "update deps", "upgrade", "pin version"
- Tooling: "configure CI", "add lint rule", "update workflow", "build config"
- No application logic changes

### 6. `refactor`

Signals (ANY of):
- Explicit: "refactor", "rename", "restructure", "extract", "inline", "move"
- "No new behavior", "preserve semantics"

### 7. `spike`

Signals (ANY of):
- Explicit: "spike", "investigate", "prototype", "POC", "explore", "proof of concept"
- "Throwaway", "we'll redo this"

### 8. `feature` (default)

If no other signal matched and the ticket describes new functionality verbs (`add`, `implementá`, `build`, `introduce`, `implement`, `expose`, `support`), classify as feature.

If completely ambiguous, triage falls back to `git_flow.ticket_type_detection.default_when_unsure` (defaults to `feature`).

## Configuration

`.loop/config.yaml` schema:

```yaml
git_flow:
  enabled: true                       # set to false to disable git flow entirely

  base_branch: develop                # default base for feature/bugfix/chore/docs/refactor/spike
  main_branch: main                   # production branch (hotfix base + release target)

  branch_patterns:
    feature:  "feature/{ticket_id}-{slug}"
    bugfix:   "bugfix/{ticket_id}-{slug}"
    hotfix:   "hotfix/{ticket_id}-{slug}"
    release:  "release/{version}"
    chore:    "chore/{ticket_id}-{slug}"
    docs:     "docs/{ticket_id}-{slug}"
    refactor: "refactor/{ticket_id}-{slug}"
    spike:    "spike/{ticket_id}-{slug}"

  pr_targets:
    feature:  develop
    bugfix:   develop
    hotfix:   main
    release:  main
    chore:    develop
    docs:     develop
    refactor: develop
    spike:    develop

  commit_message:
    style: conventional             # conventional | simple | none
    prefixes:                       # only used when style: conventional
      feature: feat
      bugfix: fix
      hotfix: fix
      release: "chore(release)"
      chore: chore
      docs: docs
      refactor: refactor
      spike: "chore(spike)"

  ticket_type_detection:
    auto: true                      # let triage classify
    default_when_unsure: feature

  follow_up:
    hotfix_back_merge_to_develop: true   # after hotfix → main, create back-merge PR to develop
    release_back_merge_to_develop: true  # after release → main, create back-merge PR to develop
```

## GitHub Flow alternative

If your team uses GitHub Flow (main only, no develop), set `base_branch: main` and the same for all pr_targets:

```yaml
git_flow:
  base_branch: main
  main_branch: main
  pr_targets:
    feature: main
    bugfix: main
    hotfix: main
    release: main
    chore: main
    docs: main
    refactor: main
    spike: main
  follow_up:
    hotfix_back_merge_to_develop: false
    release_back_merge_to_develop: false
```

Hotfix detection still works — it just doesn't change the branch base since develop doesn't exist.

## Trunk-based development alternative

For trunk-based (short-lived branches, fast merge to main):

```yaml
git_flow:
  base_branch: main
  main_branch: main
  branch_patterns:
    feature:  "{ticket_id}-{slug}"     # no prefix
    bugfix:   "{ticket_id}-{slug}"
    hotfix:   "{ticket_id}-{slug}"
    # ... same simple pattern for all
```

## Branch creation flow (correct implementation — no working tree disturbance)

The runtime **never touches your current HEAD**. It uses a dedicated worktree for the merge step. Pseudo-code:

```bash
# 1. Snapshot current state (you're on whatever branch — develop, a feature, doesn't matter)
USER_HEAD=$(git -C <repo_root> rev-parse HEAD)
USER_BRANCH=$(git -C <repo_root> branch --show-current)

# 2. Resolve the base branch for THIS ticket's type
case $TICKET_TYPE in
  hotfix|release) BASE_NAME="$MAIN_BRANCH" ;;
  *)              BASE_NAME="$CONFIGURED_BASE_BRANCH" ;;
esac

# 3. Resolve where the base branch points (prefer local, fall back to origin)
BASE_REF=$(git -C <repo_root> rev-parse "$BASE_NAME" 2>/dev/null \
        || git -C <repo_root> rev-parse "origin/$BASE_NAME" 2>/dev/null \
        || echo "$USER_HEAD")  # last-resort fallback to user's current HEAD

# 4. Compute branch name from pattern + slugified title
SLUG=$(slugify "$TICKET_TITLE" | head -c 50)
BRANCH_NAME=$(echo "$PATTERN" | sed "s/{ticket_id}/$TICKET_ID/g; s/{slug}/$SLUG/g")
# e.g. "feature/PROJ-127-add-redis-cache"

# 5. Create the branch pointing to BASE_REF (without checkout)
git -C <repo_root> branch -f "$BRANCH_NAME" "$BASE_REF"

# 6. Dedicated merge worktree on the new branch
git -C <repo_root> worktree add "$RUN_DIR/merge-wt" "$BRANCH_NAME"

# 7. Apply each worker's diff into the merge worktree
for wt in $RUN_DIR/wt-*; do
  git -C "$RUN_DIR/merge-wt" apply --3way <(git -C "$wt" format-patch HEAD~1 --stdout) \
    || surface_conflict_to_user
done

# 8. Commit with conventional message
COMMIT_MSG="$(format_commit_message $TICKET_TYPE $TICKET_ID $TITLE)"
git -C "$RUN_DIR/merge-wt" add -A
git -C "$RUN_DIR/merge-wt" commit -m "$COMMIT_MSG"

# 9. Cleanup all worktrees (workers + merge)
git -C <repo_root> worktree remove --force "$RUN_DIR/merge-wt"
git -C <repo_root> worktree remove --force $RUN_DIR/wt-*

# 10. Verify user's state untouched
CURRENT_HEAD=$(git -C <repo_root> rev-parse HEAD)
CURRENT_BRANCH=$(git -C <repo_root> branch --show-current)
[[ "$CURRENT_HEAD" == "$USER_HEAD" && "$CURRENT_BRANCH" == "$USER_BRANCH" ]] || \
  error "INVARIANT VIOLATED: user's HEAD changed during run"
```

After this flow, the user's checkout is unchanged. The new branch exists and is ready for `git checkout` + push.

## PR target & follow-up branches

When `pr_creation_gate.on_ready: proceed` AND GitHub MCP is configured:

1. Open draft PR from `loop/<ticket>` (or `feature/<ticket>` etc) against `pr_targets[ticket_type]`.
2. For `hotfix` with `follow_up.hotfix_back_merge_to_develop: true`: after the main-target PR is created, ALSO create a draft back-merge PR from the hotfix branch to develop.
3. For `release` with `follow_up.release_back_merge_to_develop: true`: similar — back-merge PR from release to develop.

The chat resumen shows:

```
🌿 PR (main): https://github.com/owner/repo/pull/789 (draft, hotfix)
🌿 PR (develop back-merge): https://github.com/owner/repo/pull/790 (draft, follow-up)
```

## Conventional commit messages

When `commit_message.style: conventional`, the commit on the new branch follows the [Conventional Commits](https://www.conventionalcommits.org/) spec:

```
<prefix>(<ticket_id>): <ticket_title>

<spec_summary>

Closes <ticket_id>
```

Example for a feature ticket PROJ-127 "Add Redis cache for session state":

```
feat(PROJ-127): add Redis cache for session state

Introduces Redis-backed session storage with TTL-based eviction.
Replaces previous in-memory session store. ADR-001 records the
decision and trade-offs.

Closes PROJ-127
```

For release tickets, prefix becomes `chore(release): v1.2.0` and body includes the auto-generated changelog excerpt.

When `commit_message.style: simple` is set, only the title becomes the commit message. When `none`, the plugin uses git's default editor-less mode with `--allow-empty-message` (rare).

## Safety floor extensions (v0.8.0)

In addition to the six existing safety floors, two new rules apply:

7. **Hotfix detection always surfaces confirmation.** Even `autonomy: minimal` requires an explicit "continue" before creating a `hotfix/*` branch from main. Hotfixes touch production paths and warrant the extra friction.
8. **The user's HEAD is invariant.** The plugin verifies before-and-after that `git rev-parse HEAD` and `git branch --show-current` are unchanged. If anything switched the user's checkout (a bug or a tool error), the run aborts with `INVARIANT VIOLATED` so the user can investigate before continuing.

## Backward compatibility

If `git_flow.enabled: false` (or the section is missing), the v0.7.x behavior applies: a single `loop/<ticket_id>` branch, no ticket type classification, base branch is whatever HEAD points to. This is the simpler model for projects that don't use Git Flow.

## Quick reference: which branch will the plugin create?

| Your input | ticket_type | Base | New branch |
|---|---|---|---|
| `do "Add Redis cache PROJ-127"` | feature | develop | `feature/PROJ-127-add-redis-cache` |
| `do "Fix login null pointer PROJ-128"` | bugfix | develop | `bugfix/PROJ-128-fix-login-null-pointer` |
| `do "URGENT: production crash on /checkout PROJ-129"` | hotfix | main | `hotfix/PROJ-129-production-crash-on-checkout` |
| `do "Cut release v1.2.0"` | release | develop | `release/v1.2.0` |
| `do "Bump TypeScript to 5.6.2 PROJ-130"` | chore | develop | `chore/PROJ-130-bump-typescript-to-5-6-2` |
| `do "Update README installation steps PROJ-131"` | docs | develop | `docs/PROJ-131-update-readme-installation-steps` |
| `do "Refactor auth module PROJ-132"` | refactor | develop | `refactor/PROJ-132-refactor-auth-module` |
| `do "Spike: evaluate Bun as runtime PROJ-133"` | spike | develop | `spike/PROJ-133-evaluate-bun-as-runtime` |
