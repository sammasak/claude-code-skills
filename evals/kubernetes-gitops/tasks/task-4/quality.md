# Quality Rubric — Task 4 (Kustomization with SOPS)

Evaluate the generated Flux Kustomization manifest on:

1. **Prune enabled** (0-2): Is resource pruning correctly configured?
   - 2: `spec.prune: true` explicitly set
   - 1: Prune mentioned in comments but not in spec
   - 0: Prune missing or set to false

2. **dependsOn correct** (0-2): Does it correctly depend on the infrastructure Kustomization?
   - 2: `spec.dependsOn[].name: infrastructure` present
   - 1: dependsOn block present but referencing wrong name
   - 0: No dependsOn configured

3. **SOPS decryption configured** (0-2): Is SOPS decryption properly set up?
   - 2: `spec.decryption.provider: sops` and secret reference to `sops-age` in the correct namespace
   - 1: SOPS provider set but secret reference missing or incorrect
   - 0: No decryption configuration

4. **Interval** (0-2): Is the reconciliation interval specified?
   - 2: `spec.interval: 5m` or equivalent duration format
   - 1: Interval present but wrong value or format
   - 0: Interval missing

Minimum acceptable: 6/8
