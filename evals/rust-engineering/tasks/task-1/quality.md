# Quality Rubric — Task 1 (RunStrategy enum)

Evaluate the generated Rust code on:

1. **Enum correctness** (0-3): Is the RunStrategy enum correctly defined?
   - 3: Well-formed enum with both variants, proper derives (Serialize, Deserialize, Debug, Clone, PartialEq at minimum)
   - 2: Enum defined with variants but missing some derives
   - 1: Enum defined but structurally incorrect
   - 0: No enum defined

2. **Serde PascalCase serialization** (0-2): Does JSON serialization produce "Always" and "Halted"?
   - 2: Uses `#[serde(rename_all = "PascalCase")]` or individual renames producing correct JSON names
   - 1: Serde annotation present but incorrect (would produce wrong JSON)
   - 0: No serde configuration for the enum

3. **Default variant** (0-2): Is Halted the default?
   - 2: `#[default]` on Halted variant, or `#[derive(Default)]` with impl, or `#[serde(default = "...")]` producing Halted
   - 1: Default mentioned in comment but not implemented
   - 0: No default configured

4. **Validator removed** (0-2): Is validate_run_strategy absent?
   - 2: No validate_run_strategy function in the output
   - 1: validate_run_strategy commented out
   - 0: validate_run_strategy still present

Minimum acceptable: 7/9
