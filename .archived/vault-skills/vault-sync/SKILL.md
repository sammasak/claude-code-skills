# Vault Sync

Extract and migrate documentation from git repositories into the Obsidian knowledge vault with proper structure and frontmatter.

## Activation

```
/vault-sync <repo-path>
```

## Parameters

- `<repo-path>`: Absolute path to the git repository to scan (required)

## What This Skill Does

1. **Scans** the repository for Markdown documentation
2. **Analyzes** content to determine appropriate vault category
3. **Extracts** relevant documentation files
4. **Transforms** content to match vault conventions:
   - Adds proper YAML frontmatter
   - Converts relative links to Obsidian wiki-links where appropriate
   - Ensures PascalCase file naming
5. **Imports** notes into the correct vault location
6. **Reports** what was migrated and any skipped files

## Expected Input

A repository path that may contain:
- `README.md` (project overview)
- `docs/` directory (structured documentation)
- Inline `*.md` files (guides, references)
- Code comments or docstrings (optional advanced extraction)

## Output

- New notes in `~/Documents/knowledge-vault/` under appropriate categories
- Git commit in the vault with migration summary
- Summary report of imported notes

## Workflow

### 1. Repository Analysis

Scan the repository structure:
```bash
find <repo-path> -name "*.md" -type f
```

Categorize by location:
- `README.md` → Project note
- `docs/**/*.md` → Technology or Concept notes
- Root-level guides → Concept notes

### 2. Content Extraction

For each Markdown file:
1. Read content
2. Determine category based on:
   - File path (`docs/architecture/` → Concepts)
   - First heading (look for keywords: "project", "guide", "reference")
   - Repository name (match against known projects)
3. Infer tags from:
   - Repository topics (via `gh repo view --json repositoryTopics`)
   - File path segments
   - Content keywords

### 3. Note Transformation

Apply vault conventions:

**Frontmatter generation:**
```yaml
---
title: <extracted-from-first-heading-or-filename>
created: <current-date>
updated: <current-date>
tags:
  - <inferred-tags>
status: active
type: <project|concept|technology>
source: <repo-name>
source_path: <relative-path-in-repo>
---
```

**Link conversion:**
- Relative MD links `[text](./other.md)` → `[[OtherNote]]` if that note exists in vault
- External links remain unchanged
- Code block references remain unchanged

**Filename conversion:**
- `my-guide.md` → `MyGuide.md`
- `README.md` → `<RepoName>Overview.md` (for project READMEs)

### 4. Vault Placement

Place notes in appropriate directories:

| Source Pattern | Vault Location | Type |
|----------------|----------------|------|
| `README.md` (root) | `Projects/Active/<repo-name>.md` | `project` |
| `docs/architecture/*.md` | `Concepts/` | `concept` |
| `docs/guides/*.md` | `Concepts/` or `Technologies/` | `concept` or `technology` |
| `docs/api/*.md` | `Technologies/<lang>/` | `technology` |
| Language-specific (e.g., `rust-*.md`) | `Technologies/rust-engineering/` | `technology` |

### 5. Conflict Resolution

If a note with the same name exists:
1. Check if content is identical (skip if so)
2. If different, append `-<repo-name>` to filename
3. Log conflict in migration summary

### 6. Git Commit

After migration:
```bash
cd ~/Documents/knowledge-vault
git add .
git commit -m "docs: migrate documentation from <repo-name>"
git push origin main
```

## Example Usage

```
/vault-sync /home/lukas/code/homelab-gitops
```

Expected output:
```
Scanning /home/lukas/code/homelab-gitops...

Found 8 Markdown files:
  - README.md
  - docs/architecture/cluster-design.md
  - docs/guides/sealed-secrets.md
  - docs/runbooks/cert-manager.md
  ...

Migrating:
  [1/8] README.md → Projects/Active/HomelabGitops.md
  [2/8] cluster-design.md → Concepts/ClusterDesign.md
  [3/8] sealed-secrets.md → Technologies/kubernetes-gitops/SealedSecrets.md
  ...

Skipped:
  - CONTRIBUTING.md (meta file, not knowledge content)

Summary:
  ✓ 7 notes imported
  ⊘ 1 file skipped
  ✓ Committed to vault git

Vault updated successfully!
```

## Edge Cases

- **Empty or invalid repo path**: Error with usage instructions
- **No Markdown files found**: Warn and exit gracefully
- **Binary or large files**: Skip files > 1MB or non-text files
- **Duplicate content**: Skip if identical, rename if different
- **Broken links in source**: Preserve as-is, note in report

## Implementation Steps

1. **Validate input**: Check repo path exists and is a git repo
2. **Discover files**: Use `find` or `fd` to locate `*.md` files
3. **Classify each file**: Determine vault category and type
4. **Generate frontmatter**: Extract title, infer tags, set metadata
5. **Transform content**: Convert links if needed
6. **Write to vault**: Create files in correct locations
7. **Git commit**: Stage, commit, push
8. **Report results**: Summary of migrated notes

## Advanced Features (Optional)

- **Incremental sync**: Track migrated files in `.vault-sync-state.json` to avoid re-importing
- **Link graph preservation**: Build map of cross-references and convert to wiki-links
- **Code extraction**: Pull docstrings from Python/Rust files
- **Auto-tagging**: Use LLM to suggest tags based on content

## Notes for Implementation

- Use `Read` tool for file contents
- Use `Glob` for file discovery
- Use `Write` tool for creating vault notes
- Use `Bash` for git operations
- Preserve original file timestamps in frontmatter if possible (`git log --format=%aI --diff-filter=A -- <file>` for creation date)

## Error Handling

- Repository not found: "Error: Repository path does not exist: <path>"
- Not a git repo: "Error: Path is not a git repository: <path>"
- No Markdown files: "No Markdown files found in <repo>. Nothing to migrate."
- Write failures: "Error writing to vault: <file>. Check permissions."

## Success Criteria

- All relevant Markdown files extracted
- Frontmatter correctly generated
- Files placed in logical vault locations
- Git commit created with summary
- User receives clear migration report
