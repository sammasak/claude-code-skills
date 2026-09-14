---
name: knowledge-vault
description: Use when reading ~/knowledge for context (who a person/company/situation is, prior decisions), or when explicitly asked to write durable reference (a runbook or ADR) to the vault. Documentation is commit-first and human-gated — never write to the vault reflexively.
---

# Knowledge Vault

`~/knowledge` is a personal reference vault, organised as rooms (directories with `INDEX.md` for discovery + `CONTEXT.md` for operation). See `~/knowledge/CLAUDE.md` for the routing map.

## Reading for context (when confused)

If you don't recognise a person, company, situation, or reference the user mentions, check the vault before asking.

- **Never** run `ls`/`grep`/`find`/`qmd` against `~/knowledge` in the main thread — it pollutes context.
- Dispatch one `Agent` subagent (`subagent_type: 'Explore'`) to search the relevant room; ask it to return `filepath: 'key context'` lines only.
- Read the summaries; `Read` a specific file if you need depth. If the subagent finds nothing useful, proceed without vault context — no fallback search in the main thread.
- Career/people live in `whoami/applications/<slug>/`; personal admin in `personal/`; systems in `homelab/`.

## Writing — commit-first and gated

The default home for the *why* of a change is a **short technical commit message**, not the vault. Write to the vault ONLY when:

1. the content is **durable reusable reference** — a runbook or an ADR (`decisions/ADR-NNN-slug.md`), or
2. the user **explicitly asks** you to.

Never dump session notes, research, or per-project status into the vault.

When you do write:

- **Markdown conventions:** relative markdown links `[text](../room/file.md)`, NOT `[[wikilinks]]`; standard GFM only — no `![[embeds]]`, `> [!callout]`, `==highlight==`, `%%comment%%`, `^block-id`, or `#inline/tag`. YAML frontmatter is fine.
- Name files after their subject (never `notes.md`, never `misc/`); one focused topic per file.
- Sync: `cd ~/knowledge && git pull && git add <files> && git commit && git push`.
