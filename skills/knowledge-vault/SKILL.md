---
name: knowledge-vault
description: Manage documentation in knowledge vault with auto-sync - create docs from templates, update content, manage projects, all changes auto-pushed to remote
---

# Knowledge Vault

Manage all documentation in the knowledge vault with automatic git synchronization.

## When to Use

- Creating new documentation (concepts, architecture, runbooks, plans, decisions)
- Updating existing documentation
- Managing project documentation and status
- Any operation that modifies vault content

## Prerequisites

**Vault Location:** `~/knowledge-vault`

**Required Tools:**
- `just` - Task runner (provides automation commands)
- `git` - Version control

**Vault Structure:**
```
~/knowledge-vault/
├── Infrastructure/   # NixOS, system config, deployment
├── Homelab/         # Kubernetes, GitOps, cluster ops
├── Development/     # Dev tools, workflows, AI agents
├── Drafts/          # Work in progress (not yet promoted)
├── Archive/         # Historical documentation
└── Meta/            # Templates and scripts
    ├── templates/   # Document templates
    └── scripts/     # Automation scripts
```

## Core Principles

**ALWAYS AUTO-SYNC:**
1. `just sync` before any operation (pull latest changes)
2. Perform vault operation (create/update document)
3. `just sync-push "message"` after changes (commit + push)

This keeps all hosts synchronized and prevents merge conflicts.

## Operations

### 1. Create New Document

**Workflow:**
1. Sync vault: `cd ~/knowledge-vault && just sync`
2. Create draft: `just draft <name> <template>`
3. Write content with Write tool (include proper frontmatter)
4. Validate: `just validate`
5. Sync and push: `just sync-push "docs: draft <name>"`

**Available Templates:**
- `concept` - How something works, mental models
- `architecture` - System design, component relationships
- `runbook` - Step-by-step operational procedures
- `plan` - Implementation plans, project planning
- `decision` - ADRs, architectural decisions

**Frontmatter Requirements:**
```yaml
---
title: "Human Readable Title"
domain: infrastructure|homelab|development
type: concept|architecture|runbook|plan|decision
tags: [tag1, tag2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: draft|published|archived
related: ["[[Related Doc]]"]
---
```

**Content Guidelines:**
- Start with `## Overview` section
- Use Mermaid diagrams for architecture/runbooks
- Link to related docs with `[[wikilinks]]`
- Include examples and code snippets
- Add `## References` section with external links

**Example - Creating a Concept Document:**
```
User: "Document the NixOS specialisation pattern"
Claude: "I'll create a concept document for NixOS specialisations."

Steps:
1. cd ~/knowledge-vault && just sync
2. just draft nix-specialisations concept
3. Use Write tool to create Drafts/nix-specialisations/nix-specialisations.md:
   - Add frontmatter (title, domain: infrastructure, type: concept, tags, dates, status: draft)
   - Write overview section
   - Add technical details
   - Include examples
   - Link related concepts with [[wikilinks]]
4. just validate
5. just sync-push "docs: draft nix-specialisations concept"
```

### 2. Update Existing Document

**Workflow:**
1. Sync vault: `cd ~/knowledge-vault && just sync`
2. Read current content: Use Read tool on the document
3. Update content: Use Edit tool to modify specific sections
4. Validate: `just validate`
5. Sync and push: `just sync-push "docs: update <document-name>"`

**Example - Updating a Document:**
```
User: "Update the k3s cluster architecture to include new monitoring stack"

Claude: "I'll update the architecture document."

Steps:
1. cd ~/knowledge-vault && just sync
2. Read Homelab/Architecture/k3s-cluster.md
3. Use Edit tool to update the monitoring section
4. Update frontmatter 'updated' field to current date
5. just validate
6. just sync-push "docs: update k3s-cluster with monitoring stack"
```

### 3. Promote Draft to Final Location

**Workflow:**
1. Sync vault: `cd ~/knowledge-vault && just sync`
2. Promote draft: `just promote <draft-name> <Domain> <Subdomain>`
3. This creates a PR on GitHub
4. Review PR and merge
5. After merge: `git checkout main && git pull`

**Example - Promoting a Draft:**
```
User: "The nix-specialisations concept is ready to publish"

Claude: "I'll promote it to Infrastructure/Concepts."

Steps:
1. cd ~/knowledge-vault && just sync
2. just promote nix-specialisations Infrastructure Concepts
3. Review PR at the URL provided
4. After user merges PR:
   git checkout main && git pull
```

