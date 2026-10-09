# expires: 2026-05-11
# keywords: pool reconciler,WorkspaceClaim,Error phase,warm pool,capacity
---
name: learned-global-stale-workspaceclaims-in-error-phase-blo
description: "Errored or stale WorkspaceClaims are treated as occupying pool capacity even though they'll never become Ready. This pre"
injectable: true
learned: true
learned_at: "2026-04-11T19:36:32Z"
scope: "global"
---

# Stale WorkspaceClaims in Error phase block pool reconciliation

Errored or stale WorkspaceClaims are treated as occupying pool capacity even though they'll never become Ready. This prevents the pool reconciler from creating replacement VMs. When provisioning new warm VMs, first check for and delete any WorkspaceClaims stuck in Error or non-Running states: `kubectl get workspaceclaim -n workstations` and delete stale ones. The reconciler will then immediately create fresh VMs in the next 2-minute cycle.
