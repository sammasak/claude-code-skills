# Python Skills: Specificity Audit

Reviewed files:
- `skills/python-engineering/SKILL.md`
- `skills/python-agentic-development/SKILL.md`

---

## python-engineering/SKILL.md

### Finding 1: `known-first-party = ["mypackage"]`

- **Line:** 40
- **Exact text:** `known-first-party = ["mypackage"]`
- **Verdict:** Reasonable placeholder. `"mypackage"` is an obviously generic placeholder name, not a leftover from a real project. Any reader will understand they should replace it.
- **Suggested fix:** None required. Optionally add a comment: `# replace with your package name`.

### Finding 2: `ENTRYPOINT ["python", "-m", "myapp"]`

- **Line:** 128
- **Exact text:** `ENTRYPOINT ["python", "-m", "myapp"]`
- **Verdict:** Reasonable placeholder. Same category as `mypackage` above -- clearly generic.
- **Suggested fix:** None required.

### Finding 3: `line-length = 99`

- **Line:** 35
- **Exact text:** `line-length = 99`
- **Verdict:** Mildly user-specific preference. 99 is an unusual choice. The most common community defaults are 79 (PEP 8), 88 (black default / ruff default), or 120 (common in organizations). Presenting 99 without comment implies it is a standard.
- **Suggested fix:** Either change to `88` (ruff/black default) and note it is the ruff default, or add a comment like `# adjust per project; ruff default is 88`.

### Finding 4: `target-version = "py313"` / `python-version = "3.13"`

- **Lines:** 34, 52
- **Exact text:** `target-version = "py313"` and `python-version = "3.13"`
- **Verdict:** Borderline. Pinning to 3.13 is a reasonable forward-looking choice for a skill written in early 2025+, but many production environments still run 3.11 or 3.12. Presenting 3.13 as the default without comment could mislead.
- **Suggested fix:** Add a brief note: `# adjust to your minimum supported Python version`. The skill already implies 3.12+ in the "Modern Typing" section, so this is mostly fine, but a comment would help.

### Finding 5: `uv_build` as build backend

- **Lines:** 95, 107-108
- **Exact text:** `uv_build` / `requires = ["uv_build>=0.10,<0.11"]`
- **Verdict:** Mildly niche. `uv_build` is new (announced mid-2025). While it is a real and promising tool, presenting it as the default over the well-established `hatchling`, `setuptools`, or `flit-core` is an opinionated personal preference. Most Python developers and CI systems default to one of the established backends.
- **Suggested fix:** Either present `hatchling` as the primary example and mention `uv_build` as an alternative for projects fully invested in the Astral ecosystem, or add a note: `# uv_build is fast but new; hatchling and setuptools are more established alternatives`.

### Finding 6: `structlog` presented as the singular logging choice

- **Lines:** 99, 140
- **Exact text:** `structlog` + contextvars / `structlog.get_logger()`
- **Verdict:** Mildly user-specific. `structlog` is a good library, but presenting it as the only correct choice (with `print()` as the anti-pattern counterpoint) skips over the standard library `logging` module, which is the most universal default. Many teams use `logging` with JSON formatters rather than adding a third-party dependency.
- **Suggested fix:** Reframe as: "Structured logging via `structlog` or stdlib `logging` with a JSON formatter. Avoid bare `print()`." This keeps the recommendation without implying there is only one valid option.

### Finding 7: `ignore = ["E501", "B008"]` with comment about Depends()

- **Line:** 38
- **Exact text:** `ignore = ["E501", "B008"]  # B008: allow Depends() in defaults`
- **Verdict:** Reasonable. This is a well-known FastAPI ergonomic choice. Since the skill explicitly covers FastAPI, this is fine.
- **Suggested fix:** None required.

### Finding 8: Version pins on tools (`uv 0.10`, `Ruff 0.15`, `ty 0.0.17`)

- **Lines:** 26-28
- **Exact text:** `uv 0.10`, `Ruff 0.15`, `ty 0.0.17`
- **Verdict:** Will become stale quickly. These are specific point-in-time versions. They are useful as "known good" references but will mislead when newer versions ship.
- **Suggested fix:** Either add a note like `# versions as of 2025-05; check for updates` or use minimum versions (`uv >= 0.10`).

---

## python-agentic-development/SKILL.md

### Finding 9: `anthropic:claude-sonnet-4-6` as the hardcoded model

