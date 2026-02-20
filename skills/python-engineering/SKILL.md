---
name: python-engineering
description: "Use when writing Python code, configuring tooling, structuring projects, or working with FastAPI, httpx, pytest, or the Astral toolchain (uv, ruff, ty)."
allowed-tools: Bash, Read, Grep, Glob
---

# Python Engineering

Fast feedback, strong types: the Astral toolchain catches bugs before tests run.

## Principles

- **Type everything** -- `ty` + `ruff` catch bugs before tests run
- **Pydantic at boundaries** -- validate at entry/exit, trust internals
- **Async-first** -- `httpx`, `asyncio.TaskGroup`, structured concurrency
- **Fast feedback** -- Astral toolchain (uv, ruff, ty) keeps iteration < 1 s
- **Explicit over implicit** -- no star imports, no mutable defaults, no magic globals
- **Dependency injection** -- pass clients/sessions in, never construct at module level

## Standards

### Astral Toolchain

| Tool | Purpose | Key command |
|------|---------|-------------|
| **uv** 0.10 | Package management, lockfiles, Python version | `uv sync`, `uv run`, `uv lock` |
| **Ruff** 0.15 | Lint + format (single tool) | `ruff check --fix && ruff format` |
| **ty** 0.0.17 | Type checker (beta, fast) | `ty check src/` |

### Ruff Configuration

```toml
[tool.ruff]
target-version = "py313"
line-length = 99
[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "UP", "SIM", "RUF", "C4", "PTH", "TC"]
ignore = ["E501", "B008"]  # B008: allow Depends() in defaults
[tool.ruff.lint.isort]
known-first-party = ["mypackage"]
[tool.ruff.format]
quote-style = "double"
docstring-code-format = true
```

### ty Configuration

Beta -- use mypy or Pyright for stable CI until ty reaches 1.0. No plugin system yet (Pydantic/Django plugins unavailable).

```toml
[tool.ty.environment]
python-version = "3.13"
[tool.ty.rules]
unresolved-reference = "error"
invalid-assignment = "error"
call-non-callable = "error"
missing-argument = "error"
unknown-argument = "error"
invalid-return-type = "warn"
invalid-argument-type = "warn"
unused-ignore-comment = "warn"
```

### Modern Typing (3.12+)

| Old | Modern |
|-----|--------|
| `Optional[X]` | `X \| None` |
| `List[int]` | `list[int]` |
| `TypeVar("T")` | `class Foo[T]:` (PEP 695) |
| `TypeAlias` | `type X = ...` |
| N/A | `Self` for fluent return types |

### Pydantic v2

- `BaseModel` + `model_config = ConfigDict(strict=True, from_attributes=True)`
- `@field_validator("field")` with `@classmethod`
- `@model_validator(mode="before")` for cross-field logic
- `Field(min_length=1, max_length=100)` for constraints

## Workflow

1. **Models** -- define Pydantic schemas and domain types
2. **Logic** -- implement business rules with full type annotations
3. **Tests** -- pytest + pytest-asyncio (`asyncio_mode = "auto"`)
4. **Integration** -- FastAPI routes, dependency wiring

Pre-commit pipeline: `ruff check --fix` -> `ruff format` -> `ty check` -> `pytest`

## Patterns We Use

| Concern | Choice | Why |
|---------|--------|-----|
| Package management | `uv sync --locked` | Deterministic, 10-100x faster than pip |
| Build backend | `uv_build` | 10-35x faster than setuptools/hatchling |
| Lint + format | Ruff (sole tool) | Replaces black + isort + flake8 |
| API framework | FastAPI + `Annotated[T, Depends()]` | Async, typed DI, OpenAPI generation |
| HTTP client | `httpx.AsyncClient` | Async, connection pooling, testable |
| Logging | `structlog` + contextvars | Structured JSON, async-safe |
| Testing | pytest + pytest-asyncio (mode=auto) | No `@pytest.mark.asyncio` boilerplate |
| Containers | `python:3.13-slim` + uv | Small image, fast installs |

### Build System

```toml
[build-system]
requires = ["uv_build>=0.10,<0.11"]
build-backend = "uv_build"
```
### Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.13-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.10 /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project --no-dev
COPY . .
RUN uv sync --locked --no-dev

FROM python:3.13-slim
COPY --from=builder /app /app
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
USER nobody
ENTRYPOINT ["python", "-m", "myapp"]
```

pytest config in `[tool.pytest.ini_options]`: `asyncio_mode = "auto"`, `asyncio_default_fixture_loop_scope = "function"`, `asyncio_default_test_loop_scope = "function"`.

## Anti-Patterns

| Do Not | Do Instead |
|--------|------------|
| `pip install` in production | `uv sync --locked` |
| `from typing import *` | Import specific types; use builtins (`list`, `dict`) |
| `requests` in async code | `httpx.AsyncClient` |
| `print()` for logging | `structlog.get_logger()` |
| Mutable default arguments | `None` + conditional init in body |
| Module-level global clients | Dependency injection or lifespan |
| Ignore type errors | Fix or annotate explicitly (`# ty: ignore[rule]`) |
| `black` + `isort` + `flake8` | Ruff (single tool, faster) |

## References

- [uv](https://docs.astral.sh/uv/) | [Ruff](https://docs.astral.sh/ruff/) | [ty](https://docs.astral.sh/ty/) -- Astral toolchain
- [FastAPI](https://fastapi.tiangolo.com/) | [Pydantic v2](https://docs.pydantic.dev/) | [Python typing](https://typing.python.org/)
- [structlog](https://www.structlog.org/) | [httpx](https://www.python-httpx.org/) | [pytest-asyncio](https://pytest-asyncio.readthedocs.io/)
