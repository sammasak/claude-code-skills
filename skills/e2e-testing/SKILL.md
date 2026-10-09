---
name: e2e-testing
description: "Use when verifying a user flow in a running web app through the browser, beyond an HTTP status check."
allowed-tools: mcp__plugin_hm_playwright__browser_navigate, mcp__plugin_hm_playwright__browser_snapshot, mcp__plugin_hm_playwright__browser_take_screenshot, mcp__plugin_hm_playwright__browser_click, mcp__plugin_hm_playwright__browser_type, mcp__plugin_hm_playwright__browser_fill_form, mcp__plugin_hm_playwright__browser_wait_for, mcp__plugin_hm_playwright__browser_press_key, mcp__plugin_hm_playwright-login__browser_navigate, mcp__plugin_hm_playwright-login__browser_snapshot, mcp__plugin_hm_playwright-login__browser_take_screenshot, mcp__plugin_hm_playwright-login__browser_click, mcp__plugin_hm_playwright-login__browser_type, mcp__plugin_hm_playwright-login__browser_fill_form, mcp__plugin_hm_playwright-login__browser_wait_for, mcp__plugin_hm_playwright-login__browser_press_key
---

# E2E Testing (homelab Playwright MCP)

Two Playwright MCP servers are installed (from `nixos-config/modules/programs/cli/claude-code/mcp.nix`):

| Server | Tool prefix | Use for |
|---|---|---|
| `playwright` | `mcp__plugin_hm_playwright__` | default: headless, isolated, fresh profile every session |
| `playwright-login` | `mcp__plugin_hm_playwright-login__` | sites that need a signed-in session: headed window, cookies persisted in `~/.local/share/claude-playwright-login/state.json` |

Apps whose Ingress carries the Authentik forward-auth middleware (and apps doing their own Authentik OIDC) send the headless server to the `auth.sammasak.dev` login page. Use `playwright-login` for gated apps (the user completes the login once in the headed window), or assert against an un-gated route.

## Method

- Assert on `browser_snapshot` (accessibility tree); screenshots are evidence only.
- `browser_wait_for` the expected text before asserting; scale-to-zero apps can take seconds to cold-start.
- Refs are per-snapshot; re-snapshot before each interaction.
- Never run destructive flows against a real account.

Report per scenario: numbered steps with PASS/FAIL, the screenshot path, and the failure detail.
