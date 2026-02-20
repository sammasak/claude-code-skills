---
name: clean-code-principles
description: "Use when writing code, reviewing PRs, refactoring, or making architectural decisions. Enforces readability, testability, and maintainability standards across all languages."
user-invocable: false
allowed-tools: Bash, Read, Grep, Glob
---

# Clean Code Principles

Code is read far more often than it is written. Optimize for the reader.
Review AI-generated code with the same rigor as human code — verify naming, test coverage, and absence of dead code.

## Principles

| Principle | Rule of Thumb |
|---|---|
| Readability > cleverness | If a junior dev can't follow it in 30 seconds, simplify it |
| Functions do one thing | Single Responsibility at the function level — one reason to change |
| Names reveal intent | If you need a comment to explain a name, rename it |
| Tests are executable documentation | A test suite should teach a new dev how the system behaves |
| Smallest possible public API | Expose only what consumers need; everything else is private |
| Composition over inheritance | Compose behaviors from small pieces; don't build deep hierarchies |
| Make illegal states unrepresentable | Use the type system to prevent invalid data from existing |

## Standards

### Size and Shape
- [ ] Functions short enough to serve a single purpose — typically under 20-30 lines. Avoid extracting every block into its own function; each extraction should reduce cognitive load, not add indirection.
- [ ] Max 3 parameters — group into a struct/dataclass if more
- [ ] Avoid boolean parameters on public APIs when the call site becomes ambiguous. Prefer enums (`DryRun::Yes`) or separate functions (`deploy()` / `deploy_dry_run()`).
- [ ] Early returns over nested ifs — reduce indentation depth to 2 levels max

### Dependencies and State
- [ ] Dependency injection over global state — accept deps as params
- [ ] No magic numbers — use named constants with units where applicable
- [ ] Errors must be actionable: `"failed to connect to DB at {host}:{port}"` not `"connection error"`

### API Design
- [ ] Every public function needs a test
- [ ] Default to private; promote to public only when required
- [ ] Accept interfaces/traits, return concrete types

## Testing Standards

### Naming and Structure
- Test names describe **behavior**, not implementation: `test_expired_token_returns_401` not `test_validate`
- One behavior per test — multiple assertions verifying facets of the same behavior are fine.
- Follow **Arrange-Act-Assert** in every test

### Coverage Strategy
- [ ] Test edge cases and error paths, not just the happy path
- [ ] Test the public API, not internals — never test private methods
- [ ] Place mocks at system boundaries only (DB, HTTP, filesystem)
- [ ] Every test runs fast (<1s) or it will not be run

### Test Quality Check
Ask: "If the implementation changes but the behavior stays the same, does this test break?"
If yes, the test is coupled to implementation. Rewrite it.

## Patterns We Use

| Tool | Purpose |
|---|---|
| Strict linters | Enable strict linting in every language and treat warnings as errors in CI (e.g., `clippy`, `ruff`, `ESLint`, `golangci-lint`) |
| `just` | Universal task runner across all repos (`just check`, `just test`, `just fmt`) |
| Pre-commit hooks | Safety net: format, lint, type-check, test — runs before every commit |
| Multi-stage Docker builds | Minimal deployable artifacts — build deps separate from app code |
| Small PRs | Reviewable in under 10 minutes — split larger work into stacked PRs |

## Anti-Patterns

| Do Not | Why |
|---|---|
| Comments that restate the code | Stale comments are worse than no comments. The code is the source of truth. **Do** comment the "why" behind non-obvious decisions, workarounds for external bugs, and algorithmic complexity notes. |
| Dead code left "just in case" | Version control remembers. Delete it. Resurrection is one `git log` away. |
| Refactoring without a reason | Don't refactor working code without a concrete driver (bug, new requirement, measurable complexity). |
| Premature abstraction | Wait for 3 concrete cases before abstracting. Duplication is cheaper than the wrong abstraction. |
| God objects/functions (>100 lines) | Split it. If you can't name what it does in 5 words, it does too much. |
| Stringly-typed APIs | Use enums and newtypes. The compiler cannot check strings. |
| Silencing linter warnings without explanation | Every suppression directive needs a comment explaining **why**. No exceptions. |

## References

- "A Philosophy of Software Design" — Ousterhout (best single book on managing complexity)
- "Refactoring" — Fowler (the catalog of safe transformations)
- "Tidy First?" — Kent Beck (2023) (incremental tidyings before behavioral changes)
- Google Engineering Practices — https://google.github.io/eng-practices/review/
- "Clean Code" — Martin (chapters 1-6; note the Ousterhout-Martin debate on function length — approach prescriptive line-count advice skeptically)
- The Zen of Python (PEP 20) — applicable beyond Python: explicit > implicit, simple > complex
