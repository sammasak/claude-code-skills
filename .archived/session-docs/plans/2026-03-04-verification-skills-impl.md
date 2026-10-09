# Verification Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add two skills (`verify-service`, `e2e-testing`) for deployment verification and E2E testing, and fix Playwright delivery on VMs by switching from `npx @playwright/mcp@latest` to the pinned `pkgs.playwright-mcp` Nix package.

**Architecture:** Skills are SKILL.md files in `~/claude-code-skills/skills/<name>/` — auto-symlinked everywhere via `skills.nix`. The `mcp.nix` change replaces a runtime npm download with a baked-in binary, making Playwright available offline on VMs. Both changes are independent (skill content vs NixOS config).

**Tech Stack:** Bash, Nix/NixOS Home Manager, `pkgs.playwright-mcp` (nixpkgs), Playwright MCP tools

**Repos:**
- `~/claude-code-skills` — skills content (push to `main`)
- `~/nixos-config` — NixOS config (push to `homelab` branch)

---

## Task 1: Create `verify-service` skill

**Files:**
- Create: `~/claude-code-skills/skills/verify-service/SKILL.md`

### Step 1: Create the skill file

```bash
mkdir -p ~/claude-code-skills/skills/verify-service
```

Write `~/claude-code-skills/skills/verify-service/SKILL.md`:

```markdown
---
name: verify-service
description: "Use after deploying any service to confirm it is live and healthy before marking a goal done. Covers HTTP health checks, Kubernetes pod status, and Playwright browser verification for UI apps."
allowed-tools: Bash, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_wait_for
---

# Verify Service

**Rule:** A deployment is not done until the service is live and verified end-to-end. Never mark a goal `done` without completing at least Tier 1.

## Tiers

Choose based on what you deployed:

| Tier | Use when | Tools |
|------|----------|-------|
| 1 — HTTP check | Any service with an HTTP endpoint | `curl` |
| 2 — Standard | Kubernetes-deployed web service | `curl` + `kubectl` |
| 3 — Thorough | App with a frontend / web UI | `curl` + `kubectl` + Playwright |

---

## Tier 1 — HTTP Check

```bash
# Returns HTTP status code. Must be 200.
curl -sf -o /dev/null -w "%{http_code}\n" https://<domain>
```

Pass: prints `200`
Fail: anything else, or `curl: (6) Could not resolve host`

For services with a health endpoint:
```bash
curl -sf https://<domain>/healthz | jq .
# or
curl -sf https://<domain>/readyz | jq .
```

---

## Tier 2 — Standard (Kubernetes)

Run in order. All three must pass.

**1. Pod status:**
```bash
kubectl get pods -n <namespace> -o wide
# All pods: Running, READY n/n
```

**2. Rollout complete:**
```bash
kubectl rollout status deployment/<name> -n <namespace> --timeout=120s
# Expected: "successfully rolled out"
```

**3. HTTP reachable:**
```bash
curl -sf -o /dev/null -w "%{http_code}\n" https://<domain>
# Expected: 200
```

If pods are stuck:
```bash
kubectl describe pod -n <namespace> <pod-name>
kubectl logs -n <namespace> <pod-name> --previous
```

---

## Tier 3 — Thorough (UI verification with Playwright)

Use the Playwright MCP tools to navigate to the deployed service, confirm the page renders expected content, and capture a screenshot as evidence.

**Step 1: Navigate to the service**
```
Use mcp__plugin_playwright_playwright__browser_navigate with url="https://<domain>"
```

**Step 2: Capture accessibility snapshot**
```
Use mcp__plugin_playwright_playwright__browser_snapshot
```
Inspect the snapshot — verify key text/elements are present (page title, main heading, expected content). This is the assertion. If expected elements are missing, the deployment has a content problem even if HTTP returns 200.

**Step 3: Take screenshot as evidence**
```
Use mcp__plugin_playwright_playwright__browser_take_screenshot with type="png"
```
Attach or log the screenshot path. This is evidence, not assertion.

**Step 4: Wait for dynamic content if needed**
```
Use mcp__plugin_playwright_playwright__browser_wait_for with text="<expected text>"
```
Use this before snapshot if the page loads data asynchronously.

---

## Quick Delegation — `verify-deployment` Sub-Agent

For Tier 1+2 without Playwright, delegate to the `verify-deployment` sub-agent:

```
Use the verify-deployment agent to check that <appname> in namespace <appname>
is healthy and https://<appname>.sammasak.dev returns HTTP 200.
```

Use Tier 3 directly (Playwright MCP tools) when UI verification is needed — the sub-agent does not support browser checks.

---

## Report Format

After verifying, always report:

```
Verification result:
- Pod status: PASS (2/2 Running) / FAIL (<reason>)
- HTTP status: PASS (200) / FAIL (<code or error>)
- UI content: PASS (found "<text>") / SKIP / FAIL (<what was missing>)
- Screenshot: <path or "not taken">

