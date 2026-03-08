# Task: Fix a stuck HelmRelease

## Context
You are working in a homelab GitOps repository that uses Flux v2.

The following HelmRelease has been failing to reconcile for 10 minutes:
```
NAME         READY   STATUS                                                    AGE
grafana      False   Helm install failed: rendered manifests contain a...      45m
```

Running `flux logs --kind=HelmRelease --name=grafana -n monitoring` shows:
```
rendered manifests contain a resource that already exists. Unable to continue with install:
ServiceAccount "grafana" in namespace "monitoring" exists and cannot be imported into
the current release: invalid ownership metadata; annotation validation error: ...
```

## Your Task
1. Diagnose why the HelmRelease is stuck
2. Identify the correct Flux remediation approach (do NOT delete the namespace or existing resources)
3. Write the exact kubectl/flux command(s) needed to unblock it
4. Explain what flag or annotation prevents this from happening again

## Deliverable
A markdown file at `/tmp/eval-output/remediation.md` containing:
- Root cause diagnosis (1-2 sentences)
- Exact remediation commands (runnable as-is)
- Prevention recommendation
