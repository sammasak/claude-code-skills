# Python Engineering Patterns

Detailed patterns, workflows, and configurations for Python development.

## Ruff Configuration

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

## ty Configuration

Beta -- use mypy or Pyright for stable CI.

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

## Build System & Dockerfile

```toml
[build-system]
requires = ["uv_build>=0.10,<0.11"]
build-backend = "uv_build"
```

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

## Modern Typing & Pydantic v2 Examples

- Use `X | None` and `list[int]`.
- Pydantic: `BaseModel` + `ConfigDict(strict=True)`.
- Use `@field_validator` and `@model_validator(mode="before")`.

## References

- [uv](https://docs.astral.sh/uv/) | [Ruff](https://docs.astral.sh/ruff/) | [ty](https://docs.astral.sh/ty/)
- [FastAPI](https://fastapi.tiangolo.com/) | [Pydantic v2](https://docs.pydantic.dev/)
- [structlog](https://www.structlog.org/) | [httpx](https://www.python-httpx.org/) | [pytest-asyncio](https://pytest-asyncio.readthedocs.io/)
