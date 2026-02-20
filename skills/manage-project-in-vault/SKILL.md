---
name: manage-project-in-vault
description: Manage project documentation and planning in Obsidian vault using MCP
---

# Manage Project in Vault

Track project status, planning, and documentation in the Obsidian knowledge vault.

## When to Use

- Starting a new project
- Planning implementation phases
- Tracking project decisions and status
- Documenting project architecture
- Creating project runbooks

## Prerequisites

**CRITICAL: Always sync vault first**
```bash
cd ~/Documents/knowledge-vault
just sync
```

## Project Structure

Each project should have documentation in the appropriate domain's `Projects/` subdirectory:

```
Infrastructure/Projects/<project-name>/
├── index.md              # Project overview and status
├── architecture.md       # System design
├── decisions/            # ADRs (Architectural Decision Records)
│   ├── 001-choice.md
│   └── 002-another.md
├── plans/                # Implementation plans
│   ├── phase-1.md
│   └── phase-2.md
└── runbooks/             # Operational procedures
    ├── deploy.md
    └── troubleshoot.md
```

## Process

### 1. Sync Vault

```bash
cd ~/Documents/knowledge-vault
just sync
```

### 2. Create Project Index

Use MCP to create project index:

```
Use mcp__obsidian__write_note:
  path: "<Domain>/Projects/<project-name>/index.md"
  content: |
    ---
    title: "<Project Name>"
    domain: infrastructure|homelab|development
    type: project
    tags: [project, <domain>]
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    status: active|planning|completed|archived
    related: []
    ---

    # <Project Name>

    ## Overview

    Brief description of what this project does.

    ## Status

    **Current Phase:** Planning | Development | Testing | Deployed | Archived

    **Last Updated:** YYYY-MM-DD

    ## Goals

    - [ ] Goal 1
    - [ ] Goal 2
    - [ ] Goal 3

    ## Architecture

    See [[architecture]] for detailed system design.

    ## Implementation Plans

    - [[plans/phase-1|Phase 1: Foundation]]
    - [[plans/phase-2|Phase 2: Features]]

    ## Decisions

    - [[decisions/001-technology-choice|Technology Choice]]

    ## Runbooks

    - [[runbooks/deploy|Deployment Procedure]]
    - [[runbooks/troubleshoot|Troubleshooting Guide]]

    ## Related Projects

    - [[../other-project/index|Other Project]]
```

### 3. Create Architecture Documentation

```bash
cd ~/Documents/knowledge-vault
just draft <project>-architecture architecture
```

Then use MCP to write architecture:

```
Use mcp__obsidian__write_note:
  path: "Drafts/<project>-architecture/<project>-architecture.md"
  content: |
    ---
    title: "<Project> Architecture"
    domain: <domain>
    type: architecture
    tags: [<project>, architecture]
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    status: draft
    related: ["[[<Domain>/Projects/<project>/index|Project Index]]"]
    ---

    # <Project> Architecture

    ## System Overview

    High-level description.

    ## Architecture Diagram

    ```mermaid
    graph TB
        subgraph "Frontend"
            A[UI]
        end
        subgraph "Backend"
            B[API]
            C[Database]
        end
        A --> B
        B --> C
    ```

    ## Components

    ### Component A

    Responsibilities and implementation.

    ## Data Flow

    How data moves through the system.

    ## Design Decisions

    Link to ADRs in [[decisions/]] directory.
```

Then promote to final location:
```bash
just promote <project>-architecture <Domain> Projects/<project>
```

### 4. Track Decisions (ADRs)

For each major decision:

```bash
just draft <project>-decision-<number> decision
```

Write decision via MCP:

```
Use mcp__obsidian__write_note:
  path: "Drafts/<project>-decision-<number>/<project>-decision-<number>.md"
  content: |
    ---
    title: "ADR <number>: <Decision Title>"
    domain: <domain>
    type: decision
    tags: [<project>, adr, decision-<number>]
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    status: draft
    related: ["[[<Domain>/Projects/<project>/index|Project Index]]"]
    ---

    # ADR <number>: <Decision Title>

    ## Context

    What decision needs to be made and why.

    ## Options Considered

    ### Option 1: <Name>

    **Pros:**
    - Pro 1
    - Pro 2

    **Cons:**
    - Con 1

    ### Option 2: <Name>

    **Pros:**
    - Pro 1

    **Cons:**
    - Con 1

    ## Decision

    We chose **Option X** because...

    ## Consequences

    - Impact 1
    - Impact 2
```

