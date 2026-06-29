# Manifest-type detection reference

Comprehensive list of dependency manifests by ecosystem. Used by `adr-author`, `spec-refiner`, and `triage` for tech-stack discovery. Detection precedence: most specific to most generic.

## By ecosystem

### Node / JS / TS

- `package.json` — universal
- `pnpm-workspace.yaml` — pnpm monorepo
- `lerna.json` — lerna monorepo
- `nx.json` + `workspace.json` — Nx monorepo
- `turbo.json` — Turborepo
- `bun.lockb` — Bun runtime hint
- `deno.json` / `deno.jsonc` — Deno

### Python

- `pyproject.toml` — PEP 518 modern projects (poetry / hatch / pdm / setuptools-config)
- `setup.py` / `setup.cfg` — older setuptools projects
- `requirements.txt` / `requirements-*.txt` — pip pinned deps
- `Pipfile` / `Pipfile.lock` — pipenv
- `environment.yml` — conda
- `tox.ini` / `nox.py` — multi-env test config

### Go

- `go.mod` — modules
- `Gopkg.toml` — legacy dep (rare)

### Rust

- `Cargo.toml` — crate
- `Cargo.lock` — locked deps
- `rust-toolchain.toml` — pinned toolchain
- `flake.nix` (often combined with Cargo for Nix users)

### Ruby

- `Gemfile` / `Gemfile.lock`
- `*.gemspec`
- `Rakefile`

### Java / Kotlin / JVM

- `pom.xml` — Maven
- `build.gradle` / `build.gradle.kts` — Gradle
- `settings.gradle(.kts)` — Gradle multi-project
- `gradle.properties` — Gradle config
- `pom.properties` — Maven sub
- `build.sbt` — Scala SBT
- `project.clj` — Clojure Leiningen
- `deps.edn` — Clojure deps

### .NET

- `*.csproj` — C# project
- `*.fsproj` — F# project
- `*.vbproj` — VB project
- `*.sln` — solution
- `Directory.Build.props` / `Directory.Packages.props` — central package mgmt
- `global.json` — SDK version pin

### Elixir / Erlang

- `mix.exs` — Mix project
- `rebar.config` — Rebar3

### PHP

- `composer.json` / `composer.lock`

### Dart / Flutter

- `pubspec.yaml` / `pubspec.lock`
- `analysis_options.yaml` — lints
- `melos.yaml` — Melos monorepo

### Swift / iOS

- `Package.swift` — SwiftPM
- `Podfile` / `Podfile.lock` — CocoaPods
- `Cartfile` — Carthage
- `project.pbxproj` (inside `*.xcodeproj/`) — Xcode

### Android

- `build.gradle(.kts)` (root + module)
- `settings.gradle(.kts)`
- `gradle/libs.versions.toml` — version catalog
- `AndroidManifest.xml`

### React Native / Expo

- `package.json` with `react-native` or `expo` deps
- `app.json` / `app.config.ts` — Expo config
- `metro.config.js` — bundler
- `react-native.config.js`

### Haskell

- `*.cabal` — Cabal package
- `cabal.project` — multi-package
- `stack.yaml` — Stack
- `package.yaml` — hpack source

### OCaml

- `dune-project`
- `dune` per dir
- `*.opam`

### Julia

- `Project.toml`
- `Manifest.toml`

### Crystal / Nim / Zig

- `shard.yml` (Crystal)
- `*.nimble` (Nim)
- `build.zig` (Zig)

### R

- `DESCRIPTION` / `NAMESPACE`
- `renv.lock`

### Lua

- `*.rockspec`

### Nix

- `flake.nix` / `flake.lock`
- `shell.nix` / `default.nix`
- `home.nix` (home-manager)

### Infrastructure

- `Dockerfile` / `docker-compose.yml` / `compose.yaml`
- `terraform/**/*.tf` / `terraform.lock.hcl`
- `*.bicep` (Azure)
- `cdk.json` (AWS CDK)
- `serverless.yml`
- `k8s/**/*.yaml` / `helm/Chart.yaml` / `kustomization.yaml`
- `ansible.cfg` / `playbook.yml`
- `Vagrantfile`
- `Pulumi.yaml`

### CI

- `.github/workflows/*.yml`
- `.gitlab-ci.yml`
- `.circleci/config.yml`
- `azure-pipelines.yml`
- `bitbucket-pipelines.yml`
- `Jenkinsfile`
- `cloudbuild.yaml`

## Detection algorithm

```python
# Pseudo-code for the agents
manifests = []
for root, dirs, files in walk(repo_root, maxdepth=3):
    # Skip vendored/build dirs
    if any(part in root for part in ["node_modules", "vendor", ".venv", "venv", "target", "build", ".gradle", ".dart_tool"]):
        continue
    for filename in files:
        if matches_any_manifest_pattern(filename):
            manifests.append(path(root, filename))

# Classify project_type by presence:
if has(manifests, ["pubspec.yaml"]) or has_dirs(["ios", "android"]):
    sub_type = "flutter" if has("pubspec.yaml") else "react-native-or-expo"
elif has(manifests, ["package.json"]):
    if scan_deps_for(["react-native", "expo"]):
        sub_type = "react-native-or-expo"
    elif scan_deps_for(["react", "next", "vue", "svelte", "solid", "angular", "qwik"]):
        sub_type = "frontend-spa-or-meta"
    elif scan_deps_for(["nest", "express", "fastify", "koa", "hono"]):
        sub_type = "backend-node"
```

## Hard rule

If the repo has NO manifest from the list above, the project is either pre-scaffolding OR uses a private build system. In both cases, the plugin asks the user to declare the stack via a `CLAUDE.md` `## Stack` section before proceeding — it does NOT guess.
