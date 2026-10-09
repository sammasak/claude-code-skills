# expires: 2026-05-12
# keywords: optimization,regression testing,validation,measurement,quality
---
name: learned-global-validate-content-optimization-with-compr
description: "When optimizing large systems (skills, prompts, configs) for token/size reduction, always run full test suites (unit tes"
injectable: true
learned: true
learned_at: "2026-04-12T07:58:55Z"
scope: "global"
---

# Validate content optimization with comprehensive test suites before deployment

When optimizing large systems (skills, prompts, configs) for token/size reduction, always run full test suites (unit tests, integration tests, behavior evals) immediately after. Token optimization can accidentally break subtle behaviors; comprehensive testing catches regressions before they reach production. Token savings are only valuable if behavior is preserved.
