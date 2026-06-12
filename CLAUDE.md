# User Context

> **Snapshot warning:** The knowledge vault is manually maintained with no automatic syncs. Treat all entries as "probably right as of the last commit." When vault content conflicts with what you observe in code or git, trust what you observe and update the vault.

## Knowledge Vault

Lives at `~/knowledge`. Rooms are directories — each has `INDEX.md` (discovery) and `CONTEXT.md` (operational instructions). Read a room's `CONTEXT.md` to activate it.

**Room routing — what lives where:**

| Room | Contents |
|------|----------|
| `whoami/` | Professional profile, career history, companies, tech preferences, recruiter interactions |
| `workflows/` | Process guides for recurring tasks — recruiter replies, invoicing, deploys, VAT, etc. |
| `homelab/` | NixOS, k3s, Flux, KubeVirt, Harbor, SOPS, observability |
| `dev/` | Active project rooms — doable, workstation-api, claude-ctl, claude-code-skills |
| `company/` | AB operations — clients, invoicing, compliance, contracts |
| `personal/` | Apartment hunting, personal finance, business formation |
| `Board/` | Kanban board — tickets, backlog, in-progress, completed |
| `sessions/` | Session history, meeting notes, prior decisions |
| `architecture/` | Cross-cutting patterns — WASM, SSE, databases |
| `sweden-company/` | Swedish company law, taxes, 3:12 rules |

## Searching the Vault — Always Use a Subagent

**Never run `ls`, `grep`, `find`, or `qmd` against `~/knowledge` in the main thread.** It pollutes context and buries the signal.

When you need information from the vault:

1. Dispatch a subagent using the `Agent` tool (`subagent_type: 'Explore'` for lookups).
2. Prompt it: _"Search `~/knowledge/<relevant-room>/` for [question]. Return results as `filepath: 'key context'` lines only — no prose."_
3. The subagent returns something like:
   ```
   ~/knowledge/whoami/profile.md: 'Senior SE at Klarna, Platform & DX, Go+Rust. Full career history.'
   ~/knowledge/workflows/reachout/CONTEXT.md: 'Recruiter reply workflow. Cold/warm/uncertain types, 3-block analysis, writing patterns.'
   ```
4. Decide: proceed with the summaries, or `Read` a specific file directly for more depth.

One subagent dispatch is enough. If it returns nothing useful, proceed without vault context — do not run a fallback search in the main thread.

## Workflows

At `~/knowledge/workflows/<name>/CONTEXT.md`. Activate by reading that file directly. Available workflows include: `reachout` (recruiter replies), `company-invoice`, `deploy-service`, `company-monthly`, `company-quarterly-vat`, `job-application`, `apartment-hunt`, and others. Full list: `~/knowledge/workflows/INDEX.md`.

## Ownership

Any session that produces new decisions, learnings, or context: update the vault before closing.
- Name files after their subject — findable from `ls` alone (never `notes.md`, never `misc/`)
- One focused topic per file; commit often with clear messages
- After writing: `cd ~/knowledge && git pull && git add <files> && git commit -m "docs: <what and why>" && git push`

Full authoring conventions live in `~/knowledge/CLAUDE.md` under "File and Folder Organisation".
