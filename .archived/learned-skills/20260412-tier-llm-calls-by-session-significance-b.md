# expires: 2026-05-12
# keywords: cost-optimization,semantic-significance,tiered-processing,hook-design
---
name: learned-global-tier-llm-calls-by-session-significance-b
description: "When building hooks that need to extract learnings or summarize work, tier the LLM calls: first check semantic signals ("
injectable: true
learned: true
learned_at: "2026-04-12T08:11:07Z"
scope: "global"
---

# Tier LLM calls by session significance before cost-intensive processing

When building hooks that need to extract learnings or summarize work, tier the LLM calls: first check semantic signals (did we write/edit files, touch repos, hit errors), and only invoke Haiku for rich sessions. Use mechanical stubs (timestamp, message count) for thin sessions. This reduces token usage by ~50% while preserving quality of captured sessions.
