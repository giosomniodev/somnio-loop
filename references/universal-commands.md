# Universal verification commands

This reference is consulted by `worker-dev`, `verifier`, `loop-self-healing` and `spec-refiner` to discover the project's actual verification commands. Read in this order:

## Discovery priority (highest first)

1. **Project's task runner of choice** — read first, use verbatim:
   - `Makefile` — targets `lint`, `test`, `typecheck`, `build`, `check`, `ci`
   - `justfile` — recipes
   - `Taskfile.yml` / `Taskfile.yaml` (Go-task)
   - `tasks.py` (Python invoke)
   - `Rakefile` (Ruby)
   - `dune-project` (OCaml)
   - `mix.exs` aliases (Elixir)
   - `lefthook.yml` / `pre-commit-config.yaml` / `.husky/`
2. **Language-native script section in the manifest** (when no task runner above):
   - `package.json` → `scripts` (npm/pnpm/yarn/bun)
   - `pyproject.toml` → `[tool.poetry.scripts]` or `[project.scripts]` or `[tool.hatch.envs.default.scripts]`
   - `Cargo.toml` → `[package.metadata.scripts]` (rare; usually `cargo` subcommands)
   - `composer.json` → `scripts` (PHP)
   - `mix.exs` aliases (Elixir, also Layer 1)
   - `pubspec.yaml` → no scripts section; commands are conventional (`dart`, `flutter`)
   - `Gemfile` + `Rakefile`
   - `*.csproj` / `*.fsproj` → `dotnet` subcommands
   - `*.cabal` → `cabal` subcommands
   - `Project.toml` → Pkg.jl test
3. **Idiomatic per-language fallbacks** when neither task runner nor manifest scripts are configured. The table below is the canonical fallback — use only when discovery fails.

## Canonical fallback commands by stack

Use ONLY when discovery in steps 1 + 2 yields nothing. Prefer the project's own commands when present.

### TypeScript / JavaScript (npm / pnpm / yarn / bun)

| Action | Command (npm) | pnpm | yarn | bun |
|---|---|---|---|---|
| Typecheck | `npx tsc --noEmit` | `pnpm exec tsc --noEmit` | `yarn tsc --noEmit` | `bun x tsc --noEmit` |
| Test | `npx jest` / `npx vitest run` / `npx mocha` | `pnpm test` | `yarn test` | `bun test` |
| Lint | `npx eslint .` / `npx biome check .` | `pnpm lint` | `yarn lint` | `bun lint` |
| Build | `npx tsc` / `npx vite build` / `npx next build` | `pnpm build` | `yarn build` | `bun run build` |

### Python

| Action | Command |
|---|---|
| Typecheck | `mypy <package>` / `pyright` / `pyre` |
| Test | `pytest` / `python -m pytest` / `nox` / `tox` |
| Lint | `ruff check` / `flake8` / `pylint` / `black --check` |
| Format-check | `black --check .` / `ruff format --check .` |
| Build | `python -m build` / `poetry build` / `hatch build` |

### Go

| Action | Command |
|---|---|
| Typecheck / Build | `go build ./...` |
| Test | `go test ./...` |
| Lint | `golangci-lint run` / `staticcheck ./...` / `go vet ./...` |
| Format-check | `gofmt -l .` / `goimports -l .` |

### Rust

| Action | Command |
|---|---|
| Typecheck | `cargo check --all-targets` |
| Test | `cargo test --all` |
| Lint | `cargo clippy --all-targets -- -D warnings` |
| Format-check | `cargo fmt --check` |
| Build | `cargo build --release` |

### Ruby

| Action | Command |
|---|---|
| Test | `bundle exec rspec` / `bundle exec rake test` |
| Lint | `bundle exec rubocop` |
| Format-check | `bundle exec rubocop --fail-level=convention` |

### Java

| Action | Command (Maven) | Gradle |
|---|---|---|
| Test | `mvn test` | `./gradlew test` |
| Lint | `mvn checkstyle:check` / `mvn spotless:check` | `./gradlew checkstyleMain` / `./gradlew spotlessCheck` |
| Build | `mvn package` | `./gradlew build` |

### Kotlin

| Action | Command |
|---|---|
| Test | `./gradlew test` |
| Lint | `./gradlew ktlintCheck` / `./gradlew detekt` |
| Build | `./gradlew build` / `./gradlew assemble` |

### .NET (C# / F#)

| Action | Command |
|---|---|
| Test | `dotnet test` |
| Lint | `dotnet format --verify-no-changes` / `dotnet build /warnaserror` |
| Build | `dotnet build` |

### Elixir

| Action | Command |
|---|---|
| Test | `mix test` |
| Lint | `mix credo --strict` |
| Format-check | `mix format --check-formatted` |
| Build | `mix compile --warnings-as-errors` |

### PHP

| Action | Command |
|---|---|
| Test | `vendor/bin/phpunit` / `vendor/bin/pest` |
| Lint | `vendor/bin/phpstan analyse` / `vendor/bin/psalm` |
| Format-check | `vendor/bin/pint --test` / `vendor/bin/php-cs-fixer fix --dry-run` |

### Flutter / Dart

| Action | Command |
|---|---|
| Test | `flutter test` / `dart test` |
| Lint | `flutter analyze` / `dart analyze` |
| Format-check | `dart format --set-exit-if-changed .` |
| Build | `flutter build apk` / `flutter build ios` / `flutter build web` (target-specific) |

### React Native / Expo

| Action | Command |
|---|---|
| Test | `npm test` / `jest` |
| Lint | `eslint .` |
| Typecheck | `tsc --noEmit` |
| Build | `npx expo prebuild` + `eas build` / `react-native run-android` (dev) |

### Swift (iOS native)

| Action | Command |
|---|---|
| Test | `xcodebuild test -scheme <scheme> -destination 'platform=iOS Simulator,name=...'` / `swift test` (SPM) |
| Lint | `swiftlint lint` |
| Format-check | `swiftformat --lint .` |

### Haskell

| Action | Command |
|---|---|
| Test | `cabal test` / `stack test` |
| Typecheck / Build | `cabal build` / `stack build` |
| Lint | `hlint .` |

### Nix

| Action | Command |
|---|---|
| Eval check | `nix flake check` |
| Build | `nix build` / `nix-build` |

### Monorepo orchestrators (apply ON TOP of per-package commands)

| Tool | Command |
|---|---|
| Nx | `nx run-many --target=test --all` / `nx affected:test` |
| Turborepo | `turbo run test` / `turbo run lint --filter=...` |
| Bazel | `bazel test //...` |
| pnpm workspace | `pnpm -r test` |
| Lerna | `lerna run test` |

## Hard rule

When the spec §8 is being authored, ALWAYS prefer commands discovered from the project (step 1 + 2) over the fallback table. The fallback exists only for the early days of a project where scripts aren't yet defined. If even the fallback wouldn't apply (e.g. an exotic stack not listed here), the spec MUST mark §8 with `TBD — verification commands missing; clarify with user before implementation` rather than guess.
