---
name: lean-code
description: Use when about to add a comment, doc block, error variant, config option, helper, or test beyond what the change strictly needs — in any code writing or review. Not for Rust-specific lints, crates, or toolchain choices — rust-engineering owns those.
---

# Lean Code

Code is cost; the behaviour is the asset. The best diff is the smallest one that solves the whole problem, and the best line is the one that no longer needs to exist.

## Comments and docs

A comment earns its line only by stating what the code cannot: a constraint, an invariant, a consequence ("X breaks when…"), or a non-obvious why. Name things well enough that narration never becomes necessary.

**State each fact exactly once, in the one place its reader looks.** A public function's contract lives in its doc comment; the module doc then only routes ("parsing for duration strings — see `parse_duration`"), it does not restate the grammar. A doc line above an attribute or signature that re-says it (`/// The input was empty.` above `#[error("duration string is empty")] Empty`) is deleted on sight. Section banners (`// ─── Config ───`) are replaced by file/module structure.

## Surface sized to real callers

Build for the callers that exist today:

- An error type gets as many variants as callers *branch on*. A CLI that prints the message needs one well-worded message, not six variants carrying owned `String`s.
- A config option, trait, or generic parameter is added when the second concrete need arrives, never for a hypothetical one (see the deep-modules skill for seam discipline).
- Deliver the design that fits now and stop; put future ideas in the commit message or nowhere, not as "we could later add a `Jitter` trait" notes in the code.

## Deletion is a feature

When touching code, remove what the change makes dead: unused impls, stale helpers, tests made redundant by better ones (replace, don't layer). Weight cleanup toward code that changed recently (git history), leave stable corners alone.

## Calibrate ceremony to the ask

Match effort to what was requested and to the environment: asked for code in a reply, write the code — a full crate scaffold, toolchain download, and pedantic-lint pass is for changes landing in a real repo. On these memory-constrained hosts, heavy verification runs once and sequentially, at the layer that owns it (git hooks / sdlc gates), not re-improvised per edit.

## Red flags

- The same contract explained in the module doc, the type doc, and the function doc.
- A comment or doc line that would survive translation into the identifier under it.
- Error variants, fields, or options nothing matches on or sets.
- A "for future flexibility" abstraction with one user.
- More lines of scaffolding and process than of requested change.
