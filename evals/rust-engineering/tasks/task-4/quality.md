# Quality Rubric — Task 4 (Error type with thiserror)

Evaluate the generated Rust error type on:

1. **thiserror used** (0-2): Is the thiserror library used correctly?
   - 2: `use thiserror::Error` and `#[derive(Error)]` on the enum
   - 1: thiserror mentioned/imported but not applied via derive
   - 0: thiserror not used (using std::error::Error manually)

2. **#[from] automatic conversion** (0-2): Are #[from] attributes present for convertible errors?
   - 2: Both reqwest::Error and serde_json::Error have `#[from]` on their variants
   - 1: Only one of the two has `#[from]`
   - 0: No `#[from]` attributes

3. **All 4 error variants covered** (0-3): Are all failure modes represented?
   - 3: All 4 modes: HTTP transport, API error response, deserialization failure, invalid name
   - 2: 3 of 4 covered
   - 1: 2 of 4 covered
   - 0: Fewer than 2 modes

4. **Error messages** (0-1): Do variants have meaningful #[error("...")] messages?
   - 1: All variants have `#[error("...")]` with descriptive messages
   - 0: Missing error messages or placeholder messages only

Minimum acceptable: 6/8
