---
name: knowledge-vault
description: Use when the user mentions a person, company, situation, or prior decision you don't recognise, when you need context from ~/knowledge, or when explicitly asked to write a runbook, ADR, or other durable reference to the vault.
---

# Knowledge Vault (`~/knowledge`)

Plain GFM markdown in a git repo, organised as rooms (`INDEX.md` for discovery + `CONTEXT.md` for operating in the room). `~/knowledge/CLAUDE.md` is the routing map. Career/people: `whoami/`; personal admin: `personal/`; systems: `homelab/`; multi-step guides: `workflows/<name>/CONTEXT.md`.

## Reading

- Search through one `Explore` subagent asked to return `filepath: 'key context'` lines only; never `ls`/`grep`/`find`/`qmd` the vault in the main thread.
- `Read` a specific file for depth. If the subagent finds nothing, proceed without vault context.

## Writing (gated)

The *why* of a change goes in the commit message. Write to the vault only for durable reference (runbook, ADR, RFC) or when the user asks; never session notes, research dumps, or project status.

- Links: relative markdown paths from the current file, e.g. `[age keys](../nix/sops-nixos.md#age-keys)`; check with `test -f "$(dirname <file>)/<relpath>"`. Standard GFM only: no `[[...]]` links, embeds, or callout syntax.
- Placement: ADRs at `<room>/decisions/ADR-NNN-slug.md`, RFCs at `<room>/decisions/RFC-YYYY-MM-slug.md`, binary sources in a co-located `sources/`. Name files after their subject (never `notes.md` or `misc/`), one topic per file.
- ADR frontmatter: `status` (proposed | accepted | deprecated | superseded), `date`, `supersedes`, `related`; sections Context, Decision (one sentence), Options Considered (table), Consequences, Links.
- After adding or renaming files, update the room's `INDEX.md` to match.
- Sync: `cd ~/knowledge && git pull && git add <files> && git commit && git push`.
