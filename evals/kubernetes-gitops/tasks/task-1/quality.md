# Quality Rubric — Task 1 (HelmRelease ownership conflict)

Evaluate the response on:

1. **Root cause accuracy** (0-3): Does it correctly identify that the ServiceAccount existed
   before Flux tried to install and Flux cannot adopt it without explicit permission?
   - 3: Precisely identifies Helm ownership annotation conflict
   - 2: Identifies "resource exists" issue but not the annotation mechanism
   - 1: Vaguely mentions conflict
   - 0: Wrong root cause

2. **Remediation correctness** (0-3): Is the recommended approach correct and safe?
   - 3: Recommends `flux suspend` + fix annotations + `flux resume` OR Helm `--force-adopt` approach
   - 2: Recommends correct approach but with extra/risky steps
   - 1: Recommends a workaround that works but has side effects
   - 0: Recommends deleting the namespace or other destructive action

3. **Prevention specificity** (0-2): Does it explain HOW to prevent this in future deployments?
   - 2: Mentions `helm.sh/resource-policy: keep` annotation or Flux `createNamespace` flag specifically
   - 1: Vaguely suggests "clean up first"
   - 0: No prevention recommendation

Minimum acceptable: 6/8