Promote to:
```bash
just promote <project>-decision-<number> <Domain> Projects/<project>/decisions
```

### 5. Create Implementation Plans

```bash
just draft <project>-phase-1 plan
```

Write plan via MCP:

```
Use mcp__obsidian__write_note:
  path: "Drafts/<project>-phase-1/<project>-phase-1.md"
  content: |
    ---
    title: "<Project> - Phase 1: Foundation"
    domain: <domain>
    type: plan
    tags: [<project>, plan, phase-1]
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    status: draft
    related: ["[[<Domain>/Projects/<project>/index|Project Index]]"]
    ---

    # <Project> - Phase 1: Foundation

    ## Goal

    Establish core infrastructure and baseline functionality.

    ## Tasks

    ### Task 1: Setup Infrastructure

    - [ ] Configure NixOS modules
    - [ ] Deploy to homelab
    - [ ] Verify connectivity

    ### Task 2: Core Services

    - [ ] Implement authentication
    - [ ] Set up database
    - [ ] Configure monitoring

    ## Testing

    - Integration tests pass
    - Can deploy to staging
    - Monitoring shows healthy metrics

    ## Dependencies

    - [[decisions/001-tech-stack|Tech Stack Decision]]
    - [[architecture|Architecture Design]]
```

### 6. Create Runbooks

```bash
just draft <project>-deploy runbook
```

Write runbook via MCP with procedure flowchart.

### 7. Update Project Status

Regularly update the project index via MCP:

```
Use mcp__obsidian__patch_note:
  path: "<Domain>/Projects/<project>/index.md"
  oldString: "**Current Phase:** Planning"
  newString: "**Current Phase:** Development"

Use mcp__obsidian__patch_note:
  path: "<Domain>/Projects/<project>/index.md"
  oldString: "- [ ] Goal 1"
  newString: "- [x] Goal 1"
```

## Examples

### Example: Start New Homelab Project

```
1. Sync vault:
   cd ~/Documents/knowledge-vault && just sync

2. Create project index via MCP:
   mcp__obsidian__write_note:
     path: "Homelab/Projects/jarvis/index.md"
     content: <project index with goals, status>

3. Create architecture draft:
   just draft jarvis-architecture architecture

4. Write architecture via MCP to Drafts/

5. Promote architecture:
   just promote jarvis-architecture Homelab Projects/jarvis

6. Document decisions:
   just draft jarvis-decision-001 decision
   Write via MCP
   Promote to Homelab/Projects/jarvis/decisions/

7. Create implementation plan:
   just draft jarvis-phase-1 plan
   Write via MCP
   Promote to Homelab/Projects/jarvis/plans/

8. As project progresses, update index via mcp__obsidian__patch_note
```

### Example: Query Project Status

```
Use mcp__obsidian__read_note:
  path: "Homelab/Projects/jarvis/index.md"

Use mcp__obsidian__search_notes:
  query: "jarvis"
  searchContent: true
  limit: 10
```

## Project Lifecycle

**Planning:**
- Create project index with status: "planning"
- Draft architecture
- Document key decisions (ADRs)
- Create implementation plan

**Development:**
- Update status to "active"
- Create runbooks as features complete
- Update index with progress (check off goals)
- Add new decisions as needed

**Deployed:**
- Mark goals complete
- Ensure all runbooks exist (deploy, troubleshoot, maintain)
- Update status to "deployed"

**Archived:**
- Move to Archive/ or mark status: "archived"
- Add final retrospective section to index
- Link to successor projects if any

## Tips

- **Always sync first** - `just sync` before any work
- **Use MCP for all edits** - Don't manually edit files
- **Link everything** - Use `[[wikilinks]]` to connect docs
- **Number decisions** - ADR 001, 002, etc. for easy reference
- **Keep index updated** - Project index is single source of truth for status
- **Archive when done** - Mark projects as archived, don't delete

## Integration

Works with:
- `mcp__obsidian__*` tools for vault operations
- `just` commands for vault management
- `document-to-vault` skill for creating individual docs
- Git workflow for version control

## Troubleshooting

**Can't find project:**
```
Use mcp__obsidian__search_notes:
  query: "<project-name>"
```

**Need to restructure project:**
Use `mcp__obsidian__move_note` to relocate files, update wikilinks manually

**Vault out of sync:**
```bash
cd ~/Documents/knowledge-vault
just sync
```
