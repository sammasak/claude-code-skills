# Re-Review (R2): skills/python-engineering/SKILL.md

**Reviewer:** Claude Opus 4.6 (automated technical review)
**Date:** 2026-02-20
**Previous Score:** 7/10
**New Score: 9/10**

---

## Fixes Verified

### Fix 1: Dockerfile (was CRITICAL -- broken)

**R1 issue:** `uv` was not copied to the runtime stage, yet the entrypoint was `ENTRYPOINT ["uv", "run"]`. The image would fail at runtime.

**R2 status: FIXED.**

The updated Dockerfile (lines 113-129) now uses:
```dockerfile
FROM python:3.13-slim
COPY --from=builder /app /app
WORKDIR /app
USER nobody
ENTRYPOINT ["/app/.venv/bin/python", "-m", "myapp"]
```

The entrypoint uses the absolute path `/app/.venv/bin/python` to invoke the virtualenv Python directly. This avoids needing `uv` in the runtime stage entirely. The image will work correctly.

**Minor nit (not a deduction):** The canonical best practice from Astral's own docs and Hynek Schlawack's guide is to set `ENV PATH="/app/.venv/bin:$PATH"` and then use `ENTRYPOINT ["python", "-m", "myapp"]`. The absolute-path approach used here is functionally equivalent and arguably more explicit about which Python binary is invoked, so this is a style choice, not a bug. If someone later adds a `CMD` override or runs `docker exec ... python`, having `PATH` set would be more convenient. But for a skill file showing a Dockerfile template, this is acceptable.

### Fix 2: pytest-asyncio missing `asyncio_default_test_loop_scope` (was Minor)

**R1 issue:** Line 126 only had `asyncio_mode = "auto"` and `asyncio_default_fixture_loop_scope = "function"`, missing the separate `asyncio_default_test_loop_scope` setting.

**R2 status: FIXED.**

Line 131 now reads:
```
pytest config in `[tool.pytest.ini_options]`: `asyncio_mode = "auto"`, `asyncio_default_fixture_loop_scope = "function"`, `asyncio_default_test_loop_scope = "function"`.
```

All three settings are present and correct.

### Fix 3: Missing `[build-system]` / `uv_build` config (was Minor)

**R1 issue:** The patterns table mentioned `uv_build` as the build backend but provided no configuration snippet. Users would know to use it but not how to set it up.

**R2 status: FIXED.**

Lines 103-109 now include a dedicated "Build System" subsection:
```toml
[build-system]
requires = ["uv_build>=0.10,<0.11"]
build-backend = "uv_build"
```

This is correct and matches the research doc.

---

## Remaining Issues from R1

### Issue: Ruff version `0.15` (R1 verdict: no change needed)

Still says `Ruff 0.15`. Latest is `0.15.2` (2026-02-19). The skill uses minor-version granularity consistently across the toolchain table (`uv 0.10`, `Ruff 0.15`, `ty 0.0.17`). This is fine for a skill file -- it avoids constant patch-level churn.

**Status:** Acceptable, no deduction.

### Issue: `target-version = "py313"` vs research doc's `py312` (R1 verdict: not an error)

Still `py313`. The Dockerfile uses `python:3.13-slim`, and the ty config uses `python-version = "3.13"`. Internally consistent.

**Status:** Acceptable, no deduction.

### Issue: Missing 3 ty rules from research doc (R1: minor)

Still 8 rules. The research doc has 11 (adds `possibly-unresolved-reference`, `deprecated`, `redundant-cast`). The 8 chosen rules are the highest-value ones. A skill file should be opinionated and concise, not exhaustive.

**Status:** Acceptable, no deduction.

### Issue: Missing `[tool.ty.src]` section (R1: minor)

Still absent. This matters for `src/` layout projects. However, the skill doesn't prescribe a specific project layout, and ty auto-discovers `src/` in many cases. Adding it would be nice but is not required.

**Status:** Acceptable, no deduction.

### Issue: Missing `indent-style` in Ruff format config (R1: cosmetic)

Still absent. The defaults (`indent-style = "space"`, `skip-magic-trailing-comma = false`) are exactly what the skill would specify anyway. Omitting defaults is a valid choice.

**Status:** Acceptable, no deduction.

---

## New Issues Found in R2

### Issue 1: Dockerfile missing `ENV PATH` (New, Minor)

