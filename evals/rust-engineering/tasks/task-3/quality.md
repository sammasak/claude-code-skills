# Quality Rubric — Task 3 (Cargo.toml lint configuration)

Evaluate the generated TOML on:

1. **unsafe_code forbidden** (0-2): Is unsafe code forbidden workspace-wide?
   - 2: `[workspace.lints.rust]` section has `unsafe_code = "forbid"` or `{ level = "forbid", priority = N }`
   - 1: unsafe_code mentioned but in wrong section or wrong level (warn instead of forbid)
   - 0: unsafe_code not configured

2. **clippy all at warn with priority** (0-2): Is clippy::all enabled with priority system?
   - 2: `[workspace.lints.clippy]` has `all = { level = "warn", priority = -1 }` or equivalent
   - 1: clippy all enabled at warn but without priority field
   - 0: clippy all not enabled

3. **Pedantic present** (0-2): Is clippy::pedantic included?
   - 2: `pedantic = { level = "warn", priority = N }` where N > -1 (overrides all)
   - 1: pedantic mentioned but without priority (would be overridden by all)
   - 0: pedantic not configured

4. **workspace = true opt-in** (0-2): Does a member crate section opt into workspace lints?
   - 2: `[lints]` section with `workspace = true`
   - 1: Section mentioned but incorrectly formatted
   - 0: No member crate opt-in

Minimum acceptable: 6/8
