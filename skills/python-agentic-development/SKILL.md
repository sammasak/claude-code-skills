---
name: python-agentic-development
description: "Use when building Python AI agents, designing LLM tool interfaces, structuring async services, or working with pydantic-ai. Guides clean agentic architecture, testing strategies, and production patterns."
allowed-tools: Bash Read Grep Glob
---

# Python Agentic Development

Build reliable AI agents in Python with typed interfaces, testable tools, and production-grade observability.

## Principles

1. **Start simple** -- only add agents when simpler approaches (direct API calls, rule engines, pipelines) demonstrably fail.
2. **Design tools for agents, not humans** -- explicit names (`search_logs_by_service`), constrained inputs (enums over free text), clear error messages (actionable, not stack traces).
3. **Set hard limits** -- iteration caps (10-20 per run), timeouts (30-60s per action), token budgets. Agents without bounds will waste money and time.
4. **Observability from day one** -- structured logs, traces, and metrics. You cannot debug an agent from print statements.
5. **Structured outputs always** -- parse into pydantic models, never regex match raw LLM text.

## Standards

### Typing & Data

| Rule | Example |
|---|---|
| Pydantic `BaseModel` at every boundary (API, DB, agent I/O) | `class ToolResult(BaseModel): ...` |
| Use `ty` (Astral's type checker) for static analysis | `ty check src/` |
| Ruff for lint + format (single tool, fast) | `ruff check --fix && ruff format` |
| No `from typing import *` -- import what you need | `from typing import Any, Sequence` |
| Annotate all public functions; use `Self`, `TypeVar`, generics | |

### Async & IO

- [ ] Async-first with `httpx.AsyncClient` -- never `requests` in async code
- [ ] Use `asyncio.TaskGroup` for concurrent work (not bare `create_task`)
- [ ] Connection pools via dependency injection, not module-level globals
- [ ] Structured logging with `structlog` -- never `print()`

### Testing

- [ ] `pytest` + `pytest-asyncio` (mode = auto)
- [ ] Every tool function independently testable without calling an LLM
- [ ] Mock external APIs at the `httpx` transport layer
- [ ] Integration tests for agent behavior use deterministic fixtures, not live models
- [ ] Aim for: tools 90%+ coverage, agent wiring 70%+, prompt logic tested via eval harness

### Dependencies & Packaging

- [ ] `uv` for package management (fast resolver, lockfile-based)
- [ ] Hatchling as build backend
- [ ] Pin dependencies in `uv.lock`, ranges in `pyproject.toml`
- [ ] Multi-stage Docker builds with `python:3.x-slim`

## Workflow

### Development Cycle

```
1. Define pydantic models (inputs, outputs, errors)
2. Write tool functions (pure logic, typed signatures)
3. Test tools in isolation (unit tests, no LLM)
4. Wire tools into agent (pydantic-ai decorators)
5. Integration test the agent (deterministic fixtures)
6. Instrument with OpenTelemetry at service boundaries
```

### Pre-Commit Pipeline

```yaml
# .pre-commit-config.yaml essentials
- ruff check --fix
- ruff format
- ty check
- pytest (on push)
```

### Observability Checklist
- [ ] OpenTelemetry traces on every agent run and tool invocation
- [ ] Structured log events: `agent.start`, `tool.call`, `tool.result`, `agent.complete`
- [ ] Metrics: token usage, iteration count, tool call latency, error rate
- [ ] Trace context propagated through async boundaries

## Patterns We Use

### Agent Framework: pydantic-ai

```python
from pydantic_ai import Agent

agent = Agent(
    "claude-sonnet",
    deps_type=MyDeps,           # typed dependency injection
    result_type=StructuredOut,  # validated output model
    retries=2,
)

@agent.tool
async def query_prometheus(ctx: RunContext[MyDeps], metric: str) -> str:
    """Fetch a Prometheus metric by name."""  # docstring = tool description
    async with ctx.deps.http_client as client:
        resp = await client.get(f"/api/v1/query", params={"query": metric})
        return resp.text
```

### Service Layer

Use **pydantic-graph** for multi-step workflows requiring branching, retries, or stateful transitions.

| Component | Choice | Why |
|---|---|---|
| API framework | FastAPI + WebSocket | Real-time agent streaming |
| Knowledge store | SurrealDB | Graph relations + document flexibility |
| HTTP client | httpx.AsyncClient | Async-native, connection pooling |
| Build backend | Hatchling | Simple, standards-compliant |
| Container base | python:3.x-slim | Small image, multi-stage build |

### Tool Design Pattern -- wrap external APIs with typed interfaces

```python
class LogSearchInput(BaseModel):
    service: str
    query: str
    limit: int = Field(default=100, le=1000)

async def search_loki_logs(deps: AgentDeps, input: LogSearchInput) -> LogSearchResult:
    """Search Loki logs for a service. Returns structured log entries."""
    # Independently testable -- no LLM coupling
    ...
```

## Anti-Patterns

| Do Not | Do Instead |
|---|---|
| String prompts without output models | Define a `BaseModel` for every agent result |
| Agents without timeout or iteration cap | Set `max_retries`, timeouts, iteration limits |
| Test agents by calling the LLM | Test tools and logic separately; use eval harness for prompts |
| Catch bare `Exception` | Catch specific exceptions; let unexpected errors propagate |
| Mutable global state for agent config | Inject config via deps; freeze with `model_config = {"frozen": True}` |
| `from typing import *` | Import specific names |
| Nested `asyncio.run()` / event loop hacks | Use `TaskGroup`, proper async entry points |
| Ignore type checker errors | Fix or explicitly annotate; zero tolerance policy |

## References

- [Building Effective Agents](https://anthropic.com/research/building-effective-agents) -- Anthropic's agentic design guide
- [pydantic-ai docs](https://ai.pydantic.dev) -- agent framework with typed deps and structured results
- [FastAPI best practices](https://fastapi.tiangolo.com/tutorial/) -- async API patterns
- [Python typing (PEP 484/544/612)](https://typing.readthedocs.io) -- type annotation reference
- [structlog docs](https://www.structlog.org) -- structured logging for Python
- [OpenTelemetry Python](https://opentelemetry.io/docs/languages/python/) -- instrumentation SDK
