---
name: python-agentic-development
description: "Use when building AI agents, designing LLM tool interfaces, working with pydantic-ai, pydantic-graph, or MCP. Guides agentic architecture, tool design, evaluation, and production patterns."
allowed-tools: Bash, Read, Grep, Glob
---

# Python Agentic Development

Build reliable AI agents with typed dependencies, structured outputs, and composable toolsets.

## Principles

- **Start simple** -- only add agents when simpler approaches (direct API calls, rule engines, pipelines) demonstrably fail
- **Design tools for agents** -- explicit names (`search_logs_by_service`), constrained inputs (enums over free text), clear error messages
- **Set hard limits** -- iteration caps, timeouts, token budgets; agents without bounds waste money and time
- **Structured outputs always** -- use `output_type` with Pydantic models, never regex-parse raw LLM text
- **Observability from day one** -- Logfire / OpenTelemetry traces on every agent run
- **Human-in-the-loop for dangerous actions** -- `.approval_required()` for mutations and destructive tools

## Standards

### Agent Construction (pydantic-ai v1)

```python
from pydantic_ai import Agent
agent = Agent("anthropic:claude-sonnet-4-6", deps_type=MyDeps,
              output_type=StructuredOut, retries=2)
```

### Output Modes

| Mode | When to use |
|------|-------------|
| `ToolOutput` (default) | Most reliable; uses tool calling for structured data |
| `NativeOutput` | Model's native JSON schema mode; faster but less reliable |
| `PromptedOutput` | Schema injected into prompt; fallback for models without JSON mode |
| `TextOutput` | Custom text post-processing via a function |

### Tool Design

```python
@agent.tool
async def query_metrics(ctx: RunContext[MyDeps], metric: str) -> str:
    """Fetch a Prometheus metric by name."""  # docstring = tool description
    async with ctx.deps.http as client:
        resp = await client.get("/api/v1/query", params={"query": metric})
        return resp.text
```

### Toolset Composition

All tools implement `AbstractToolset`. Chainable modifiers:
- `.filtered(filter_fn)` -- filter which tools are available per-run
- `.prefixed(prefix)` -- namespace tool names to avoid collisions
- `.prepared(prepare_fn)` -- dynamic tool preparation based on context
- `.approval_required(filter_fn)` -- human-in-the-loop approval gate

Register at construction (`Agent(toolsets=[...])`) or at runtime (`agent.run(toolsets=[...])`).

## MCP Integration

| Transport | Use case |
|-----------|----------|
| `MCPServerStreamableHTTP(url)` | Remote HTTP servers (recommended) |
| `MCPServerStdio(cmd, args=[...])` | Subprocess-based local servers |
| `FastMCPToolset(server_or_url)` | In-process FastMCP server or remote via URL |

```python
from pydantic_ai.mcp import MCPServerStreamableHTTP
agent = Agent("anthropic:claude-sonnet-4-6",
              toolsets=[MCPServerStreamableHTTP("http://localhost:8000/mcp")])
```

## Human-in-the-Loop

Use `.approval_required(filter_fn)` on any toolset, then handle `DeferredToolRequests` in the output. If the result is deferred, collect approvals and re-run with `DeferredToolResults`. Set `output_type=[str, DeferredToolRequests]` so the agent can return either.

## Multi-Step Workflows: pydantic-graph

**Class-based API (stable)** -- nodes are dataclasses; edges defined by return type hints. Nodes return another node or `End[T]`. **Function-based API (beta)** -- `GraphBuilder` with `@g.step` decorators; supports `map`/`broadcast` for parallel steps and streaming.

## Evaluation: pydantic-evals

```python
from pydantic_evals import Case, Dataset
from pydantic_evals.evaluators import IsInstance, LLMJudge
dataset = Dataset(cases=[
    Case(name="capital", inputs="What is the capital of France?", expected_output="Paris"),
], evaluators=[IsInstance(type_name="str"), LLMJudge(rubric="Is it correct?")])
report = dataset.evaluate_sync(my_task_fn)
report.print(include_input=True, include_output=True)
```

## Testing

```python
from pydantic_ai.models.test import TestModel
result = agent.run_sync("test input", model=TestModel())
# Or override for all runs in a block:
with agent.override(model=TestModel()):
    result = agent.run_sync("test input")
```

- [ ] Use `TestModel` for deterministic agent testing without LLM calls
- [ ] Set `models.ALLOW_MODEL_REQUESTS = False` in conftest to prevent accidental LLM calls in tests
- [ ] Tool functions independently testable -- no LLM coupling
- [ ] `pydantic-evals` for prompt quality evaluation with `Dataset.evaluate_sync`
- [ ] Integration tests with deterministic fixtures, never live models

## Observability

`logfire.configure()` + `logfire.instrument_pydantic_ai()` gives full traces for all agents. Track: token usage, iteration count, tool call latency, error rate. Works with any OTel backend (`logfire.configure(send_to_logfire=False)`).

## Patterns We Use

| Component | Choice | Why |
|-----------|--------|-----|
| Agent framework | pydantic-ai | Typed deps, structured outputs, toolset composition |
| Workflows | pydantic-graph | Stateful multi-step with branching |
| Evaluation | pydantic-evals | Dataset-driven prompt testing |
| Observability | Logfire / OTel | Full agent traces, token accounting |
| Inter-agent | A2A via `agent.to_a2a()` | Standards-based agent communication |
| External tools | MCP (`MCPServerStreamableHTTP`) | Connect to external tool servers |

## Anti-Patterns

| Do Not | Do Instead |
|--------|------------|
| String prompts without output models | `output_type=MyModel` for every agent result |
| Agents without limits | Set `retries`, timeouts, iteration caps |
| Test agents by calling the LLM | Use `TestModel` for deterministic tests |
| Regex-parse LLM output | Structured outputs via Pydantic models |
| No approval for mutations | `.approval_required()` for dangerous tools |
| Monolithic agent doing everything | Compose with toolsets and pydantic-graph |
| Ignore agent traces | Instrument with Logfire from day one |

## References

- [Building Effective Agents](https://anthropic.com/research/building-effective-agents) -- Anthropic's guide
- [pydantic-ai](https://ai.pydantic.dev) | [MCP](https://ai.pydantic.dev/mcp/overview/) | [Logfire](https://pydantic.dev/logfire)
- [pydantic-graph](https://ai.pydantic.dev/graph/) -- workflow orchestration
- [pydantic-evals](https://ai.pydantic.dev/evals/) -- evaluation framework
- [A2A protocol](https://a2a-protocol.org/latest/) -- agent interop standard (Linux Foundation)
- [FastMCP](https://gofastmcp.com) -- MCP server/client framework