- **Lines:** 26, 70
- **Exact text:** `Agent("anthropic:claude-sonnet-4-6", ...)` (appears twice)
- **Verdict:** User-specific / vendor-specific. Hardcoding a specific model name in a generic skill implies that this is the correct or only model to use. pydantic-ai supports many providers. Presenting one specific model without caveat reads as a personal default rather than a universal recommendation.
- **Suggested fix:** Use a variable or generic placeholder, e.g., `Agent(model, ...)` with a comment `# e.g. "anthropic:claude-sonnet-4-6", "openai:gpt-4o"`, or note that the model string should be selected per project.

### Finding 10: `query_metrics` tool fetching Prometheus metrics

- **Lines:** 42-47
- **Exact text:** Tool named `query_metrics` that fetches from `/api/v1/query`
- **Verdict:** Mildly specific. The Prometheus `/api/v1/query` endpoint is a real API, but choosing Prometheus metrics as the example tool (rather than something more universally relatable) hints at a specific production stack. The tool name `query_metrics` and the Prometheus endpoint together suggest this was lifted from a real project.
- **Suggested fix:** Either keep it (Prometheus is common enough to be a decent example) or generalize to a more universal example like querying a weather API or a generic REST endpoint. If keeping, add a comment: `# Example: Prometheus query tool`.

### Finding 11: Logfire as the singular observability choice

- **Lines:** 17, 112, 121, 135
- **Exact text:** `Logfire / OpenTelemetry traces`, `logfire.configure()`, `logfire.instrument_pydantic_ai()`
- **Verdict:** User-specific leaning. Logfire is Pydantic's commercial observability product. While the skill does mention "Works with any OTel backend" (line 112), Logfire is presented as the primary/default choice throughout, appearing in the Principles, the Patterns table, and the Anti-Patterns table. This reads as a strong personal (or ecosystem) preference rather than a neutral recommendation.
- **Suggested fix:** Lead with OpenTelemetry as the generic standard, then mention Logfire as one compatible backend: "OpenTelemetry traces (via Logfire, Jaeger, Grafana Tempo, or any OTel collector)". Change code examples to show the generic OTel setup with Logfire as one option.

### Finding 12: `http://localhost:8000/mcp` in MCP example

- **Line:** 71
- **Exact text:** `MCPServerStreamableHTTP("http://localhost:8000/mcp")`
- **Verdict:** Reasonable placeholder. `localhost:8000` is a generic dev URL.
- **Suggested fix:** None required.

---

## Summary Table

| # | File | Line(s) | Issue | Severity | Action |
|---|------|---------|-------|----------|--------|
| 1 | python-engineering | 40 | `"mypackage"` placeholder | None | OK as-is |
| 2 | python-engineering | 128 | `"myapp"` placeholder | None | OK as-is |
| 3 | python-engineering | 35 | `line-length = 99` | Low | Change to 88 or add comment |
| 4 | python-engineering | 34, 52 | Python 3.13 pinned | Low | Add "adjust to your version" comment |
| 5 | python-engineering | 95, 107-108 | `uv_build` as default backend | Medium | Note as newer alternative, or lead with hatchling |
| 6 | python-engineering | 99, 140 | `structlog` as only logging choice | Medium | Acknowledge stdlib `logging` as valid |
| 7 | python-engineering | 38 | B008 ignore for Depends() | None | OK (FastAPI context) |
| 8 | python-engineering | 26-28 | Exact version pins on tools | Low | Add date note or use minimums |
| 9 | python-agentic | 26, 70 | Hardcoded `claude-sonnet-4-6` | Medium | Use variable or show multiple providers |
| 10 | python-agentic | 42-47 | Prometheus-specific tool example | Low | Add comment or generalize |
| 11 | python-agentic | 17, 112, 121, 135 | Logfire as primary observability | Medium | Lead with OTel, Logfire as one option |
| 12 | python-agentic | 71 | `localhost:8000/mcp` | None | OK as-is |

**Overall assessment:** Both files are quite clean. There are no leaked project names, service names, or obvious find-replace artifacts. The main specificity issues are opinionated tool choices (structlog, Logfire, uv_build, claude-sonnet-4-6) presented as defaults without acknowledging alternatives. These are defensible opinions, but a generic skill should either frame them as recommendations with alternatives noted or present the most universal option first.
