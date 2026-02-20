# Review: nix-flake-development + nix-explorer

**Reviewer:** Claude Opus 4.6
**Date:** 2026-02-18
**Files reviewed:**
- `/home/lukas/claude-code-skills/skills/nix-flake-development/SKILL.md`
- `/home/lukas/claude-code-skills/agents/nix-explorer.md`

## Score: 7/10

Both files are well-structured and demonstrate solid Nix knowledge. The skill file covers the core workflow competently, and the agent file provides clear, focused instructions. However, there are several areas where the content is outdated or incomplete relative to the state of the Nix ecosystem in early 2026.

---

## Findings

### Accurate

- **Module option patterns are correct.** The `mkEnableOption`, `mkOption`, `mkIf`, `mkMerge`, `mkDefault`, `mkForce` usage and priority values (1000 for `mkDefault`, 50 for `mkForce`) are accurate.
- **Overlay patterns are correct.** Using `final`/`prev` naming (rather than the older `self`/`super`) is the current convention. The advice to apply overlays via `nixpkgs.overlays` rather than inline is sound.
- **Input hygiene table is excellent.** The advice on `follows`, committing `flake.lock`, pinning inputs, and updating one input at a time is all current best practice.
- **Anti-patterns table is solid.** Every "Don't / Do Instead" entry is accurate: discouraging `nix-env -iA`, unpinned inputs, monolithic configs, IFD, manual `/etc` edits, overuse of `mkForce`, and disabling the firewall.
- **Secrets management mention is appropriate.** Listing both SOPS and agenix as options, with the principle of never storing plaintext in the Nix store, is correct.
- **Home Manager as NixOS module pattern is correct.** Importing via `home-manager.nixosModules.home-manager` and sharing the system `nixpkgs` instance is the standard approach for the NixOS module integration path.
- **`nix flake update --commit-lock-file` syntax is correct.** This flag is valid and current.
- **The rebuild cycle workflow (check, build, test, switch) is a sound practice** and the ordering is appropriate for safe deployments.
- **Agent file: exploration methodology is well-structured.** The four-step process (start with flake, trace module graph, identify patterns, explain clearly) is a logical and effective approach for exploring NixOS configurations.
- **Agent file: the instruction to "read files before making claims"** is critical and well-placed.

### Issues

#### 1. Missing mention of `nixos-rebuild-ng` (Skill, line 95-97)

**Currently says:** Uses `nixos-rebuild build`, `nixos-rebuild test`, `nixos-rebuild switch` without qualification.

**Issue:** As of NixOS 25.11, `nixos-rebuild-ng` (a Python rewrite of the original Bash-based `nixos-rebuild`) is enabled by default via `system.rebuild.enableNg`. The old Bash version is expected to be fully removed in NixOS 26.05. While the command name remains `nixos-rebuild`, users should be aware that the underlying implementation has changed, that a `--debug` flag is now available for troubleshooting, and that `--ask-sudo-password` is now supported for remote sudo operations.

**Recommendation:** Add a brief note in the Workflow section acknowledging `nixos-rebuild-ng` as the new default and its key improvements (better error messages, `--debug` flag).

