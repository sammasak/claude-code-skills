# expires: 2026-05-12
# keywords: learning-systems,documentation,capture-vs-synthesis,architecture
---
name: learned-global-separate-automatic-capture-from-synthesi
description: "When building learning/documentation systems, use automatic capture on every session completion (low overhead, raw recor"
injectable: true
learned: true
learned_at: "2026-04-12T07:53:01Z"
scope: "global"
---

# Separate automatic capture from synthesis in learning pipelines

When building learning/documentation systems, use automatic capture on every session completion (low overhead, raw records) and defer synthesis to a separate on-demand or periodic phase. This prevents blocking active sessions with synthesis logic and allows batch processing of multiple sessions to find patterns. Example: persist-session.sh captures immediately; knowledge-vault skill synthesizes on-demand after sufficient data accumulates.
