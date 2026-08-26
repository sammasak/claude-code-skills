# Quality Rubric — Task 2 (HelmRelease manifest)

Evaluate the generated Flux HelmRelease manifest on:

1. **YAML validity** (0-2): Is the file valid YAML that would parse correctly?
   - 2: Valid YAML, well-structured
   - 1: Minor formatting issues but parseable
   - 0: Invalid YAML or not YAML at all

2. **apiVersion and kind correctness** (0-2): Does it use the correct Flux API?
   - 2: `apiVersion: helm.toolkit.fluxcd.io/v2` and `kind: HelmRelease`
   - 1: Correct kind but wrong apiVersion version (e.g. v2beta1 instead of v2)
   - 0: Wrong kind or wrong API group entirely

3. **Remediation configuration** (0-2): Are retries properly configured?
   - 2: `spec.install.remediation.retries` or `spec.upgrade.remediation.retries` set to a specific integer
   - 1: Remediation block present but retry count missing or incorrect
   - 0: No remediation configuration

4. **Drift detection** (0-2): Is drift detection enabled?
   - 2: `spec.driftDetection.mode: enabled` or `warn`
   - 1: Drift detection mentioned in comments but not configured
   - 0: No drift detection configuration

Minimum acceptable: 6/8
