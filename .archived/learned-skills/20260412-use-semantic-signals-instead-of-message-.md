# expires: 2026-05-12
# keywords: trigger design,heuristics,learning systems,guards
---
name: learned-global-use-semantic-signals-instead-of-message-
description: "Message count (e.g., 'trigger after 8 messages') is a poor proxy for whether a session generated meaningful learnings. I"
injectable: true
learned: true
learned_at: "2026-04-12T07:58:55Z"
scope: "global"
---

# Use semantic signals instead of message count for learning capture triggers

Message count (e.g., 'trigger after 8 messages') is a poor proxy for whether a session generated meaningful learnings. Instead, guard learning capture on actual semantic signals: repos touched, files written/edited, or errors encountered. This prevents capturing read-only exploration sessions while enabling capture of short but intense implementation work. Apply when building any system that learns from interactions.
