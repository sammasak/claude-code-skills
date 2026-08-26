# User Context

> **Snapshot warning:** The knowledge vault is manually maintained with no automatic syncs. Treat all entries as "probably right as of the last commit." When vault content conflicts with what you observe in code or git, trust what you observe and update the vault.

## Knowledge Vault

Personal knowledge base at `~/knowledge`. Organised as rooms — directories with `INDEX.md` (what's in this room) and `CONTEXT.md` (how to operate in it). Read `~/knowledge/CLAUDE.md` for the full routing map of what lives where.

## Searching the Vault — Always Use a Subagent

**Never run `ls`, `grep`, `find`, or `qmd` against `~/knowledge` in the main thread.** It pollutes context and buries the signal.

When you need information from the vault:

1. Dispatch a subagent using the `Agent` tool (`subagent_type: 'Explore'` for lookups).
2. Prompt it to search the relevant room and return results as `filepath: 'key context'` lines only — no prose.
3. The main agent reads the summaries and decides: proceed with what it got, or `Read` a specific file directly for more depth.

One subagent dispatch is enough. If it returns nothing useful, proceed without vault context — do not run a fallback search in the main thread.

## Workflows

Multi-step process guides live at `~/knowledge/workflows/<name>/CONTEXT.md`. The routing map in `~/knowledge/CLAUDE.md` lists all available workflows. Activate one by reading its `CONTEXT.md` directly.

## Ownership

Any session that produces new decisions, learnings, or context: update the vault before closing.
- Name files after their subject — findable from `ls` alone (never `notes.md`, never `misc/`)
- One focused topic per file; commit often with clear messages
- After writing: `cd ~/knowledge && git pull && git add <files> && git commit -m "docs: <what and why>" && git push`

Full authoring conventions: `~/knowledge/CLAUDE.md` under "File and Folder Organisation".
