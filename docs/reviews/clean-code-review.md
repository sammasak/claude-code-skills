# Review: clean-code-principles

## Score: 7/10

A solid, opinionated skill file that covers the most important clean code heuristics in a
concise format. The principles are well-chosen, the anti-patterns table is excellent, and
the overall structure maps well to a Claude Code background-knowledge skill. However,
several specific claims are either overstated, slightly outdated, or missing important
nuance -- and the references section could be stronger. Details below.

---

## Findings

### Accurate

- **Readability over cleverness.** The "30-second rule for a junior dev" is a good
  pragmatic heuristic. Still widely endorsed.

- **Functions do one thing / Single Responsibility at the function level.** This remains
  the consensus across every modern style guide and book (Fowler, Ousterhout, Beck, Martin).

- **Names reveal intent.** Universally accepted. The wording ("if you need a comment to
  explain a name, rename it") is clean and memorable.

- **Tests as executable documentation.** Well stated and increasingly important as teams
  use AI to generate code -- tests become the authoritative specification.

- **Smallest possible public API / default to private.** Still a cornerstone of API design
  guidance (Rust API Guidelines, Effective Java, Google style guides).

- **Composition over inheritance.** Still the prevailing wisdom in 2025-2026. Multiple
  university curricula, Thoughtworks, and the Rust/Go ecosystems continue to reinforce
  this. The skill states it correctly.

- **Make illegal states unrepresentable.** Excellent inclusion. This principle has gained
  momentum beyond the Rust/F# communities and is now taught in TypeScript, Swift, and
  Go contexts as well. Language-agnostic framing here is appropriate.

- **Dependency injection over global state.** Sound advice, still standard.

- **No magic numbers.** Uncontroversial and correct.

- **Actionable error messages.** The example (`"failed to connect to DB at {host}:{port}"`
  vs. `"connection error"`) is well-chosen and practical.

- **Accept interfaces/traits, return concrete types.** Good heuristic, applicable across
  Go, Rust, Java, TypeScript, and Python (protocols). Still current.

- **Test naming describes behavior, not implementation.** Standard advice, well worded.

- **Arrange-Act-Assert.** Still the dominant unit-test structuring pattern. See detailed
  note under Issues for the "one assertion per test" clause.

- **Test edge cases, not just happy path.** Correct and important.

- **Test the public API, not internals.** Correct. Matches guidance from Kent Beck,
  Martin Fowler, and Google's testing blog.

- **Place mocks at system boundaries only.** Good advice. Consistent with the "London vs.
  Classical" testing schools' common ground.

- **Every test runs fast (<1s).** Reasonable threshold. Some teams use 100ms for unit
  tests and reserve 1s for integration, but 1s as a general ceiling is fine.

- **Test quality check (implementation coupling detector).** The heuristic question ("if
  implementation changes but behavior stays the same, does this test break?") is an
  excellent, memorable formulation.

- **Anti-patterns table.** All six entries are correct and well-explained:
  - Comments restating code -- correct.
  - Dead code -- correct ("version control remembers" is a great one-liner).
  - Premature abstraction / "rule of three" -- still the consensus.
  - God objects/functions -- correct.
  - Stringly-typed APIs -- correct.
  - Silencing linter warnings without explanation -- correct and important.

- **Patterns table.** `just`, pre-commit hooks, multi-stage Docker builds, small PRs --
  all solid, current practices.

### Issues

1. **"One assertion per test" is overstated (line 47)**

   Current text: "One assertion per test -- test exactly one thing"

   This is a frequently cited rule, but the modern consensus (as articulated by the Stack
   Overflow blog in their 2022 article "Stop requiring only one assertion per unit test,"
   Ardalis, Industrial Logic, and xUnit Test Patterns) is more nuanced: the real rule is
   **one logical behavior per test**, not one `assert` statement. Multiple assertions
   verifying different facets of the same behavior are perfectly acceptable. The original
   "one assertion" rule stems from a misreading of the Assertion Roulette test smell
   described in Meszaros's *xUnit Test Patterns*.

   **Recommendation:** Change to: "One behavior per test -- verify exactly one logical
   concept. Multiple assertions are fine if they all verify facets of the same behavior."

   Sources:
   - https://stackoverflow.blog/2022/11/03/multiple-assertions-per-test-are-fine/
   - https://www.industriallogic.com/blog/multiple-asserts-are-ok/
   - https://ardalis.com/grouping-assertions-in-tests/

2. **"Functions under 20 lines (prefer under 10)" lacks nuance (line 27)**

   Current text: "Functions under 20 lines (prefer under 10)"

   The 20-line guideline is reasonable as a heuristic and is used by some corporate style
   guides. However, it is not a consensus hard number. Martin Fowler's influential essay
   on function length argues the key metric is the gap between intention and
   implementation, not a line count. The "Rule of 30" (methods under ~30 lines) is
   another common heuristic. Ousterhout in *A Philosophy of Software Design* explicitly
   pushes back against tiny functions, arguing they can create "shallow modules" that
   increase cognitive overhead by forcing readers to jump between many small definitions.

   The "prefer under 10" parenthetical echoes Robert Martin's most extreme position (2-4
   line functions), which has been widely criticized as leading to atomized, hard-to-follow
   codebases.

   **Recommendation:** Soften to: "Functions should be short enough to serve a single
   purpose -- typically under 20-30 lines. Avoid the extreme of extracting every 3-line
   block into its own function; each extraction should reduce cognitive load, not add
   indirection."

   Sources:
   - https://martinfowler.com/bliki/FunctionLength.html
   - Ousterhout, *A Philosophy of Software Design*, Ch. 3 "Working Code Isn't Enough"

3. **"No boolean parameters" is too absolute (line 29)**

   Current text: "No boolean parameters -- use enums or named types (`Mode::Dry` not
   `dry_run: bool`)"

   The advice is directionally correct -- boolean flag arguments are a well-documented code
   smell (Martin Fowler calls them "flag arguments," Robert Martin calls them "ugly").
   However, the blanket "No boolean parameters" phrasing is too absolute. Boolean
   parameters are fine for genuinely boolean concepts (e.g., `verbose: bool` in a CLI
   library, or `recursive: bool` in a file-system function), especially on private methods.
   The real concern is boolean parameters on public APIs where the call site reads as
   `do_thing(true, false)` with no indication of what the booleans mean.

   Additionally, the example `Mode::Dry` uses Rust syntax, which slightly undermines the
   language-agnostic goal. A language-neutral example would be stronger.

   **Recommendation:** Soften to: "Avoid boolean parameters on public APIs when the call
   site becomes ambiguous (e.g., `deploy(true, false)`). Prefer enums, named types, or
   separate functions. Boolean parameters are acceptable when the concept is genuinely
   binary and the name is self-documenting."

   Adjust the example to be language-neutral: `DryRun` vs `dry_run: bool` or use
   pseudocode.

