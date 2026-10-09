# Clean Code Principles -- Specificity Audit

**File:** `skills/clean-code-principles/SKILL.md`
**Date:** 2026-02-20
**Auditor:** Claude Opus 4.6

## Summary

The skill is largely language-agnostic and contains well-grounded, universal clean-code advice. However, a handful of items embed personal tooling preferences or opinionated conventions that would feel foreign to someone outside this particular workflow. Each finding is listed below.

---

## Findings

### 1. `just` as the universal task runner (Line 65)

**Exact text:**
```
| `just` | Universal task runner across all repos (`just check`, `just test`, `just fmt`) |
```

**Issue:** `just` is a niche tool. Calling it "universal" implies every project must use it. A genuinely language-agnostic skill should remain tool-neutral here; `make`, `task`, `mise`, `nx`, and language-native runners (`cargo`, `npm run`, `pnpm`, `go` subcommands) are equally valid.

**Category:** User-specific tooling preference.

**Suggested fix:** Generalize to the principle, not the tool:
```
| Task runner | Define a single `check` / `test` / `fmt` entry point so every repo is invoked the same way (e.g., `make`, `just`, `task`, `npm run`, or a language-native runner) |
```

---

### 2. Rust-flavored examples in a language-agnostic skill (Lines 30, 79)

**Line 30 -- exact text:**
```
Prefer enums (`DryRun::Yes`) or separate functions (`deploy()` / `deploy_dry_run()`).
```

**Line 79 -- exact text:**
```
| Stringly-typed APIs | Use enums and newtypes. The compiler cannot check strings. |
```

**Issue:** `DryRun::Yes` is Rust enum syntax. "Newtypes" is Rust/Haskell jargon. These are not wrong, but they skew the document toward a Rust mental model. For a language-agnostic skill, examples should either be pseudo-code or include multi-language illustrations.

**Category:** Mildly opinionated (reasonable content, biased presentation).

**Suggested fix for line 30:**
```
Prefer enums (e.g., `DryRun.YES` / `DryRun::Yes`) or separate functions (`deploy()` / `deploy_dry_run()`).
```

**Suggested fix for line 79:**
```
| Stringly-typed APIs | Use enums and wrapper types (newtypes, branded types, value objects). The compiler/type-checker cannot validate bare strings. |
```

---

### 3. Section title "Patterns We Use" (Line 60)

**Exact text:**
```
## Patterns We Use
```

**Issue:** "We Use" makes this a team-specific policy document rather than a transferable skill. Skills in this suite should read as expert guidance that any project can adopt, not as "here is what our team does."

**Category:** User-specific framing.

**Suggested fix:**
```
## Recommended Tooling Patterns
```

---

### 4. Multi-stage Docker builds in a clean-code skill (Line 67)

**Exact text:**
```
| Multi-stage Docker builds | Minimal deployable artifacts -- build deps separate from app code |
```

**Issue:** Docker build strategy is an infrastructure/container concern, not a clean-code principle. It also presumes every project ships containers. This belongs in the `container-workflows` skill, not here.

**Category:** Scope creep / user-specific workflow assumption.

**Suggested fix:** Remove the row entirely or replace it with a genuinely code-level principle such as:
```
| Dependency isolation | Separate build-time deps from runtime deps; keep the deployable artifact minimal |
```

---

### 5. Specific linter list (Line 64)

**Exact text:**
```
| Strict linters | Enable strict linting in every language and treat warnings as errors in CI (e.g., `clippy`, `ruff`, `ESLint`, `golangci-lint`) |
```

**Issue:** The linter names themselves are fine as examples, but the selection reveals the author's personal language stack (Rust, Python, JS/TS, Go). Missing are common equivalents for other ecosystems (e.g., `ktlint`, `SwiftLint`, `phpstan`, `cppcheck`). More importantly, `ruff` is a relatively new and opinionated choice over `flake8`/`pylint` -- including it signals a personal preference.

**Category:** Mildly user-specific (reasonable but reveals personal stack).

**Suggested fix:** Either trim to just the principle (no examples) or broaden:
```
| Strict linters | Enable the strictest practical lint profile for every language used and treat warnings as errors in CI |
```

---

### 6. Stacked PRs assumption (Line 68)

**Exact text:**
```
| Small PRs | Reviewable in under 10 minutes -- split larger work into stacked PRs |
```

**Issue:** "Stacked PRs" is a specific Git workflow pattern (associated with tools like `ghstack`, `spr`, Graphite). Many teams use feature branches, trunk-based development, or other strategies. The principle of small, reviewable changes is universal; prescribing "stacked PRs" as the mechanism is opinionated.

**Category:** User-specific workflow preference.

**Suggested fix:**
```
| Small PRs / CLs | Reviewable in under 10 minutes -- split larger work into incremental, independently mergeable changes |
```

---

### 7. "The Ousterhout-Martin debate" editorial aside (Line 88)

**Exact text:**
```
"Clean Code" -- Martin (chapters 1-6; note the Ousterhout-Martin debate on function length -- approach prescriptive line-count advice skeptically)
```

**Issue:** This is not user-specific, but it is an editorialized opinion embedded in a references section. It is actually a *good* note -- but it stands out as the only reference with a parenthetical caveat, which gives it the feel of a personal annotation rather than a neutral listing.

**Category:** Mildly opinionated (reasonable, but stylistically inconsistent).

**Suggested fix:** Keep it, but make the tone consistent with the other entries:
```
"Clean Code" -- Martin (chapters 1-6 especially; later chapters are more debated)
```

---

## Verdict

| Severity | Count |
|---|---|
| User-specific (should change) | 3 (findings 1, 3, 4) |
| Mildly opinionated (consider changing) | 4 (findings 2, 5, 6, 7) |

The core principles, standards, testing guidance, and anti-patterns sections are strong and genuinely universal. The issues cluster in the "Patterns We Use" table (lines 60-68), which reads more like a team playbook entry than a transferable skill. Generalizing that section would resolve the majority of the findings.
