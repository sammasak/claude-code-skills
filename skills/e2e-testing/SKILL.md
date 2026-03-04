---
name: e2e-testing
description: "Use when verifying user flows in a running web application using Playwright MCP tools. Covers navigation, form interaction, multi-step flows, and evidence collection."
allowed-tools: mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_press_key
---

# E2E Testing with Playwright

Use when you need to verify that a user flow works in a running service, not just that it returns HTTP 200.

## Core Rule

**Use the accessibility snapshot (`browser_snapshot`) for assertions, not screenshots.** Screenshots are evidence. The snapshot gives you the page's semantic structure (roles, labels, text) — this is what you assert against.

The Playwright MCP browser session starts automatically when you call `browser_navigate` — no explicit initialization needed.

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

Before navigating, identify 1-2 text fragments you expect to see on a successful page (e.g., page title, main heading). These are your assertions.

```
1. browser_navigate url="https://<domain>"
2. browser_wait_for text="<expected heading or title>"
3. browser_snapshot
   → Confirm expected text appears in snapshot output
4. browser_take_screenshot type="png"
   → Save as evidence
```

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
7. browser_take_screenshot type="png"
```

---

## Multi-Step Flow Pattern

```
1. Navigate to start page
2. Snapshot → identify first action target (note its ref)
3. Click / fill / interact using that ref
4. Wait for next state (browser_wait_for)
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
  2. Waited for "<heading>" — PASS
  3. Found heading "<text>" in snapshot — PASS
  4. Filled login form — OK
  5. Clicked Submit — OK
  6. Waited for "Dashboard" — PASS
  7. Screenshot saved: <path>

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
| Use `ref` values across sessions | Refs are ephemeral — re-snapshot before each interaction |