4. **Linter example is language-specific (line 63)**

   Current text: "Strict linters: Automated enforcers -- Rust: `clippy::all = deny`;
   Python: `ruff` + `ty`"

   This is fine as illustrative, but it names only Rust and Python, which could create an
   impression that the skill is Rust/Python-centric rather than language-agnostic. For a
   skill titled "clean-code-principles" that is meant to apply across all languages, it
   would be better to keep examples either more generic or to list 3-4 language ecosystems
   to make the breadth explicit.

   **Recommendation:** Either expand to include examples from more ecosystems (e.g.,
   ESLint for JS/TS, golangci-lint for Go) or replace with a generic statement like
   "Enable strict linting in every language: treat warnings as errors in CI."

5. **`allowed-tools` format may be non-standard (line 5)**

   Current text: `allowed-tools: Bash Read Grep Glob`

   The official Claude Code documentation shows `allowed-tools` as a comma-separated
   string (e.g., `allowed-tools: Bash, Read, Grep, Glob`) or a YAML list. The
   space-separated format used here is consistent across all skills in this repository,
   so it may work in practice (Claude Code may be lenient in parsing). However, it does
   not match the documented format.

   **Recommendation:** Consider switching to the comma-separated format to match the
   official documentation: `allowed-tools: Bash, Read, Grep, Glob`. If the
   space-separated format is confirmed to work and is a deliberate style choice for this
   repo, add a comment in the repo README noting the convention.

   Source: https://code.claude.com/docs/en/skills

