# Quality Rubric — Task 4 (Add new host to flake)

Evaluate the generated flake.nix on:

1. **Both hosts present** (0-2): Are both workstation and server hosts defined?
   - 2: Both `nixosConfigurations.workstation` and `nixosConfigurations.server` defined
   - 1: One host present, other missing
   - 0: Neither host present or only one host total

2. **Shared common module** (0-3): Is common.nix included in both host configurations?
   - 3: `./modules/common.nix` (or similar path) appears in both hosts' modules list
   - 2: common.nix referenced once (only in one host)
   - 1: Common module concept mentioned in comment but not in modules list
   - 0: No common module

3. **nixosSystem call correct** (0-2): Is the Nix syntax for defining hosts correct?
   - 2: Both hosts use `nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [...]; }`
   - 1: One host correctly defined, other has syntax issues
   - 0: nixosSystem not used or wrong pattern

Minimum acceptable: 5/7
