# Task: Explain nixos-rebuild failure and fix it

## Context
Running `sudo nixos-rebuild switch --flake .#myhost` fails with:

```
error: attribute 'htop' missing
       at /nix/store/...-source/configuration.nix:42:5:
           41|   environment.systemPackages = with pkgs; [
           42|     htop
           43|     git
```

You look at the current nixpkgs input in `flake.lock` and notice it's pinned to
`nixos-23.05`. The `htop` package was renamed to `htop-vim` in nixos-24.05.

## Your Task
1. Explain why this error occurs
2. Write the exact command to update ONLY the nixpkgs input to `nixos-24.11`
3. Explain the safe way to test the rebuild before switching

## Deliverable
Write your analysis and commands to `/tmp/eval-output/fix.md`.
