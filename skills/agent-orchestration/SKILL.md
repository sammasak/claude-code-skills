---
name: agent-orchestration
description: "Use when dispatching work to background agents, defining custom subagents, or choosing between local agent dispatch and VM-based workers (claude-ctl)."
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
injectable: true
---

Use when dispatching work to background agents, defining custom subagents, or choosing between local agent dispatch and VM-based workers (claude-ctl).

# agent-orchestration

## Prerequisites

- Claude Code v2.1.139+ (agent view GA) — run `claude --version` to confirm
- `.claude/agents/*.md` directory for custom subagent definitions
- For VM workers: `claude-ctl` binary and `workstations-api` access (see claude-ctl skill)

---

## Section A: Agent View Basics

`claude agents` opens the multi-session dashboard where you can list, monitor, and resume background sessions.

**Dashboard row signals:**
| Column | Meaning |
|--------|---------|
| Session ID | Unique identifier for the session (use with attach/logs/stop) |
| Waiting | Whether the session is blocked on a permission prompt |
| Last response | Truncated tail of the agent's last output line |
| Timestamp | Time of last activity |

**Launching agents from Agent View:**
- Type `<agent-name> <prompt>` to start a named subagent with that prompt
- Type `@<agent-name>` to select a custom agent from `.claude/agents/`
- Press `n` to open a new session inline

---

## Section B: CLI Integration Commands

These commands enable scripting, CI pipelines, and orchestration loops.

```bash
# Dispatch a background session (returns session ID)
claude --bg "<task description>"

# Reconnect to a running session's interactive view
claude attach <id>

# Read a session's full output log
claude logs <id>

# Terminate a running session
claude stop <id>

# Restart a stopped session from the beginning
claude respawn <id>

# Remove a completed or terminated session record
claude rm <id>
```

**Scripting pattern:**
```bash
ID=$(claude --bg "Run the test suite and report failures" | grep -oP '(?<=session: )\S+')
claude logs "$ID"   # tail output when done
```

---

## Section C: Custom Subagent Definition Format

Place agent definition files at `.claude/agents/<name>.md`. The frontmatter controls model, tools, permissions, and isolation.

```yaml
---
name: my-agent                 # slug used in `@my-agent` or Agent View
model: claude-opus-4-7         # or claude-sonnet-4-6, claude-haiku-4-5
tools: [Bash, Read, Write, Edit, Grep, Glob]
permissionMode: auto           # or default (interactive), or bypassPermissions
isolation: worktree            # optional: run in isolated git worktree copy
---

System prompt / instructions for this agent go here.
```

**`permissionMode` values:**
| Value | Behaviour |
|-------|-----------|
| `default` | Prompts user for every sensitive tool call |
| `auto` | Blocks risky actions, allows safe ones automatically |
| `bypassPermissions` | Allows all tool calls without prompting — use only in monitored environments |

**Homelab note:** The homelab's built-in agents (`verify-deployment.md`, `validate-k8s.md`, `code-reviewer.md`, `k8s-debugger.md`, `nix-explorer.md`) are managed via Home Manager and live in the nix store. They cannot be edited directly. To add metadata fields, update the NixOS Home Manager configuration and rebuild.

---

## Section D: Effort Levels

Control how much reasoning budget a session uses with `--effort` (CLI) or `/effort` (interactive slider).

| Level | When to use |
|-------|-------------|
| `min` | Trivial one-liners, quick lookups |
| `low` | Simple maintenance: dep updates, config tweaks, minor fixes |
| `medium` | Moderate tasks: single-file features, short debug sessions |
| `high` | Standard features, multi-file changes, test writing |
| `xhigh` | Complex multi-file refactors, deep debugging, architecture work (Opus 4.7+) |

```bash
# CLI dispatch with effort
claude --bg --effort high "Implement the retry middleware for the API client"
```

**Default:** `medium` if omitted. `xhigh` is only available with `claude-opus-4-7`.

---

## Section E: Decision Matrix — Which Dispatch Pattern

| Need | Pattern | Command |
|------|---------|---------|
| Quick task, no system access needed | Local agent | `claude --bg "task"` |
| Task needs buildah, kubectl, or cluster access | VM worker | `claude-ctl provision <name> --goal "task"` |
| Parallel independent tasks (review, research) | Multiple local agents | Dispatch N sessions from Agent View |
| Long-running task with persistent state | VM worker | `claude-ctl provision <name> --goal "task" --watch` |
| Task needs isolated filesystem | Local agent in worktree | Use `isolation: worktree` in agent definition |

**Rule of thumb:** If a task only reads/writes files and calls APIs, use a local agent. If a task needs cluster tools, a container runtime, or persistent disk state beyond the conversation, use a VM worker.

---

## Section F: Cost and Safety Guardrails

- **Parallel agents multiply API costs linearly.** Ten concurrent `xhigh` Opus sessions cost ten times a single session. Monitor usage dashboards before scaling.
- **Never run unattended sessions with `bypassPermissions`** without cost monitoring and budget alerts configured.
- **Prefer `permissionMode: auto`** for headless dispatch — it blocks risky actions (file deletions, shell injections) while allowing safe reads and writes automatically.
- **Set termination conditions** for background sessions: pass `--max-turns N` or configure a timeout so runaway sessions don't burn budget.
- **One goal per VM worker.** Don't reuse a provisioned VM for a second goal if the first left filesystem state behind — provision a fresh worker.

---

## Known Gotchas

- **Agent View requires v2.1.139+.** Run `claude --version` and upgrade if needed. The `claude agents` sub-command simply does not exist in older versions.
- **`permissionMode: auto` may block legitimate worker actions.** `buildah build`, `kubectl apply`, and `nix build` may all be flagged as risky. Test your agent with `default` mode first, then switch to `auto` once you've confirmed which prompts trigger.
- **Background sessions inherit the launching session's model** unless the agent frontmatter or `--model` flag overrides it. A `haiku`-defaulted session that spawns a background session will also use `haiku`.
- **Homelab cluster VM provisioning can fail silently on OOM.** `msi-ms7758` is frequently offline and `acer-swift` is low-memory. If `claude-ctl provision` hangs or fails, fall back to `claude --bg` for non-system tasks rather than retrying VM provisioning.
- **`isolation: worktree` creates a git worktree.** The worktree is automatically cleaned up if the agent makes no changes; if changes are made, the worktree path and branch are returned. The agent must be run inside a git repository for this to work.

---

## Verification

```bash
# Verify claude agents is available
claude agents --help 2>&1 | head -5

# Verify custom agents are linked
ls -la ~/.claude/agents/

# Test background dispatch (dry run)
claude --bg "echo hello from background agent" 2>&1 | head -3
```
