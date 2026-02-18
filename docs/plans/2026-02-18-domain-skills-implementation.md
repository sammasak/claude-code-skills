# Domain-Partitioned Skills Suite — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace repo-specific skills with 8 universal domain skills and 1 new agent that teach patterns any developer needs for our NixOS + K8s + Rust + Python stack.

**Architecture:** Each skill follows a consistent template (Principles → Standards → Workflow → Patterns We Use → Anti-Patterns → References). Skills are generic enough to be useful on any project using the same technology, with a "Patterns We Use" section for our specific choices. Under 150 lines each.

**Tech Stack:** Claude Code plugin system, SKILL.md format with YAML frontmatter, Markdown agent definitions.

---

### Task 1: Delete old repo-specific skills

**Files:**
- Delete: `skills/nixos-rebuild/SKILL.md`
- Delete: `skills/homelab-deploy/SKILL.md`

**Step 1: Remove old skill directories**

Run: `rm -rf skills/nixos-rebuild skills/homelab-deploy`

**Step 2: Verify removal**

Run: `ls skills/`
Expected: empty directory

**Step 3: Commit**

```bash
git add -A && git commit -m "chore: remove repo-specific skills before rewrite"
```

---

### Task 2: Create `nix-flake-development` skill

**Files:**
- Create: `skills/nix-flake-development/SKILL.md`

**Content requirements (replaces nixos-rebuild):**
- Frontmatter: name, description triggers on NixOS/Nix/flake/rebuild/module work, allowed-tools: Bash Read Grep Glob
- Principles: declarative config, reproducibility, flake lock pinning, module composition
- Standards: flake.nix structure, input hygiene (follows/pinning), module option patterns (mkOption, mkEnableOption), lib usage (mkIf, mkMerge, mkDefault, mkForce)
- Workflow: rebuild cycle (flake check → build → switch), rollback, remote deploys, garbage collection
- Patterns We Use: role-based host composition, custom option namespaces, variables.nix per host, Home Manager integration, mkHost helpers
- Anti-patterns: imperative nix-env, unpinned inputs, monolithic configuration.nix, eval-time IFD
- References: NixOS manual, nix.dev, Nix Pills, zero-to-nix, mcp-nixos

**Step 1: Create skill directory and write SKILL.md**

Write the complete skill file.

**Step 2: Verify frontmatter parses**

Run: `head -10 skills/nix-flake-development/SKILL.md`
Expected: valid YAML frontmatter between `---` markers

**Step 3: Verify line count under 150**

Run: `wc -l skills/nix-flake-development/SKILL.md`
Expected: under 150 lines

**Step 4: Commit**

```bash
git add skills/nix-flake-development/SKILL.md
git commit -m "feat: add nix-flake-development skill"
```

---

### Task 3: Create `kubernetes-gitops` skill

**Files:**
- Create: `skills/kubernetes-gitops/SKILL.md`

**Content requirements (replaces homelab-deploy):**
- Frontmatter: triggers on K8s/cluster/deploy/flux/gitops/helm/kubectl work
- Principles: Git as single source of truth, pull-based reconciliation, drift detection, declarative desired state
- Standards: repo structure (infra vs apps separation), Kustomization layering, HelmRelease patterns, namespace isolation, Pod Security Standards, resource requests/limits
- Workflow: health checks (nodes, pods, flux), force reconciliation, debugging failed resources, image update automation
- Patterns We Use: FluxCD over ArgoCD (lightweight, K8s-native), MetalLB for bare-metal LB, ingress-nginx + cert-manager, KubeVirt for VM workloads, SOPS+age for secrets (cross-ref secrets-management skill)
- Anti-patterns: kubectl apply from laptop, hardcoded image tags, secrets in plaintext, skipping resource limits, cluster-admin for everything
- References: FluxCD docs, Kubernetes docs, GitOps principles (OpenGitOps), k8s production best practices

**Steps:** Same pattern as Task 2 — write, verify frontmatter, verify line count, commit.

---

### Task 4: Create `rust-engineering` skill

**Files:**
- Create: `skills/rust-engineering/SKILL.md`

