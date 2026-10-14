---
name: pi-offload
description: "Use when a small, mechanical, machine-checkable task (lint or clippy fixes, adding tests, small refactors, repetitive edits) could be delegated to the free-tier Pi worker instead of spending your own context. Not for design, security-sensitive code, or work without a check command."
allowed-tools: Bash, Read
---

# pi-offload

`pi-offload` runs the Pi worker on the free router pool (Cloudflare Qwen, Gemini flash-lite) in a throwaway copy of the repo, loops until your check command passes, and prints one JSON line with a patch. You get a summary and a diff instead of reading files yourself.

## Offload when

- The task is mechanical and small: lint/clippy fixes, adding tests for existing behaviour, renames, small refactors, repetitive edits.
- A crisp check command decides success (`cargo test -p X`, `cargo clippy -p X -- -D warnings`, `devenv tasks run ...`).

## Do not offload

- Design, architecture, or anything judgement-heavy.
- Security-sensitive code, secrets, or private code you would not send to a free Gemini tier (prompts leave the machine).
- Anything without a check command.

The pool is quota-limited (10k Cloudflare neurons/day, 15 RPM Gemini): keep tasks small.

## How

```bash
pi-offload --repo . --task "Fix all clippy warnings in crate foo" --check "cargo clippy -p foo -- -D warnings"
# devenv repos: add --runner "devenv shell --"
```

Optional: `--rounds N`, `--check-timeout S`, `--model router/free`, `--keep`.

Read ONLY the JSON on stdout (`status`, `rounds`, `patch`, `diffstat`, `added_files`, `dirty_source`, `check_timed_out`, `new_refs`, `summary`). Exit codes: 0 passed, 1 failed, 2 invalid, 70 error, 64 usage.

1. `passed`: the patch is a candidate, not a result. Review `patch` (`git apply --check <patch>`, then `git apply`), then run the repo's gate yourself.
2. `failed`: read `summary`. A router quota refusal means do not retry until the quota resets; do the work yourself or wait.
3. `invalid` or `error`: never trust the output; do the work yourself or fix the invocation.
4. `new_refs`: inspect them, delete any that Pi made.
5. `dirty_source` or `check_timed_out` true: treat the result with suspicion and re-verify.
