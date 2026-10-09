# Re-Review: python-agentic-development (Round 4 -- Full Rewrite)

## Previous Score: 9/10 (R3, pre-rewrite)
## New Score: 9.5/10

The skill has been completely rewritten from a mixed Python engineering + agentic file into a focused, domain-partitioned agentic development reference. All R3 gaps (HITL, A2A, output modes, MCP details) have been addressed. The rewritten file is dense with correct API surface and contains no general Python engineering content (uv, ruff, ty, pytest-asyncio config -- all correctly absent, belonging to the separate python-engineering skill). Every API call has been cross-verified against pydantic-ai v1.61.0 documentation and the companion research document.

---

## What's Accurate and Well-Done

### YAML Frontmatter
- `name`, `description`, and `allowed-tools` all follow the Claude Code skill format consistently with sibling skills (e.g., `python-engineering`, `clean-code-principles`).
- The description correctly scopes activation: "pydantic-ai, pydantic-graph, or MCP" -- no overlap with the python-engineering skill's uv/ruff/ty triggers.

### Agent Constructor (line 26)
```python
Agent("anthropic:claude-sonnet-4-6", deps_type=MyDeps, output_type=StructuredOut, retries=2)
```
- `"anthropic:claude-sonnet-4-6"` -- confirmed in `KnownModelName` literal type as of v1.61.0. Correct.
- `output_type` -- correct (renamed from `result_type` in v1.0.0). Correct.
- `deps_type=MyDeps` -- correct parameter name (type, not instance). Correct.
- `retries=2` -- valid parameter. Correct.

### Output Modes Table (lines 33-37)
All four modes (`ToolOutput`, `NativeOutput`, `PromptedOutput`, `TextOutput`) are real classes in pydantic-ai v1. Descriptions match the research doc precisely:
- `ToolOutput` -- default, uses tool calling. Correct.
- `NativeOutput` -- model's native JSON schema mode. Correct.
- `PromptedOutput` -- schema injected into prompt. Correct.
- `TextOutput` -- custom text post-processing via a function. Correct.

### Tool Design (lines 42-48)
```python
@agent.tool
async def query_metrics(ctx: RunContext[MyDeps], metric: str) -> str:
```
- `@agent.tool` -- correct decorator (vs `@agent.tool_plain` for no-context). Correct.
- `RunContext[MyDeps]` -- correct generic type (NOT `AgentDeps`). Correct.
- Docstring-as-description pattern is idiomatic. Correct.

### Toolset Composition (lines 52-58)
- `AbstractToolset` as base class -- confirmed. Correct.
- `.filtered(filter_fn)` -- confirmed. Correct.
- `.prefixed(prefix)` -- confirmed. Correct.
- `.prepared(prepare_fn)` -- confirmed. Correct.
- `.approval_required(filter_fn)` -- confirmed. Correct.
- Registration at construction (`Agent(toolsets=[...])`) or runtime (`agent.run(toolsets=[...])`) -- confirmed. Correct.

### MCP Integration (lines 60-72)
- `MCPServerStreamableHTTP(url)` -- confirmed import from `pydantic_ai.mcp`. Correct.
- `MCPServerStdio(cmd, args=[...])` -- confirmed. Correct.
- `FastMCPToolset(server_or_url)` -- confirmed import from `pydantic_ai.toolsets.fastmcp`. Correct.
- The table correctly marks `MCPServerStreamableHTTP` as "recommended" for HTTP. Correct.
- Code example import path `from pydantic_ai.mcp import MCPServerStreamableHTTP` -- confirmed. Correct.

### Human-in-the-Loop (lines 74-87)
```python
from pydantic_ai import Agent, DeferredToolRequests, DeferredToolResults
```
- `DeferredToolRequests` and `DeferredToolResults` can be imported directly from `pydantic_ai`. Confirmed by research doc (Section 10, "Import Convenience"). Correct.

```python
approval_toolset = my_toolset.approval_required(
    lambda ctx, tool_def, tool_args: tool_def.name.startswith("delete"))
```
- `.approval_required()` filter signature `(ctx, tool_def, tool_args)` -- confirmed by research doc. Correct.

```python
output_type=[str, DeferredToolRequests]
```
- Union output type with `DeferredToolRequests` -- confirmed pattern. Correct.

```python
if isinstance(result.output, DeferredToolRequests):
    approvals = {tc.tool_call_id: True for tc in result.output.approvals}
```
- `result.output.approvals` is `list[ToolCallPart]` -- confirmed. Correct.
- `tc.tool_call_id` on `ToolCallPart` -- confirmed. Correct.
- Dictionary mapping `tool_call_id -> bool` for `DeferredToolResults(approvals=...)` -- confirmed (`dict[str, bool | DeferredToolApprovalResult]`). Correct.