Overall: PASS / FAIL
```

Do not mark the goal done if Overall is FAIL.

---

## Anti-Patterns

| Don't | Why |
|-------|-----|
| Claim "deployed successfully" after `kubectl apply` | Apply does not mean running — pods may fail to start |
| Use `curl -k` to skip TLS verification | Hides cert-manager failures; always verify TLS |
| Assert on HTTP 200 alone for UI apps | App can return 200 with an error page |
| Skip verification when "it's just a config change" | Config changes break things too |
```

### Step 2: Verify the file exists and has correct frontmatter

```bash
head -10 ~/claude-code-skills/skills/verify-service/SKILL.md
# Expected: --- frontmatter block with name, description, allowed-tools
```

### Step 3: Commit

```bash
cd ~/claude-code-skills
git add skills/verify-service/
git commit -m "feat(skills): add verify-service skill with tiered HTTP/k8s/Playwright checks"
```

---

## Task 2: Create `e2e-testing` skill

**Files:**
- Create: `~/claude-code-skills/skills/e2e-testing/SKILL.md`

### Step 1: Create the skill file

```bash
mkdir -p ~/claude-code-skills/skills/e2e-testing
```

Write `~/claude-code-skills/skills/e2e-testing/SKILL.md`:

```markdown
---
name: e2e-testing
description: "Use when verifying user flows in a running web application using Playwright MCP tools. Covers navigation, form interaction, multi-step flows, and evidence collection."
allowed-tools: mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_press_key
---

# E2E Testing with Playwright

Use when you need to verify that a user flow works in a running service, not just that it returns HTTP 200.

## Core Rule

**Use the accessibility snapshot (`browser_snapshot`) for assertions, not screenshots.** Screenshots are evidence. The snapshot gives you the page's semantic structure (roles, labels, text) — this is what you assert against.

---

## Playwright MCP Tool Reference

| Tool | When to use |
|------|-------------|
| `browser_navigate` | Go to a URL |
| `browser_snapshot` | Capture accessibility tree — use for assertions |
| `browser_take_screenshot` | Capture visual evidence — not for assertions |
| `browser_wait_for` | Wait for text to appear before asserting |
| `browser_click` | Click a button or link (use `ref` from snapshot) |
| `browser_type` | Type into a focused input field |
| `browser_fill_form` | Fill multiple form fields at once |
| `browser_press_key` | Press a key (Enter, Tab, Escape, ArrowDown) |

---

## Basic Pattern: Navigate and Assert

```
1. browser_navigate url="https://<domain>"
2. browser_snapshot
   → Inspect result for expected elements/text
3. browser_take_screenshot type="png"
   → Save as evidence
```

Assert by inspecting snapshot output for expected text or role. Example: if the snapshot contains `heading "Service Status"` and `text "All systems operational"`, the page rendered correctly.

---

## Form Interaction Pattern

```
1. browser_navigate url="https://<domain>/login"
2. browser_snapshot
   → Find refs for username/password fields and submit button
3. browser_fill_form fields=[
     {name: "username", type: "textbox", ref: "<ref>", value: "testuser"},
     {name: "password", type: "textbox", ref: "<ref>", value: "testpass"}
   ]
4. browser_click ref="<submit-button-ref>"
5. browser_wait_for text="Welcome"
6. browser_snapshot
   → Assert "Welcome testuser" or similar is present
7. browser_take_screenshot
```

---

## Multi-Step Flow Pattern

```
1. Navigate to start page
2. Snapshot → identify first action target
3. Click / fill / interact
4. Wait for next state
5. Snapshot → assert expected state
6. Repeat for each step
7. Final screenshot as evidence
```

---

## Reporting

After each E2E test scenario, report:

```
E2E scenario: <scenario name>
Steps:
  1. Navigate to https://<domain> — OK
  2. Found heading "<text>" in snapshot — PASS
  3. Filled login form — OK
  4. Clicked Submit — OK
  5. Waited for "Dashboard" — PASS
  6. Screenshot saved: <path>

Result: PASS / FAIL
Failure detail: <what was missing or wrong>
```

---

## Anti-Patterns

| Don't | Why |
|-------|-----|
| Assert on CSS classes or `aria-*` internal IDs | Brittle — breaks on style changes |
| Use screenshot pixels to assert content | Use snapshot (semantic) instead |
| Skip `browser_wait_for` after navigation | Dynamic content may not be loaded yet |
| Run E2E against production on destructive flows | Use a test account or staging |
| Assert on exact layout ("button is at position X") | Layout changes break tests; assert semantics |
```

