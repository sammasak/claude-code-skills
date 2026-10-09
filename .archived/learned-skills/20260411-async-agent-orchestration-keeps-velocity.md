# expires: 2026-05-11
# keywords: parallelization,agent-orchestration,async-monitoring
---
name: learned-global-async-agent-orchestration-keeps-velocity
description: "When running parallel agents alongside builds and commits, dispatch all work concurrently and monitor status asynchronou"
injectable: true
learned: true
learned_at: "2026-04-11T13:01:26Z"
scope: "global"
---

# Async agent orchestration keeps velocity high

When running parallel agents alongside builds and commits, dispatch all work concurrently and monitor status asynchronously rather than blocking on individual tasks. Check agent/build progress while doing other work (reads, edits, commits) to maintain steady forward motion. This prevents context-switching overhead and keeps the session productive.
