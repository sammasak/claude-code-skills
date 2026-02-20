# Specificity Audit: nix-flake-development + nix-explorer

**Reviewer:** Claude Opus 4.6
**Date:** 2026-02-20
**Purpose:** Identify user-specific content that should be genericized for a universally distributable skill/agent.

**Files audited:**
- `/home/lukas/claude-code-skills/skills/nix-flake-development/SKILL.md`
- `/home/lukas/claude-code-skills/agents/nix-explorer.md`

---

## Findings

### Finding 1: `homelab.*` custom option namespace presented as a standard pattern

**File:** `skills/nix-flake-development/SKILL.md`
**Lines:** 52, 60, 129

**Exact text (line 52):**
```nix
options.homelab.services.myapp = {
```

**Exact text (line 60):**
```nix
config = lib.mkIf config.homelab.services.myapp.enable {
```

**Exact text (line 129):**
```
- **Custom option namespaces** — `homelab.*` for infra services, `profile.*` for user presets; avoids collision with upstream options
```

**Assessment:** User-specific. `homelab.*` and `profile.*` are clearly one person's naming convention for their personal NixOS configuration. These are not community-standard namespaces -- they are opinionated choices that reflect a specific user's infrastructure organization. The code example on lines 52/60 embeds `homelab.services.myapp` as if it were a universal pattern, when in reality most NixOS configurations use entirely different custom namespace names (or none at all).

**Suggested fix:**
- Lines 52/60: Change `homelab.services.myapp` to a generic placeholder like `myOrg.services.myapp` or simply `custom.services.myapp`, and add a comment like `# choose your own top-level namespace` to make it clear this is an example namespace, not a convention.
- Line 129: Rewrite to: `**Custom option namespaces** -- use a project-specific top-level namespace (e.g., `myOrg.*`, `infra.*`) for custom services and user presets; avoids collision with upstream `services.*`, `programs.*`, etc.` This removes the specific `homelab.*` and `profile.*` names while keeping the advice.

---

### Finding 2: `profile.*` namespace as a user-specific convention

**File:** `skills/nix-flake-development/SKILL.md`
**Line:** 129

**Exact text:**
```
`profile.*` for user presets
```

**Assessment:** User-specific. `profile.*` as a namespace for "user presets" is a personal organizational pattern. It is not a community convention. This is part of the same finding as Finding 1 (line 129) but worth calling out separately because `profile.*` is even more niche than `homelab.*` -- it implies a specific pattern where the user has defined "profile" modules that bundle preset configurations.

**Suggested fix:** Covered by the rewrite suggested in Finding 1, line 129.

---

### Finding 3: `hosts/<name>/` directory structure with `variables.nix` presented as a pattern

**File:** `skills/nix-flake-development/SKILL.md`
**Line:** 128

**Exact text:**
```
- **Role-based host composition** — each host imports from `hosts/<name>/` with a `variables.nix` for host-specific values
```

**Assessment:** Borderline. The `hosts/<name>/` directory structure is a common community pattern and is reasonable as an illustrative example. However, the specific convention of a `variables.nix` file within each host directory is not a widely-adopted community standard -- it is one user's approach to separating host-specific values from module logic. Some configurations use `hardware-configuration.nix` + `configuration.nix` per host, others use a flat attribute set in `flake.nix`, and others use entirely different structures.

**Suggested fix:** Rewrite to: `**Role-based host composition** -- organize per-host configs under a directory (e.g., `hosts/<name>/`) that imports shared role modules and defines host-specific values`. This keeps the useful advice without prescribing the `variables.nix` convention.

---

### Finding 4: `mkHost` helper presented as a shared pattern

**File:** `skills/nix-flake-development/SKILL.md`
**Lines:** 35, 130

**Exact text (line 35):**
```nix
nixosConfigurations.<hostname> = mkHost { ... };
```

**Exact text (line 130):**
```
- **`mkHost` helper** — wrapper in `flake.nix` wiring `nixpkgs`, overlays, Home Manager, and host modules into `lib.nixosSystem`
```

**Assessment:** Borderline / mildly user-specific. `mkHost` is not a standard Nix function -- it is a user-defined helper. Many NixOS configurations define similar wrappers, but the name varies (`mkHost`, `mkSystem`, `mkNixos`, `mkMachine`, or just inline calls to `lib.nixosSystem`). Presenting `mkHost` as a named pattern is reasonable as an example, but the way it appears in the flake.nix structure example (line 35) makes it look like a built-in function, which could confuse readers.

**Suggested fix:**
- Line 35: Change to `nixosConfigurations.<hostname> = lib.nixosSystem { ... };` (the actual built-in) or add a comment: `# mkHost is a local helper wrapping lib.nixosSystem`.
- Line 130: Add "(or similar wrapper)" after `mkHost helper` to clarify it is a user-defined convention, not a specific function name that must be used.

---

### Finding 5: `myapp` / `myservice` as placeholder names

