# expires: 2026-05-11
# keywords: nix,flake,home-manager,symlinks
---
name: learned-global-nixos-flake-updates-require-rebuild-to-a
description: "After running `nix flake update`, Home Manager symlinks (like claude-code skills) won't take effect until you run `sudo "
injectable: true
learned: true
learned_at: "2026-04-11T13:01:26Z"
scope: "global"
---

# NixOS flake updates require rebuild to activate symlinks

After running `nix flake update`, Home Manager symlinks (like claude-code skills) won't take effect until you run `sudo nixos-rebuild switch --flake .#<hostname>`. The flake lock updates but the symlinks remain stale until rebuild. Account for this in workflows that depend on fresh skill/module content.
