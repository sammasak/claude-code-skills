# expires: 2026-05-12
# keywords: learning systems,false positives,signal-to-noise,quality control
---
name: learned-global-over-triggering-learning-capture-is-wors
description: "When designing thresholds for knowledge extraction systems, bias toward false negatives rather than false positives. Cap"
injectable: true
learned: true
learned_at: "2026-04-12T07:58:55Z"
scope: "global"
---

# Over-triggering learning capture is worse than under-triggering

When designing thresholds for knowledge extraction systems, bias toward false negatives rather than false positives. Capturing trivial or read-only sessions pollutes your knowledge vault more than missing genuine learnings. Use multi-factor guards (changes + errors, not OR) and validate that triggers are actually meaningful before deploying them.
