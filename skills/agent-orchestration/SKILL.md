---
name: agent-orchestration
description: "Use when dispatching work to background or parallel subagents, defining custom subagents, or choosing between local agent dispatch and running Claude on another machine (herdr)."
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
injectable: true
---

Use when dispatching work to background or parallel subagents, defining custom subagents, or choosing between local agent dispatch and running Claude on another machine (herdr).

# agent-orchestration

## Local dispatch: the Agent tool

The `Agent` tool spawns a subagent in the current session. `subagent_type: "fork"` forks the caller — full conversation context, same model, shares the prompt cache — and is the right default whenever intermediate output isn't worth keeping in the parent's context. Any other `subagent_type` (or omitting it) starts a fresh agent with zero memory of the conversation; brief it like a colleague who just walked in.

**Parallel dispatch:** independent tasks go in a single message with multiple `Agent` tool calls — that is what makes them run concurrently. Sequential calls across separate messages block on each other.

**Custom subagents:** define reusable ones at `.claude/agents/<name>.md`. Frontmatter controls model, tools, and permissions:

```yaml
---
name: my-agent
model: sonnet            # explicit model always — see assigning-subagent-models
tools: [Bash, Read, Grep]
---
System prompt / instructions for this agent go here.
```

The homelab's built-in agents (`verify-deployment.md`, `validate-k8s.md`, `code-reviewer.md`, `k8s-debugger.md`, `nix-explorer.md`) are managed via Home Manager and live in the Nix store — edit them by updating the NixOS Home Manager config and rebuilding, not by editing the linked file directly.

**Every spawn needs an explicit model** — see the `assigning-subagent-models` skill for the effort-tier ladder. Don't leave a subagent to silently inherit the parent's model.

## Remote dispatch: running on another machine

For work that needs a *different host* (not just isolation — an actual remote machine), use `herdr`, the terminal workspace manager, to open a session on that host and run `claude` there. There is no VM-provisioning layer in this homelab (KubeVirt and the claude-worker/claude-ctl VM fleet were torn down) — herdr sessions on existing hosts are the only remote pattern.

## Decision Matrix

| Need | Pattern |
|------|---------|
| Independent research/review tasks | Multiple `Agent` calls in one message |
| Output not worth keeping in context | `subagent_type: "fork"` |
| Reusable specialised role | `.claude/agents/<name>.md` definition |
| Isolated filesystem for a task | `isolation: "worktree"` on the `Agent` call |
| Work must run on a specific other machine | `herdr` session on that host |

## Known Gotchas

- **A forked agent's tool output isn't yours until it reports back.** Never fabricate or predict a fork's results — wait for the completion notification.
- **`isolation: "worktree"` only helps inside a git repo** — it creates a git worktree, auto-cleaned if the agent makes no changes; otherwise the path/branch are returned.
- **Don't re-delegate your whole assignment to one subagent** when you're already the agent assigned to a task — use subagents for sub-tasks you'd otherwise have to context-switch out of, not as a proxy for the whole job.