```python
result = agent.run_sync(message_history=result.all_messages(),
                        deferred_tool_results=DeferredToolResults(approvals=approvals))
```
- `result.all_messages()` for continuing conversation -- confirmed. Correct.
- `deferred_tool_results` parameter name -- confirmed. Correct.

### pydantic-graph (lines 89-93)
- "Class-based API (stable)" -- correct characterization. Correct.
- "nodes are dataclasses; edges defined by return type hints" -- confirmed. Correct.
- "Nodes return another node or `End[T]`" -- confirmed. Correct.
- "Function-based API (beta)" -- correctly marked as beta. Correct.
- "`GraphBuilder` with `@g.step` decorators" -- confirmed (`from pydantic_graph.beta import GraphBuilder, StepContext`). Correct.
- "Supports `map`/`broadcast` for parallel steps, reducers for joins, and streaming via `GraphBuilder.stream`" -- confirmed. Correct.

### pydantic-evals (lines 95-105)
```python
from pydantic_evals import Case, Dataset
from pydantic_evals.evaluators import IsInstance, LLMJudge
```
- Import paths confirmed. Correct.
- `Case(name=..., inputs=..., expected_output=...)` -- confirmed API. Correct.
- `Dataset(cases=[...], evaluators=[...])` -- confirmed. Correct.
- `IsInstance(type_name="str")` -- confirmed. Correct.
- `LLMJudge(rubric="...")` -- confirmed. Correct.
- `dataset.evaluate_sync(my_task_fn)` -- confirmed. Correct.
- `report.print(include_input=True, include_output=True)` -- confirmed. Correct.

### Testing (lines 108-112)
- `TestModel` for deterministic testing -- confirmed (import: `from pydantic_ai.models.test import TestModel`). Correct.
- "Tool functions independently testable" -- sound guidance. Correct.
- `pydantic-evals` for prompt quality evaluation -- correct. Correct.

### Observability (line 116)
```
logfire.configure() + logfire.instrument_pydantic_ai()
```
- Confirmed exact API calls. Correct.
- `logfire.configure(send_to_logfire=False)` for alternative OTel backends -- confirmed. Correct.

### A2A (line 126)
- `agent.to_a2a()` creates ASGI app -- confirmed (FastA2A built on Starlette/ASGI). Correct.

### Anti-Patterns Table (lines 129-139)
All anti-patterns are accurate and well-paired with the "Do Instead" alternatives. No inaccuracies.

### References (lines 141-148)
| Reference | URL | Status |
|---|---|---|
| Building Effective Agents | https://anthropic.com/research/building-effective-agents | Verified live |
| pydantic-ai docs | https://ai.pydantic.dev | Verified live |
| MCP overview | https://ai.pydantic.dev/mcp/overview/ | Verified live |
| Logfire | https://pydantic.dev/logfire | Verified live |
| pydantic-graph | https://ai.pydantic.dev/graph/ | Verified live |
| pydantic-evals | https://ai.pydantic.dev/evals/ | Verified live |
| A2A protocol | https://google.github.io/A2A/ | **404 -- BROKEN** |
| FastMCP | https://gofastmcp.com | Verified live |

---

## Issues Found

### Issue 1: Broken A2A reference URL (line 147)

**What it says:**
```
- [A2A protocol](https://google.github.io/A2A/) -- agent interop standard
```

**What it should say:**
The A2A project has moved from Google's GitHub Pages to the Linux Foundation. The URL `https://google.github.io/A2A/` returns a 404. The correct URLs are:
- Official docs: `https://a2a-protocol.org/latest/`
- GitHub repo: `https://github.com/a2aproject/A2A`

**Recommendation:** Change to:
```
- [A2A protocol](https://a2a-protocol.org/latest/) -- agent interop standard
```

**Severity:** Low (cosmetic -- the link is broken, but the A2A concept description is correct).

### Issue 2: MCP table describes FastMCPToolset parameter as `server_or_url` (line 66)

**What it says:**
```
| `FastMCPToolset(server_or_url)` | In-process FastMCP server or remote via URL |
```

**What the API actually accepts:**
Per the research doc and official docs, `FastMCPToolset` accepts a FastMCP `Server`, a FastMCP `Client`, a FastMCP `Transport`, a URL string, a Python script path, a Node.js script path, or a JSON MCP configuration. The parameter name in the constructor is not `server_or_url` -- it is more generic. However, calling it `server_or_url` in the table is a reasonable simplification for a summary table.

