# Container Workflows -- Specificity Audit

Audit of `/skills/container-workflows/SKILL.md` for user-specific details that should be generalized.

---

## Findings

### 1. Line 81: Section header "Patterns We Use"

**Text:** `## Patterns We Use`

**Issue:** The phrase "We Use" implies a specific team or organization's chosen stack. A generic skill should present guidance as best practices or recommended patterns, not as "our team's choices."

**Verdict:** User-specific framing.

**Suggested fix:** Rename to `## Recommended Patterns` or `## Tooling Choices`.

---

### 2. Line 86: Harbor presented as the private registry choice

**Text:** `| **Harbor** | Private registry with built-in vulnerability scanning and RBAC. |`

**Issue:** Harbor is one option among many (AWS ECR, GCP Artifact Registry, Azure ACR, GitHub Container Registry, GitLab Container Registry, JFrog Artifactory). Listing only Harbor as "the" registry choice leaks a personal infrastructure decision. Most teams using cloud providers will never touch Harbor.

**Verdict:** User-specific infrastructure choice.

**Suggested fix:** Either remove the row entirely (the skill already uses `registry.example.com` in examples, which is neutral) or broaden it:

```
| **Private registry** | Use one with built-in vulnerability scanning and RBAC (e.g., Harbor, GitHub Container Registry, cloud-provider registries). |
```

---

### 3. Line 87: Nix flake dev shells as the tooling delivery mechanism

**Text:** `| **Nix flake dev shells** | Provide buildah, skopeo, trivy -- reproducible tooling across machines. |`

**Issue:** Nix flakes are a niche tool preference. Most developers install buildah/skopeo/trivy via their OS package manager, Homebrew, or CI base images. Presenting Nix as the delivery mechanism is a personal workflow detail. There is already a separate `nix-flake-development` skill in this repo for that concern.

**Verdict:** User-specific tooling preference.

**Suggested fix:** Remove the row, or generalize:

```
| **Reproducible dev environment** | Pin tool versions (buildah, skopeo, trivy) via Nix flakes, devcontainers, or a lockfile-driven installer so every machine matches. |
```

---

### 4. Line 91: `just` commands as the task runner

**Text:** `| **\`just\` commands** | \`just build\`, \`just scan\`, \`just push\` wrap the full cycle. |`

**Issue:** `just` is a reasonable tool but it is a personal preference over `make`, `task`, shell scripts, or CI-native steps. Presenting it as "the" wrapper leaks a specific workflow.

**Verdict:** Mildly user-specific (just is less mainstream than make).

**Suggested fix:** Generalize:

```
| **Task runner** | Wrap the build/scan/push cycle behind simple commands (`just`, `make`, or similar) for consistency. |
```

---

### 5. Line 92: Flux image automation as the deploy mechanism

**Text:** `| **Flux image automation** | Watches registry for new tags, updates Git manifests, triggers deploy. |`

**Issue:** Flux is one GitOps operator. ArgoCD is equally popular, and many teams use CI-driven deployment (GitHub Actions, GitLab CI) with no image-automation controller at all. This is a specific infrastructure choice.

**Verdict:** User-specific infrastructure choice.

**Suggested fix:** Generalize or note alternatives:

```
| **GitOps image automation** | A controller (Flux Image Automation, ArgoCD Image Updater) watches the registry for new tags, updates Git manifests, and triggers deploy. |
```

---

### 6. Lines 83-92: The entire "Patterns We Use" table

**Text:** The full table at lines 83-92.

**Issue (structural):** This table conflates two things: (a) broadly good engineering choices (buildah+skopeo, multi-stage builds, Chainguard images) and (b) personal stack decisions (Harbor, Nix, just, Flux). The first category belongs in the skill. The second category makes the skill a description of one person's setup rather than transferable guidance.

**Verdict:** The table should be split or pruned. Keep rows that are genuinely best-practice (buildah+skopeo, scratch/Chainguard/distroless, slim+uv) and either remove or generalize the personal-stack rows (Harbor, Nix, just, Flux).

---

### 7. Lines 83-84: buildah + skopeo as the only build tooling

**Text:** `| **buildah + skopeo** | Rootless, daemonless, OCI-native. No Docker socket needed. |`

**Issue:** This is borderline. buildah+skopeo is a strong technical choice and the justification is sound, but it is worth noting that most developers still use `docker build` or `docker buildx`, and many CI environments provide Docker natively. The skill's workflow section (lines 51-71) exclusively uses buildah/skopeo with no mention of Docker alternatives.

**Verdict:** Reasonable opinionated choice, but the skill should at minimum acknowledge that `docker buildx build` is a valid alternative, since it now supports rootless mode too. Otherwise, someone using Docker will find the skill inapplicable.

**Suggested fix:** Add a brief note, e.g., after line 84:

```
> buildah and skopeo are preferred for rootless, daemonless workflows. If your environment provides Docker, `docker buildx build` is also acceptable -- the Dockerfile best practices above apply equally.
```

---

### 8. Lines 51-71: Workflow example uses generic naming (GOOD)

**Text:** `myapp`, `registry.example.com`

**Verdict:** These are properly generic placeholder names. No issue here. Noted for completeness: this is the right way to do it.

---

### 9. Line 90: uv presented as pip replacement

**Text:** `| **\`python:3.x-slim\` + uv** | Fast installs, small image. uv replaces pip for dependency resolution. |`

**Issue:** uv is rapidly gaining adoption and is a defensible recommendation, but calling it a direct "replacement" for pip positions a newer tool as the default without caveat. Many Python projects still use pip or pip-tools.

**Verdict:** Mildly opinionated but reasonable. Low priority.

**Suggested fix:** Minor wording tweak: "uv for fast, deterministic dependency resolution (pip also works)."

---

## Summary

| # | Line(s) | Severity | Category |
|---|---------|----------|----------|
| 1 | 81 | Low | User-specific framing ("We Use") |
| 2 | 86 | High | User-specific infra (Harbor as only registry) |
| 3 | 87 | High | User-specific tooling (Nix flakes as only dev env) |
| 4 | 91 | Medium | User-specific tooling (just as only task runner) |
| 5 | 92 | High | User-specific infra (Flux as only deploy mechanism) |
| 6 | 83-92 | Medium | Structural: table mixes universal and personal choices |
| 7 | 83-84 | Low | Opinionated but justified (buildah+skopeo only) |
| 8 | 51-71 | None | Generic placeholders used correctly |
| 9 | 90 | Low | Mildly opinionated (uv as pip "replacement") |

**High-severity items (2, 3, 5):** Harbor, Nix flakes, and Flux are specific infrastructure/tooling decisions that should be generalized or presented as one option among several.

**Medium-severity items (4, 6):** `just` as task runner and the overall table structure leak personal workflow without enough alternatives mentioned.

**Low-severity items (1, 7, 9):** Minor framing issues that are easily fixed with small wording changes.
