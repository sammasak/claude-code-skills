# Re-Review: nix-flake-development + nix-explorer (Round 2)

**Reviewer:** Claude Opus 4.6
**Date:** 2026-02-18
**Previous score:** 7/10
**New score:** 8/10

**Files reviewed:**
- `/home/lukas/claude-code-skills/skills/nix-flake-development/SKILL.md`
- `/home/lukas/claude-code-skills/agents/nix-explorer.md`

---

## Issue-by-Issue Assessment

### Issues (from original review)

#### 1. Missing mention of `nixos-rebuild-ng` -- FIXED

The skill now includes the line (line 98): `nixos-rebuild-ng is the default rebuild tool starting in NixOS 25.11+.`

This is accurate. However, the fix is minimal -- it does not mention the `--debug` flag, `--ask-sudo-password` for remote sudo, or the fact that the old Bash version is expected to be removed in 26.05. These were recommended in the original review. The note is sufficient but not thorough.

**Verdict:** Fixed (minimally).

#### 2. No mention of `flake-parts` framework -- FIXED

The skill now includes (line 117): `**flake-parts** -- recommended framework for modular flakes; use perSystem to abstract per-system boilerplate`

This is placed in the "Patterns We Use" section, which is appropriate. The `flake.parts` documentation link was also added to the References section (line 143). No code example of the `perSystem` pattern is provided, which was suggested but not required. This is a solid fix.

Additionally, the agent file (line 13) now references flake-parts: `Read flake.nix to understand inputs, outputs, and the module system in use (flake-parts, etc.)`

**Verdict:** Fixed.

#### 3. No mention of `devShells` or `nix develop` -- FIXED

The skill now includes (line 118): `**devShells / nix develop** -- declare project dev environments in the flake; keeps tooling reproducible and per-project`

This is a one-line mention in "Patterns We Use." The original review recommended a brief section covering the `devShells` output attribute, `pkgs.mkShell`, and direnv integration with `use flake`. The current fix is a bullet point rather than a section -- it does not mention `mkShell`, `nix-direnv`, or `.envrc` with `use flake`. Given the skill's broad claim of covering "Nix flakes" in its description, this remains thin for one of the most common flake use cases.

**Verdict:** Partially fixed. The concept is mentioned but lacks the practical details (mkShell, direnv) that would make it actionable.

#### 4. Missing `mkPackageOption` from the Key `lib` Functions table -- FIXED

The skill now includes (line 74): `| mkPackageOption | Declare a package option with proper defaults and type |`

This is accurate. `mkPackageOption` creates a typed package option with correct `defaultText`, `literalExpression`, and `type = lib.types.package` handling. The description is concise and correct.

**Verdict:** Fixed.

#### 5. `lib.mdDoc` not mentioned as removed -- FIXED

The skill now includes in the Anti-Patterns table (line 136): `| lib.mdDoc for option descriptions | Removed in 24.11 -- Markdown is now the default |`

This is accurate. `lib.mdDoc` was indeed deprecated and removed from nixpkgs as of 24.11. The phrasing is clear and actionable.

**Verdict:** Fixed.

#### 6. Garbage collection commands use only legacy CLI -- FIXED

The skill now includes (line 112): `nix store gc                                           # modern equivalent`

This is placed alongside the legacy `nix-collect-garbage --delete-older-than 14d` command. However, the comment "modern equivalent" is slightly misleading. `nix store gc` is **not** a full equivalent of `nix-collect-garbage -d` -- it does not delete old profile generations, only unreachable store paths. The original `nix-collect-garbage -d` deletes old generations first and then garbage collects, which frees significantly more space. Calling `nix store gc` a "modern equivalent" without this caveat could lead users to wonder why it frees less space.

The original review specifically recommended: "noting that `nix-collect-garbage -d` remains convenient as a higher-level wrapper that also deletes old generations." This nuance was not included.

**Verdict:** Partially fixed. The command is present but the comment is somewhat inaccurate. `nix store gc` is the modern GC command, not a direct equivalent of `nix-collect-garbage -d`.

#### 7. Agent file uses `model: haiku` without comment on capability tradeoffs -- NOT FIXED

The agent file still specifies `model: haiku` (line 5) with no comment or rationale. The original review noted this is not strictly wrong but suggested either upgrading to `sonnet` or documenting the tradeoff. No change was made.

**Verdict:** Not fixed (low priority, acknowledged as a conscious choice).

#### 8. No mention of flakes/nix-command still being experimental -- FIXED

The skill now includes (lines 21): `> **Note:** Flakes require experimental-features = nix-command flakes in nix.conf (on NixOS: nix.settings.experimental-features = [ "nix-command" "flakes" ]).`

This is accurate. As of Nix 2.33.1 (the latest version), flakes remain experimental and require explicit enablement. The note correctly shows both the `nix.conf` syntax and the NixOS module syntax. Good placement as a blockquote at the top of the Standards section.

**Verdict:** Fixed.

#### 9. NixOS version in flake.nix example contradicts input hygiene advice -- FIXED

The input hygiene table (line 44) now reads: `Pin nixpkgs to a release branch, nixos-unstable, or a specific commit -- flake.lock provides the actual reproducibility guarantee`

This resolves the contradiction. The example still uses `nixos-unstable` (line 28), which is now consistent with the updated hygiene rule. The added explanation that `flake.lock` provides the actual reproducibility guarantee is a good clarification.

**Verdict:** Fixed.

### Missing Items (from original review)