The Dockerfile hardcodes `/app/.venv/bin/python` in the entrypoint, which works. However, best practice per Astral's official Docker guide and the widely-cited Hynek Schlawack article is to set `ENV PATH="/app/.venv/bin:$PATH"`. This makes `python`, `pip`, and any installed console scripts available without absolute paths, which matters for:
- `docker exec <container> python` (debugging)
- `CMD` overrides in docker-compose
- Health check commands

Not a correctness bug -- the Dockerfile will build and run -- but a gap versus the canonical pattern. Minor deduction.

### Issue 2: No `--mount=type=cache` in Dockerfile RUN (New, Cosmetic)

The Dockerfile uses bare `RUN uv sync ...` without `--mount=type=cache,target=/root/.cache/uv`. The cache mount is a Docker BuildKit best practice that dramatically speeds up rebuilds. Astral's own example Dockerfile uses it. However, adding it increases complexity and requires BuildKit (which `# syntax=docker/dockerfile:1` already implies). This is a nice-to-have, not a requirement.

**Verdict:** No deduction, but worth noting.

### Issue 3: Inline pytest config is harder to reference than a code block (New, Cosmetic)

The pytest config is on a single prose line (line 131) rather than a fenced `toml` code block like the Ruff and ty configs. This is a stylistic inconsistency -- every other config in the skill gets a code block, but pytest gets an inline sentence. It works, but breaks the visual pattern.

**Verdict:** No deduction. The information is complete and correct.

---

## Content Still Missing (carried from R1, not deductions)

These were noted in R1 as "Missing Content" items. They remain absent but are deliberate scope choices for a concise skill file:

1. No FastAPI lifespan pattern
2. No httpx testing patterns (`ASGITransport`, `MockTransport`)
3. No structlog configuration
4. No respx mention
5. No workspace/monorepo guidance
6. No TypeVar defaults (3.13+) or TypeIs
7. No per-file ty overrides

These are all valid content for a comprehensive guide but would bloat a skill file. The current scope is appropriate.

---

## Version Accuracy Check (as of 2026-02-20)

| Tool | Skill says | Latest available | Status |
|------|-----------|-----------------|--------|
| uv | 0.10 | 0.10.4 (2026-02-17) | Correct (minor-version reference) |
| Ruff | 0.15 | 0.15.2 (2026-02-19) | Correct (minor-version reference) |
| ty | 0.0.17 | 0.0.17 (2026-02-13) | Exact match |
| uv_build | `>=0.10,<0.11` | Ships with uv 0.10.x | Correct |
| Python | 3.13 | 3.13.x | Correct |

All versions are current.

---

## Scoring Breakdown

| Criterion | R1 Score | R2 Score | Notes |
|-----------|----------|----------|-------|
| YAML frontmatter | 10/10 | 10/10 | Unchanged, correct |
| Version accuracy | 9/10 | 10/10 | All current as of today |
| Config syntax correctness | 8/10 | 9/10 | `[build-system]` added; all configs valid |
| Dockerfile correctness | 3/10 | 8/10 | Fixed: works correctly. Missing `ENV PATH` is minor |
| Modern typing accuracy | 9/10 | 9/10 | Unchanged; correct for 3.12+ |
| pytest-asyncio config | 8/10 | 10/10 | Both loop scope settings now present |
| No AI/agentic content leak | 10/10 | 10/10 | Clean separation maintained |
| Reference URLs | 10/10 | 10/10 | All valid |
| Completeness vs research doc | 6/10 | 7/10 | Build-system snippet added |
| Overall utility as a skill | 8/10 | 9/10 | All critical issues resolved |

---

## What Would Make This 10/10

1. Add `ENV PATH="/app/.venv/bin:$PATH"` to the Dockerfile runtime stage and simplify the entrypoint to `ENTRYPOINT ["python", "-m", "myapp"]`. This matches Astral's canonical Docker pattern.
2. Optionally add `--mount=type=cache,target=/root/.cache/uv` to the `RUN uv sync` lines for faster rebuilds (since the Dockerfile already opts into BuildKit with `# syntax=docker/dockerfile:1`).

That's it. Two small Dockerfile tweaks separate this from a perfect score.

---

**Final Score: 9/10** -- All three flagged issues from R1 are fixed. The Dockerfile now works correctly, the pytest-asyncio config is complete, and the build-system snippet is present. The only remaining gap is the Dockerfile not setting `ENV PATH` (minor best-practice deviation, not a correctness bug). This is a high-quality, production-ready skill file.
