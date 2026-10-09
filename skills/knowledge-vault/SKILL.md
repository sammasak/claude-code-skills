---
name: knowledge-vault
description: Use when the user mentions a person, company, situation, or prior decision you don't recognise, when you need context from ~/knowledge, or when explicitly asked to write a runbook, ADR, or other durable reference to the vault.
---

# Knowledge Vault (`~/knowledge`)

Plain GFM markdown in a git repo, organised as rooms (`INDEX.md` for discovery + `CONTEXT.md` for operating in the room). `~/knowledge/CLAUDE.md` is the routing map. Career/people: `whoami/`; personal admin: `personal/`; systems: `homelab/`; multi-step guides: `workflows/<name>/CONTEXT.md`.

Search discipline and the write gate are owned by the global CLAUDE.md (subagent-only search; durable reference only, commit-first). This skill owns the writing mechanics:

- Links: relative markdown paths from the current file, e.g. `[age keys](../nix/sops-nixos.md#age-keys)`; check with `test -f "$(dirname <file>)/<relpath>"`. Standard GFM only: no `[[...]]` links, embeds, or callout syntax.
- Placement: ADRs at `<room>/decisions/ADR-NNN-slug.md`, RFCs at `<room>/decisions/RFC-YYYY-MM-slug.md`, binary sources in a co-located `sources/`.
- ADR frontmatter: `status` (proposed | accepted | deprecated | superseded), `date`, `supersedes`, `related`; sections Context, Decision (one sentence), Options Considered (table), Consequences, Links.
- After adding or renaming files, update the room's `INDEX.md` to match.
  (Naming and the commit+push flow are owned by the global CLAUDE.md.)
