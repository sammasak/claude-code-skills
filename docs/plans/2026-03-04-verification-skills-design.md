# Verification Skills Design — 2026-03-04

## Problem

Agents have no structured guidance for verifying deployments beyond a minimal `verify-deployment` sub-agent (kubectl + curl only). Playwright MCP is configured on physical hosts but uses `npx @playwright/mcp@latest` at runtime — unreliable on VMs without guaranteed internet access.

## Solution

Two new skills + fix Playwright delivery on VMs.

---

## Skill 1: `verify-service`

**Purpose:** Confirm a deployed service is alive and healthy before marking a goal done.

**Trigger:** After any deployment (pod apply, Flux reconcile, docker run, etc.).

**Tiered approach:**

| Tier | When to use | Tools |
|------|-------------|-------|
| Quick | APIs, health endpoints | `curl -sf -w "%{http_code}"` → 200 |
| Standard | Any web service | curl + `kubectl rollout status` + pod check |
| Thorough | UI-heavy / frontend apps | Playwright: navigate → snapshot → screenshot |

**Content:**
- Decision matrix (which tier to use)
- Curl patterns with exact flags and expected output
- kubectl rollout + pod status patterns
- Playwright navigation + accessibility snapshot for content assertion
- Screenshot for evidence (not for assertion)
- "Not done until verified" rule — explicit tie to Definition of Done
- Relationship to `verify-deployment` sub-agent (use for quick delegation)

---

## Skill 2: `e2e-testing`

**Purpose:** Write and run E2E test scenarios against a running service using Playwright MCP tools.

**Trigger:** When verifying user flows, not just availability.

**Patterns:**
- Navigate + snapshot (accessibility tree = preferred assertion mechanism)
- Form fill + submit (`browser_fill_form`, `browser_click`)
- Multi-step flows (login → action → confirm result)
- Wait for content (`browser_wait_for`)
- Screenshot as evidence, not as assertion
- Reporting format: scenario name, steps, pass/fail, screenshots

**Anti-patterns:**
- Don't use screenshots to assert content (use snapshot/accessibility tree)
- Don't assert on CSS classes or internal IDs
- Don't skip waits between navigation and assertion

---

## Playwright on VMs — Fix

**Problem:** `mcp.nix` uses `exec npx @playwright/mcp@latest` which downloads the package at MCP server startup. Fails or stalls when VM has no internet access.

**Fix:** Replace with `pkgs.playwright-mcp` from nixpkgs (v0.0.56). Pinned, reproducible, baked into the golden image.

Change in `modules/programs/cli/claude-code/mcp.nix`:
```nix
# Before
command = "sh";
args = [ "-c" ''exec npx @playwright/mcp@latest --headless --browser chromium --executable-path "$(which chromium)"'' ];

# After
command = "${pkgs.playwright-mcp}/bin/mcp-server-playwright";
args = [ "--headless" "--executable-path" "${pkgs.chromium}/bin/chromium" ];
```

Requires golden image rebuild after nixos-config change.

---

## Files to Create/Modify

| File | Repo | Action |
|------|------|--------|
| `skills/verify-service/SKILL.md` | claude-code-skills | Create |
| `skills/e2e-testing/SKILL.md` | claude-code-skills | Create |
| `modules/programs/cli/claude-code/mcp.nix` | nixos-config | Edit — switch to pkgs.playwright-mcp |
| golden image | nixos-config | Rebuild + publish |
