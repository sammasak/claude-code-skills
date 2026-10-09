# expires: 2026-05-11
# keywords: workstation-pool,kubernetes,workspaceclaim,reconciliation,debugging
---
name: learned-global-stuck-workspaceclaims-block-pool-reconci
description: "When the workstation pool reconciler fails to create fresh warm VMs despite configuration being correct, check for orpha"
injectable: true
learned: true
learned_at: "2026-04-11T18:06:52Z"
scope: "global"
---

# Stuck WorkspaceClaims block pool reconciliation

When the workstation pool reconciler fails to create fresh warm VMs despite configuration being correct, check for orphaned WorkspaceClaims stuck in Error phase (kubectl get workspaceclaims -n workstations). These block the reconciler even after their VMIs are deleted. Delete the stuck claim to unblock the next 2-minute reconciliation cycle.
