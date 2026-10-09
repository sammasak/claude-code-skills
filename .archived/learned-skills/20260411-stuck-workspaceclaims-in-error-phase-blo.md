# expires: 2026-05-11
# keywords: WorkspaceClaim,pool-reconciler,Error-phase,capacity,replenish
---
name: learned-global-stuck-workspaceclaims-in-error-phase-blo
description: "If the warm VM pool isn't creating replacement VMs, check for WorkspaceClaims stuck in Error phase. The pool reconciler "
injectable: true
learned: true
learned_at: "2026-04-11T18:08:48Z"
scope: "global"
---

# Stuck WorkspaceClaims in Error phase block pool replenishment

If the warm VM pool isn't creating replacement VMs, check for WorkspaceClaims stuck in Error phase. The pool reconciler treats non-Ready claims as 'holding capacity' even if errored, preventing new VMs from being created. Delete the stuck claim to allow the reconciler to replenish the pool.