**File:** `skills/nix-flake-development/SKILL.md`
**Lines:** 52-62, 80, 103-109

**Exact text (lines 52-62):**
```nix
options.homelab.services.myapp = {
  enable = lib.mkEnableOption "myapp service";
  ...
  description = "Listen port for myapp";
  ...
config = lib.mkIf config.homelab.services.myapp.enable {
  systemd.services.myapp = { ... };
};
```

**Exact text (line 80):**
```nix
myapp = final.callPackage ./pkgs/myapp { };
```

**Exact text (lines 103-104):**
```nix
checks.x86_64-linux.myservice = nixosTest {
  nodes.machine = { ... }: { services.myservice.enable = true; };
```

**Assessment:** These are reasonable generic placeholders. `myapp` and `myservice` are standard placeholder names in documentation and tutorials. They do not appear to be find-replace artifacts from a real project name. No change needed.

**Verdict:** Acceptable as-is.

---

### Finding 6: `myproject.*` in the agent file

**File:** `agents/nix-explorer.md`
**Line:** 22

**Exact text:**
```
- Custom option namespaces (e.g., `myproject.*`, `homelab.*`)
```

**Assessment:** Mixed. `myproject.*` is a fine generic placeholder. However, `homelab.*` appearing again here reinforces it as a specific convention rather than just an example. This cross-reference between the agent and skill file creates the impression that `homelab.*` is the standard namespace.

**Suggested fix:** Change to: `Custom option namespaces (e.g., `myproject.*`, `infra.*`)` -- replacing `homelab.*` with another generic example that does not tie back to a specific user's configuration.

---

### Finding 7: "Patterns We Use" section heading

**File:** `skills/nix-flake-development/SKILL.md`
**Line:** 124

**Exact text:**
```
## Patterns We Use
```

**Assessment:** Mildly user-specific in tone. The phrase "We Use" implies these are the author's personal patterns rather than recommended community patterns. For a generic skill meant to be distributed, this heading makes the content sound like documentation of one person's (or one team's) setup rather than general best practice.

**Suggested fix:** Change to `## Recommended Patterns` or `## Common Patterns`. This preserves the section's purpose while framing it as general guidance rather than personal practice.

---

### Finding 8: SOPS/agenix presented without alternatives

**File:** `skills/nix-flake-development/SKILL.md`
**Line:** 132

**Exact text:**
```
- **SOPS / agenix for secrets** — encrypted in-repo, decrypted at activation time; never store plaintext secrets in the Nix store
```

**Assessment:** Reasonable but slightly opinionated. SOPS and agenix are indeed the two most popular secret management approaches in NixOS. However, presenting them as the only two options ("SOPS / agenix for secrets") without mentioning alternatives like `sops-nix` (the actual NixOS module, distinct from the SOPS CLI), `ragenix`, or vault-based approaches makes this feel like a personal tooling choice. That said, these two genuinely dominate the ecosystem, so this is a borderline case.

**Verdict:** Acceptable as-is, but could benefit from a parenthetical "(most common options)" to frame them as representative rather than exhaustive.

---

## Summary Table

| # | Location | Text/Pattern | Severity | Verdict |
|---|----------|-------------|----------|---------|
| 1 | SKILL.md L52,60,129 | `homelab.*` namespace | **High** | User-specific convention; genericize |
| 2 | SKILL.md L129 | `profile.*` namespace | **High** | User-specific convention; genericize |
| 3 | SKILL.md L128 | `variables.nix` per-host convention | Medium | Overly specific structure; soften |
| 4 | SKILL.md L35,130 | `mkHost` helper | Medium | User-defined function presented as standard; clarify |
| 5 | SKILL.md L52-62,80,103-109 | `myapp`/`myservice` placeholders | None | Acceptable generic placeholders |
| 6 | Agent L22 | `homelab.*` in examples | **High** | Cross-references user-specific namespace; genericize |
| 7 | SKILL.md L124 | "Patterns We Use" heading | Low | Personal tone; rename to "Recommended Patterns" |
| 8 | SKILL.md L132 | SOPS/agenix as the secret tools | Low | Acceptable but slightly opinionated |

---

## Recommended Actions

### Must fix (user-specific content leaking into generic skill)

1. **Replace all `homelab.*` references** across both files with a clearly generic namespace. Use something like `custom.*` or show multiple examples to make it clear the namespace is the user's choice.

2. **Remove `profile.*`** as a named convention. Either drop it or replace with a second generic example.

3. **Replace `homelab.*` in the agent file** (line 22) with a different generic example like `infra.*`.

### Should fix (overly opinionated but not user-identifying)

4. **Soften the `variables.nix` convention** to be presented as one approach among several.

5. **Clarify `mkHost` is user-defined**, not a built-in, especially in the flake.nix structure example.

6. **Rename "Patterns We Use"** to "Recommended Patterns" or "Common Patterns".

### Optional (minor tone/framing)

7. **Add "(most common options)" or similar qualifier** to the SOPS/agenix bullet.
