---
name: deep-modules
description: Use when designing or reviewing module boundaries, public APIs, traits/interfaces, or test seams — before adding a wrapper, helper, abstraction layer, or new public type. Not for Rust-specific lints, crates, or toolchain choices — rust-engineering owns those.
---

# Deep Modules

Design vocabulary and rules adapted from Matt Pocock's `codebase-design` skill (github.com/mattpocock/skills, MIT), itself built on Ousterhout's *A Philosophy of Software Design*.

## Vocabulary

- **Module** — scale-agnostic: a function, struct, trait, crate, or tier-spanning slice.
- **Interface** — everything a caller must know to use the module correctly: signatures, invariants, ordering constraints, error modes, required configuration, performance characteristics.
- **Depth** — behaviour a caller (or test) can exercise per unit of interface they must learn. Deep = much behaviour behind a small interface. Depth is a property of the interface, not the implementation.
- **Seam** — a place where behaviour can change without editing in that place. **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** (benefit to callers) and **locality** (fix once, fixed everywhere) are what depth buys.

## Rules

1. **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through — delete it for real. If complexity reappears across N callers, it was earning its keep.
2. **The interface is the test surface.** Tests exercise the module through its public interface. Wanting to test past the interface (reaching into fields, asserting internals) means the module is the wrong shape — reshape it, don't widen access.
3. **Seam discipline.** One adapter means a hypothetical seam; two adapters means a real one. Introduce a seam only where something actually varies. A test double counts as the second adapter only for dependencies that genuinely need substituting:

   | Dependency tier | Testing approach |
   |---|---|
   | In-process, pure | Call it directly — no seam |
   | Local but slow/stateful (clock, fs, rand) | Substitutable value or small trait |
   | Remote but owned (own DB, own services) | Ports & adapters |
   | True external (third-party APIs) | Mock at the boundary |

4. **Count the public surface.** Every `pub` type a caller must touch to do the common thing is interface cost. Give the common case a one-call entry point with defaults; "it's public because callers need it to construct X" means X needs a constructor that doesn't require it.
5. **Replace, don't layer.** When interface-level tests cover the behaviour, delete the old implementation-coupled unit tests. Keeping both is paying twice for the weaker one.
6. **Design it twice.** Before committing to an interface, sketch a second, radically different one (minimal entry points vs. maximal flexibility vs. optimised-for-common-case). Compare by depth, locality, and seam placement — the first idea is rarely the best.
7. **Testability without seam sprawl:** accept dependencies, don't create them; return results, don't produce side effects; keep the surface small.

## Red flags

- A wrapper whose body is one call to something with a near-identical signature.
- A trait with exactly one production implementation and no concrete variation on the horizon.
- "Made it public for tests" / tests asserting private state or exact internal call sequences.
- The common-case caller must name 4+ types to get the default behaviour.
- Suggesting a future abstraction ("we could add a trait for…") instead of the simplest present design.