**Content requirements:**
- Frontmatter: triggers on Rust/Cargo/clippy/unsafe/lifetime/workspace work
- Principles: let the compiler catch bugs (ownership, borrowing, lifetimes are your allies not obstacles), zero-cost abstractions, make illegal states unrepresentable, if it compiles it's probably correct
- Standards: `unsafe_code = "forbid"` in all crates, clippy `all = deny` + `pedantic = warn` + `nursery = warn`, rustfmt enforced in CI, error handling via thiserror (libraries) / anyhow (binaries), newtype pattern for domain types, prefer `impl Trait` over `dyn Trait` when possible
- Workflow: cargo check (fast feedback) → clippy → test → build, workspace dependency deduplication (`[workspace.dependencies]`), release profiles (opt-level, LTO, codegen-units, strip)
- Patterns We Use: axum for HTTP, kube-rs for K8s, tower middleware, utoipa for OpenAPI, multi-stage Docker with `FROM scratch`, `just` for task running
- Anti-patterns: `.unwrap()` in library code, `String` where `&str` suffices, `clone()` to satisfy the borrow checker without understanding why, ignoring clippy warnings, `pub` on everything
- References: Rust API Guidelines, Rust Performance Book, Error Handling in Rust (blog), Rust Design Patterns book, Clippy lint list

**Steps:** Same pattern — write, verify, commit.

---

### Task 5: Create `python-agentic-development` skill

**Files:**
- Create: `skills/python-agentic-development/SKILL.md`

**Content requirements:**
- Frontmatter: triggers on Python/agent/pydantic/LLM/tool/agentic work
- Principles: start simple (only add agents when simpler approaches fail), design tools for agents not humans, set iteration limits and timeouts, invest in observability from day one
- Standards: pydantic models for all data boundaries, structured outputs over string parsing, async-first with httpx, dependency injection for agent deps, ruff for lint+format, ty for type checking, pytest-asyncio for async tests
- Workflow: uv for package management, pre-commit hooks (ruff, ty, pytest), structured logging with structlog, OpenTelemetry instrumentation
- Patterns We Use: pydantic-ai for agent definitions, pydantic-graph for task execution workflows, FastAPI + WebSocket for real-time interfaces, SurrealDB for knowledge persistence, tool functions that wrap external APIs (Prometheus, Loki, workstation-api)
- Anti-patterns: string-based prompts without structured outputs, agents without timeout/iteration limits, testing agents by running them (test tools and logic separately), catching bare Exception, mutable global state
- References: Anthropic building effective agents guide, pydantic-ai docs, FastAPI best practices, Python typing best practices, structlog docs

**Steps:** Same pattern — write, verify, commit.

---

### Task 6: Create `clean-code-principles` skill

**Files:**
- Create: `skills/clean-code-principles/SKILL.md`

**Content requirements:**
- Frontmatter: triggers on code review, refactor, naming, architecture, test, quality work — user-invocable false (Claude auto-invokes when reviewing or writing code)
- Principles: readability > cleverness, functions do one thing, names reveal intent, tests are documentation, smallest possible public API
- Standards: functions under 20 lines (prefer under 10), max 3 parameters, no boolean parameters (use enums/named types), early returns over nested ifs, dependency injection over global state, composition over inheritance
- Workflow: write the test first, make it pass, refactor, repeat. Run formatter and linter before committing. Every PR should be reviewable in under 10 minutes.
- Patterns We Use: strict linters as enforcers (clippy deny-all, ruff, ty), just as universal task runner, pre-commit hooks as safety net, multi-stage Docker for minimal deployable artifacts
- Anti-patterns: comments that restate the code, dead code left "just in case", premature abstraction, god objects/functions, stringly-typed APIs, silencing linter warnings without explanation
- References: Clean Code (Martin), A Philosophy of Software Design (Ousterhout), Refactoring (Fowler), Google Engineering Practices

**Steps:** Same pattern — write, verify, commit.

---

### Task 7: Create `container-workflows` skill

**Files:**
- Create: `skills/container-workflows/SKILL.md`

**Content requirements:**
- Frontmatter: triggers on Docker/container/image/buildah/skopeo/registry/Dockerfile work
- Principles: minimal images (smallest attack surface = fewest CVEs), rootless builds, reproducible layers, separate build and runtime stages
- Standards: multi-stage builds always, `FROM scratch` or `*-slim` for runtime, no secrets in image layers, pin base image digests for reproducibility, set non-root USER, COPY specific files (never COPY .)
- Workflow: buildah build → skopeo inspect → skopeo copy to registry, image scanning before push
- Patterns We Use: buildah+skopeo (rootless, daemonless) over Docker, Harbor as private registry, Nix for reproducible build environments, `FROM scratch` for Rust binaries, `python:3.x-slim` for Python
- Anti-patterns: running as root, installing dev tools in runtime image, `latest` tags in production, secrets via ENV or ARG, ignoring .dockerignore
- References: Docker best practices, buildah docs, Chainguard images guide, SLSA supply chain security

