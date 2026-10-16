# ChatGPT prompt for pi-ticket issues

Paste this into ChatGPT after the plan. Save each body it returns (between the `~~~` lines) to a file and lint it (`pi-ticket lint ... --body-file`) before filing.

````text
Turn the plan above into small GitHub issues for a coding agent that only does
mechanical work against a machine check. Rules:

1. One behaviour per issue. If a step touches more than 3 files or about 150
   changed lines, split it into several issues. When an issue needs an earlier
   one, end its Out of scope section with the line "Blocked by #<k>"
   (k = that issue's number in your list).
2. For each issue, emit a title line, a labels line, then the issue body inside
   one ~~~markdown fence (tildes, so the inner ``` block survives), exactly in
   this shape:

Title: <short imperative title>
Labels: <size:xs|size:s>, risk:low

~~~markdown
## Goal
<one sentence: the behaviour. Optionally one more sentence: why.>

## Acceptance criteria
- [ ] <checkable on its own, ideally one test assertion>
- [ ] <...>

## Verification
```bash
<exact commands, e.g. cd <project> && devenv tasks run sdlc:test>
```

## Files in scope
- `<path>`
- `<path>` (at most 3 paths)

## Out of scope
<what must not change>

## Budget
Rounds: 3. Check timeout: 900s.

## Prepared branch
<!-- optional: written by pi-ticket prepare (branch name + red sha). -->
~~~

3. Keep all 7 "## " headings, in this order, with these exact names. No other
   headings. Leave Prepared branch as the comment only.
4. size:xs = at most 1 file and 50 lines; size:s = at most 3 files and 150 lines.
   Always risk:low. If a step is security, secrets, a wire format, a deploy or
   design work, do not make it an issue: list it separately as "not for the agent".
5. Use only file paths that appear in the plan or that I gave you. If unsure,
   say so after the issue instead of guessing.
````

## Example body

````markdown
## Goal
`GET /healthz` returns 200 with body `ok`. Why: probes need a cheap liveness route.

## Acceptance criteria
- [ ] `route("GET /healthz HTTP/1.1")` returns status 200.
- [ ] The response body is exactly `ok`.

## Verification
```bash
cd examples/rust-service && devenv tasks run sdlc:test
```

## Files in scope
- `examples/rust-service/src/main.rs`

## Out of scope
Other routes, the OpenAPI file, dependencies.

## Budget
Rounds: 3. Check timeout: 900s.

## Prepared branch
<!-- optional: written by pi-ticket prepare (branch name + red sha). -->
````
