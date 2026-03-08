# Quality Rubric — Task 2 (WorkspaceName newtype)

Evaluate the generated Rust code on:

1. **Private inner field** (0-3): Is the inner String field private, enforcing construction through the validator?
   - 3: Struct field is private (no `pub` on the inner field), struct itself may be pub
   - 2: Field is private but struct is also private (prevents external use)
   - 1: Field is pub but comment explains it should be private
   - 0: Field is public — anyone can bypass validation

2. **Constructor returns Result** (0-2): Is there a fallible constructor?
   - 2: `fn new(s: &str) -> Result<Self, ...>` or `fn try_from` or `fn from_str` returning Result
   - 1: Constructor exists but doesn't return Result (panics instead)
   - 0: No constructor provided

3. **AsRef<str> implementation** (0-2): Is AsRef<str> (or Deref) implemented?
   - 2: `impl AsRef<str> for WorkspaceName` correctly implemented
   - 1: AsRef implemented but with wrong target type
   - 0: No AsRef or Deref implementation

4. **Validation logic** (0-2): Does it actually validate the name?
   - 2: Checks length (>0 and <=63), character set (alphanumeric + hyphen), no leading/trailing hyphen
   - 1: Validates some but not all RFC 1123 rules
   - 0: No validation — constructor just wraps the string

Minimum acceptable: 7/9
