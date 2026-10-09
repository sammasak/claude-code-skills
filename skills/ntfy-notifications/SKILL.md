---
name: ntfy-notifications
description: "Use when sending a notification to ntfy from a homelab service, loop, script, or agent."
allowed-tools: Bash
---

# ntfy Notifications

ntfy runs in namespace `ntfy` on the control-plane node (`lenovo`) and is the paging path. It is **deliberately unauthenticated** (no Authentik forward-auth since 2026-08-26, so pages still deliver when SSO is down); `ntfy.sammasak.dev` resolves only on LAN/tailnet. Do not add auth middleware to it.

## Publish

Pick the URL by where the caller runs:

| Caller | URL |
|---|---|
| pod, Job, Alertmanager/incident-responder webhook, host resolving cluster DNS | `http://ntfy.ntfy.svc.cluster.local/<topic>` (preferred) |
| LAN or tailnet host without cluster DNS | `https://ntfy.sammasak.dev/<topic>` |
| cluster network reach, no DNS at all | `http://10.43.19.253/<topic>` (ClusterIP, not stable across Service recreation; re-check with `kubectl get svc -n ntfy ntfy`) |

```bash
curl -fsS -X POST -H "Title: <title>" -H "Tags: <tag>" -H "Priority: <prio>" -d "<body>" <url>
```

Success is exit 0 with a JSON body containing `"id"`. Use `-f`: with plain `-s` a redirect or error page (e.g. if someone re-adds auth) looks like success.

## Topics

Reuse existing topics; if you add one, add a row here in the same change.

| Topic | Used by |
|---|---|
| `homelab-alerts` | Alertmanager (via `alertmanager-ntfy-bridge`), incident-responder |
| `homelab-improvements` | improvement/DevEx loops |

Headers: `Title` short subject; `Tags` emoji shortcodes (`wrench`, `white_check_mark`, `warning`); `Priority` `min` / `default` / `high`.
