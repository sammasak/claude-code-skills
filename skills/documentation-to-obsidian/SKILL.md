---
name: documentation-to-obsidian
description: Use when writing human-readable documentation that should be stored in the Obsidian knowledge vault
---

# Documentation to Obsidian

## When to Use This Skill

Use this skill when:
- Writing **human-readable documentation** (guides, tutorials, concepts, architecture docs)
- Creating **cross-project knowledge** (shared concepts like "SOPS encryption", "flake-parts patterns")
- Documenting **technologies** (deep dives into NixOS, Kubernetes, Rust, etc.)
- Adding **project documentation** (architecture overviews, API docs, runbooks)

**DO NOT use for:**
- CLAUDE.md files (those stay in project repos)
- Code comments (those stay in source files)
- Temporary notes or task lists

## Architecture

```
Obsidian Vault Structure:
~/Documents/knowledge-vault/
├── Projects/               # Project-specific docs
│   ├── nixos-config/
│   │   ├── index.md       # Project overview
│   │   ├── README.md      # Synced from repo
│   │   └── docs/          # Synced from repo
│   ├── homelab-gitops/
│   └── workstation-api/
├── Concepts/              # Cross-cutting knowledge
│   ├── flake-parts.md
│   ├── sops-secrets.md
│   ├── specialisations.md
│   └── workstation-fleet.md
├── Technologies/          # Tech stack deep dives
│   ├── NixOS/
│   ├── Kubernetes/
│   └── Rust/
└── Meta/                  # Vault management
    ├── templates/
    └── scripts/
```

## Using the Obsidian MCP Server

You have access to the `obsidian` MCP server with these tools:

### Reading Notes
```javascript
// Read a specific note
obsidian_read_note({
  path: "Concepts/flake-parts.md"
})

// List notes in a directory
obsidian_list({
  path: "Concepts"
})

// Search across all notes
obsidian_search({
  query: "SOPS encryption"
})
```

### Writing Notes
```javascript
// Create or update a note
obsidian_write_note({
  path: "Concepts/flake-parts.md",
  content: `---
type: concept
tags: [nix, flake-parts, architecture]
related: [module-registry, auto-discovery]
---

# Flake-Parts Architecture

## What It Is
...content...
`
})
```

## Documentation Workflow

### 1. Determine Location

**For cross-project concepts:**
- Location: `Concepts/concept-name.md`
- Example: `Concepts/sops-secrets.md`, `Concepts/specialisations.md`

**For project-specific docs:**
- Location: `Projects/{project-name}/docs/topic.md`
- Example: `Projects/nixos-config/docs/architecture/flake-parts.md`
- Note: These get synced back to repo via the sync script

**For technology deep dives:**
- Location: `Technologies/{tech}/topic.md`
- Example: `Technologies/NixOS/module-system.md`

### 2. Use Consistent Frontmatter

All documentation notes should have YAML frontmatter:

```yaml
---
type: [concept|guide|reference|architecture]
tags: [tag1, tag2, tag3]
related: [related-note-1, related-note-2]
technology: [NixOS|Kubernetes|Rust|Python]  # if applicable
project: [nixos-config|homelab-gitops]      # if applicable
---
```

### 3. Write Clear, Structured Content

Use this structure:

```markdown
# Title

## Overview
Brief description (1-2 paragraphs)

## How It Works
Technical details

## Examples
Concrete examples with code blocks

## Related Concepts
- [[concept-1]]
- [[concept-2]]

## References
- [External Link](https://...)
```

### 4. Use Wikilinks for Cross-References

```markdown
# SOPS Secrets Management

## Related
- [[flake-parts]] - Module discovery uses SOPS for secrets
- [[homelab-gitops]] - Kubernetes secrets via SOPS
- See also: [[Technologies/NixOS/module-system]]
```

## Examples

### Example 1: Writing a Cross-Project Concept

**User asks:** "Document how the specialisation pattern works"

**Your response:**
```
I'll create a concept note for the specialisation pattern in Obsidian.

<uses obsidian_write_note>
path: Concepts/specialisations.md
content: |
  ---
  type: concept
  tags: [nixos, specialisation, desktop, architecture]
  related: [flake-parts, module-registry]
  project: nixos-config
  ---

  # NixOS Specialisations Pattern

  ## Overview
  All hosts boot into **server mode** by default (optimized headless environment with full CLI tooling).

  Hosts with compatible GPUs (Intel iGPU) have a **desktop specialisation** - an optional boot menu entry that adds Hyprland, SDDM, and GUI applications.

  ## How It Works
  ...
```

### Example 2: Adding Project Documentation

**User asks:** "Document the workstation fleet architecture"

**Your response:**
```
This is project-specific documentation that spans multiple repos. I'll create it in the Projects section.

<uses obsidian_write_note>
path: Projects/homelab-gitops/docs/workstation-fleet-architecture.md
content: |
  ---
  type: architecture
  tags: [kubevirt, workstation, fleet]
  related: [workspace-claim-crd]
  ---

  # Workstation Fleet Architecture

  End-to-end flow:
  1. nixos-config builds qcow2 image
  2. Published as OCI containerDisk to Harbor
  3. KubeVirt imports as DataVolume
  4. WorkspaceClaim CRD provisions VMs
  ...
```

## Best Practices

1. **One Concept Per Note**: Keep notes focused on a single topic
2. **Use Wikilinks Liberally**: Connect related concepts
3. **Add Metadata**: Use frontmatter for tags and relationships
4. **Write for Humans**: This is human-readable docs, not AI instructions
5. **Update, Don't Duplicate**: Search first, update existing notes rather than creating duplicates
6. **Sync Regularly**: Project docs should be synced back to repos

## Checklist

Before writing documentation:
- [ ] Determine if this is a concept, project doc, or tech deep dive
- [ ] Choose appropriate location in vault structure
- [ ] Search for existing notes on this topic
- [ ] Add proper YAML frontmatter
- [ ] Use wikilinks to connect related concepts
- [ ] Write clear, structured content
- [ ] For project docs: note that they need to be synced back to repo

## Common Mistakes to Avoid

❌ **Don't put CLAUDE.md content in Obsidian**
- CLAUDE.md stays in repos
- Obsidian = human-readable docs

❌ **Don't write code-level documentation**
- Code comments stay in source files
- Obsidian = high-level architecture, concepts, guides

❌ **Don't create isolated notes**
- Always link to related concepts
- Use frontmatter to establish relationships

❌ **Don't duplicate existing notes**
- Search first
- Update existing notes rather than creating new ones

## Integration with Project Repos

**Important**: Documentation written to `Projects/{name}/docs/` should be synced back to the actual repository.

**On dev machine after updating project docs:**
```bash
# Sync vault changes back to repos
cd ~/Documents/knowledge-vault
# Review what changed
git diff Projects/

# Copy changes back to repo
rsync -av Projects/nixos-config/docs/ ~/nixos-config/docs/

# Commit in both places
cd ~/nixos-config
git add docs/ && git commit -m "Update architecture docs"

cd ~/Documents/knowledge-vault
git add . && git commit -m "Sync nixos-config docs" && git push
```

**Future improvement**: This could be automated with a reverse-sync script.
