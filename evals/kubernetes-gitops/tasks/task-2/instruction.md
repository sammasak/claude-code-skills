# Task: Write a correct HelmRelease manifest

## Context
You need to deploy cert-manager v1.16.x using Flux into a Kubernetes cluster.

Requirements:
- Namespace: cert-manager
- Helm chart: cert-manager from the jetstack Helm repository
- Version: any v1.16.x (use semver range)
- CRDs must be installed (use `installCRDs=true` or equivalent)
- Remediation: retry on install failure (3 retries)
- Drift detection: enabled

## Your Task
Write a complete, production-ready Flux HelmRelease manifest.

## Deliverable
Write the manifest to `/tmp/eval-output/helmrelease.yaml`.
