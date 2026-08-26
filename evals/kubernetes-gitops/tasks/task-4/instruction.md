# Task: Write a Kustomization with SOPS decryption

## Context
You need to write a Flux Kustomization manifest that:
- Watches the `apps/monitoring` path in your GitOps repository
- Has a 5-minute reconciliation interval
- Depends on `infrastructure` Kustomization being ready first
- Decrypts SOPS secrets using an age key stored in a Kubernetes secret named `sops-age` in the `flux-system` namespace
- Prunes deleted resources

## Your Task
Write a complete, correct Flux Kustomization manifest.

## Deliverable
Write the manifest to `/tmp/eval-output/kustomization.yaml`.
