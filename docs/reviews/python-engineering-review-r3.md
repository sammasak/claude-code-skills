# Re-Review (R3): skills/python-engineering/SKILL.md

**Reviewer:** Claude Opus 4.6 (automated technical review)
**Date:** 2026-02-20
**Previous Score:** 9/10 (R2)
**New Score: 10/10**

---

## R2 Issue Resolution

### Issue: Dockerfile missing `ENV PATH` (was R2's sole deduction)

**R2 problem:** The Dockerfile hardcoded `/app/.venv/bin/python` in the entrypoint. Best practice per Astral's official Docker guide and Hynek Schlawack's widely-cited article is to set `ENV PATH="/app/.venv/bin:$PATH"` so that `python`, console scripts, and any installed CLI tools are available without absolute paths. This matters for `docker exec` debugging, `CMD` overrides, and health checks.

**R3 status: FIXED.**

Lines 123-129 now read:

```dockerfile
FROM python:3.13-slim
COPY --from=builder /app /app
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
USER nobody
ENTRYPOINT ["python", "-m", "myapp"]
```

This matches the canonical pattern exactly:
1. `ENV PATH` is set before the entrypoint (line 126).
2. The entrypoint uses plain `python` (line 128), relying on `PATH` resolution.
3. `USER nobody` is correctly placed after `ENV` and before `ENTRYPOINT`.

---

## Full File Re-Verification (Line-by-Line)

Since this is the final review, every section was re-checked against current documentation and the research file, not just the changed lines.

### YAML Frontmatter (lines 1-5)

```yaml
name: python-engineering
description: "Use when writing Python code, configuring tooling, structuring projects, or working with FastAPI, httpx, pytest, or the Astral toolchain (uv, ruff, ty)."
allowed-tools: Bash, Read, Grep, Glob
```

- `name` matches the directory name. Correct.
- `description` is a single quoted string (avoids Prettier multiline issues). Content accurately describes when the skill should trigger. Correct.
- `allowed-tools` matches the convention used across all skills in this repo. Correct.

**Verdict:** No issues.

### Principles (lines 7-18)

Six principles covering typing, Pydantic at boundaries, async-first, fast feedback, explicit over implicit, and dependency injection. All are accurate, actionable, and non-overlapping. No AI/agentic content has leaked in from the sibling `python-agentic-development` skill.

**Verdict:** No issues.

### Astral Toolchain Table (lines 22-28)

| Tool | Version in skill | Latest available | Status |
|------|-----------------|-----------------|--------|
| uv | 0.10 | 0.10.4 (2026-02-17) | Correct (minor-version reference) |
| Ruff | 0.15 | 0.15.2 (2026-02-19) | Correct (minor-version reference) |
| ty | 0.0.17 | 0.0.17 (2026-02-13) | Exact match |

All three rows use consistent granularity (minor version for uv and Ruff, exact for ty since it is pre-1.0 with breaking changes between patches). Key commands (`uv sync`, `uv run`, `uv lock`, `ruff check --fix && ruff format`, `ty check src/`) are all correct.

**Verdict:** No issues.

### Ruff Configuration (lines 30-44)

- `target-version = "py313"` is consistent with the Dockerfile (`python:3.13-slim`) and ty config (`python-version = "3.13"`). Internally consistent.
- `line-length = 99` is a valid, common choice.
- Rule set `["E", "W", "F", "I", "B", "UP", "SIM", "RUF", "C4", "PTH", "TC"]` is well-chosen and matches the research doc.
- `ignore = ["E501", "B008"]` with comment explaining B008 for `Depends()` is correct.
- `[tool.ruff.lint.isort]` with `known-first-party` is correctly structured.
- `[tool.ruff.format]` with `quote-style = "double"` and `docstring-code-format = true` is valid TOML and correct Ruff config.

**Verdict:** No issues.

### ty Configuration (lines 46-62)

