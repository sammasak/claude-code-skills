# Task: Explain and fix Flux image automation

## Context
You have image update automation configured for a service called `api`. The ImagePolicy
is set to semver range `>=1.0.0 <2.0.0`. A new image `registry.example.com/api:1.5.0`
was pushed to the registry 30 minutes ago, but Flux has NOT updated the manifest.

Running `flux get images all -n apps` shows:
```
NAME         READY   STATUS                                AGE
api          True    Latest image tag for 'api' resolved   2h
```

But `flux get imagerepositories -n apps` shows:
```
NAME    READY   STATUS                    LAST SCAN
api     True    successful scan, 1 tag    2h ago
```

The last scan was 2 hours ago — before the new image was pushed.

## Your Task
1. Explain why the automation has not picked up the new image
2. Write the exact command to force a new scan now
3. Identify the configuration field that controls scan frequency and provide the correct value for a 5-minute scan interval

## Deliverable
Write your analysis to `/tmp/eval-output/image-automation.md`.
