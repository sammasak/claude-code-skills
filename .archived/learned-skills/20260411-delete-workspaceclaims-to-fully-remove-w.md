# expires: 2026-05-11
# keywords: warm-pool,WorkspaceClaim,VMI,cleanup,runStrategy
---
name: learned-global-delete-workspaceclaims-to-fully-remove-w
description: "When cleaning up warm VMs that won't delete, don't just delete the VMI — delete the WorkspaceClaim instead. VMs with `"
injectable: true
learned: true
learned_at: "2026-04-11T18:08:48Z"
scope: "global"
---

# Delete WorkspaceClaims to fully remove warm pool VMs

When cleaning up warm VMs that won't delete, don't just delete the VMI — delete the WorkspaceClaim instead. VMs with `runStrategy: Always` will recreate their VMI immediately. The reconciler that manages the warm pool watches WorkspaceClaims, not VMIs directly.