- Beta caveat about using mypy/Pyright for stable CI is accurate and important.
- `[tool.ty.environment]` with `python-version = "3.13"` is correct syntax.
- All 8 rules (`unresolved-reference`, `invalid-assignment`, `call-non-callable`, `missing-argument`, `unknown-argument`, `invalid-return-type`, `invalid-argument-type`, `unused-ignore-comment`) are real ty 0.0.17 rules with correct severity levels.
- The error/warn split is sensible: definite bugs as errors, possible issues as warnings.

**Verdict:** No issues. The research doc has 3 additional rules (`possibly-unresolved-reference`, `deprecated`, `redundant-cast`) but the chosen 8 are the highest-value subset. Conciseness is appropriate for a skill file.

### Modern Typing Table (lines 64-73)

All five rows are accurate for Python 3.12+:
- `X | None` replaces `Optional[X]` (PEP 604)
- `list[int]` replaces `List[int]` (PEP 585)
- `class Foo[T]:` replaces `TypeVar("T")` (PEP 695)
- `type X = ...` replaces `TypeAlias` (PEP 695)
- `Self` for fluent return types (PEP 673)

**Verdict:** No issues.

### Pydantic v2 (lines 74-79)

- `BaseModel` + `model_config = ConfigDict(strict=True, from_attributes=True)` is correct Pydantic v2 syntax.
- `@field_validator("field")` with `@classmethod` is the correct v2 pattern.
- `@model_validator(mode="before")` is correct.
- `Field(min_length=1, max_length=100)` is correct.

**Verdict:** No issues.

### Workflow (lines 81-88)

Four-step workflow (Models, Logic, Tests, Integration) is sensible. Pre-commit pipeline order (`ruff check --fix` -> `ruff format` -> `ty check` -> `pytest`) is correct -- lint before format, type-check before test.

**Verdict:** No issues.

### Patterns Table (lines 90-101)

All 8 rows are accurate:
- `uv sync --locked` for deterministic installs. Correct.
- `uv_build` as build backend, 10-35x claim matches research. Correct.
- Ruff as sole lint+format tool. Correct.
- FastAPI + `Annotated[T, Depends()]` is the modern FastAPI DI pattern. Correct.
- `httpx.AsyncClient` for async HTTP. Correct.
- `structlog` + contextvars for structured logging. Correct.
- pytest + pytest-asyncio (mode=auto). Correct.
- `python:3.13-slim` + uv for containers. Correct.

**Verdict:** No issues.

### Build System (lines 103-109)

```toml
[build-system]
requires = ["uv_build>=0.10,<0.11"]
build-backend = "uv_build"
```

Matches the research doc exactly. Version constraint `>=0.10,<0.11` is appropriate for a build backend (avoid breaking changes).

**Verdict:** No issues.

### Dockerfile (lines 110-129)

Complete multi-stage Dockerfile:

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

Verification checklist:
- [x] `# syntax=docker/dockerfile:1` enables BuildKit features. Correct.
- [x] Builder stage copies uv from the official image. Correct.
- [x] `UV_COMPILE_BYTECODE=1` pre-compiles `.pyc` for faster startup. Correct.
- [x] `UV_LINK_MODE=copy` ensures files are copied (not symlinked) for cross-stage COPY. Correct.
- [x] Two-phase install: deps first (`--no-install-project`), then full install. Correct Docker layer caching pattern.
- [x] `--locked` ensures lockfile is respected. Correct.
- [x] `--no-dev` excludes dev dependencies. Correct.
- [x] Runtime stage uses `python:3.13-slim` (no uv needed). Correct.
- [x] `COPY --from=builder /app /app` brings over the built virtualenv. Correct.
- [x] `ENV PATH="/app/.venv/bin:$PATH"` makes the venv the default Python. Correct.
- [x] `USER nobody` for non-root execution. Correct.
- [x] `ENTRYPOINT ["python", "-m", "myapp"]` uses plain `python` via PATH. Correct.

**Verdict:** No issues. The Dockerfile is now the canonical Astral pattern.

### pytest Config (line 131)

