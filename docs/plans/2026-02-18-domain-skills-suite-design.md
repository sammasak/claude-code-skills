# Domain-Partitioned Skills Suite — Design

**Date**: 2026-02-18
**Status**: Approved

## Goal

Replace repo-specific skills with universal, domain-partitioned skills that teach patterns and standards any developer needs to work effectively with our toolchain. Each skill is educational but compact — checklists over prose, compiler enforcement over human review, under 150 lines.

## Skill Inventory

| Skill | Replaces | Purpose |
|-------|----------|---------|
| `nix-flake-development` | `nixos-rebuild` | Nix flake patterns, module composition, rebuild workflows, rollback safety |
| `kubernetes-gitops` | `homelab-deploy` | FluxCD/GitOps patterns, repo structure, reconciliation, secrets, health checks |
| `rust-engineering` | — | Compiler-driven development, clippy strictness, workspace patterns, error handling |
| `python-agentic-development` | — | pydantic-ai agents, structured outputs, tool design, async, testing |
| `clean-code-principles` | — | Language-agnostic readability, testability, naming, SOLID without ceremony |
| `container-workflows` | — | Rootless buildah/skopeo, multi-stage builds, minimal images, registry patterns |
| `observability-patterns` | — | Prometheus, structured logging, OpenTelemetry, Loki, alerting |
| `secrets-management` | — | SOPS + age, sealed secrets, env var hygiene, rotation |

## Agents

| Agent | Status | Purpose |
|-------|--------|---------|
| `nix-explorer` | Existing (minor cleanup) | NixOS config exploration |
| `k8s-debugger` | New | kubectl diagnostics, Flux troubleshooting, pod/node analysis |

## Skill Template

Each skill follows: Principles → Standards → Workflow → Patterns We Use → Anti-Patterns → References.

## Design Principles

1. Generic patterns first, specific tooling choices in "Patterns We Use" section
2. Checklists and tables over prose paragraphs
3. Point to compiler/linter enforcement wherever possible
4. Curated reference links at the end of each skill
5. Under 150 lines — context window is a public good
