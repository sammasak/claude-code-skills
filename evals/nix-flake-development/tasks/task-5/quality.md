# Quality Rubric — Task 5 (Home Manager collision fix)

Evaluate the response on:

1. **Collision explanation** (0-3): Does it correctly explain why the collision occurs?
   - 3: Precisely explains that `programs.git` installs its own `git` package, so adding `pkgs.git` to `home.packages` results in two different versions of the same binary
   - 2: Explains "double install" but not the mechanism (programs module adds its own package)
   - 1: Vaguely mentions "conflict" without explaining why
   - 0: Wrong explanation

2. **Correct fix** (0-3): Does it provide the right fix (remove from home.packages, keep programs.git)?
   - 3: Shows updated config removing `pkgs.git` from `home.packages` while keeping `programs.git` intact
   - 2: Identifies the correct fix verbally but doesn't show updated Nix config
   - 1: Suggests removing `programs.git` instead (wrong direction — loses configuration)
   - 0: Wrong fix (e.g. use `override`, add `forceSource`)

3. **General rule stated** (0-2): Does it explain the general principle?
   - 2: States that `programs.*` modules install their own package — don't add the same package to `home.packages`
   - 1: Hints at the rule but doesn't state it clearly
   - 0: No general rule provided

Minimum acceptable: 6/8
