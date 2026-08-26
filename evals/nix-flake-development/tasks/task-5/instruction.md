# Task: Diagnose and fix a Home Manager activation failure

## Context
Running `home-manager switch --flake .#myuser` fails with:

```
Error: collision between
  /nix/store/...-git-2.43.0/bin/git
  /nix/store/...-git-2.44.0/bin/git
```

The user profile has `git` installed both via `home.packages` and via a program module:

```nix
{ pkgs, ... }: {
  home.packages = [ pkgs.git ];

  programs.git = {
    enable = true;
    userName = "Lukas";
    userEmail = "lukas@example.com";
  };
}
```

## Your Task
1. Explain why the collision occurs
2. Write the fix (the correct configuration — not a workaround)
3. Explain the general rule to avoid this in future

## Deliverable
Write to `/tmp/eval-output/fix.md` with your explanation and the corrected Nix config.