#### M1. No coverage of the Nix ecosystem fragmentation -- NOT ADDRESSED

No mention of Lix, Determinate Nix, Tvix, Snix, or the broader ecosystem fragmentation. This was categorized as informational in the original review.

**Verdict:** Not addressed (informational, not blocking).

#### M2. No `nix-direnv` or direnv integration -- NOT ADDRESSED

The `devShells` bullet point (line 118) does not mention direnv or `nix-direnv`. For a practical development workflow guide, the `.envrc` + `use flake` pattern is important.

**Verdict:** Not addressed (overlaps with Issue 3 partial fix).

#### M3. No mention of Numtide Blueprint -- NOT ADDRESSED

Blueprint is not mentioned. This is a lower-priority item; `flake-parts` coverage (which was added) is more important.

**Verdict:** Not addressed (low priority).

#### M4. No testing patterns -- NOT ADDRESSED

No mention of `nixosTest`, `testing-python`, or custom `checks` flake output. The skill mentions `nix flake check` but not how to write custom checks.

**Verdict:** Not addressed.

#### M5. No deploy tooling mention -- NOT ADDRESSED

No mention of `colmena`, `deploy-rs`, or `nixos-anywhere` for multi-host deployments.

**Verdict:** Not addressed (low priority).

#### M6. Agent file does not mention Lix or Determinate Nix -- NOT ADDRESSED

The agent file has no mention of alternative Nix implementations.

**Verdict:** Not addressed (low priority).

### Nix Pills reference caveat -- FIXED

The Nix Pills reference (line 142) now reads: `Nix Pills -- deep-dive into Nix fundamentals (uses pre-flake legacy commands)`

This parenthetical note correctly warns users that the content predates flakes. Good fix.

**Verdict:** Fixed.

---

## New Issues Introduced by the Fixes

### N1. `nix store gc` described as "modern equivalent" is inaccurate

As detailed under Issue 6 above, calling `nix store gc` a "modern equivalent" of `nix-collect-garbage` is misleading. They have different scopes: `nix-collect-garbage -d` removes old generations and then collects garbage, while `nix store gc` only removes unreachable store paths. A user who switches from `nix-collect-garbage -d` to `nix store gc` will find that old generations are retained and less disk space is freed.

**Recommendation:** Change the comment from `# modern equivalent` to `# nix3 GC (store paths only; does not remove old generations)`.

### N2. `devShells` bullet is too terse to be actionable

The one-line bullet `**devShells / nix develop** -- declare project dev environments in the flake; keeps tooling reproducible and per-project` does not tell the user *how* to do this. There is no mention of `pkgs.mkShell`, `packages` vs. `buildInputs`, `shellHook`, or the `devShells.<system>.default` output convention. A user reading this bullet would know the concept exists but not how to implement it.

**Recommendation:** Either expand into a 3-4 line subsection with a minimal `mkShell` example, or link to an external resource like the nix.dev development shell tutorial.

### N3. No new issues in the agent file

The agent file change (adding "flake-parts, etc." to step 1) is accurate and introduces no problems.

---

## Frontmatter Check (unchanged from R1)

| File | Field | Status |
|------|-------|--------|
| SKILL.md | `name` | Valid |
| SKILL.md | `description` | Valid |
| SKILL.md | `allowed-tools` | Valid (`Bash Read Grep Glob`) -- still no `Write`/`Edit`, acceptable if purely advisory |
| Agent | `name` | Valid |
| Agent | `description` | Valid |
| Agent | `model` | Valid (`haiku`) |
| Agent | `tools` | Valid (`Read, Glob, Grep`) |

---

## Summary

| Category | Count |
|----------|-------|
| Original issues fixed | 7 of 9 |
| Original issues partially fixed | 2 (Issues 3 and 6) |
| Original "missing" items addressed | 0 of 6 (these were informational) |
| New issues introduced | 2 (N1 inaccurate GC comment, N2 terse devShells) |

### What Improved

The skill file is meaningfully better. The most important fixes were:

1. **Experimental features note** (Issue 8) -- eliminates a major onboarding stumbling block.
2. **Input hygiene contradiction resolved** (Issue 9) -- the example and advice are now consistent.
3. **flake-parts mention** (Issue 2) -- acknowledges the dominant flake framework.
4. **mkPackageOption added** (Issue 4) -- completes the module authoring function table.
5. **lib.mdDoc anti-pattern** (Issue 5) -- catches a common migration gotcha.
6. **Nix Pills caveat** -- properly sets expectations for legacy content.

### What Still Needs Work

1. The `nix store gc` comment should be corrected to avoid implying feature parity with `nix-collect-garbage -d`.
2. The `devShells` coverage should be expanded from a single bullet into at least a minimal working example.
3. The agent model choice (`haiku`) should ideally have a rationale comment, though this is minor.

---

## Final Verdict

**Previous score: 7/10**
**New score: 8/10**

The fixes address the majority of the high-priority and medium-priority issues from the original review. The skill is now more accurate (experimental features note, input hygiene fix, lib.mdDoc anti-pattern), more complete (flake-parts, mkPackageOption, nixos-rebuild-ng), and better referenced (flake.parts link, Nix Pills caveat). The two partially-fixed items and two new minor issues prevent a score of 9. A score of 9 would require correcting the `nix store gc` comment and expanding the `devShells` coverage. A score of 10 would additionally require addressing testing patterns, direnv integration, and deploy tooling -- making the skill a comprehensive Nix flake reference rather than a solid but focused one.
