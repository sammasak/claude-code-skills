---
name: python-engineering
description: "Use when writing Python code, setting up a Python project or its tooling, or containerising a Python service."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Python Engineering (homelab choices)

Python is a minority language here (Rust is the default for services); the reference project is `evals/` in this repo.

| Concern | Choice |
|---|---|
| Packages / venv | `uv` (`uv sync --locked`, `uv run`); `uv_build` backend |
| Lint + format | `ruff` (target py313, line-length 99) |
| Type check | `ty` (beta; `mypy` acceptable where ty falls short) |
| HTTP | `httpx.AsyncClient`, injected rather than module-global |
| API | FastAPI + Pydantic v2 at the boundaries |
| Logging | `structlog` JSON (see `observability-patterns`) |
| Tests | `pytest` + `pytest-asyncio` |

## Container image

Multi-stage on `python:3.13-slim` (pin the digest), uv copied from `ghcr.io/astral-sh/uv`, `UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy`, `uv sync --locked --no-dev` in the builder, copy `/app` (with `.venv`) to the runtime stage, run as non-root. Push via the `container-workflows` skill.
