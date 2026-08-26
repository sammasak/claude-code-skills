# Review: skills/python-engineering/SKILL.md

**Reviewer:** Claude Opus 4.6 (automated technical review)
**Date:** 2026-02-20
**Score: 7/10**

---

## What's Accurate and Well-Done

1. **YAML frontmatter** follows the correct Claude Code skill format (`name`, `description`, `allowed-tools`). The description is a single line (avoids the Prettier multiline footgun). The `allowed-tools: Bash, Read, Grep, Glob` matches the convention used across all other skills in this repo.

2. **Astral toolchain table** correctly identifies uv, Ruff, and ty as the three tools, with accurate purpose descriptions and key commands.

3. **Ruff configuration syntax** is valid pyproject.toml. The `[tool.ruff]`, `[tool.ruff.lint]`, `[tool.ruff.lint.isort]`, and `[tool.ruff.format]` sections are all correctly structured. The rule set (`E`, `W`, `F`, `I`, `B`, `UP`, `SIM`, `RUF`, `C4`, `PTH`, `TC`) matches the research doc and is a well-chosen set. The `B008` ignore for `Depends()` is a correct and practical choice.

4. **ty configuration** uses the correct `[tool.ty.environment]` and `[tool.ty.rules]` sections. All rule names (`unresolved-reference`, `invalid-assignment`, `call-non-callable`, `missing-argument`, `unknown-argument`, `invalid-return-type`, `invalid-argument-type`, `unused-ignore-comment`) are real ty rules with correct severity values.

5. **ty caveat** about no plugin system (Pydantic/Django) and recommending mypy/Pyright for stable CI is accurate and important.

6. **Modern typing table** is correct for 3.12+: `X | None`, `list[int]`, PEP 695 `class Foo[T]:`, `type X = ...`, and `Self` are all accurate.

7. **Pydantic v2 patterns** are correct: `model_config = ConfigDict(strict=True, from_attributes=True)`, `@field_validator` with `@classmethod`, `@model_validator(mode="before")`, `Field()` constraints.

8. **Anti-patterns table** is practical and correct. The `# ty: ignore[rule]` syntax matches the official ty suppression format.

9. **Principles** are sound and well-articulated. No AI/agentic content has leaked in -- this is cleanly separated from the `python-agentic-development` skill.

10. **References** section URLs are all valid: `docs.astral.sh/uv/`, `docs.astral.sh/ruff/`, `docs.astral.sh/ty/`, `fastapi.tiangolo.com`, `docs.pydantic.dev`, `typing.python.org`, `www.structlog.org`, `www.python-httpx.org`, `pytest-asyncio.readthedocs.io`.

---

## Issues Found

### Issue 1: Ruff version is stale (Minor)

**What it says:** `Ruff 0.15`
**What it should say:** `Ruff 0.15` is acceptable as a minor-version pin, but the latest patch is **0.15.2** (released 2026-02-19). The research doc has `0.15.1`. Not strictly wrong since the table uses minor-version granularity, but inconsistent with the uv and ty rows that also use minor-version. Acceptable as-is if the intent is minor-version references.

**Verdict:** No change needed, but be aware.

### Issue 2: Ruff target-version says py313, research doc says py312 (Minor discrepancy)

**What it says:** `target-version = "py313"`
**Research doc says:** `target-version = "py312"`

Both are valid values. However, `py313` is a reasonable choice for a 3.13-focused project. The discrepancy should be intentional. Since the skill title says "Modern Typing (3.12+)" and the Dockerfile uses `python:3.13-slim`, using `py313` is internally consistent within the skill file. **Not an error**, but worth noting the deviation from the research doc.

### Issue 3: Dockerfile ENTRYPOINT uses `uv run` -- not production best practice (Significant)

**What it says:**
```dockerfile
ENTRYPOINT ["uv", "run"]
```

**What it should say:** The multi-stage Dockerfile copies the built app from the builder stage but then uses `ENTRYPOINT ["uv", "run"]` in the final stage. This has several problems:

1. **uv is not available in the final stage.** The `COPY --from=ghcr.io/astral-sh/uv:0.10 /uv /uvx /bin/` is only in the builder stage. The final `python:3.13-slim` stage never gets the uv binary. This Dockerfile **will not work as written**.
2. Even if uv were copied to the final stage, using `uv run` as the entrypoint is **not recommended for production** because it adds an unnecessary process wrapper (PID 1 signal handling issues), increases image size, and increases attack surface.
3. The recommended pattern is to activate the virtualenv via `ENV PATH="/app/.venv/bin:$PATH"` and use a direct entrypoint like `ENTRYPOINT ["python", "-m", "uvicorn", ...]` or `CMD ["python", "-m", "myapp"]`.

**Recommended fix:**
```dockerfile
FROM python:3.13-slim
COPY --from=builder /app /app
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
USER nobody
ENTRYPOINT ["python", "-m", "uvicorn", "myapp:app", "--host", "0.0.0.0"]
```

Or for a generic skill example:
```dockerfile
FROM python:3.13-slim
COPY --from=builder /app /app
WORKDIR /app
ENV PATH="/app/.venv/bin:$PATH"
USER nobody
```

### Issue 4: Dockerfile uv image tag `0.10` -- not a real tag (Minor)

**What it says:** `COPY --from=ghcr.io/astral-sh/uv:0.10 /uv /uvx /bin/`
**What it should say:** The `ghcr.io/astral-sh/uv` image supports `{major}.{minor}` tags like `0.10`, which resolves to the latest patch. This is actually valid per the Docker registry docs. However, best practice per Astral's own docs is to pin to a specific patch version (e.g., `0.10.4`) or even a SHA256 digest for reproducibility.

**Verdict:** Not wrong, but a minor best-practice gap.

