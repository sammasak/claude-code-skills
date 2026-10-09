---
name: python-agentic-development
description: "Use when building an LLM agent or tool server in Python, or working with pydantic-ai, pydantic-graph, pydantic-evals, or MCP."
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Python Agentic Development (homelab choices)

| Concern | Choice |
|---|---|
| Agent framework | `pydantic-ai` (typed `deps_type`, `output_type` Pydantic models) |
| Multi-step workflows | `pydantic-graph` |
| Evaluation | `pydantic-evals` datasets (see `evals/` in this repo) |
| MCP client | `pydantic_ai.mcp.MCPServerStreamableHTTP` |
| Unit tests | `agent.override(model=TestModel())`, no live LLM calls |
| Model IDs | take current IDs from the `assigning-subagent-models` ladder, e.g. `Agent("anthropic:claude-sonnet-5")` |

Tracing: no OTLP backend is deployed in the homelab, so agent token/latency accounting goes to logs and Prometheus metrics (see `observability-patterns`), not Logfire/Tempo, unless the project exports elsewhere.

General Python tooling: `python-engineering`.
