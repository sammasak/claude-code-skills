# Task: Add a new host to a multi-host flake

## Context
You have a NixOS flake that currently defines one host called `workstation`.
The flake.nix currently looks like:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/workstation/configuration.nix ];
    };
  };
}
```

You need to add a new host called `server` with:
- System: `x86_64-linux`
- Config: `./hosts/server/configuration.nix`
- It should share a common module at `./modules/common.nix` (add this to BOTH hosts)

## Your Task
Write the updated `flake.nix` to `/tmp/eval-output/flake.nix`.
