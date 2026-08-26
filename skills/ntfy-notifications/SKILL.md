---
name: ntfy-notifications
description: "Use when sending a notification to ntfy from a homelab service, loop, or agent. Covers the canonical in-cluster publish pattern and the silent-failure trap of posting to the Authentik-gated public URL."
allowed-tools: Bash
injectable: true
---

# ntfy Notifications

Publish notifications by POSTing to the in-cluster ntfy service. Never publish to the public URL — it is behind Authentik forward-auth and silently swallows POSTs.

## Prerequisites

You need network reach to the ntfy Service in the `ntfy` namespace. Any of the following works:

- Inside the cluster (a pod, a Job, a HelmRelease's webhook target).
- A claude-worker VM whose resolver points at cluster DNS.
- The bare-metal host running the k3s tooling (resolves cluster DNS via the kubelet config).

If you have a kubectl context for the homelab cluster you almost certainly also have network reach — those two travel together here.

## Default pattern — in-cluster DNS

Use this from any pod, any Alertmanager/incident-responder webhook, and any agent or loop running on a host that resolves cluster DNS.

```bash
curl -fsS -X POST \
  -H "Title: <title>" \
  -H "Tags: <tag>" \
  -H "Priority: <prio>" \
  -d "<body>" \
  http://ntfy.ntfy.svc.cluster.local/<topic>
```

A successful publish returns a JSON body with an `"id"` field and exit 0.

## Fallback pattern — ClusterIP

Use only when the caller has cluster network reach but cannot resolve cluster DNS (e.g. a host cron job whose `/etc/resolv.conf` does not point at the cluster resolver).

```bash
curl -fsS -X POST \
  -H "Title: <title>" \
  -H "Tags: <tag>" \
  -H "Priority: <prio>" \
  -d "<body>" \
  http://10.43.19.253/<topic>
```

The ClusterIP is not stable across Service recreation. Re-check with `kubectl get svc -n ntfy ntfy` if you suspect drift.

## Topics

Reuse the existing topics. Do not invent new ones unless there is a clear reason — and if you do, add a one-line entry to this table in the same change.

| Topic | Used by |
|---|---|
| `homelab-improvements` | improvement loop, DevEx Monitor |
| `homelab-alerts` | Alertmanager, incident-responder |

## Header conventions

| Header | Values used in this repo |
|---|---|
| `Title` | Short human-readable subject |
| `Tags` | Emoji shortcodes — `wrench`, `white_check_mark`, `warning`, etc. |
| `Priority` | `min`, `default`, `high` |

## Known gotchas

**Do not POST to `https://ntfy.sammasak.dev/<topic>`.** The public URL is fronted by Traefik with the `authentik-authentik-forward-auth@kubernetescrd` middleware (Pattern A). An unauthenticated POST is 302-redirected to `/outpost.goauthentik.io/start?...`, curl reports exit 0, and the message is silently dropped. The public hostname is for *subscribing* (mobile app, browser) — not publishing. (Source: `~/homelab-improvement-loop/loop.log`, May 2026, four consecutive passes lost notifications this way.)

**Prefer the DNS form over the ClusterIP.** `10.43.19.253` is the ClusterIP at the time of writing but is not stable across Service recreation. Re-check with `kubectl get svc -n ntfy ntfy` if a fallback is needed.

**Use `curl -fsS`, not `curl -s`.** `-s` swallows errors and the 302 above will look like success. `-f` makes non-2xx responses produce a non-zero exit so the failure surfaces.

## Verification

```bash
kubectl get svc -n ntfy ntfy
# expect: a ClusterIP set on port 80, type ClusterIP

curl -fsS -X POST -H "Title: skill verify" -d "ok" \
  http://ntfy.ntfy.svc.cluster.local/homelab-improvements
# expect: JSON body containing "id", exit 0
```
