---
name: nix-flake-development
description: "Use when working with NixOS configurations, Nix flakes, module composition, system rebuilds, or Home Manager. Guides declarative system management patterns and safe rebuild workflows."
allowed-tools: Bash Read Grep Glob
---

# Nix Flake Development

Declarative, reproducible system configuration through Nix flakes and module composition.

## Principles

- **Declarative over imperative** — the repo *is* the system; no manual state mutations
- **Reproducibility** — `flake.lock` pins every input to an exact revision; builds are hermetic
- **Composition over inheritance** — small, focused modules combined per host via imports
- **Flake lock pinning** — update inputs intentionally (`nix flake update --commit-lock-file`), never implicitly
- **Module system is the API** — expose behavior through `mkOption`; consume through `config.*`

## Standards

> **Note:** Flakes require `experimental-features = nix-command flakes` in `nix.conf` (on NixOS: `nix.settings.experimental-features = [ "nix-command" "flakes" ]`).

### flake.nix Structure

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";  # single nixpkgs eval
    };
  };
  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.<hostname> = mkHost { ... };
  };
}
```

### Input Hygiene

| Rule | Why |
|---|---|
| Pin `nixpkgs` to a release branch, `nixos-unstable`, or a specific commit — `flake.lock` provides the actual reproducibility guarantee | Avoid surprise breakage while staying flexible |
| Use `inputs.X.follows = "nixpkgs"` for transitive deps | Single eval, smaller closure |
| Commit `flake.lock` — never gitignore it | Reproducibility guarantee |
| Update one input at a time when debugging | Isolate regressions |

### Module Option Patterns

```nix
options.homelab.services.myapp = {
  enable = lib.mkEnableOption "myapp service";
  port = lib.mkOption {
    type = lib.types.port;
    default = 8080;
    description = "Listen port for myapp";
  };
};
config = lib.mkIf config.homelab.services.myapp.enable {
  systemd.services.myapp = { ... };
};
```

### Key `lib` Functions

| Function | Use |
|---|---|
| `mkIf` | Conditional config blocks — guards entire attrsets |
| `mkMerge` | Combine multiple config fragments in one module |
| `mkDefault` | Set a value that downstream modules can override (priority 1000) |
| `mkForce` | Override everything (priority 50) — use sparingly |
| `mkEnableOption` | Shorthand for a boolean option defaulting to `false` |
| `mkPackageOption` | Declare a package option with proper defaults and type |

### Overlay Patterns

```nix
overlays.default = final: prev: {
  myapp = final.callPackage ./pkgs/myapp { };
};
```

- Apply overlays via `nixpkgs.overlays` in the host config, not inline
- Prefer `final` (self) for deps that may also be overlaid; `prev` (super) for the original

## Workflow

### Rebuild Cycle

```bash
nix flake check                                       # 1. Run all `checks.*` outputs (nixosTest VMs, package builds, formatter)
nixos-rebuild build --flake .#<hostname>               # 2. Build without switching
sudo nixos-rebuild test --flake .#<hostname>           # 3. Ephemeral activation (reverts on reboot)
sudo nixos-rebuild switch --flake .#<hostname>         # 4. Activate + set as boot default
```

`nixos-rebuild-ng` is the default rebuild tool starting in NixOS 25.11+.

### nixosTest — define `checks.<system>.<name>` for VM integration tests

```nix
checks.x86_64-linux.myservice = nixosTest {
  nodes.machine = { ... }: { services.myservice.enable = true; };
  testScript = ''
    machine.wait_for_unit("myservice")
    machine.succeed("curl -f localhost:8080/health")
  '';
};
```
### Rollback, Remote Deploys, GC

```bash
# Rollback (or select older generation at boot menu)
sudo nixos-rebuild switch --rollback

# Remote deploy
nixos-rebuild switch --flake .#<hostname> --target-host root@<ip> --use-remote-sudo
# Garbage collection
sudo nix-collect-garbage --delete-older-than 14d       # delete old profile generations + run GC
nix store gc                                           # store-level GC (does not delete generations)
```

## Patterns We Use

- **flake-parts** — recommended framework for modular flakes; use `perSystem` to abstract per-system boilerplate
- **`devShells` / `nix develop`** — declare project dev environments with `pkgs.mkShell` in the flake; keeps tooling reproducible and per-project. Pair with [direnv](https://direnv.net/) and `use flake` in `.envrc` for automatic shell activation on `cd`
- **Role-based host composition** — each host imports from `hosts/<name>/` with a `variables.nix` for host-specific values
- **Custom option namespaces** — `homelab.*` for infra services, `profile.*` for user presets; avoids collision with upstream options
- **`mkHost` helper** — wrapper in `flake.nix` wiring `nixpkgs`, overlays, Home Manager, and host modules into `lib.nixosSystem`
- **Home Manager as NixOS module** — imported via `home-manager.nixosModules.home-manager`; shares the system `nixpkgs` instance
- **SOPS / agenix for secrets** — encrypted in-repo, decrypted at activation time; never store plaintext secrets in the Nix store

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `nix-env -iA` for system packages | Declare in `environment.systemPackages` or Home Manager |
| Unpinned / floating flake inputs | Pin to branch or commit; use `follows` |
| Monolithic `configuration.nix` (500+ lines) | Split into role modules under `modules/` |
| Import-from-derivation (IFD) at eval time | Pre-generate files or use `builtins.readFile` |
| Manual edits to `/etc/*` on NixOS | Declare via `environment.etc` or service options |
| `mkForce` to fix option conflicts | Understand merge precedence; restructure modules |
| Disabling the firewall "temporarily" | Add explicit `networking.firewall.allowedTCPPorts` |
| `lib.mdDoc` for option descriptions | Removed in 24.11 — Markdown is now the default |

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/) | [nix.dev](https://nix.dev/) | [Nix Pills](https://nixos.org/guides/nix-pills/) (pre-flake legacy)
- [flake.parts](https://flake.parts/) | [zero-to-nix.com](https://zero-to-nix.com/) | [mcp-nixos](https://github.com/utensils/mcp-nixos)
