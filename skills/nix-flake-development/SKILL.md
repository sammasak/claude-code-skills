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
| Pin `nixpkgs` to a release branch or commit | Avoid surprise breakage |
| Use `inputs.X.follows = "nixpkgs"` for transitive deps | Single eval, smaller closure |
| Commit `flake.lock` — never gitignore it | Reproducibility guarantee |
| Update one input at a time when debugging | Isolate regressions |

### Module Option Patterns

```nix
# Defining options
options.homelab.services.myapp = {
  enable = lib.mkEnableOption "myapp service";
  port = lib.mkOption {
    type = lib.types.port;
    default = 8080;
    description = "Listen port for myapp";
  };
};

# Implementing options
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

### Overlay Patterns

```nix
overlays.default = final: prev: {
  myapp = final.callPackage ./pkgs/myapp { };
};
```

- Apply overlays via `nixpkgs.overlays` in the host config, not inline
- Keep overlays in a dedicated `overlays/` directory
- Prefer `final` (self) for deps that may also be overlaid; `prev` (super) for the original

## Workflow

### Rebuild Cycle

```bash
nix flake check                                       # 1. Validate eval
nixos-rebuild build --flake .#<hostname>               # 2. Build without switching
sudo nixos-rebuild test --flake .#<hostname>           # 3. Ephemeral activation (reverts on reboot)
sudo nixos-rebuild switch --flake .#<hostname>         # 4. Activate + set as boot default
```

### Rollback, Remote Deploys, GC

```bash
# Rollback
nix-env --list-generations -p /nix/var/nix/profiles/system
sudo nixos-rebuild switch --rollback
# Or select older generation at GRUB/systemd-boot menu

# Remote deploy
nixos-rebuild switch --flake .#<hostname> --target-host root@<ip> --use-remote-sudo

# Garbage collection
sudo nix-collect-garbage --delete-older-than 14d       # prune old generations
sudo nix-collect-garbage -d                            # remove all but current (aggressive)
```

## Patterns We Use

- **Role-based host composition** — each host imports from `hosts/<name>/` with a `variables.nix` defining host-specific values (IP, role, hardware)
- **Custom option namespaces** — `homelab.*` for infrastructure services, `profile.*` for user environment presets; avoids collision with upstream NixOS options
- **`mkHost` helper** — a wrapper in `flake.nix` that wires `nixpkgs`, overlays, Home Manager, and host modules into `lib.nixosSystem` with minimal boilerplate
- **Home Manager as NixOS module** — imported via `home-manager.nixosModules.home-manager`; shares the system `nixpkgs` instance, no separate channel
- **SOPS / agenix for secrets** — secrets are encrypted in-repo, decrypted at activation time; never store plaintext secrets in the Nix store

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

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/) — official module and configuration reference
- [nix.dev](https://nix.dev/) — curated tutorials and best practices
- [Nix Pills](https://nixos.org/guides/nix-pills/) — deep-dive into Nix fundamentals
- [zero-to-nix.com](https://zero-to-nix.com/) — beginner-friendly flake onboarding
- [mcp-nixos](https://github.com/utensils/mcp-nixos) — MCP server for querying NixOS options and packages
- [numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) — Nix-native patterns for LLM agent tooling
