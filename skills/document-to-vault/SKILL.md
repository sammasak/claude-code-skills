---
name: document-to-vault
description: Write documentation to Obsidian knowledge vault using MCP with proper frontmatter and structure
---

# Document to Vault

Write documentation to the Obsidian knowledge vault with proper frontmatter, categorization, and linking.

## When to Use

- Documenting a concept, technology, or architecture
- Creating runbooks or operational guides
- Writing implementation plans or ADRs
- Capturing knowledge from projects

## Prerequisites

**CRITICAL: Always sync vault first**
```bash
cd ~/Documents/knowledge-vault
just sync
```

## Process

### 1. Determine Document Type and Domain

**Domains:**
- `Infrastructure` - NixOS, system config, deployment
- `Homelab` - Kubernetes, GitOps, cluster ops
- `Development` - Dev tools, workflows, AI agents

**Document Types:**
- `concept` - How something works, mental models
- `architecture` - System design, component relationships
- `runbook` - Step-by-step operational procedures
- `plan` - Implementation plans, project planning
- `decision` - ADRs, architectural decisions

### 2. Create Draft Using Justfile

```bash
cd ~/Documents/knowledge-vault
just draft <topic-name> <template-type>

# Examples:
just draft nix-flakes concept
just draft k3s-cluster architecture
just draft deploy-app runbook
```

This creates `Drafts/<topic-name>/<topic-name>.md` with proper template.

### 3. Write Content Using MCP

Use the Obsidian MCP to write/edit the draft:

```
Use mcp__obsidian__write_note to write content to:
  path: "Drafts/<topic-name>/<topic-name>.md"
  mode: "overwrite"
  content: <full markdown with frontmatter>
```

**Frontmatter Requirements:**
```yaml
---
title: "Human Readable Title"
domain: infrastructure|homelab|development
type: concept|architecture|runbook|plan|decision
tags: [tag1, tag2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: draft
related: ["[[Related Doc]]"]
---
```

**Content Guidelines:**
- Start with ## Overview section
- Use Mermaid diagrams for architecture/runbooks
- Link to related docs with `[[wikilinks]]`
- Include examples and code snippets
- Add ## References section with external links

### 4. Validate Content

After writing, validate frontmatter:

```bash
cd ~/Documents/knowledge-vault
just validate
```

### 5. Commit Draft

```bash
cd ~/Documents/knowledge-vault
git add Drafts/<topic-name>/
git commit -m "docs: draft <topic-name>"
git push
```

### 6. Promote to Final Location (when ready)

Use the promote command to create a PR:

```bash
just promote <topic-name> <domain> <subdomain>

# Examples:
just promote nix-flakes Infrastructure Concepts
just promote k3s-cluster Homelab Architecture
just promote deploy-app Homelab Runbooks
```

This creates a PR to move the draft to its final location with status changed to `published`.

## Examples

### Example 1: Document a Concept

```
1. Sync vault:
   cd ~/Documents/knowledge-vault && just sync

2. Create draft:
   just draft nix-specialisations concept

3. Write content via MCP:
   Use mcp__obsidian__write_note with:
     path: "Drafts/nix-specialisations/nix-specialisations.md"
     content: |
       ---
       title: "NixOS Specialisations"
       domain: infrastructure
       type: concept
       tags: [nixos, nix, system-config]
       created: 2026-02-20
       updated: 2026-02-20
       status: draft
       related: ["[[NixOS Modules]]", "[[System Configuration]]"]
       ---

       # NixOS Specialisations

       ## Overview
       Specialisations allow multiple system configurations in a single NixOS build...

       [... content ...]

4. Validate:
   just validate

5. Commit:
   git add Drafts/nix-specialisations/
   git commit -m "docs: draft nix-specialisations concept"
   git push

6. Promote (when ready):
   just promote nix-specialisations Infrastructure Concepts
```

### Example 2: Create a Runbook

```
1. Sync: just sync

2. Create draft:
   just draft deploy-k3s runbook

3. Write via MCP with procedure flowchart:
   ---
   title: "Deploy k3s Cluster"
   domain: homelab
   type: runbook
   [...]
   ---

   # Deploy k3s Cluster

   ## Purpose
   Deploy a fresh k3s cluster with Flux GitOps

   ## Procedure

   ```mermaid
   graph TD
       A[Prepare Nodes] --> B[Install k3s]
       B --> C[Configure kubectl]
       C --> D[Bootstrap Flux]
   ```

   ### Step 1: Prepare Nodes
   ...

4. Commit and promote
```

## Tips

- **Use MCP for all vault operations** - Don't manually edit files
- **Always sync first** - Prevents conflicts
- **Use wikilinks** - Connect related concepts with `[[wikilinks]]`
- **Add diagrams** - Use Mermaid for architecture/runbooks
- **Validate before committing** - Run `just validate`
- **Draft first, promote later** - Don't write directly to final locations

## Integration

This skill works with:
- `mcp__obsidian__*` tools for vault operations
- `just` commands for vault management
- Git workflow for version control
- GitHub PRs for review process

## Troubleshooting

**Vault not synced:**
```bash
cd ~/Documents/knowledge-vault
just sync
```

**Frontmatter validation fails:**
Check required fields: title, domain, type, created, updated, status

**MCP write fails:**
Ensure path is relative to vault root: `Drafts/topic/file.md`

**Can't promote draft:**
Ensure draft exists in `Drafts/` and has valid frontmatter
