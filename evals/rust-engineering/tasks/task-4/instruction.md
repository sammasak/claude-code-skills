# Task: Write an idiomatic error type for a library crate

## Context
You are writing a library crate `workspace-client` that makes HTTP calls to the workstation-api.

The library can fail in these ways:
1. HTTP transport error (from `reqwest::Error`)
2. The API returned an error response (`status`, `message` fields in JSON body)
3. The response body couldn't be deserialized (from `serde_json::Error`)
4. The workspace name was invalid (invalid RFC 1123 DNS label)

## Your Task
Using `thiserror`, design and write:
1. A typed error enum `WorkspaceClientError` covering all 4 failure modes
2. Each variant should have a meaningful `#[error("...")]` message
3. `reqwest::Error` and `serde_json::Error` should use `#[from]` for automatic conversion
4. Include a `Display` impl showing the error — `thiserror` does this via the attribute

Write the error type to `/tmp/eval-output/error.rs`.
