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