**Source:** [NixOS 25.11 Release Notes](https://nixos.org/manual/nixos/stable/release-notes), [nixos-rebuild-ng announcement](https://discourse.nixos.org/t/nixos-rebuild-ng-a-nixos-rebuild-rewrite/55606)

#### 2. No mention of `flake-parts` framework (Skill, entire file)

**Currently says:** The flake.nix example uses a raw/manual flake structure.

**Issue:** `flake-parts` (from Hercules CI) has become the de facto standard framework for writing modular flakes. It leverages the NixOS module system for flake configuration, provides the `perSystem` abstraction to avoid manual system iteration, and has a growing ecosystem of composable modules. A February 2026 community comparison concluded that `flake-parts` is the recommended choice for any project that plans to create reusable flake modules. The "every file is a flake-parts module" pattern is gaining significant traction.

**Recommendation:** Add a subsection under "Patterns We Use" or "Standards" mentioning `flake-parts` as the recommended flake framework for larger configurations, with a brief example of the `perSystem` pattern. At minimum, note its existence in the references.

**Source:** [flake.parts](https://flake.parts/), [Flake Parts - Official NixOS Wiki](https://wiki.nixos.org/wiki/Flake_Parts), [flake-parts vs flake-utils comparison (Feb 2026)](https://www.mccurdyc.dev/posts/2026/02/nix-flake-parts-flake-utils-or-neither/index.html)

#### 3. No mention of `devShells` or `nix develop` (Skill, entire file)

**Currently says:** The skill focuses on NixOS system configuration only.

**Issue:** Development shells (`devShells` output + `nix develop` + direnv integration) are one of the most common flake use cases. The skill's description says "working with Nix flakes" broadly, but development environments are not covered at all. This is a significant gap given how central `nix develop` and `nix-direnv` are to modern Nix workflows.

**Recommendation:** Add a brief "Development Shells" section covering the `devShells` output attribute, `pkgs.mkShell`, and direnv integration with `use flake`.

#### 4. Missing `mkPackageOption` from the Key `lib` Functions table (Skill, lines 68-74)

**Currently says:** Lists `mkIf`, `mkMerge`, `mkDefault`, `mkForce`, `mkEnableOption`.

**Issue:** `mkPackageOption` is now a standard part of module authoring best practice. It creates a `package` option with correct `defaultText`, `literalExpression`, and type handling. Current NixOS module convention is to use the trio: `mkEnableOption` for the enable toggle, `mkPackageOption` for the package, and `mkOption` for everything else.

**Recommendation:** Add `mkPackageOption` to the table with usage: "Declare a package option with proper defaults and documentation".

**Source:** [lib.options reference](https://ryantm.github.io/nixpkgs/functions/library/options/)

#### 5. `lib.mdDoc` not mentioned as removed (Skill, entire file)

**Currently says:** Nothing about `lib.mdDoc`.

**Issue:** While the skill does not explicitly use `lib.mdDoc`, it would be valuable to note in the anti-patterns or module patterns section that `lib.mdDoc` was removed in NixOS 24.11. Option descriptions are now Markdown by default. This is a common gotcha for anyone reading older Nix code or tutorials. Since the skill's module examples use plain strings for descriptions (which is correct), a brief note would help users who encounter `lib.mdDoc` in existing codebases.

**Recommendation:** Add a note to the anti-patterns table: "Don't use `lib.mdDoc` in option descriptions (removed in 24.11; Markdown is now the default)."

**Source:** [NixOS/nixpkgs#300735 - Remove all uses of lib.mdDoc](https://github.com/NixOS/nixpkgs/issues/300735)

#### 6. Garbage collection commands use only legacy CLI (Skill, lines 110-112)

**Currently says:** `nix-collect-garbage --delete-older-than 14d` and `nix-collect-garbage -d`.

**Issue:** While these legacy commands still work, the skill does not mention the nix3 equivalent `nix store gc`. The skill uses `nix flake check` (a nix3 command) in the rebuild cycle but only legacy commands for GC, which is inconsistent. Users should be aware of both, and that `nix store gc` is the forward-looking replacement (though it does not handle generation deletion the way `nix-collect-garbage -d` does).

**Recommendation:** Add a brief note showing `nix store gc` alongside the legacy commands, noting that `nix-collect-garbage -d` remains convenient as a higher-level wrapper that also deletes old generations.

**Source:** [NixOS Discourse: GC command comparison](https://discourse.nixos.org/t/difference-between-nix-collect-garbage-vs-nix-store-gc-vs-nix-store-gc-vs-nix-env-delete-generations-vs-nix-heuristic-gc/69374)

#### 7. Agent file uses `model: haiku` without comment on capability tradeoffs (Agent, line 6)

**Currently says:** `model: haiku`

**Issue:** Using `haiku` as the model for a Nix code explorer agent is a reasonable cost optimization, but Nix code can be quite complex (lazy evaluation, recursive attribute sets, overlays, module system merge semantics). The agent's instructions ask it to trace module graphs, understand priority overrides, and explain option chains -- tasks that may push the limits of a smaller model. This is not strictly wrong, but worth noting.

**Recommendation:** Consider whether `sonnet` would be more appropriate given the complexity of Nix module analysis, or add a comment noting the tradeoff. At minimum, this is a conscious choice that should be documented.

#### 8. No mention of flakes/nix-command still being experimental (Skill, entire file)

**Currently says:** Treats flakes as the standard without qualification.

**Issue:** As of Nix 2.28.6 (the current stable version), flakes and the `nix` CLI commands remain officially experimental and require `experimental-features = nix-command flakes` in the Nix configuration. While flakes are de facto standard in the community and widely used, this experimental status is relevant context, especially for new users who may encounter errors if the features are not enabled.

**Recommendation:** Add a brief note in the Principles or Standards section that flakes require `experimental-features = nix-command flakes` in `nix.conf` (or the equivalent NixOS option `nix.settings.experimental-features`).

**Source:** [NixOS Wiki: Flakes](https://nixos.wiki/wiki/Flakes), [Nix Reference Manual](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html)

#### 9. NixOS version in flake.nix example may cause confusion (Skill, line 26)

**Currently says:** `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";`

**Issue:** The example uses `nixos-unstable` which is fine and common for flake-based setups, but the "Input Hygiene" table immediately below says "Pin `nixpkgs` to a release branch or commit." Using `nixos-unstable` in the example directly contradicts the first hygiene rule. The current stable release branch is `nixos-25.11`. Either the example should use a stable branch to match the advice, or the hygiene rule should clarify that `nixos-unstable` is an acceptable choice for flake setups (since the lock file provides the actual pinning).

**Recommendation:** Either change the example to `nixos-25.11` to match the hygiene advice, or update the hygiene rule to say "Pin `nixpkgs` to a release branch, `nixos-unstable`, or a specific commit" and add a note explaining that `flake.lock` provides the actual reproducibility guarantee regardless of branch choice.

### Missing

#### 1. No coverage of the Nix ecosystem fragmentation

The Nix ecosystem has experienced significant fragmentation since 2024. There are now multiple Nix implementations: upstream Nix, Determinate Nix (from Determinate Systems), Lix (community fork), Tvix, and Snix. Determinate Systems' installer no longer offers upstream Nix as of November 2025. A brief acknowledgment of this landscape would help users understand the context and make informed choices about which Nix implementation to use.

#### 2. No `nix-direnv` or direnv integration

For flake-based development workflows, `nix-direnv` with `use flake` in `.envrc` is the standard ergonomic pattern. This is one of the most impactful day-to-day Nix tools and is completely absent.

#### 3. No mention of Numtide Blueprint

Blueprint (`github:numtide/blueprint`) is an opinionated flake structuring tool that maps a standard folder structure to flake outputs. It is gaining traction as a simpler alternative to `flake-parts` for projects that benefit from convention-over-configuration. Worth mentioning alongside `flake-parts`.

#### 4. No testing patterns

The skill mentions `nix flake check` but does not cover NixOS testing patterns like `nixosTest` / `testing-python` for integration tests, or how to add custom checks to the `checks` flake output.

#### 5. No deploy tooling mention

Remote deployment is shown using `nixos-rebuild --target-host`, but there is no mention of popular deployment tools like `colmena`, `deploy-rs`, or `nixos-anywhere`, which are commonly used in multi-host setups.

#### 6. Agent file does not mention Lix or Determinate Nix

The agent may encounter configurations using Lix or Determinate Nix. A note about being aware of these variants and their minor differences from upstream would be helpful.

---

## References Check

| # | Reference | Status | Notes |
|---|-----------|--------|-------|
| 1 | [NixOS Manual](https://nixos.org/manual/nixos/stable/) | **Valid** | Currently serving NixOS 25.11 manual. Active and current. |
| 2 | [nix.dev](https://nix.dev/) | **Valid** | Active. Curated tutorials and best practices, actively maintained. |
| 3 | [Nix Pills](https://nixos.org/guides/nix-pills/) | **Valid but dated** | The page is live, but content dates from 2014-2015 (ported 2017). Does not cover flakes or the new CLI. Still valuable for fundamentals but should carry a caveat that it uses legacy commands. |
| 4 | [zero-to-nix.com](https://zero-to-nix.com/) | **Valid** | Live, maintained by Determinate Systems. Note: Determinate Systems has become controversial in the Nix community (see ecosystem fragmentation above). The content remains useful but is opinionated toward the Determinate Nix ecosystem. |
| 5 | [mcp-nixos](https://github.com/utensils/mcp-nixos) | **Valid** | Actively maintained (v1.0.3+, last updated ~October 2025). 358 stars. Provides NixOS/Home Manager/nix-darwin option lookup via MCP. |
| 6 | [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) | **Valid** | Very actively maintained with daily automated updates. 635+ stars. Provides Nix packages for AI coding tools including claude-code. |

### Suggested Additional References

- [flake.parts](https://flake.parts/) -- flake-parts framework documentation
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) -- unofficial but comprehensive beginner-friendly flake guide
- [Official NixOS Wiki](https://wiki.nixos.org/) -- the new official wiki (replacing the community wiki at nixos.wiki)
- [Comparison of secret managing schemes](https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes) -- for the secrets management section
- [nix-community/home-manager](https://github.com/nix-community/home-manager) -- direct link to Home Manager repo

---

## Recommendations

### High Priority

1. **Add a note about flakes being experimental.** Include the required `experimental-features = nix-command flakes` configuration. This is a common stumbling block.

2. **Add `flake-parts` coverage.** At minimum, mention it in references. Ideally, add a brief section showing the `perSystem` pattern and explaining when to use it vs. raw flake outputs.

3. **Fix the `nixos-unstable` vs. input hygiene contradiction.** Either align the example with the advice or clarify the advice to explain that `nixos-unstable` + `flake.lock` is acceptable.

4. **Add `mkPackageOption` to the lib functions table.** It is now a standard part of the module authoring trio.

### Medium Priority

5. **Add `devShells` / `nix develop` / direnv section.** This is one of the most common flake use cases and the skill claims broad flake coverage.

6. **Mention `nixos-rebuild-ng`.** Note that it is the default in NixOS 25.11+ and the old Bash version will be removed in 26.05.

7. **Add `lib.mdDoc` removal to anti-patterns.** This catches users migrating or reading older code.

8. **Show `nix store gc` alongside legacy GC commands** for consistency with the nix3 commands used elsewhere.

### Low Priority

9. **Consider upgrading the agent model from `haiku` to `sonnet`** for better handling of complex Nix module tracing tasks, or document the rationale for using `haiku`.

10. **Add references to the NixOS & Flakes Book and the official NixOS Wiki** as supplementary learning resources.

11. **Add a note about the Nix Pills reference being pre-flakes** so users know to supplement with modern resources.

12. **Consider mentioning deploy tools** (colmena, deploy-rs, nixos-anywhere) in the remote deploy section for multi-host scenarios.

### Frontmatter Format Check

| File | Field | Status |
|------|-------|--------|
| SKILL.md | `name` | Valid (`nix-flake-development`) |
| SKILL.md | `description` | Valid, clear trigger description within 1024 chars |
| SKILL.md | `allowed-tools` | Valid (`Bash Read Grep Glob`) -- appropriate for a read-heavy exploration skill, though `Write` and `Edit` are notably absent if the skill is also meant to guide creating/editing Nix code |
| Agent | `name` | Valid (`nix-explorer`) |
| Agent | `description` | Valid, clear multi-line description |
| Agent | `model` | Valid (`haiku` is a recognized alias) |
| Agent | `tools` | Valid (`Read, Glob, Grep` -- appropriate for read-only exploration) |

**Note on SKILL.md `allowed-tools`:** The skill description says "Guides declarative system management patterns and safe rebuild workflows," which implies the user might want to edit Nix files. But the `allowed-tools` list (`Bash Read Grep Glob`) does not include `Write` or `Edit`. If the skill is purely advisory (Claude reads code and advises the user), this is fine. If it is meant to help the user make changes, `Write` and `Edit` should be added. This should be a deliberate choice either way.