### 4. Manage Project Documentation

**Project Structure:**
```
<Domain>/Projects/<project-name>/
├── index.md              # Project overview and status
├── architecture.md       # System design
├── decisions/            # ADRs
│   ├── 001-choice.md
│   └── 002-another.md
├── plans/                # Implementation plans
│   ├── phase-1.md
│   └── phase-2.md
└── runbooks/             # Operational procedures
    ├── deploy.md
    └── troubleshoot.md
```

**Workflow:**
1. Sync vault
2. Create project index with Write tool
3. Create supporting docs (architecture, decisions, plans) using draft workflow
4. Update project status using Edit tool
5. Sync and push after each change

**Example - Starting a New Project:**
```
User: "Start documenting the new Jarvis project in homelab"

Claude: "I'll create the project structure."

Steps:
1. cd ~/knowledge-vault && just sync
2. Use Write tool to create Homelab/Projects/jarvis/index.md:
   - Frontmatter: title, domain: homelab, type: project, status: planning
   - Overview section
   - Goals checklist
   - Links to architecture/plans/decisions (create placeholders)
3. just sync-push "docs: create jarvis project index"
4. Create architecture draft:
   just draft jarvis-architecture architecture
5. Write architecture content with Write tool
6. just validate
7. just sync-push "docs: draft jarvis architecture"
8. Promote architecture:
   just promote jarvis-architecture Homelab Projects/jarvis
```

## Error Handling

### Merge Conflicts

**Symptoms:** `just sync` fails with merge conflict message

**Resolution:**
1. Run: `cd ~/knowledge-vault && git status`
2. Identify conflicted files
3. Resolve conflicts manually (edit files, remove conflict markers)
4. Run: `git add .`
5. Run: `git commit -m "resolve merge conflict"`
6. Run: `git push`
7. Retry operation

**Prevention:** Always sync before operations

### Validation Failures

**Symptoms:** `just validate` reports missing frontmatter fields

**Resolution:**
1. Check which fields are missing
2. Use Edit tool to add required fields to frontmatter
3. Run `just validate` again
4. Continue with sync-push

**Required Fields:**
- title
- domain
- type
- created
- updated
- status

### Vault Not Found

**Symptoms:** `~/knowledge-vault` directory doesn't exist

**Resolution:**
1. Clone vault: `git clone git@github.com:sammasak/knowledge-vault.git ~/knowledge-vault`
2. Or rebuild NixOS: `sudo nixos-rebuild switch --flake .#<hostname>`
3. Verify vault exists: `ls -la ~/knowledge-vault`

### Git Push Failures

**Symptoms:** `git push` fails with authentication or network error

**Resolution:**
1. Check network: `ping github.com`
2. Verify SSH keys: `ssh -T git@github.com`
3. Check git remote: `cd ~/knowledge-vault && git remote -v`
4. If SSH key issue: add key to ssh-agent
5. Retry push

## Tips

- **Always sync first** - Prevents merge conflicts
- **Validate before pushing** - Catches frontmatter errors early
- **Use wikilinks** - Connect related concepts with `[[wikilinks]]`
- **Draft first, promote later** - Don't write directly to final locations
- **Descriptive commit messages** - Clear messages help track changes
- **Leverage templates** - Use `just draft` for consistent structure

## Integration with Justfile

This skill orchestrates these Justfile commands:

| Command | Purpose |
|---------|---------|
| `just sync` | Pull latest changes from remote |
| `just draft <name> <template>` | Create draft from template |
| `just validate` | Check frontmatter in all documents |
| `just sync-push "message"` | Atomic sync + commit + push |
| `just promote <draft> <domain> <subdir>` | Create PR to promote draft |
| `just stats` | Show vault statistics |
| `just templates` | List available templates |

## Checklist

Before creating a document:
- [ ] Sync vault with `just sync`
- [ ] Choose appropriate template
- [ ] Determine correct domain (Infrastructure/Homelab/Development)
- [ ] Include all required frontmatter fields
- [ ] Use wikilinks to related concepts
- [ ] Validate with `just validate`
- [ ] Push with `just sync-push "descriptive message"`

Before promoting a draft:
- [ ] Sync vault
- [ ] Verify draft is complete and reviewed
- [ ] Run `just validate` to ensure frontmatter is correct
- [ ] Use `just promote` to create PR
- [ ] Review PR on GitHub before merging
