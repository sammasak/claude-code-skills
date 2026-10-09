# expires: 2026-05-11
# keywords: token-optimization,evals,trigger-accuracy,quality-assurance,regression-testing
---
name: learned-global-evals-validation-catches-skill-trigger-a
description: "After optimizing skill content for token reduction, run comprehensive evals (unit test suites covering diverse queries) "
injectable: true
learned: true
learned_at: "2026-04-11T13:14:28Z"
scope: "global"
---

# Evals validation catches skill trigger accuracy regressions

After optimizing skill content for token reduction, run comprehensive evals (unit test suites covering diverse queries) immediately to catch both behavioral regressions and trigger accuracy issues. This session's 140-unit evals caught two real bugs: kubernetes-gitops producing invalid YAML syntax, and secrets-management over-triggering on 'tokens' in non-secrets contexts. Pattern: optimize → validate with broad query coverage → fix identified false-positives/false-negatives before deployment.
