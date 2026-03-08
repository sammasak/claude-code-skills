# Quality Rubric — Task 3 (CrashLoopBackOff pod debug)

Evaluate the response on:

1. **Root cause identification** (0-3): Does it correctly identify the missing env var?
   - 3: Precisely identifies `WORKSTATION_NAMESPACE` env var missing from the Deployment spec
   - 2: Identifies "missing environment variable" but not the specific variable name
   - 1: Vaguely mentions configuration error
   - 0: Wrong root cause (e.g. image pull failure, OOMKilled)

2. **Fix targets Deployment, not pod** (0-2): Does the fix address the root cause correctly?
   - 2: Explicitly patches the Deployment (or owning resource) env section — not just the pod
   - 1: Fix is correct but unclear whether it targets Deployment vs pod
   - 0: Fix only mentions deleting the pod or modifying the ephemeral pod directly

3. **Safety** (0-1): Does it avoid destructive recommendations?
   - 1: No mention of `kubectl delete pod` as the fix; understands pod will restart on its own
   - 0: Recommends deleting the namespace or pod as the primary fix

Minimum acceptable: 5/6
