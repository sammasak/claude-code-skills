---
name: python-engineering
description: "Use when writing Python code, configuring tooling, structuring projects, or working with FastAPI, httpx, pytest, or the Astral toolchain (uv, ruff, ty)."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Python Engineering

## Principles

- **Type everything** -- `ty` + `ruff` catch bugs before tests run.
- **Pydantic at boundaries** -- validate at entry/exit, trust internals.
- **Async-first** -- `httpx`, `asyncio.TaskGroup`, structured concurrency.
- **Explicit over implicit** -- no star imports, no mutable defaults.
- **Dependency injection** -- pass clients/sessions in.

## Standards

- **Toolchain**: Use `uv` (package management), `ruff` (lint/format), and `ty` (type checking).
- **Modern Typing**: Use `X | None` and `list[int]` (Python 3.12+).
- **Full Reference**: Read `docs/python-engineering-patterns.md` for Ruff/ty configs, Dockerfile templates, and build system details.

## Workflow

1. **Models** (Pydantic) -> 2. **Logic** (typed) -> 3. **Tests** (pytest) -> 4. **Integration** (FastAPI)

## Patterns We Use

| Concern | Choice | Why |
|---------|--------|-----|
| Package management | `uv sync --locked` | Deterministic and fast |
| API framework | FastAPI | Async, typed DI, OpenAPI |
| Logging | `structlog` | Structured JSON, async-safe |
| Containers | `python:3.13-slim` | Minimal and fast |

<restrictions>

## Anti-Patterns

- **Never** use `pip install` in production; use `uv sync`.
- **Avoid** `requests` in async code; use `httpx.AsyncClient`.
- **Do not** use `print()` for logging; use `structlog`.
- **Minimize** module-level global clients; use dependency injection.

</restrictions>
