# Specificity Audit: rust-engineering/SKILL.md

Audit of user-specific, oddly specific, or overly opinionated content that limits the skill's generality.

## Summary

The rust-engineering skill is **mostly generic and universal**. It reads as a well-written community-consensus Rust guide with only a handful of user-specific fingerprints. The main concerns are the "Patterns We Use" table (which encodes one person's infrastructure stack as universal), a few placeholder names that leak real project structure, and the bundled container/Kubernetes tooling that belongs in the sibling skills.

---

## Findings

### 1. "Patterns We Use" header implies personal/team choices are universal

- **Line:** 93
- **Text:** `## Patterns We Use`
- **Problem:** The phrase "We Use" signals these are one team's or person's choices, not universal Rust recommendations. The table that follows mixes genuinely mainstream choices (axum, tower) with infrastructure-specific opinions (kube-rs, buildah, just, utoipa). A reader adopting this skill inherits a full opinionated stack without knowing which parts are consensus and which are personal.
- **Suggested fix:** Rename to `## Recommended Libraries` or `## Common Crate Choices`. Add a brief qualifier that these are strong defaults, not mandates.

### 2. `kube-rs` as a universal Rust pattern

- **Line:** 97
- **Text:** `| Kubernetes client | \`kube-rs\` | First-class async, derive-based CRDs |`
- **Problem:** Not every Rust project involves Kubernetes. Including kube-rs in the core Rust engineering skill reveals the author's infrastructure context (homelab/platform engineering with K8s). This belongs in the `kubernetes-gitops` skill or a specialized "Rust for Kubernetes" section, not the general Rust engineering guide.
- **Suggested fix:** Remove from this skill. If kept, move to a clearly labeled "Domain-specific crates" subsection so it does not appear as a universal Rust recommendation.

### 3. `buildah` presented as the standard container build tool

- **Line:** 102
- **Text:** `| Rootless builds | \`buildah\` | No daemon, OCI-compliant |`
- **Problem:** buildah is a legitimate tool, but presenting it in the core Rust engineering skill (rather than the container-workflows skill) is user-specific. Most Rust developers use `docker build` or `cargo-zigbuild`. The same buildah preference appears in the container-workflows skill where it actually belongs.
- **Suggested fix:** Remove from this skill entirely. Container tooling is already covered in the `container-workflows` skill.

### 4. `FROM scratch` container pattern in a Rust skill

- **Line:** 101
- **Text:** `| Container images | Multi-stage Docker with \`FROM scratch\` | Minimal attack surface, small images |`
- **Problem:** Container image strategy is not a Rust engineering concern -- it is a deployment concern. The container-workflows skill already covers this pattern in detail (lines 88-110 of that skill). Duplicating it here reflects the author's workflow where Rust and containers are tightly coupled, which is not universally true.
- **Suggested fix:** Remove. Add a cross-reference like "See the container-workflows skill for image build patterns."

### 5. Justfile with `buildah` and `myapp` placeholder

- **Line:** 111
- **Text:** `image:  buildah build -t myapp:latest .`
- **Problem:** Two issues: (a) `buildah` again appears as the assumed build tool, and (b) the placeholder `myapp` is suspiciously generic in a way that suggests it was a find-replace from a real project name. Additionally, the entire Justfile section overlaps with the container-workflows skill.
- **Suggested fix:** If keeping a Justfile example, limit it to Rust-specific tasks (`check`, `lint`, `test`, `build`). Remove the `image` target or replace with a comment like `# image: <your container build command>`.

### 6. Dockerfile example with hardcoded binary name `api`

- **Lines:** 121, 125-126
- **Text:**
  ```
  RUN cargo build --release --target x86_64-unknown-linux-musl --bin api
  COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/api /api
  ENTRYPOINT ["/api"]
  ```
- **Problem:** The binary name `api` matches the workspace organization example on line 87 (`api/  # thin binary`). This is clearly the author's real project structure leaking through. A generic skill should use a clearly-marked placeholder.
- **Suggested fix:** Either (a) remove the entire Dockerfile section (it duplicates the container-workflows skill), or (b) use an obviously-placeholder name like `myapp` or `<binary-name>` with a comment noting it should match the `[[bin]]` name in Cargo.toml.

### 7. Workspace organization is oddly specific

- **Lines:** 83-90
- **Text:**
  ```
  workspace/
    crates/
      core/       # shared types, traits, error definitions
      api/        # thin binary -- depends on core
      worker/     # thin binary -- depends on core
    Cargo.toml
  ```
- **Problem:** The `core/api/worker` structure is a very specific microservice architecture pattern (API server + background worker sharing a core library). This is a reasonable example but it is presented as THE workspace organization rather than one possible layout. The names `api` and `worker` then leak into the Dockerfile example (line 121), confirming this is the author's actual project structure.
- **Suggested fix:** Keep the example but add a qualifier: "Example workspace layout (adapt to your project):" and consider using more generic names like `lib/`, `server/`, `cli/` or showing two alternative layouts.

### 8. `utoipa` for OpenAPI is a niche choice presented as standard

- **Line:** 99
- **Text:** `| OpenAPI generation | \`utoipa\` | Derive macros keep spec next to code |`
- **Problem:** utoipa is a fine crate, but OpenAPI generation is not a universal Rust concern. Including it in the core patterns table implies every Rust project needs an OpenAPI spec. This is specific to HTTP API development (which itself is only one category of Rust project). Other alternatives like `aide` or `poem-openapi` exist.
- **Suggested fix:** Move to a subsection labeled "HTTP API crates" or "If building REST APIs" to clarify this is conditional, not universal.

### 9. `just` as task runner presented without alternatives

- **Line:** 100
- **Text:** `| Task runner | \`just\` | Language-agnostic, simple syntax |`
- **Problem:** While `just` is popular, presenting it as the single task runner choice is opinionated. Many Rust projects use `cargo-make`, `cargo-xtask`, plain `Makefile`, or no task runner at all. The existing review (rust-review.md) already flagged the omission of `cargo-xtask`.
- **Suggested fix:** Either mention alternatives briefly (`just` or `cargo-xtask` for Rust-only projects) or frame as "our default" rather than "the choice."

### 10. x86_64-only musl target

- **Lines:** 121, 125
- **Text:** `x86_64-unknown-linux-musl`
- **Problem:** The Dockerfile hardcodes x86_64 architecture. With ARM/aarch64 becoming common (Apple Silicon, Graviton, Ampere), a generic skill should at least acknowledge multi-arch builds or use a variable.
- **Suggested fix:** Add a comment noting the architecture assumption, e.g., `# For aarch64: aarch64-unknown-linux-musl`. Or use a `--build-arg` pattern for the target triple.

---

## Classification Summary

| # | Line(s) | Item | Verdict | Severity |
|---|---------|------|---------|----------|
| 1 | 93 | "Patterns We Use" header | User-specific framing | Low |
| 2 | 97 | kube-rs in core patterns | User-specific (K8s infrastructure) | Medium |
| 3 | 102 | buildah as standard tool | User-specific (repeated across skills) | Medium |
| 4 | 101 | Container image pattern in Rust skill | User-specific (duplicates container skill) | Medium |
| 5 | 111 | Justfile with buildah + myapp | User-specific placeholder + tool choice | Low |
| 6 | 121, 125-126 | Binary name `api` in Dockerfile | User-specific project name leak | Medium |
| 7 | 83-90 | core/api/worker workspace layout | Reasonable example but presented as canonical | Low |
| 8 | 99 | utoipa as universal pattern | Niche presented as universal | Low |
| 9 | 100 | just without alternatives | Opinionated but defensible | Low |
| 10 | 121, 125 | x86_64-only musl target | Overly specific architecture | Low |

## Overall Assessment

**Specificity score: 4 out of 10 findings are medium-severity user-specific content.**

The core Rust content (principles, lints, error handling, type design, anti-patterns, references) is genuinely universal and well-written. The specificity problems are concentrated in two areas:

1. **The "Patterns We Use" table** (lines 93-102) which encodes one person's full-stack preferences (axum + kube-rs + utoipa + buildah + just) as universal Rust patterns.
2. **The container/deployment section** (lines 104-127) which duplicates the container-workflows skill and leaks real project structure (`api` binary, `core/api/worker` layout).

The cleanest fix would be to remove lines 96-127 entirely (the Kubernetes, container, and Dockerfile content) since it is fully covered by the sibling skills, and rename the remaining patterns table to something less possessive than "Patterns We Use."
