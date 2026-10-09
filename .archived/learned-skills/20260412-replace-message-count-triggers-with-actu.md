# expires: 2026-05-12
# keywords: metrics,signal-quality,trigger-design,noise-reduction
---
name: learned-global-replace-message-count-triggers-with-actu
description: "MSG_COUNT is a noisy signal for whether a session produced real work. Better signals: did we write/edit files, commit co"
injectable: true
learned: true
learned_at: "2026-04-12T08:11:07Z"
scope: "global"
---

# Replace message count triggers with actual work signals for session significance

MSG_COUNT is a noisy signal for whether a session produced real work. Better signals: did we write/edit files, commit code, touch repositories, or encounter errors requiring investigation. Set a semantic significance floor based on these work indicators, not just conversation length. This prevents spurious triggers on read-only sessions.
