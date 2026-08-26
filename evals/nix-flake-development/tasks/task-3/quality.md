# Quality Rubric — Task 3 (nixos-rebuild failure and fix)

Evaluate the response on:

1. **Correct error explanation** (0-3): Does it correctly explain why the error occurs?
   - 3: Precisely explains that `htop` was renamed in nixpkgs between 23.05 and 24.05, and the flake is pinned to the old version
   - 2: Correctly identifies version mismatch but not the specific rename
   - 1: Vaguely mentions "package changed" or "update nixpkgs"
   - 0: Wrong explanation (e.g. typo, network error)

2. **Update only nixpkgs** (0-2): Does it show how to update only the nixpkgs input?
   - 2: Shows `nix flake update nixpkgs` (modern) or `nix flake lock --update-input nixpkgs`
   - 1: Shows `nix flake update` without specifying just nixpkgs (updates all inputs)
   - 0: Does not address updating nixpkgs specifically

3. **Safe test approach** (0-2): Does it recommend testing before switching?
   - 2: Mentions `sudo nixos-rebuild test` or `--dry-run` before switch
   - 1: Mentions testing concept but not the specific nixos-rebuild flags
   - 0: Goes straight to switch with no safety step

Minimum acceptable: 5/7
