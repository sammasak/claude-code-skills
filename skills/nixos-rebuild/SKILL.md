---
name: nixos-rebuild
description: "Use when the user asks to rebuild, deploy, or apply NixOS configuration changes to one or more hosts. Handles local and remote rebuilds with proper verification."
argument-hint: "[hostname|all]"
allowed-tools: Bash Read Grep Glob
---

# NixOS Rebuild

Build and apply NixOS configuration changes safely.

## Steps

1. **Identify target host(s)**:
   - If `$ARGUMENTS` is a specific hostname, target that host
   - If `$ARGUMENTS` is `all`, target all physical hosts (skip `workstation-template`)
   - If no argument, detect the current hostname via `hostname` and target it

2. **Pre-flight checks**:
   - Run `git status` in the nixos-config repo to show uncommitted changes
   - Run `nix flake check --all-systems --no-write-lock-file` to catch eval errors early
   - If there are unstaged new `.nix` files, warn that the flake won't see them

3. **Build** (dry-run first):
   - Run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link` for each target
   - Report success/failure before applying

4. **Apply**:
   - Local host: `sudo nixos-rebuild switch --flake .#<host>`
   - Remote host: `nixos-rebuild switch --flake .#<host> --target-host lukas@<ip> --sudo --ask-sudo-password`
   - Ask the user before applying (never auto-apply)

5. **Post-apply verification**:
   - Check `systemctl --failed` for broken services
   - Report the new system generation number

## Host Reference

| Config Name | Hostname | Type |
|-------------|----------|------|
| `lenovo` | `lenovo-21CB001PMX` | Local (control plane) |
| `acer-swift` | `acer-swift` | Remote worker |
| `msi-ms7758` | `msi-ms7758` | Remote worker |
| `workstation-template` | — | VM image (use `just release`) |
