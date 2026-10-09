# expires: 2026-05-11
# keywords: pool-reconciler,warm-vms,workstation-api,timing
---
name: learned-global-workstation-pool-reconciler-runs-on-2-mi
description: "The workstation-api reconciler detects stale or error-phase claims and replenishes warm VM capacity every 2 minutes. Whe"
injectable: true
learned: true
learned_at: "2026-04-11T18:08:08Z"
scope: "global"
---

# Workstation pool reconciler runs on 2-minute cycle

The workstation-api reconciler detects stale or error-phase claims and replenishes warm VM capacity every 2 minutes. When fixing pool issues (e.g., deleting orphaned claims), wait ~2 minutes and check for new VMs being created automatically before taking further action.
