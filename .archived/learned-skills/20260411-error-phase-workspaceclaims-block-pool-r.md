# expires: 2026-05-11
# keywords: workspaceclaim,pool-reconciler,claude-ctl,warm-vms
---
name: learned-global-error-phase-workspaceclaims-block-pool-r
description: "When deleting VMs via claude-ctl, the WorkspaceClaim may remain in Error phase, which the pool reconciler treats as 'hol"
injectable: true
learned: true
learned_at: "2026-04-11T18:08:08Z"
scope: "global"
---

# Error-phase WorkspaceClaims block pool replenishment

When deleting VMs via claude-ctl, the WorkspaceClaim may remain in Error phase, which the pool reconciler treats as 'holding capacity' and prevents new VMs from being created. Always verify orphaned claims are deleted after VM deletion, or manually delete them to unblock pool reconciliation.