**Severity:** Very low (a simplification in a summary table, not an error in code).

### Issue 3: TestModel import path not shown (lines 109)

**What it says:**
```
- [ ] `TestModel` for deterministic agent testing without LLM calls
```

**What would be more helpful:**
The file never shows the import for `TestModel`. The correct import is `from pydantic_ai.models.test import TestModel`. Unlike the other key types (`DeferredToolRequests`, `RunContext`, etc.), `TestModel` is NOT importable directly from `pydantic_ai` -- it requires the sub-module import. A developer following the skill file alone would need to look up the import path.

**Severity:** Low (a missing convenience, not an error).

---

## No General Python Engineering Content Leakage

Confirmed that the file contains:
- No uv, ruff, or ty configuration
- No pyproject.toml tooling setup
- No pytest-asyncio configuration
- No FastAPI patterns
- No structlog/structlog configuration
- No dependency management guidance

All of these correctly reside in the sibling `python-engineering` skill. The domain partition is clean.

---

## Missing Content (Minor)

| Topic | Impact | Notes |
|---|---|---|
| `TestModel` import path | Low | Only type not shown with its import; `from pydantic_ai.models.test import TestModel` |
| `FunctionModel` for custom test control | Very Low | Mentioned in pydantic-ai testing docs as complement to `TestModel` |
| `MCPServerSSE` (deprecated) | Very Low | Correctly omitted -- deprecated in favor of StreamableHTTP |
| Streaming (`run_stream`, `stream_output`) | Low | Not covered, but streaming is a runtime pattern not a design pattern |
| `agent.override(model=...)` for testing | Low | Idiomatic testing pattern used with `TestModel`; would strengthen the Testing section |
| `ALLOW_MODEL_REQUESTS=False` global guard | Low | Best practice for test suites to prevent accidental live LLM calls |
| Retry / `ModelRetry` exception | Very Low | Mentioned via `retries=2` but the `ModelRetry` tool-level retry is not shown |

None of these are errors. They represent the long tail of pydantic-ai features that could be added but would expand the skill beyond its current tightly-scoped design.

---

## Scoring Breakdown

| Category | Score | Notes |
|---|---|---|
| API correctness | 4.5/5 | Every API call, import, class name, and parameter name verified correct against v1.61.0. Half point withheld for missing TestModel import path. |
| Architecture & design | 2/2 | Clean domain partition; no overlap with python-engineering. Principles are sound and actionable. |
| Completeness | 2/2 | All R3 gaps (HITL, A2A, output modes, MCP transports) now addressed. |
| Reference quality | 1/1.5 | One broken URL (A2A). All other 7 references verified live. |

**Deductions:**
- -0.25 for broken A2A URL
- -0.25 for missing TestModel import path

**Total: 9.5/10**

---

## Recommendations

1. **Fix the A2A URL** (line 147): Change `https://google.github.io/A2A/` to `https://a2a-protocol.org/latest/`. This is the only broken link in the file.

2. **Add TestModel import** to the Testing section: A one-liner showing `from pydantic_ai.models.test import TestModel` would complete the section, since this is the one key import that cannot be inferred from the top-level `pydantic_ai` package.

3. **Optional: Add `agent.override` pattern**: The Testing section would benefit from a brief note that `TestModel` is used via `with agent.override(model=TestModel()):` rather than at construction time. This is the idiomatic pydantic-ai testing pattern.

4. **Optional: Add `ALLOW_MODEL_REQUESTS=False`**: A one-liner in the Testing section recommending `models.ALLOW_MODEL_REQUESTS = False` in conftest.py would prevent accidental live LLM calls during testing.

---

## Final Verdict

The rewritten skill file is excellent. It is a focused, accurate reference for building AI agents with pydantic-ai v1. Every code example would work as-is against the current API (v1.61.0). The HITL pattern is correctly implemented with `DeferredToolRequests`/`DeferredToolResults`. The MCP integration shows all three transport types with correct import paths. The pydantic-graph and pydantic-evals sections are concise and accurate. The output modes table covers all four strategies.

The only actionable fix is the broken A2A URL. The TestModel import path is a nice-to-have. Everything else is correct.

This file is ready for production use as a Claude Code skill.

---

*Review conducted: 2026-02-20*
*Pydantic-ai version at time of review: v1.61.0*
*Reviewer: Claude Opus 4.6 (automated technical review, round 4)*
*Previous reviews: R1 (5/10), R2 (8/10), R3 (9/10 pre-rewrite)*
*Verified against: pydantic-ai-research.md + live web searches of official documentation*
