# expires: 2026-05-12
# keywords: state-management,persistence,debugging-pattern,frequency-capping
---
name: learned-global-frequency-caps-in-per-session-state-don-
description: "Never store frequency cap checks in session-local state (state resets per session, so the check always passes on first r"
injectable: true
learned: true
learned_at: "2026-04-12T08:11:07Z"
scope: "global"
---

# Frequency caps in per-session state don't work—use persistent checks instead

Never store frequency cap checks in session-local state (state resets per session, so the check always passes on first run). Instead, check against persistent data like file modification times or last-execution timestamps stored outside the session. This prevents unintended repeated LLM calls when the hook fires multiple times per session.