6. **Reference to "Clean Code" chapters 1-6 deserves more context (line 85)**

   Current text: `"Clean Code" -- Martin (chapters 1-6 only; skip the later chapters)`

   This is a reasonable qualification, and the "chapters 1-6 only" caveat shows awareness
   of the book's shortcomings. However, the community discourse has shifted significantly
   since this skill was written. As of 2025:

   - A notable public debate between John Ousterhout and Robert Martin (September 2024 -
     February 2025) highlighted fundamental disagreements on function length, comments,
     and module depth.
   - A second edition of *Clean Code* was published in 2025, drawing fresh criticism for
     its treatment of pure functions and continued insistence on extremely short functions.
   - Many senior engineers and educators now recommend *A Philosophy of Software Design*
     as the primary book, with *Clean Code* as supplementary.

   The skill already lists Ousterhout first (good), but the Martin reference could be
   further qualified.

   **Recommendation:** Update to something like: `"Clean Code" -- Martin (naming and
   function chapters only; approach function-length advice skeptically; the community
   has largely moved to Ousterhout as the primary design reference)`.

   Source: https://github.com/johnousterhout/aposd-vs-clean-code

7. **PEP 20 reference is Python-specific (line 87)**

   Current text: `Python PEP 20 -- \`import this\` (the Zen of Python)`

   While the Zen of Python contains excellent universal principles ("Explicit is better
   than implicit," "Simple is better than complex"), PEP 20 is by definition a Python
   Enhancement Proposal. In a language-agnostic skill file, including a Python-specific
   reference without equivalent references for other languages creates a subtle bias.

   **Recommendation:** Either remove this reference (the principles it encodes are already
   covered by the skill's own guidelines) or reframe it as: "The Zen of Python (PEP 20)
   -- applicable beyond Python: explicit > implicit, simple > complex, readability counts."

### Missing

1. **No mention of AI-assisted code and its implications for clean code.**
   In 2025-2026, a significant portion of code is AI-generated. The skill should
   acknowledge that AI-generated code needs the same (or stricter) review standards as
   human-written code. Clean code principles apply regardless of who or what wrote the
   code. This is especially relevant given this is a Claude Code skill.

2. **No mention of "Tidy First?" by Kent Beck (2023).**
   This concise book on incremental tidying has become a frequently recommended companion
   to refactoring guidance. It bridges the gap between "clean code as ideal" and "working
   with messy code in practice."

3. **No mention of "Code That Fits in Your Head" by Mark Seemann.**
   An increasingly recommended modern alternative to *Clean Code* that focuses on
   cognitive-load-based heuristics for sustainable software development.

4. **No guidance on when NOT to refactor.**
   The skill focuses heavily on what clean code looks like but does not address the
   pragmatic question of when cleanup is not worth it (throwaway prototypes, performance-
   critical hot paths where clarity trades off with optimization, etc.). Ousterhout's
   "strategic vs. tactical programming" framework would be a useful addition.

5. **No mention of cognitive complexity metrics.**
   Tools like SonarQube's cognitive complexity metric have gained traction as a more
   meaningful alternative to cyclomatic complexity or raw line counts for measuring code
   readability. This would strengthen the "Size and Shape" section.

6. **No mention of documentation/comments as a positive tool.**
   The anti-patterns section correctly warns against comments that restate code, but the
   skill never makes the positive case for *when* comments are valuable (documenting
   "why," explaining non-obvious algorithmic choices, noting workarounds for external
   bugs). Ousterhout makes a strong case that good comments are a design tool, not a
   failure, pushing back against the "comments are always failures" stance from *Clean
   Code*.

---

## References Check

| Reference | Status | Notes |
|---|---|---|
| "A Philosophy of Software Design" -- Ousterhout | Valid, highly recommended | Still considered the best single book on managing complexity. 2nd edition (2021) is current. Correctly listed first. |
| "Refactoring" -- Fowler | Valid, highly recommended | 2nd edition (2018) remains a classic. Still frequently purchased alongside other engineering books. |
| Google Engineering Practices guide | Valid | Available at https://google.github.io/eng-practices/review/. Note: the skill says "Google Engineering Practices guide" but does not provide a link. Adding the URL would help. The Google Style Guides at https://google.github.io/styleguide/ are a separate resource and also remain actively maintained. |
| "Clean Code" -- Martin | Valid but increasingly controversial | See Issue #6 above. The "chapters 1-6 only" caveat is appropriate. A 2nd edition was published in 2025. The community is divided on whether to continue recommending it at all. |
| Rust API Guidelines | Valid | https://rust-lang.github.io/api-guidelines/ is live and maintained. However, this is a language-specific reference in a language-agnostic skill. |
| Python PEP 20 | Valid but language-specific | See Issue #7 above. The Zen of Python itself is timeless, but citing it by PEP number is Python-centric. |

### References that should be added

- **Google Engineering Practices URL:** https://google.github.io/eng-practices/review/
- **"Tidy First?" by Kent Beck (2023)** -- concise, modern, practical.
- **"Code That Fits in Your Head" by Mark Seemann** -- cognitive-load-focused clean code.
- **Martin Fowler's Refactoring Catalog (online):** https://refactoring.com/catalog/ --
  a free, searchable, always-current companion to the book.

### References that could be removed or demoted

- **Rust API Guidelines** -- excellent resource, but language-specific. Better suited to
  the `rust-engineering` skill (where it is already listed).
- **Python PEP 20** -- language-specific. The principles are already embedded in the
  skill's own guidelines.

---

## Recommendations

### Priority 1 (Accuracy)

1. Rewrite the "one assertion per test" line to "one behavior per test."
2. Soften the "prefer under 10 lines" guidance or remove it entirely.
3. Replace the Rust-syntax `Mode::Dry` example with a language-neutral alternative.

### Priority 2 (Completeness)

4. Add a brief note on when comments ARE valuable (the "why" behind non-obvious code).
5. Add a note that these principles apply equally to AI-generated code.
6. Add *Tidy First?* to the references.

### Priority 3 (Consistency)

7. Consider switching `allowed-tools` to comma-separated format to match the official
   Claude Code documentation.
8. Remove or reframe the Python PEP 20 and Rust API Guidelines references in favor of
   language-agnostic resources.
9. Add the URL for the Google Engineering Practices guide.

### Priority 4 (Polish)

10. Expand the linter examples to cover more than Rust/Python, or make them generic.
11. Soften "No boolean parameters" to "Avoid boolean parameters on public APIs."
12. Consider adding *Code That Fits in Your Head* (Seemann) to references.

---

## Summary

The skill is well-structured, concise, and covers the most important clean code
principles. The anti-patterns table is particularly strong. The main areas for improvement
are: (a) the "one assertion per test" claim, which is demonstrably outdated as stated;
(b) a few places where specific advice is too absolute or leans on Robert Martin's more
extreme positions without acknowledging the counter-arguments; and (c) a handful of
language-specific details (Rust syntax, Python PEP, Rust API Guidelines) that weaken
the language-agnostic framing. With the Priority 1 and 2 fixes applied, this would be
an 8.5-9/10 skill file.
