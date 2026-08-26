# Quality Rubric — Task 5 (Flux image automation)

Evaluate the response on:

1. **Stale scan diagnosis** (0-3): Does it correctly explain why the image wasn't picked up?
   - 3: Precisely identifies that the ImageRepository's scan interval is too long (2h default) and the last scan predates the push
   - 2: Identifies "scan didn't run" but not the interval configuration cause
   - 1: Vaguely mentions timing issue
   - 0: Wrong diagnosis

2. **Force reconcile command** (0-2): Does it include the correct flux command to force a scan?
   - 2: Includes `flux reconcile imagerepository api -n apps` or equivalent with correct flags
   - 1: Includes a flux reconcile command but targeting wrong resource type or namespace
   - 0: No force reconcile command provided

3. **Interval field knowledge** (0-2): Does it identify the configuration field and correct value?
   - 2: Identifies `spec.interval` on the ImageRepository and suggests `5m` value
   - 1: Mentions interval concept but not the specific field path
   - 0: Does not address interval configuration

Minimum acceptable: 5/7
