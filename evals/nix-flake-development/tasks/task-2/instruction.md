# Task: Write a NixOS module with options

## Context
You need to write a NixOS module for a custom service called `my-api`.

The module should expose these options:
- `services.my-api.enable` — bool, default false
- `services.my-api.port` — port number, default 8080
- `services.my-api.package` — package, default `pkgs.my-api`

When enabled, it should create a systemd service that:
- Runs the package binary as the `my-api` user
- Sets `Environment = "PORT=${toString config.services.my-api.port}"`
- Restarts on failure
- Has `After = ["network.target"]`

## Your Task
Write the complete NixOS module to `/tmp/eval-output/module.nix`.