### Step 2: Verify the file exists and has correct frontmatter

```bash
head -10 ~/claude-code-skills/skills/e2e-testing/SKILL.md
# Expected: --- frontmatter block with name, description, allowed-tools
```

### Step 3: Commit

```bash
cd ~/claude-code-skills
git add skills/e2e-testing/
git commit -m "feat(skills): add e2e-testing skill with Playwright MCP patterns"
```

### Step 4: Push both skills

```bash
cd ~/claude-code-skills
git push
```

---

## Task 3: Fix `mcp.nix` — switch to `pkgs.playwright-mcp`

**Files:**
- Modify: `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`

### Step 1: Read current mcp.nix

```bash
cat ~/nixos-config/modules/programs/cli/claude-code/mcp.nix
```

Current playwright MCP config (lines ~27-35):
```nix
playwright = {
  type = "stdio";
  command = "sh";
  args = [
    "-c"
    ''exec npx @playwright/mcp@latest --headless --browser chromium --executable-path "$(which chromium)"''
  ];
};
```

### Step 2: Replace with pkgs.playwright-mcp

Edit `~/nixos-config/modules/programs/cli/claude-code/mcp.nix`, replacing the playwright MCP block:

```nix
playwright = {
  type = "stdio";
  command = "${pkgs.playwright-mcp}/bin/mcp-server-playwright";
  args = [];
};
```

The `pkgs.playwright-mcp` wrapper sets `PLAYWRIGHT_BROWSERS_PATH` and uses chromium from `playwright-driver.browsers` internally — no extra arguments needed.

### Step 3: Verify the NixOS config builds

```bash
cd ~/nixos-config
nix build .#nixosConfigurations.lenovo-21CB001PMX.config.system.build.toplevel --no-link
# Expected: build succeeds, no errors
```

If the build fails with "playwright-mcp not found", run `nix flake update` to get the latest nixpkgs.

### Step 4: Apply to local host

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#lenovo-21CB001PMX
```

### Step 5: Verify settings.json updated

```bash
cat ~/.claude/settings.json | jq .mcpServers.playwright
# Expected:
# {
#   "type": "stdio",
#   "command": "/nix/store/...-playwright-mcp-.../bin/mcp-server-playwright",
#   "args": []
# }
```

The command path should be a `/nix/store/...` path, not `sh`.

### Step 6: Smoke-test playwright MCP works

Start the MCP server manually to confirm it launches:
```bash
$(cat ~/.claude/settings.json | jq -r .mcpServers.playwright.command) 2>&1 | head -3
# Expected: server starts, shows "Listening on stdio" or similar (Ctrl-C to exit)
```

### Step 7: Commit and push nixos-config

```bash
cd ~/nixos-config
git add modules/programs/cli/claude-code/mcp.nix
git commit -m "fix(claude-code): use pkgs.playwright-mcp instead of npx for MCP server"
git push origin homelab
```

---

## Task 4: Rebuild and publish golden image

**Prereq:** Harbor node (`192.168.10.200`) must be online. Check first:
```bash
kubectl get pod -n harbor | grep -v Running
# If any pods not Running, Harbor is down — skip this task until Harbor is back
```

### Step 1: Build and publish

```bash
cd ~/nixos-config
just release-agent latest
# This builds the qcow2 image and pushes OCI to registry.sammasak.dev/agents/claude-worker:latest
# Takes 10-20 minutes on first build
```

### Step 2: Verify image pushed

```bash
curl -s https://registry.sammasak.dev/v2/agents/claude-worker/tags/list | jq .
# Expected: {"name":"agents/claude-worker","tags":["latest"]}
```

### Step 3: (Optional) Smoke-test on a fresh VM

```bash
claude-ctl provision verify-playwright --goal "Use the e2e-testing skill to navigate to https://status.sammasak.dev and take a screenshot. Report what you see." --watch
```

Expected: agent navigates, takes screenshot, reports content of the status page.

---

## Verification

After all tasks complete:

1. `ls ~/.claude/skills/` — should show `verify-service` and `e2e-testing`
2. `cat ~/.claude/skills/verify-service/SKILL.md | head -5` — frontmatter present
3. `cat ~/.claude/settings.json | jq .mcpServers.playwright.command` — should be a `/nix/store/` path
4. New VMs provisioned after golden image rebuild will have Playwright available offline
