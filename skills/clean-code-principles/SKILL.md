---
name: clean-code-principles
description: "Use when writing code, reviewing PRs, refactoring, or making architectural decisions. Enforces readability, testability, and maintainability standards across all languages."
user-invocable: false
allowed-tools: Bash, Read, Grep, Glob
injectable: true
---

# Clean Code Principles

Optimize for the reader. Review AI code with the same rigor as human code.

## Principles

- **Readability > cleverness** -- simplify for the next developer.
- **Functions do one thing** -- single responsibility at the function level.
- **Names reveal intent** -- clear names reduce the need for comments.
- **Tests as documentation** -- suites should teach how the system behaves.
- **Smallest public API** -- expose only what is strictly necessary.
- **Illegal states unrepresentable** -- use the type system to prevent invalid data.

## Standards

- **Size**: Functions ~20-30 lines; max 3 parameters per function.
- **API**: Default to private; accept interfaces/traits, return concrete types.
- **Testing**: Follow Arrange-Act-Assert; test edge cases and mocks only at boundaries.
- **Full Reference**: Read `docs/clean-code-reference.md` for detailed checklists, testing standards, and pattern descriptions.

## Patterns We Use

| Tool / Pattern | Purpose |
|---|---|
| Strict linters | Catch errors in CI (clippy, ruff, ESLint) |
| `just` | Universal task runner (`just check`, `just test`) |
| Pre-commit hooks | Format, lint, and type-check before commit |
| Small PRs | Reviewable in under 10 minutes |

<restrictions>

## Anti-Patterns

- **Never** leave dead code "just in case"; version control remembers.
- **Avoid** stringly-typed APIs; use enums and newtypes.
- **Do not** refactor without a reason (bug, requirement, complexity).
- **Silence warnings** only with a comment explaining **why**.

</restrictions>
