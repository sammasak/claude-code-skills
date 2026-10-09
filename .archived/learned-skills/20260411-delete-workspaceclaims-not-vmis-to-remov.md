# expires: 2026-05-11
# keywords: WorkspaceClaim,warm pool,VMI,deletion,kubernetes
---
name: learned-global-delete-workspaceclaims-not-vmis-to-remov
description: "When deleting warm pool VMs from the homelab, `claude-ctl delete` removes the VMI but leaves the WorkspaceClaim intact. "
injectable: true
learned: true
learned_at: "2026-04-11T19:36:32Z"
scope: "global"
---

# Delete WorkspaceClaims, not VMIs, to remove warm pool VMs

When deleting warm pool VMs from the homelab, `claude-ctl delete` removes the VMI but leaves the WorkspaceClaim intact. If the claim has `runStrategy: Always`, it will recreate the VMI automatically. To fully remove a warm VM, delete the WorkspaceClaim directly: `kubectl delete workspaceclaim <name> -n workstations`. This prevents stale claims from blocking pool replenishment.
