# Python Agentic Development Patterns

Detailed patterns for building AI agents with `pydantic-ai`, `pydantic-graph`, and `MCP`.

## Agent Construction & Tools

```python
from pydantic_ai import Agent, RunContext
agent = Agent("anthropic:claude-sonnet-4-6", deps_type=MyDeps)

@agent.tool
async def query_metrics(ctx: RunContext[MyDeps], metric: str) -> str:
    """Fetch a Prometheus metric by name."""
    async with ctx.deps.http as client:
        resp = await client.get("/api/v1/query", params={"query": metric})
        return resp.text
```

## MCP Integration

```python
from pydantic_ai.mcp import MCPServerStreamableHTTP
agent = Agent("anthropic:claude-sonnet-4-6",
              toolsets=[MCPServerStreamableHTTP("http://localhost:8000/mcp")])
```

## Evaluation with pydantic-evals

```python
from pydantic_evals import Case, Dataset
from pydantic_evals.evaluators import IsInstance, LLMJudge
dataset = Dataset(cases=[
    Case(name="capital", inputs="What is the capital of France?", expected_output="Paris"),
], evaluators=[IsInstance(type_name="str"), LLMJudge(rubric="Is it correct?")])
```

## Testing with TestModel

```python
from pydantic_ai.models.test import TestModel
with agent.override(model=TestModel()):
    result = agent.run_sync("test input")
```

## Multi-Step Workflows

Use `pydantic-graph` for stateful multi-step processes with branching. Nodes are dataclasses; edges are defined by return type hints.

## References

- [Building Effective Agents](https://anthropic.com/research/building-effective-agents)
- [pydantic-ai](https://ai.pydantic.dev) | [MCP](https://ai.pydantic.dev/mcp/overview/)
- [pydantic-graph](https://ai.pydantic.dev/graph/) | [pydantic-evals](https://ai.pydantic.dev/evals/)
- [Logfire](https://pydantic.dev/logfire)
