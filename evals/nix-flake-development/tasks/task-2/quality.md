# Quality Rubric — Task 2 (NixOS module with options)

Evaluate the generated NixOS module on:

1. **mkOption declarations** (0-3): Are the required options declared correctly?
   - 3: All 3 options (enable, port, package) declared with `mkOption`, correct types, and defaults
   - 2: 2 of 3 options declared with mkOption
   - 1: Options block exists but using wrong approach (no mkOption)
   - 0: No options declaration

2. **Conditional systemd service** (0-2): Is the service conditional on the enable option?
   - 2: `mkIf config.services.my-api.enable { ... }` or equivalent guards the service definition
   - 1: Service defined but not conditional on enable
   - 0: No systemd service definition

3. **Option types** (0-2): Are option types correctly specified?
   - 2: enable is `lib.types.bool`, port is `lib.types.port` or `lib.types.int`, package is `lib.types.package`
   - 1: Some types correct but others missing or wrong
   - 0: No type specifications

4. **enable option** (0-1): Does the module have an enable option defaulting to false?
   - 1: `enable` option with `default = false`
   - 0: No enable option or defaults to true

Minimum acceptable: 6/8
