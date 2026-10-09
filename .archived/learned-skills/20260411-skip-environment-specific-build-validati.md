# expires: 2026-05-11
# keywords: build-validation,environment-constraints,CI-CD
---
name: learned-global-skip-environment-specific-build-validati
description: "Tools like trivy scanning may fail in certain environments (e.g., trivy needs docker daemon, which NixOS doesn't have by"
injectable: true
learned: true
learned_at: "2026-04-11T13:01:26Z"
scope: "global"
---

# Skip environment-specific build validations gracefully

Tools like trivy scanning may fail in certain environments (e.g., trivy needs docker daemon, which NixOS doesn't have by default). Rather than blocking the build, expect these failures for specific tools on specific platforms and document them as expected. The image may still be valid even if one validation tool fails.
