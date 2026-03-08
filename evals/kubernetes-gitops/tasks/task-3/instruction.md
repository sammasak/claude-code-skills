# Task: Debug a failing pod

## Context
A pod named `api-6b7f9d-x9kzp` in namespace `workstations` is in CrashLoopBackOff.

The following information is available:
```
$ kubectl get pod api-6b7f9d-x9kzp -n workstations
NAME                 READY   STATUS             RESTARTS   AGE
api-6b7f9d-x9kzp    0/1     CrashLoopBackOff   8          15m

$ kubectl describe pod api-6b7f9d-x9kzp -n workstations | grep -A5 "Last State:"
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Sat, 08 Mar 2026 10:00:00 +0000
      Finished:     Sat, 08 Mar 2026 10:00:02 +0000

$ kubectl logs api-6b7f9d-x9kzp -n workstations --previous
Error loading config: environment variable WORKSTATION_NAMESPACE is not set
```

## Your Task
1. Identify the root cause of the crash
2. Write the minimal Kubernetes patch or manifest change to fix it
3. Explain how to apply the fix without deleting the pod

## Deliverable
Write your analysis and fix to `/tmp/eval-output/fix.md`.
The fix must include the exact `kubectl` command to apply it.
