# expires: 2026-05-11
# keywords: skill-design,trigger-tuning,false-positives,evals-driven-refinement
---
name: learned-global-skill-descriptions-need-refinement-based
description: "Skill trigger accuracy issues revealed by evals often stem from overly broad keyword matches in descriptions. When a ski"
injectable: true
learned: true
learned_at: "2026-04-11T13:14:28Z"
scope: "global"
---

# Skill descriptions need refinement based on actual query patterns

Skill trigger accuracy issues revealed by evals often stem from overly broad keyword matches in descriptions. When a skill shows high false-positive triggers (e.g., secrets-management activating on 'tokens' in infrastructure queries), refine the description to explicitly exclude common non-matching contexts or use more specific trigger language. This moves skill design from intuitive categorization to data-driven precision.
