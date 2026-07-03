# Clean Code Reference

Detailed standards and checklists for maintaining high code quality.

## Size and Shape Checklist

- [ ] Functions short enough to serve a single purpose (~20-30 lines).
- [ ] Max 3 parameters — group into a struct/dataclass if more.
- [ ] Prefer enums (`DryRun::Yes`) or separate functions over boolean parameters.
- [ ] Early returns over nested ifs — max 2 levels deep.

## API Design Checklist

- [ ] Every public function has a test.
- [ ] Default to private; promote to public only when required.
- [ ] Accept interfaces/traits, return concrete types.

## Testing Standards

- **Arrange-Act-Assert** in every test.
- Test edge cases and error paths, not just the happy path.
- Place mocks at system boundaries only (DB, HTTP, filesystem).
- Every test runs fast (<1s).

## References

- "A Philosophy of Software Design" — Ousterhout
- "Refactoring" — Fowler
- Google Engineering Practices — https://google.github.io/eng-practices/review/
- "Clean Code" — Martin
