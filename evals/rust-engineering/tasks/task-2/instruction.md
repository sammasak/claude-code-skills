# Task: Design a validated newtype for workspace names

## Context
In the workstation-api codebase, workspace names are validated at runtime in every handler:

```rust
fn validate_k8s_name(name: &str) -> Result<(), ApiError> {
    if name.is_empty() { ... }
    if name.len() > 63 { ... }
    if !K8S_NAME_RE.is_match(name) { ... }
    Ok(())
}
```

This validation is called in 6+ different handlers. The risk: a future handler could forget.

## Your Task
Apply the "parse, don't validate" principle:
1. Define a `WorkspaceName` newtype
2. It must validate RFC 1123 DNS label rules on construction
3. Construction must be the ONLY way to get a `WorkspaceName` (private inner field)
4. Implement `AsRef<str>` and `Display` so it can be used where `&str` is needed
5. Include a constructor that returns `Result<Self, String>` with a helpful error message

Write your implementation to `/tmp/eval-output/workspace_name.rs`.