```
pytest config in `[tool.pytest.ini_options]`: `asyncio_mode = "auto"`,
`asyncio_default_fixture_loop_scope = "function"`,
`asyncio_default_test_loop_scope = "function"`.
```

All three settings are present and correct. This is inline prose rather than a TOML block, which is a minor stylistic inconsistency with the other configs, but the information is complete and unambiguous.

**Verdict:** No issues.

### Anti-Patterns Table (lines 133-144)

All 8 rows are accurate and practical. The `# ty: ignore[rule]` syntax matches the official ty suppression format. The "Ruff replaces black + isort + flake8" recommendation is correct.

**Verdict:** No issues.

### References (lines 146-150)

All 9 URLs verified:
- `docs.astral.sh/uv/` -- valid
- `docs.astral.sh/ruff/` -- valid
- `docs.astral.sh/ty/` -- valid
- `fastapi.tiangolo.com` -- valid
- `docs.pydantic.dev` -- valid
- `typing.python.org` -- valid
- `www.structlog.org` -- valid
- `www.python-httpx.org` -- valid
- `pytest-asyncio.readthedocs.io` -- valid

**Verdict:** No issues.

---

## Previously Noted Items (Carried Forward, Not Deductions)

These were noted in R1 and R2 as acceptable scope decisions for a concise skill file. They remain unchanged and remain acceptable:

1. **ty has 8 of 11 rules from the research doc.** The chosen 8 are the highest-value subset. Acceptable.
2. **No `[tool.ty.src]` section.** ty auto-discovers in many cases; not prescribing project layout is a valid choice. Acceptable.
3. **No `indent-style` in Ruff format config.** The default (`space`) is what the skill would specify. Omitting defaults is valid. Acceptable.
4. **No `--mount=type=cache` in Dockerfile.** A build performance optimization, not a correctness requirement. Acceptable for a template.
5. **pytest config is inline prose, not a TOML block.** Minor visual inconsistency; information is complete. Acceptable.
6. **Missing content (FastAPI lifespan, httpx testing, structlog config, respx, workspaces, TypeVar defaults, per-file ty overrides).** All valid for a comprehensive guide but would bloat a skill file beyond its purpose as a quick reference. Acceptable.

---

## Scoring Breakdown

| Criterion | R1 | R2 | R3 | Notes |
|-----------|-----|-----|-----|-------|
| YAML frontmatter | 10 | 10 | 10 | Correct format, matches repo conventions |
| Version accuracy | 9 | 10 | 10 | All versions current as of 2026-02-20 |
| Config syntax correctness | 8 | 9 | 10 | All configs valid TOML, correct tool syntax |
| Dockerfile correctness | 3 | 8 | 10 | Canonical Astral pattern with ENV PATH |
| Modern typing accuracy | 9 | 9 | 9 | Correct for 3.12+; 3.13 features omitted by scope |
| pytest-asyncio config | 8 | 10 | 10 | All three settings present |
| No AI/agentic content leak | 10 | 10 | 10 | Clean separation maintained |
| Reference URLs | 10 | 10 | 10 | All valid |
| Completeness vs research doc | 6 | 7 | 7 | Appropriate scope for a skill file |
| Overall utility as a skill | 8 | 9 | 10 | No remaining correctness or best-practice gaps |

---

## Review History

| Round | Score | Key Changes |
|-------|-------|-------------|
| R1 | 7/10 | Initial review. Broken Dockerfile (uv not in runtime stage), missing build-system config, incomplete pytest-asyncio config. |
| R2 | 9/10 | All R1 issues fixed. Dockerfile worked but used hardcoded venv path instead of ENV PATH. |
| R3 | 10/10 | ENV PATH fix applied. Dockerfile now matches canonical Astral pattern. |

---

**Final Score: 10/10** -- Every section of the skill file is technically correct, internally consistent, and aligned with current best practices. The Dockerfile is now the canonical Astral multi-stage pattern. All tool versions are current. All configurations use valid syntax. The scope is appropriate for a skill file: opinionated, concise, and actionable without being exhaustive. No remaining correctness issues, best-practice gaps, or deductions.
