# Task: Replace stringly-typed run strategy with a sealed enum

## Context
You have the following Rust code in `src/crd.rs`:

```rust
#[serde(rename_all = "camelCase")]
pub struct WorkspaceClaimSpec {
    pub run_strategy: String,
    // ... other fields
}

fn default_run_strategy() -> String {
    "Halted".to_string()
}
```

And in `src/handlers.rs`:

```rust
fn validate_run_strategy(rs: &str) -> Result<(), ApiError> {
    if !matches!(rs, "Always" | "Halted") {
        return Err(ApiError::BadRequest(
            format!("runStrategy must be 'Always' or 'Halted', got '{rs}'")
        ));
    }
    Ok(())
}
```

## Your Task
Apply the CDD (Compiler-Driven Development) principle "make illegal states unrepresentable":
1. Define a `RunStrategy` enum with `Always` and `Halted` variants
2. Replace `run_strategy: String` with `run_strategy: RunStrategy`
3. Remove the `validate_run_strategy` function — the compiler makes it unnecessary
4. The enum must serialize/deserialize to `"Always"` and `"Halted"` (PascalCase) in JSON
5. The enum must have `"Halted"` as the serde default

Write your implementation to `/tmp/eval-output/run_strategy.rs`.
Include the full enum definition and the updated spec field — NOT the entire file.
