# sdlc-pipeline reference — the machine contract

## Reading the Machine

Stage order and briefs are no longer hardcoded here; they live in the repo's own machine, rendered at devenv eval and exposed as `$SDLC_MACHINE` (a JSON file path). Before relying on its contents, reject any unsupported schema version:

```sh
devenv shell -q -- sh -c 'jq -e ".schemaVersion == 1" "$SDLC_MACHINE" >/dev/null'
```

If this check fails, stop and report the observed version; do not infer or silently accept a different schema. The current machine contract is version 1. Additive fields retain that version; changing or removing existing fields requires a new version and a compatible walker update.

```json
{ "schemaVersion": 1, "name": "<repo>", "bar": 9, "order": ["sketch", "..."], "terminal": ["..."],
  "stages": { "<name>": { "after": [], "guards": [], "verdict": false,
      "plans": ["/nix/store/...-plan.md"],
      "rubrics": ["/nix/store/...-SDLC-REVIEW.md"],
      "brief": "...", "wrappers": ["sdlc:<s>-<g>", "..."] } } }
```

When already inside `devenv shell`, read the machine directly. For a one-shot/non-interactive shell, keep the variable access inside the shell and capture the JSON output:

```sh
machine_json="$(devenv shell -q -- sh -c 'cat "$SDLC_MACHINE"')"
```

Read a stage's brief with jq inside the devenv shell, don't guess it:

```sh
devenv shell -q -- sh -c 'jq -r ".stages.review.brief" "$SDLC_MACHINE"'
```

`order` is the topological stage order for the current repo's preset (deps first); `stages.<name>.verdict` marks review-style stages. Briefs, plan paths, and rubric paths are consumer-overridable, so always read `$SDLC_MACHINE` rather than assuming rust-preset defaults apply. The Nix store paths identify immutable review inputs; read every listed plan and rubric before reviewing.

