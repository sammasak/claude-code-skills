---
name: python-agentic-development
description: "Use when building AI agents, designing LLM tool interfaces, working with pydantic-ai, pydantic-graph, or MCP. Guides agentic architecture, tool design, evaluation, and production patterns."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Python Agentic Development

## Principles

- **Start simple** -- only add agents when simpler approaches fail.
- **Design tools for agents** -- explicit names, constrained inputs, clear errors.
- **Structured outputs always** -- use `output_type` with Pydantic models.
- **Observability from day one** -- track tokens, latency, and errors.
- **Human-in-the-loop** -- approval required for mutations and destructive actions.

## Standards

- **Framework**: Use `pydantic-ai` for typed dependencies and structured outputs.
- **MCP Integration**: Prefer `MCPServerStreamableHTTP` for connecting to tool servers.
- **Testing**: Use `TestModel` for deterministic agent testing without LLM calls.
- **Full Reference**: Read `docs/python-agentic-patterns.md` for toolset composition, evaluation examples, and multi-step workflow details.

## Patterns We Use

| Component | Choice | Why |
|-----------|--------|-----|
| Agent framework | `pydantic-ai` | Typed deps, toolset composition |
| Workflows | `pydantic-graph` | Stateful multi-step with branching |
| Evaluation | `pydantic-evals` | Dataset-driven prompt testing |
| Observability | Logfire / OTel | Full agent traces, token accounting |

<restrictions>

## Anti-Patterns

- **Never** regex-parse raw LLM text; use structured outputs.
- **Avoid** monolithic agents; compose with toolsets and graphs.
- **Do not** test agents by calling the live LLM; use `TestModel`.
- **Set hard limits**: always configure `retries`, timeouts, and iteration caps.

</restrictions>
