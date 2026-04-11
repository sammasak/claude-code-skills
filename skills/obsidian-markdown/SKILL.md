---
name: obsidian-markdown
description: Use when creating or editing notes in an Obsidian vault, writing to ~/workspace, or using Obsidian-specific syntax (wikilinks, callouts, embeds, frontmatter properties).
allowed-tools: Bash, Read, Grep, Glob, Write, Edit
injectable: true
---

# Obsidian Flavored Markdown

Extends CommonMark/GFM with wikilinks, embeds, callouts, and properties. Standard Markdown (headings, bold, lists, tables) is assumed.

## Internal Links (Wikilinks)

```markdown
[[Note Name]]                   Link to note (Obsidian tracks renames)
[[Note Name|Display Text]]      Custom display text
[[Note Name#Heading]]           Link to heading
[[Note Name#^block-id]]         Link to block
[[#Heading]]                    Same-note heading
```

Use `[[wikilinks]]` for vault-internal notes; `[text](url)` for external URLs only.

Define a block ID by appending `^my-id` to any paragraph (lists/quotes: put it on a separate line after).

## Embeds

```markdown
![[Note Name]]                  Embed full note
![[Note Name#Heading]]          Embed section
![[image.png|300]]              Embed image with width
![[document.pdf#page=3]]        Embed PDF page
```

## Callouts

```markdown
> [!note]
> Basic callout.

> [!warning] Custom Title
> Callout with custom title.

> [!faq]- Collapsed by default
> - collapsed, + expanded
```

Common types: `note` `tip` `warning` `info` `example` `quote` `bug` `danger` `success` `todo`

## Properties (Frontmatter)

```yaml
---
date: 2024-01-15
tags:
  - project
  - active
aliases:
  - Alternative Name
---
```

`tags` — searchable labels. `aliases` — alternative names for link suggestions.

## Misc Syntax

```markdown
==Highlighted text==            Highlight
%%hidden comment%%              Hidden in reading view
#nested/tag                     Inline tag with hierarchy
$e^{i\pi} + 1 = 0$             Inline LaTeX
```

## Homelab Vault Conventions (`~/workspace`)

This vault uses the ICM (Interpreted Context Methodology) structure:

| Convention | Pattern |
|---|---|
| Session records | `sessions/ai-sessions/YYYY-MM-DD-slug.md` |
| ADRs | `<room>/decisions/ADR-NNN-slug.md` |
| RFCs | `<room>/decisions/RFC-YYYY-MM-slug.md` |
| Room routing | `INDEX.md` (discovery) + `CONTEXT.md` (activation) |
| Cross-room links | Wikilinks: `[[sessions/ai-sessions/2024-01-15-slug]]` |

**Frontmatter for session records:**
```yaml
---
date: 2026-04-11
type: ai-session   # or: meeting, work-session
project: homelab
goal: "one sentence"
outcome: "result"
session_id: abc123
---
```

**Frontmatter for ADRs:**
```yaml
---
status: accepted   # proposed | accepted | deprecated | superseded
date: 2026-04-11
supersedes: null
related: []
---
```

Required ADR sections: Context, Decision (one sentence), Options Considered (table), Consequences, Links.