**Steps:** Same pattern — write, verify, commit.

---

### Task 8: Create `observability-patterns` skill

**Files:**
- Create: `skills/observability-patterns/SKILL.md`

**Content requirements:**
- Frontmatter: triggers on metrics/logging/tracing/prometheus/loki/grafana/opentelemetry/alerting work
- Principles: observe, don't guess. Three pillars: metrics (what), logs (why), traces (where). Instrument at system boundaries. Alert on symptoms not causes.
- Standards: structured logging always (JSON), use log levels correctly (ERROR = action needed, WARN = degraded, INFO = business events, DEBUG = dev only), RED metrics for services (Rate, Errors, Duration), USE metrics for resources (Utilization, Saturation, Errors), trace IDs propagated across service boundaries
- Workflow: add metrics/traces at service creation (not after incidents), Prometheus scrape config, Loki log queries (LogQL), Grafana dashboard patterns
- Patterns We Use: kube-prometheus-stack for cluster monitoring, Loki+Promtail for log aggregation, OpenTelemetry SDK in application code, structlog for Python, tracing crate for Rust, metrics crate + prometheus exporter for Rust
- Anti-patterns: logging PII, unstructured log lines, alerting on every error (alert fatigue), missing trace context in cross-service calls, dashboards nobody looks at
- References: Google SRE book (monitoring chapter), OpenTelemetry docs, Prometheus best practices, Grafana Loki docs

**Steps:** Same pattern — write, verify, commit.

---

### Task 9: Create `secrets-management` skill

**Files:**
- Create: `skills/secrets-management/SKILL.md`

**Content requirements:**
- Frontmatter: triggers on secret/sops/age/credential/token/key/encrypt work
- Principles: secrets never in plaintext in Git, encrypt at rest and in transit, principle of least privilege, rotate regularly, audit access
- Standards: use SOPS+age for file-level encryption, .sops.yaml config at repo root, encrypt only value fields (not keys) for reviewable diffs, Kubernetes Secrets via SOPS-encrypted manifests, environment variables for runtime secrets (never baked into images)
- Workflow: generate age key → configure .sops.yaml → encrypt with `sops -e` → commit encrypted file → Flux/controller decrypts at deploy time
- Patterns We Use: age over PGP (simpler key management), SOPS for GitOps-friendly encryption, Flux SOPS integration for automatic decryption, separate age keys per environment
- Anti-patterns: secrets in Docker ENV/ARG, committing .env files, shared secrets across environments, never-rotated tokens, secrets in CI logs
- References: SOPS docs, age docs, Flux SOPS guide, OWASP secrets management cheat sheet

**Steps:** Same pattern — write, verify, commit.

---

### Task 10: Create `k8s-debugger` agent

**Files:**
- Create: `agents/k8s-debugger.md`

**Content requirements:**
- Frontmatter: name, description (triggers on K8s troubleshooting, pod failures, node issues, Flux errors), model: haiku, tools: Bash, Read, Grep, Glob
- System prompt: you are a Kubernetes cluster debugger, systematic approach — check nodes first, then system pods, then workload pods, then events, then logs
- Methodology: 1) cluster overview (nodes, system health) 2) identify the failing layer (infra, platform, app) 3) gather evidence (describe, events, logs) 4) diagnose with specific remediation steps
- Patterns to recognize: CrashLoopBackOff, ImagePullBackOff, Pending (scheduling), OOMKilled, Flux reconciliation failures, certificate expiry
- Always run commands, never guess from descriptions

**Step 1: Write agent file**

**Step 2: Verify frontmatter**

**Step 3: Commit**

```bash
git add agents/k8s-debugger.md
git commit -m "feat: add k8s-debugger agent"
```

---

### Task 11: Clean up `nix-explorer` agent

**Files:**
- Modify: `agents/nix-explorer.md`

**Changes:**
- Make description slightly more generic (not tied to a specific repo)
- Keep methodology as-is (already pattern-focused)

**Step 1: Edit agent file**

**Step 2: Commit**

```bash
git add agents/nix-explorer.md
git commit -m "refactor: generalize nix-explorer agent description"
```

---

### Task 12: Final verification and commit

**Step 1: Verify all skills exist and are under 150 lines**

Run: `wc -l skills/*/SKILL.md agents/*.md`

**Step 2: Verify plugin structure is correct**

Run: `find . -name '*.md' -not -path './.git/*' | sort`

**Step 3: Final commit with all changes**

If any uncommitted changes remain, commit them.