### Issue 5: Missing `asyncio_default_test_loop_scope` in pytest config (Minor)

**What it says (line 126):**
```
asyncio_mode = "auto", asyncio_default_fixture_loop_scope = "function"
```

**What the research doc includes that the skill omits:**
```toml
asyncio_default_test_loop_scope = "function"
```

The research doc (line 674) includes `asyncio_default_test_loop_scope = "function"` alongside the fixture scope. This is a separate config option added in pytest-asyncio 1.3.0 that controls the default loop scope for tests (not just fixtures). While it defaults to `function` when unset, explicitly setting it is good practice and is documented in the research.

### Issue 6: ty config is missing rules from the research doc (Minor)

**What it says:** The skill's ty config has 8 rules.
**What the research doc has:** The research doc includes 3 additional rules: `possibly-unresolved-reference = "warn"`, `deprecated = "warn"`, `redundant-cast = "warn"`.

These are useful rules that the skill could include. The skill's subset is not wrong, but it's less comprehensive than what the research supports.

### Issue 7: ty config is missing `[tool.ty.src]` section (Minor)

**What it says:** The ty config only has `[tool.ty.environment]` and `[tool.ty.rules]`.
**What the research doc includes:** `[tool.ty.src]` with `root = "src"`. This is important for projects using the `src/` layout (which is the standard for uv-managed projects). Its omission could cause ty to fail to find modules.

### Issue 8: Ruff config is missing `indent-style` (Cosmetic)

**What it says:**
```toml
[tool.ruff.format]
quote-style = "double"
docstring-code-format = true
```

**Research doc includes:** `indent-style = "space"` and `skip-magic-trailing-comma = false`. These are the defaults, so omitting them is technically fine, but the research doc includes them for explicitness.

**Verdict:** Not an error. The skill is being concise.

### Issue 9: `uv_build` mentioned in patterns table but not explained (Minor)

**What it says:** `uv_build` is listed as the build backend choice with "10-35x faster than setuptools/hatchling".
**What's missing:** No pyproject.toml example showing the `[build-system]` configuration for `uv_build`. The research doc provides:
```toml
[build-system]
requires = ["uv_build>=0.10,<0.11"]
build-backend = "uv_build"
```

This is a notable omission since someone following the skill would know to use `uv_build` but not how to configure it.

---

## Missing Content

1. **No `[build-system]` / `uv_build` config example.** The "Patterns We Use" table mentions it, but there is no config snippet showing the setup.

2. **No lifespan pattern for FastAPI.** The skill mentions `httpx.AsyncClient` and dependency injection but doesn't show the lifespan pattern for long-lived resources (the research doc has a full example).

3. **No httpx testing patterns.** The skill mentions httpx but doesn't show `ASGITransport` for testing FastAPI apps or `MockTransport` for mocking -- both are important patterns covered in the research.

4. **No structlog configuration.** The skill mentions `structlog + contextvars` in the patterns table but provides zero configuration. The research doc has full dev and prod configs.

5. **No `respx` mention.** The research doc covers respx for httpx mocking, which is listed as a dev dependency in the example pyproject.toml.

6. **No workspace/monorepo guidance.** The research doc covers `[tool.uv.workspace]` for Cargo-style monorepos, but the skill has nothing on this.

7. **No TypeVar defaults (3.13+) or TypeIs mention.** The modern typing table covers 3.12+ patterns but omits 3.13-specific features like `class Container[T = int]:` and `TypeIs` for type narrowing, both of which are in the research doc.

8. **No per-file ty overrides.** The research doc shows `[[tool.ty.overrides]]` for relaxing rules in `tests/**`, which is a practical pattern for real projects.

---

## Recommendations

1. **Fix the Dockerfile (critical).** The current Dockerfile is broken -- `uv` is not available in the final stage, so `ENTRYPOINT ["uv", "run"]` will fail at runtime. Either copy uv to the final stage and use `uv run --no-sync`, or (preferred) set `ENV PATH="/app/.venv/bin:$PATH"` and use a direct Python entrypoint.

2. **Add a `[build-system]` snippet.** Since `uv_build` is called out in the patterns table, show the 3-line config.

3. **Add `asyncio_default_test_loop_scope = "function"`** to the pytest config line on line 126.

4. **Consider adding the 3 missing ty rules** (`possibly-unresolved-reference`, `deprecated`, `redundant-cast`) to bring the config closer to the research doc's recommended set.

5. **Consider adding `[tool.ty.src]`** with `root = "src"` for src-layout projects.

6. **Keep the skill focused.** The current length is good. Do NOT try to add everything from the research doc -- the skill should be a quick reference, not a comprehensive guide. But the Dockerfile fix and build-system snippet are important enough to add.

---

## Scoring Breakdown

| Criterion | Score | Notes |
|-----------|-------|-------|
| YAML frontmatter | 10/10 | Correct format, matches repo conventions |
| Version accuracy | 9/10 | All versions current within minor version |
| Config syntax correctness | 8/10 | All valid, minor omissions vs research doc |
| Dockerfile correctness | 3/10 | Broken: uv not in final stage, anti-pattern ENTRYPOINT |
| Modern typing accuracy | 9/10 | Correct for 3.12+, missing 3.13 features |
| pytest-asyncio config | 8/10 | Missing `asyncio_default_test_loop_scope` |
| No AI/agentic content leak | 10/10 | Clean separation |
| Reference URLs | 10/10 | All valid |
| Completeness vs research doc | 6/10 | Several practical patterns missing |
| Overall utility as a skill | 8/10 | Good quick reference despite gaps |

**Final Score: 7/10** -- The skill is well-structured and mostly accurate, but the broken Dockerfile is a significant issue that would cause real failures. Fix that and add the build-system config to reach 8-9/10.
