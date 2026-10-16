---
name: pi-offload
description: "Use when a small, mechanical, machine-checkable task (lint or clippy fixes, adding tests, small refactors, repetitive edits) could be delegated to the free-tier Pi worker instead of spending your own context. Not for design, security-sensitive code, work without a check command, or durable issue-to-PR work (pi-ticket)."
allowed-tools: Bash, Read
---

# pi-offload

`pi-offload` runs the Pi worker through the homelab llm-gateway (`homelab/auto`: free Gemini Flash, then Cloudflare Qwen / Gemini flash-lite, then msi Ollama) in a throwaway copy of the repo, loops until your check command passes, and prints one JSON line with a patch. You get a summary and a diff instead of reading files yourself.

## Offload when

- The task is mechanical and small: lint/clippy fixes, adding tests for existing behaviour, renames, small refactors, repetitive edits.
- A crisp check command decides success (`cargo test -p X`, `cargo clippy -p X -- -D warnings`, `devenv tasks run ...`).

## Do not offload

- Design, architecture, or anything judgement-heavy.
- Security-sensitive code, secrets, or private code you would not send to a free Gemini tier (prompts leave the machine).
- Anything without a check command.

The free tiers are small (Gemini Flash 20 requests/day, Cloudflare 10k neurons/day, flash-lite 15 RPM) and shared by every host and project through the gateway: keep tasks small.

## How

```bash
pi-offload --repo . --task "Fix all clippy warnings in crate foo" --check "cargo clippy -p foo -- -D warnings"
# devenv repos: add --runner "devenv shell --"
```

Optional: `--rounds N`, `--check-timeout S`, `--model homelab/{auto|best|local}` (default `auto`; `best` = tier 1 only, `local` = msi only, which may be off), `--keep`. Not `router/free`: the hosts hold no provider keys.

Read ONLY the JSON on stdout (`status`, `rounds`, `patch`, `diffstat`, `added_files`, `dirty_source`, `check_timed_out`, `new_refs`, `summary`). Exit codes: 0 passed, 1 failed, 2 invalid, 70 error, 64 usage.

1. `passed`: the patch is a candidate, not a result. Review `patch` (`git apply --check <patch>`, then `git apply`), then run the repo's gate yourself.
2. `failed`: read `summary`. A 429 there means the gateway's free models are spent or cooling down (daily quotas reset at 00:00 UTC): do not rerun now; do the work yourself or wait. A timeout or other error may be an outage.
3. `invalid` or `error`: never trust the output; do the work yourself or fix the invocation.
4. `new_refs`: inspect them, delete any that Pi made.
5. `dirty_source` or `check_timed_out` true: treat the result with suspicion and re-verify.
