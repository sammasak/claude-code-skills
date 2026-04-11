---
name: verify-service
description: "Use after deploying any service to confirm it is live and healthy before marking a goal done. Covers HTTP health checks, Kubernetes pod status, and Playwright browser verification for UI apps."
allowed-tools: Bash, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_wait_for
---

# Verify Service

**CRITICAL: Never mark a goal done before completing at least Tier 1 verification.** A command that exits 0 proves the request was submitted — not that the service is healthy.

**CRITICAL: Use dedicated health endpoints, not `/`.** `GET /` can return 200 while the service is degraded. Use `/healthz`, `/readyz`, or the app's documented endpoint.

## Tiers

| Tier | Use when | Tools |
|------|----------|-------|
| 1 — HTTP check | Any service with an HTTP endpoint | `curl` |
| 2 — Standard | Kubernetes-deployed web service | `curl` + `kubectl` |
| 3 — Thorough | App with a frontend / web UI | `curl` + `kubectl` + Playwright |

---

## Tier 1 — HTTP Check

```bash
curl -s -w "%{http_code}\n" -o /dev/null https://<domain>   # must print 200
curl -s https://<domain>/readyz | jq .
```

---

## Tier 2 — Standard (Kubernetes)

Run in order. All three must pass.

```bash
# 1. Pod status — all Running, READY n/n
kubectl get pods -n <namespace> -o wide

# 2. Rollout complete
kubectl rollout status deployment/<name> -n <namespace> --timeout=120s

# 3. HTTP reachable
curl -s -w "%{http_code}\n" -o /dev/null https://<domain>
```

If pods are stuck:
```bash
kubectl describe pod -n <namespace> <pod-name>
kubectl logs -n <namespace> <pod-name> --previous
```

---

## Tier 3 — Thorough (UI + Playwright)

The Playwright MCP browser starts automatically on `browser_navigate`.

1. `browser_navigate` → `url="https://<domain>"`
2. `browser_snapshot` → verify expected text/elements are present (**assertion**)
3. `browser_take_screenshot` → capture as evidence
4. `browser_wait_for` → use before snapshot if page loads data asynchronously

---

## Quick Delegation — `verify-deployment` Sub-Agent

For Tier 1+2 without Playwright:
```
Use the verify-deployment agent to check that <appname> in namespace <appname>
is healthy and https://<appname>.sammasak.dev returns HTTP 200.
```

Use Tier 3 directly when UI verification is needed.

---

## Anti-Patterns

| Don't | Why |
|-------|-----|
| Claim success after `kubectl apply` | Apply submits intent — pods may fail to start |
| Use `curl -k` to skip TLS | Hides cert-manager failures |
| Assert HTTP 200 alone for UI apps | App can return 200 with an error page |
| Skip verification for "just a config change" | Config changes break things too |
