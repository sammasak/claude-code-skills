---
name: nix-flake-development
description: "Use when working with NixOS configurations, Nix flakes, module composition, system rebuilds, or Home Manager. Guides declarative system management patterns and safe rebuild workflows."
allowed-tools: Bash Read Grep Glob
injectable: true
---

# Nix Flake Development

Declarative, reproducible system configuration through Nix flakes and module composition.

## Principles

| Principle | Rule |
|---|---|
| Declarative | The repo *is* the system — no manual state mutations |
| Reproducibility | `flake.lock` pins every input; commit it, never gitignore |
| Composition | Small focused modules combined per host via `imports` |
| Module system | Expose behavior via `mkOption`; consume via `config.*` |

> Requires `nix.settings.experimental-features = [ "nix-command" "flakes" ]`.

## flake.nix Structure

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.<hostname> = mkHost { ... };
  };
}
```

**Input rules:** Pin to a branch/rev. Use `inputs.X.follows = "nixpkgs"` for transitive deps. Update one input at a time when debugging.

## Key `lib` Functions

| Function | Use |
|---|---|
| `mkIf` | Conditional config blocks |
| `mkMerge` | Combine multiple config fragments |
| `mkDefault` | Override-able default (priority 1000) |
| `mkForce` | Override everything — use sparingly |
| `mkEnableOption` | Boolean option defaulting to `false` |

## Module Pattern

```nix
options.homelab.services.myapp.enable = lib.mkEnableOption "myapp";
config = lib.mkIf config.homelab.services.myapp.enable {
  systemd.services.myapp = { ... };
};
```

## Rebuild Workflow

```bash
nix flake check                                        # validate all outputs
nixos-rebuild build --flake .#<hostname>               # build without activating
sudo nixos-rebuild test --flake .#<hostname>           # ephemeral (reverts on reboot)
sudo nixos-rebuild switch --flake .#<hostname>         # activate + set boot default
```

### Updating a flake input before a rebuild

```bash
nix flake update <input>
sudo nixos-rebuild switch --flake .#<hostname>
# or for agent image: just release-agent latest
```

The build uses exactly the commit in `flake.lock`. **Pushing to GitHub does not update the lock.**

## Patterns We Use

- **Role-based host composition** — `hosts/<name>/` + `variables.nix` per host
- **`mkHost` helper** — wires nixpkgs, overlays, Home Manager, and host modules
- **Home Manager as NixOS module** — shares system nixpkgs instance
- **SOPS for secrets** — encrypted in-repo, decrypted at activation; never in Nix store
- **`homelab.*` / `profile.*` namespaces** — avoids collision with upstream options

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `nix-env -iA` for system packages | Declare in `environment.systemPackages` or Home Manager |
| `inputs.nixpkgs.url = "nixpkgs"` (unpinned) | `url = "github:NixOS/nixpkgs/nixos-unstable"` |
| Monolithic `configuration.nix` (500+ lines) | Split into role modules under `modules/` |
| Import-from-derivation (IFD) at eval time | Pre-generate or use `builtins.readFile` |
| Manual edits to `/etc/*` | Declare via `environment.etc` or service options |
| `mkForce` to fix option conflicts | Understand merge precedence; restructure modules |
| `lib.mdDoc` for option descriptions | Removed in 24.11 — Markdown is the default |
