# Review: python-agentic-development

## Score: 5/10

The skill covers the right topics and has strong architectural principles, but contains several outdated API references that would cause errors with current versions of pydantic-ai (v1.61.0, Feb 2026). The model name is wrong, a key parameter has been renamed, one code example uses a non-existent type, and two important ecosystem developments (uv build backend, Logfire, MCP/A2A) are unmentioned.

---

## Findings

### Accurate

- **Principles section is excellent.** "Start simple," "design tools for agents, not humans," "set hard limits," "observability from day one," and "structured outputs always" are all well-aligned with Anthropic's own "Building Effective Agents" guide and current industry practice.
- **Async-first with httpx.AsyncClient** is correct. httpx remains the async HTTP client of choice.
- **asyncio.TaskGroup** recommendation is correct for Python 3.11+.
- **structlog** remains the standard recommendation for structured logging in Python. Latest version is 25.5.0 (Oct 2025), actively maintained. The reference URL (https://www.structlog.org) is valid.
- **Ruff for lint + format** is accurate. Ruff v0.15.1 (Feb 2026) is the latest release. The `ruff check --fix && ruff format` invocation is still correct.
- **uv for package management** is correct and still the recommended tool. The lockfile-based workflow description is accurate.
- **pytest + pytest-asyncio** is the correct testing stack. pytest-asyncio is at v1.3.0 (Nov 2025).
- **Connection pools via dependency injection** matches pydantic-ai's `RunContext[DepsT]` pattern.
- **Pydantic BaseModel at every boundary** is consistent with the pydantic-ai philosophy.
- **Anti-patterns table** is well-curated and accurate.
- **Development cycle** (models first, then tools, then agent wiring, then integration tests) is sound methodology.
- **pydantic-graph** is still actively maintained (v1.59.0, Feb 2026) as part of the pydantic-ai monorepo, and the description of using it for multi-step workflows with branching, retries, or stateful transitions is correct.
- **OpenTelemetry traces on agent runs and tool invocations** is the right pattern. OTel now has GenAI-specific semantic conventions for agent spans (`create_agent`, `invoke_agent`).
- **SurrealDB** remains a valid choice. It raised $23M in Feb 2026 and launched v3.0 with AI-native features. However, it is an opinionated/niche choice (see Missing section).

### Issues

#### 1. Model name `"claude-sonnet"` is invalid (Critical)

**Currently says:**
```python
agent = Agent(
    "claude-sonnet",
    ...
)
```

**Should say:**
```python
agent = Agent(
    "anthropic:claude-sonnet-4-6",
    ...
)
```

Pydantic-ai uses the format `provider:model-name` for `KnownModelName`. The bare string `"claude-sonnet"` is not a recognized model identifier and will raise an error. The current default in pydantic-ai examples (PyPI, GitHub README) is `"anthropic:claude-sonnet-4-6"`. Other valid options include `"anthropic:claude-sonnet-4-5"` or `"anthropic:claude-sonnet-4-0"`.

**Source:** [Pydantic AI Models Overview](https://ai.pydantic.dev/models/overview/), [PyPI pydantic-ai](https://pypi.org/project/pydantic-ai/)

#### 2. `result_type` parameter has been removed; must use `output_type` (Critical)

**Currently says:**
```python
agent = Agent(
    "claude-sonnet",
    deps_type=MyDeps,
    result_type=StructuredOut,
    retries=2,
)
```

**Should say:**
```python
agent = Agent(
    "anthropic:claude-sonnet-4-6",
    deps_type=MyDeps,
    output_type=StructuredOut,
    retries=2,
)
```

The `result_type` parameter was deprecated and then fully removed before the pydantic-ai v1.0 release (Sep 2025). Using `result_type` will raise a `TypeError`. The replacement is `output_type`. Similarly, `result_retries` was renamed to `output_retries`, and result access changed from `.data` to `.output`.

**Source:** [Pydantic AI Changelog/Upgrade Guide](https://ai.pydantic.dev/changelog/)

#### 3. `AgentDeps` type does not exist in pydantic-ai (Moderate)

**Currently says:**
```python
async def search_loki_logs(deps: AgentDeps, input: LogSearchInput) -> LogSearchResult:
```

**Should say:**
```python
async def search_loki_logs(ctx: RunContext[MyDeps], input: LogSearchInput) -> LogSearchResult:
```

`AgentDeps` is not an exported type in pydantic-ai. The correct pattern for accessing dependencies in tool functions is through `RunContext[DepsT]`, where `DepsT` is your dependency type. The first parameter of a tool function decorated with `@agent.tool` should be `ctx: RunContext[YourDepsType]`, and dependencies are accessed via `ctx.deps`. The example in the "Agent Framework" section above correctly uses `RunContext[MyDeps]`, but this second example is inconsistent.

**Source:** [Pydantic AI Dependencies docs](https://ai.pydantic.dev/dependencies/), [Pydantic AI Tools docs](https://ai.pydantic.dev/tools/)

#### 4. `ty` is beta, not stable -- recommendation should include caveat (Moderate)

**Currently says:**
> Use `ty` (Astral's type checker) for static analysis -- `ty check src/`

**Should say:**
> Use `ty` (Astral's type checker, beta) for static analysis -- `ty check src/`. For projects requiring stable tooling, `mypy` or `pyright` remain production-ready alternatives.

ty was announced in beta on Dec 16, 2025. As of Feb 2026, it is at v0.0.17 with 0.0.x versioning and an explicitly unstable API. The GitHub "Stable" milestone is only 36% complete. While ty is extremely fast (10-60x faster than mypy/pyright), Astral themselves warn: "Expect to encounter bugs, missing features, and fatal errors." The stable release is projected for later in 2026.

**Source:** [ty GitHub releases](https://github.com/astral-sh/ty/releases), [Astral blog: ty announcement](https://astral.sh/blog/ty), [ty Stable milestone](https://github.com/astral-sh/ty/milestone/4)

#### 5. Hatchling is no longer the default recommended build backend (Minor)

**Currently says:**
> Hatchling as build backend

**Should say:**
> `uv_build` as default build backend for pure Python projects; Hatchling for projects needing plugins, VCS versioning, or custom build hooks.

As of mid-2025, `uv init` defaults to `uv_build` for new packaged applications. Charlie Marsh (uv creator) says "Hatchling is a lot more extensible than the uv build backend and is still a great choice for projects that need plugins, customization, more flexibility, etc." For pure Python projects (which most agent services are), `uv_build` is now the default and is 10-35x faster.

**Source:** [uv Build Backend docs](https://docs.astral.sh/uv/concepts/build-backend/), [The uv build backend is now stable](https://pydevtools.com/blog/uv-build-backend/)

#### 6. pytest-asyncio `mode = auto` is not the default (Minor)

**Currently says:**
> `pytest` + `pytest-asyncio` (mode = auto)

This is fine as a recommendation, but it would be clearer to note that `strict` is the default mode and you need to explicitly configure auto mode in `pyproject.toml`:

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

Also, pytest-asyncio v1.0 (May 2025) removed the deprecated `event_loop` fixture, which is a significant breaking change worth mentioning for anyone upgrading.

**Source:** [pytest-asyncio configuration](https://pytest-asyncio.readthedocs.io/en/latest/reference/configuration.html)

#### 7. Typing reference URL redirects (Minor)

**Currently says:**
> [Python typing (PEP 484/544/612)](https://typing.readthedocs.io)

The URL `https://typing.readthedocs.io` now 302-redirects to `https://typing.python.org/`. The link should be updated to the canonical URL.

**Should say:**
> [Python typing (PEP 484/544/612)](https://typing.python.org/)

---

### Missing

#### 1. Pydantic AI Logfire integration for observability

The skill recommends OpenTelemetry directly but does not mention Pydantic Logfire, which is the observability platform built by the Pydantic team specifically for pydantic-ai agents. Logfire is built on top of OpenTelemetry (not a replacement) and provides a much nicer developer experience for agent debugging, including live spans ("pending spans") that show activity as it happens. Since the skill recommends pydantic-ai as the agent framework, mentioning Logfire as the companion observability tool is a natural fit. Free tier includes 10M spans/month.

**Source:** [Pydantic Logfire](https://pydantic.dev/logfire)

#### 2. MCP (Model Context Protocol) integration

Pydantic-ai has first-class MCP support via `MCPServerStreamableHTTP`, `MCPServerStdio`, and `FastMCPToolset`. MCP is now a standard way for agents to access external tools and data sources. The skill does not mention MCP at all, despite it being a core capability of the recommended framework. Anthropic's own "Building Effective Agents" guide specifically calls out MCP as an approach to implementing tool augmentations.

**Source:** [Pydantic AI MCP docs](https://ai.pydantic.dev/mcp/overview/)

#### 3. A2A (Agent2Agent) protocol

Pydantic-ai supports A2A for agent interoperability. A simple `agent.to_a2a()` call can expose any agent as an A2A server. This is increasingly important for multi-agent architectures.

**Source:** [Pydantic AI homepage](https://ai.pydantic.dev/)

#### 4. pydantic-evals for evaluation

The skill mentions "eval harness" for testing prompt logic but does not reference `pydantic-evals`, which is the evaluation library built into the pydantic-ai ecosystem. It supports report-level evaluators, experiment-wide analyses, and multi-run aggregation.

**Source:** [Pydantic Evals docs](https://ai.pydantic.dev/evals/)

#### 5. Human-in-the-Loop tool approval

Pydantic-ai v1 introduced Human-in-the-Loop Tool Approval, letting agents request user confirmation before executing certain tools. This is a significant safety feature for production agents that is not mentioned.

**Source:** [Pydantic AI v1 announcement](https://pydantic.dev/articles/pydantic-ai-v1)

#### 6. Durable Execution with Temporal

Pydantic-ai v1 also introduced durable execution support via Temporal for handling agent crashes during long-running workflows. This is relevant for production deployment patterns.

**Source:** [Pydantic AI v1 announcement](https://pydantic.dev/articles/pydantic-ai-v1)

#### 7. OpenTelemetry GenAI semantic conventions for agents

The OTel community has defined specific semantic conventions for GenAI agent spans, including `create_agent` and `invoke_agent` operations, `gen_ai.agent.name`/`gen_ai.agent.id` attributes, and `gen_ai.conversation.id` for session tracking. Pydantic-ai v1.60.0 added instrumentation version 4 to match these OTel GenAI semantic conventions. The observability checklist should reference these.

**Source:** [OTel GenAI Agent Spans](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/)

#### 8. `NativeOutput` / `PromptedOutput` / `ToolOutput` for structured output control

Pydantic-ai now offers fine-grained control over how structured outputs are extracted from models: `NativeOutput` (uses model's native structured output), `PromptedOutput` (prompts the model with JSON schema), and `ToolOutput` (uses tool calling). This is relevant to the "Structured outputs always" principle.

**Source:** [Pydantic AI Output docs](https://ai.pydantic.dev/output/)

---

### References Check

| Reference | Status | Notes |
|---|---|---|
| [Building Effective Agents](https://anthropic.com/research/building-effective-agents) | Valid | Redirects to `www.anthropic.com/research/building-effective-agents`. Content is current. |
| [pydantic-ai docs](https://ai.pydantic.dev) | Valid | Active, showing v1.61.0 features. |
| [FastAPI best practices](https://fastapi.tiangolo.com/tutorial/) | Valid | Active tutorial page. FastAPI is at ~v0.128.x, now requires Python 3.10+. |
| [Python typing (PEP 484/544/612)](https://typing.readthedocs.io) | Redirect | 302 redirects to `https://typing.python.org/`. Should update to the canonical URL. |
| [structlog docs](https://www.structlog.org) | Valid | Active, documenting v25.5.0. |
| [OpenTelemetry Python](https://opentelemetry.io/docs/languages/python/) | Valid | Active, updated Jan 27, 2026. Traces and Metrics are stable; Logs still in development. |

**Missing references that should be added:**
- [Pydantic Logfire](https://pydantic.dev/logfire) -- observability platform
- [Pydantic AI MCP](https://ai.pydantic.dev/mcp/overview/) -- Model Context Protocol integration
- [Pydantic Evals](https://ai.pydantic.dev/evals/) -- evaluation framework
- [OTel GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/) -- GenAI-specific telemetry standards
- [uv docs](https://docs.astral.sh/uv/) -- package manager (mentioned but not linked)
- [Ruff docs](https://docs.astral.sh/ruff/) -- linter/formatter (mentioned but not linked)
- [ty docs](https://docs.astral.sh/ty/) -- type checker (mentioned but not linked)

---

### Recommendations

1. **Fix the model name immediately.** Change `"claude-sonnet"` to `"anthropic:claude-sonnet-4-6"` (or at minimum `"anthropic:claude-sonnet-4-5"`). This is a breaking error -- the current string will not work with any version of pydantic-ai.

2. **Rename `result_type` to `output_type`** in the Agent constructor example. Also rename `StructuredOut` comment from "validated output model" to "validated output type" to match current terminology. The `result` to `output` rename was completed before the v1.0 release in September 2025.

3. **Replace `AgentDeps` with `RunContext[MyDeps]`** in the tool design pattern example. Align it with the first code example which correctly uses `RunContext[MyDeps]`.

4. **Add a caveat to the ty recommendation.** Recommend it alongside mypy or pyright as a fallback, since ty is still in beta (v0.0.17) with an explicitly unstable API. Something like: "Use `ty` for fast feedback during development; validate with `mypy` or `pyright` in CI until ty reaches stable."

5. **Update the build backend recommendation** to mention `uv_build` as the new default for pure Python projects, with Hatchling as the choice for projects needing extensibility.

6. **Add MCP and A2A integration** to the "Patterns We Use" section. These are first-class features of pydantic-ai and represent major capabilities for production agent systems.

7. **Add Logfire** to the observability section as the recommended companion to raw OpenTelemetry when using pydantic-ai.

8. **Add pydantic-evals** reference to the testing section, since the skill already mentions "eval harness" but does not name the specific tool.

9. **Fix the typing reference URL** from `https://typing.readthedocs.io` to `https://typing.python.org/`.

10. **Add missing reference links** for uv, Ruff, ty, Logfire, MCP, and pydantic-evals.

---

## Summary

The skill has a strong foundation: the principles are sound, the development workflow is logical, and the anti-patterns table is useful. However, three code examples contain errors that would fail at runtime with current pydantic-ai (wrong model name, removed parameter name, non-existent type), which is a serious problem for a skill file that is meant to guide development. The ty recommendation needs qualification. Several important pydantic-ai v1 features (MCP, A2A, Logfire, Human-in-the-Loop, pydantic-evals) are entirely absent. Fixing the three code errors and adding the ty caveat would bring this to a 7/10. Covering the missing ecosystem features would bring it to 9/10.

---

*Review conducted: 2026-02-18*
*Pydantic-ai version at time of review: v1.61.0*
*Reviewer: Claude Opus 4.6 (automated technical review)*
